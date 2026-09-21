<#
.SYNOPSIS
    从私有源码树构建 ITHome WinUI 的发布产物（绿色版 zip + MSIX）。

.DESCRIPTION
    本脚本属于「公开门面仓」的编排层，不进入源码仓。源码由 workflow 从私有仓
    只读检出后，通过 -SourceRoot 指向其本地路径。

    两个已知的 publish 管线缺口由本脚本在编排层补齐（不改源码仓）：
      1. dotnet publish 只拷贝带显式 CopyToOutputDirectory 元数据的 Content，
         导致 Assets\{ArticleGrade,Emotion,Nav,Quan} 缺失（表情、导航图标、
         圈子图标运行时读不到）。
      2. 非打包自举依赖的 ITHomeWinUI.exe.manifest 由 Build 后置 Target 写到
         $(OutDir)，publish 的 OutDir 不指向 publish 目录，故产物中缺失。

.PARAMETER SourceRoot
    私有源码检出根目录（应包含 ITHome_For_WinUI/ITHomeWinUI/ITHomeWinUI.csproj）。

.PARAMETER OutputDir
    产物与暂存目录。默认 <当前目录>/release-output。

.PARAMETER CertificatePath
    PFX 证书路径。提供则对 MSIX 签名；缺省则产出未签名 MSIX。
    证书 Subject 必须与 Package.appxmanifest 的 Identity/@Publisher 完全一致。
#>
[CmdletBinding()]
param(
    [string]$SourceRoot = "",
    [ValidateSet("x64", "ARM64")]
    [string]$Platform = "x64",
    [string]$OutputDir = "release-output",
    [string]$Version = "",
    [string]$CertificatePath = "",
    [string]$CertificatePassword = "",
    [string]$TimestampUrl = "",
    [switch]$SkipPortable,
    [switch]$SkipMsix
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Resolve-FullPath {
    param([Parameter(Mandatory)][string]$Path, [string]$Base = (Get-Location).Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return [System.IO.Path]::GetFullPath((Join-Path $Base $Path))
}

# 从 NuGet 缓存 / Windows Kits 定位 signtool.exe，避免依赖 PATH。
function Find-SignTool {
    $candidates = @()

    $nugetRoot = Join-Path $env:USERPROFILE ".nuget\packages\microsoft.windows.sdk.buildtools"
    if (Test-Path -LiteralPath $nugetRoot) {
        $candidates += Get-ChildItem -LiteralPath $nugetRoot -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName "bin" } |
            Where-Object { Test-Path -LiteralPath $_ } |
            ForEach-Object { Get-ChildItem -LiteralPath $_ -Directory -ErrorAction SilentlyContinue } |
            ForEach-Object { Join-Path $_.FullName "x64\signtool.exe" }
    }

    $kitsRoot = "C:\Program Files (x86)\Windows Kits\10\bin"
    if (Test-Path -LiteralPath $kitsRoot) {
        $candidates += Get-ChildItem -LiteralPath $kitsRoot -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName "x64\signtool.exe" }
    }

    $found = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Sort-Object -Unique
    if (-not $found) { return $null }
    return $found[-1]
}

# 把源码树的 Assets 逐文件补齐到 publish 产物中缺失的位置。
function Restore-PublishAssets {
    param(
        [Parameter(Mandatory)][string]$SourceAssets,
        [Parameter(Mandatory)][string]$TargetRoot
    )

    if (-not (Test-Path -LiteralPath $SourceAssets)) {
        throw "Source Assets directory not found: $SourceAssets"
    }

    $targetAssets = Join-Path $TargetRoot "Assets"
    $copied = 0
    Get-ChildItem -LiteralPath $SourceAssets -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($SourceAssets.Length).TrimStart('\')
        $destination = Join-Path $targetAssets $relative
        $destinationDir = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $destinationDir)) {
            New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
        }
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
        $copied++
    }
    return $copied
}

# ---------------------------------------------------------------------------
# 路径与版本解析
# ---------------------------------------------------------------------------

$scriptRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $scriptRoot

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    throw "-SourceRoot is required (path to the private source checkout)."
}
$SourceRoot = Resolve-FullPath $SourceRoot
if (-not (Test-Path -LiteralPath $SourceRoot)) {
    throw "SourceRoot does not exist: $SourceRoot"
}

$projectPath = Join-Path $SourceRoot "ITHome_For_WinUI\ITHomeWinUI\ITHomeWinUI.csproj"
if (-not (Test-Path -LiteralPath $projectPath)) {
    throw "Project not found under SourceRoot: $projectPath"
}

$projectDir = Split-Path -Parent $projectPath
$manifestPath = Join-Path $projectDir "Package.appxmanifest"
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Package.appxmanifest not found: $manifestPath"
}

[xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
$ns = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
$ns.AddNamespace("m", "http://schemas.microsoft.com/appx/manifest/foundation/windows10")
$identity = $manifest.SelectSingleNode("/m:Package/m:Identity", $ns)
if ($null -eq $identity) { throw "Manifest Identity node is missing." }

$manifestVersion = [string]$identity.Version
$publisher = [string]$identity.Publisher
if ([string]::IsNullOrWhiteSpace($Version)) { $Version = $manifestVersion }
if ($Version -notmatch "^\d+\.\d+\.\d+\.\d+$") {
    throw "Version must be four numeric parts: $Version"
}

$runtimeIdentifier = "win-$($Platform.ToLowerInvariant())"
$OutputDir = Resolve-FullPath $OutputDir

$summary = [ordered]@{
    SourceRoot = $SourceRoot
    Platform   = $Platform
    RuntimeId  = $runtimeIdentifier
    Version    = $Version
    Publisher  = $publisher
    OutputDir  = $OutputDir
    Portable   = ""
    Msix       = ""
    MsixSigned = $false
}
$summary.GetEnumerator() | ForEach-Object { "{0,-12} {1}" -f $_.Key, $_.Value }

if (Test-Path -LiteralPath $OutputDir) {
    Write-Step "Cleaning output directory"
    Get-ChildItem -LiteralPath $OutputDir -Recurse -Force -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Attributes = "Normal" }
    Remove-Item -LiteralPath $OutputDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$sourceAssets = Join-Path $projectDir "Assets"
$artifactBase = "ITHomeWinUI-$Version-windows-$Platform"

# ---------------------------------------------------------------------------
# 绿色版：publish -> 补齐 -> 打包 zip
# ---------------------------------------------------------------------------

if (-not $SkipPortable) {
    Write-Step "Publishing portable build ($Platform / $runtimeIdentifier)"
    $stageRoot = Join-Path $OutputDir "stage-portable"
    $portableDir = Join-Path $stageRoot "ITHomeWinUI"
    New-Item -ItemType Directory -Force -Path $portableDir | Out-Null

    # DebugType=none / DebugSymbols=false：不生成 PDB。
    # 本项目以「源码不公开」为前提分发二进制，携带 Portable PDB 会让 ILSpy/dnSpy
    # 等工具几乎无损还原出原始类型名、局部变量名与行号，等同于变相开源。
    dotnet publish $projectPath `
        -c Release `
        "-p:Platform=$Platform" `
        "-p:RuntimeIdentifier=$runtimeIdentifier" `
        "-p:Version=$Version" `
        "-p:FileVersion=$Version" `
        "-p:DebugType=none" `
        "-p:DebugSymbols=false" `
        -o $portableDir
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed with exit code $LASTEXITCODE" }

    Write-Step "Restoring Assets omitted by the publish pipeline"
    $assetCount = Restore-PublishAssets -SourceAssets $sourceAssets -TargetRoot $portableDir
    Write-Host "    assets present in package: $assetCount files"

    Write-Step "Restoring generated exe manifest"
    $manifestCandidates = Get-ChildItem -LiteralPath (Join-Path $projectDir "obj\$Platform\Release") `
        -Recurse -Filter "app.manifest" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match [regex]::Escape($runtimeIdentifier) }
    if (-not $manifestCandidates) {
        $manifestCandidates = Get-ChildItem -LiteralPath (Join-Path $projectDir "obj\$Platform\Release") `
            -Recurse -Filter "app.manifest" -File -ErrorAction SilentlyContinue
    }
    if (-not $manifestCandidates) {
        Write-Warning "Generated app.manifest not found; portable package may fail to self-bootstrap."
    }
    else {
        $exeManifest = ($manifestCandidates | Sort-Object LastWriteTime -Descending)[0].FullName
        Copy-Item -LiteralPath $exeManifest -Destination (Join-Path $portableDir "ITHomeWinUI.exe.manifest") -Force
        Write-Host "    copied: $exeManifest"
    }

    $exePath = Join-Path $portableDir "ITHomeWinUI.exe"
    if (-not (Test-Path -LiteralPath $exePath)) {
        throw "Portable build is missing ITHomeWinUI.exe: $portableDir"
    }

    # 兜底清扫：DebugType=none 只作用于本项目，依赖库自带的 PDB 仍会被复制过来。
    # 打包前物理删除，确保产物中不存在任何调试符号。
    Write-Step "Stripping debug symbols"
    $pdbFiles = @(Get-ChildItem -LiteralPath $portableDir -Filter "*.pdb" -Recurse -File -ErrorAction SilentlyContinue)
    if ($pdbFiles.Count -gt 0) {
        $pdbFiles | ForEach-Object { Write-Host "    removing: $($_.Name) ($([math]::Round($_.Length/1KB)) KB)" }
        $pdbFiles | Remove-Item -Force
    }
    else {
        Write-Host "    no PDB files found"
    }

    # 断言：产物中不得残留任何调试符号，否则直接失败而不是发出一个带符号的包
    $remaining = @(Get-ChildItem -LiteralPath $portableDir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @('.pdb', '.pdbx', '.mdb') })
    if ($remaining.Count -gt 0) {
        throw "Debug symbols still present in portable package: $($remaining.Name -join ', ')"
    }

    Write-Step "Compressing portable package"
    $zipPath = Join-Path $OutputDir "$artifactBase-portable.zip"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $stageRoot, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)

    Remove-Item -LiteralPath $stageRoot -Recurse -Force
    $summary.Portable = $zipPath
    Write-Host ("    {0} ({1:N1} MB)" -f (Split-Path -Leaf $zipPath), ((Get-Item $zipPath).Length / 1MB))
}

# ---------------------------------------------------------------------------
# MSIX：GenerateAppxPackageOnBuild -> 可选签名
# ---------------------------------------------------------------------------

if (-not $SkipMsix) {
    Write-Step "Building MSIX package ($Platform)"
    $appPackages = Join-Path $projectDir "AppPackages"
    if (Test-Path -LiteralPath $appPackages) {
        Get-ChildItem -LiteralPath $appPackages -Recurse -Force -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Attributes = "Normal" }
        Remove-Item -LiteralPath $appPackages -Recurse -Force
    }

    # WindowsPackageType=None 与 GenerateAppxPackageOnBuild=true 被
    # Microsoft.Windows.SDK.BuildTools.MSIX.Packaging.targets:404 明令禁止，
    # 故此处必须覆盖为 MSIX。源码仓的 csproj 保持非打包自包含形态不变。
    # DebugType=none / DebugSymbols=false 同绿色版：MSIX 也不得携带调试符号。
    dotnet build $projectPath `
        -c Release `
        "-p:Platform=$Platform" `
        "-p:RuntimeIdentifier=$runtimeIdentifier" `
        "-p:Version=$Version" `
        "-p:WindowsPackageType=MSIX" `
        "-p:GenerateAppxPackageOnBuild=true" `
        "-p:AppxPackageSigningEnabled=false" `
        "-p:DebugType=none" `
        "-p:DebugSymbols=false"
    if ($LASTEXITCODE -ne 0) { throw "dotnet build (MSIX) failed with exit code $LASTEXITCODE" }

    $packages = @(Get-ChildItem -LiteralPath $appPackages -Recurse -Filter "*.msix" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "\\Dependencies\\" -and $_.Name -like "ITHomeWinUI_*.msix" })
    if ($packages.Count -eq 0) { throw "MSIX package was not generated under $appPackages" }

    $msixPath = Join-Path $OutputDir "$artifactBase.msix"
    Copy-Item -LiteralPath $packages[0].FullName -Destination $msixPath -Force

    if (-not [string]::IsNullOrWhiteSpace($CertificatePath)) {
        Write-Step "Signing MSIX"
        $CertificatePath = Resolve-FullPath $CertificatePath
        if (-not (Test-Path -LiteralPath $CertificatePath)) {
            throw "Certificate not found: $CertificatePath"
        }

        # 优先使用环境变量下传的密码：命令行参数会出现在进程列表与 CI 日志中。
        if ([string]::IsNullOrWhiteSpace($CertificatePassword)) {
            $CertificatePassword = $env:SIGNING_CERT_PASSWORD
        }
        if ([string]::IsNullOrWhiteSpace($CertificatePassword)) {
            throw "No certificate password supplied. Pass -CertificatePassword or set SIGNING_CERT_PASSWORD."
        }

        $signTool = Find-SignTool
        if (-not $signTool) {
            throw "signtool.exe not found. Install the Windows SDK or Microsoft.Windows.SDK.BuildTools."
        }
        Write-Host "    signtool: $signTool"

        $signArgs = @("sign", "/fd", "SHA256", "/f", $CertificatePath)
        if (-not [string]::IsNullOrWhiteSpace($CertificatePassword)) {
            $signArgs += @("/p", $CertificatePassword)
        }
        if (-not [string]::IsNullOrWhiteSpace($TimestampUrl)) {
            $signArgs += @("/tr", $TimestampUrl, "/td", "SHA256")
        }
        $signArgs += $msixPath

        & $signTool @signArgs
        if ($LASTEXITCODE -ne 0) { throw "signtool sign failed with exit code $LASTEXITCODE" }

        $signature = Get-AuthenticodeSignature -LiteralPath $msixPath
        $signerSubject = $signature.SignerCertificate.Subject
        if ($signerSubject -ne $publisher) {
            throw "Signer subject mismatch. Manifest Publisher='$publisher' but certificate Subject='$signerSubject'."
        }

        # 自签证书未装入本机信任存储时，链校验必然以 UntrustedRoot 终止，这是
        # 侧载分发的预期状态（用户需手动信任证书），不代表签名无效。因此只在此
        # 之外视为失败：HashMismatch / NotSignatureValid 等意味着包被篡改或漏签。
        $chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
        [void]$chain.Build($signature.SignerCertificate)
        $fatalStatuses = @($chain.ChainStatus | Where-Object { $_.Status -ne 'UntrustedRoot' })
        if ($fatalStatuses.Count -gt 0) {
            $details = ($fatalStatuses | ForEach-Object { "$($_.Status): $($_.StatusInformation.Trim())" }) -join "; "
            throw "MSIX signature is not valid: $details"
        }

        if ($chain.ChainStatus -match 'UntrustedRoot') {
            Write-Warning "Signature is cryptographically valid but the certificate is not trusted on this machine; users must trust the published certificate before installing."
        }
        $summary.MsixSigned = $true
        Write-Host "    signature valid, subject: $signerSubject"
    }
    else {
        Write-Warning "No certificate supplied; MSIX is UNSIGNED and cannot be installed until signed."
    }

    $summary.Msix = $msixPath
    Write-Host ("    {0} ({1:N1} MB)" -f (Split-Path -Leaf $msixPath), ((Get-Item $msixPath).Length / 1MB))
}

Write-Step "Release artifacts"
Get-ChildItem -LiteralPath $OutputDir -File | ForEach-Object {
    [pscustomobject]@{
        File      = $_.Name
        SizeMB    = [math]::Round($_.Length / 1MB, 1)
        SHA256    = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
} | Format-Table -AutoSize

# 供 workflow 读取的机器可读摘要
$resultPath = Join-Path $OutputDir "release-summary.json"
[pscustomobject]@{
    version    = $Version
    platform   = $Platform
    publisher  = $publisher
    portable   = if ($summary.Portable) { Split-Path -Leaf $summary.Portable } else { "" }
    msix       = if ($summary.Msix) { Split-Path -Leaf $summary.Msix } else { "" }
    msixSigned = $summary.MsixSigned
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $resultPath -Encoding UTF8

Write-Host ""
Write-Host "Summary written to $resultPath" -ForegroundColor Green
