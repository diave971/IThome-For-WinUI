<#
.SYNOPSIS
    构建绿色版（portable）与 MSIX 两种发布产物，并输出校验清单。

.DESCRIPTION
    公开门面仓的编排入口。源码由调用方（workflow 或本地）检出到 -SourceRoot，
    本脚本不持有源码。详见 Build-ReleaseArtifacts.ps1。

.EXAMPLE
    # 本地验证（-SourceRoot 指向源码检出目录）
    pwsh scripts/Build-Release.ps1 -SourceRoot ".\src" -Platforms x64 -SkipMsix

.EXAMPLE
    # 只出 MSIX，用自签证书签名
    pwsh scripts/Build-Release.ps1 -SourceRoot ./src -Platforms x64 -SkipPortable `
        -CertificatePath ./devcert.pfx -CertificatePassword password
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SourceRoot,
    [string[]]$Platforms = @("x64"),
    [string]$OutputDir = "release-output",
    [string]$Version = "",
    [string]$CertificatePath = "",
    [string]$CertificatePassword = "",
    [string]$TimestampUrl = "http://timestamp.digicert.com",
    [switch]$SkipPortable,
    [switch]$SkipMsix
)

$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
$builder = Join-Path $scriptRoot "Build-ReleaseArtifacts.ps1"
if (-not (Test-Path -LiteralPath $builder)) {
    throw "Build-ReleaseArtifacts.ps1 not found next to this script: $builder"
}

# PowerShell 会把 "-Platforms x64,ARM64" 当作单个字符串绑定到 [string[]]，
# 不会按逗号拆分。这里统一展开，兼容数组、逗号串与 "x64, ARM64" 三种写法。
$Platforms = @(
    $Platforms |
        ForEach-Object { $_ -split "," } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ }
)
if ($Platforms.Count -eq 0) {
    throw "-Platforms must contain at least one platform."
}

$OutputDir = if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir
} else {
    [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $OutputDir))
}

$results = @()

foreach ($platform in $Platforms) {
    Write-Host ""
    Write-Host ("#" * 72) -ForegroundColor DarkGray
    Write-Host "# Platform: $platform" -ForegroundColor DarkGray
    Write-Host ("#" * 72) -ForegroundColor DarkGray

    $platformOutput = Join-Path $OutputDir $platform

    $invokeArgs = @{
        SourceRoot = $SourceRoot
        Platform   = $platform
        OutputDir  = $platformOutput
        Version    = $Version
    }
    if ($SkipPortable) { $invokeArgs.SkipPortable = $true }
    if ($SkipMsix) { $invokeArgs.SkipMsix = $true }
    if (-not [string]::IsNullOrWhiteSpace($CertificatePath)) {
        $invokeArgs.CertificatePath = $CertificatePath
        $invokeArgs.CertificatePassword = $CertificatePassword
        if (-not [string]::IsNullOrWhiteSpace($TimestampUrl)) {
            $invokeArgs.TimestampUrl = $TimestampUrl
        }
    }

    & $builder @invokeArgs

    $summaryPath = Join-Path $platformOutput "release-summary.json"
    if (Test-Path -LiteralPath $summaryPath) {
        $results += (Get-Content -LiteralPath $summaryPath -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
}

# SHA256SUMS：随 Release 一起发布，供用户校验下载完整性
Write-Host ""
$checksumLines = @()
foreach ($platform in $Platforms) {
    $platformOutput = Join-Path $OutputDir $platform
    Get-ChildItem -LiteralPath $platformOutput -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike "release-summary.json" } |
        Sort-Object Name |
        ForEach-Object {
            $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            $checksumLines += "$hash  $($_.Name)"
        }
}
$checksumPath = Join-Path $OutputDir "SHA256SUMS.txt"
$checksumLines | Set-Content -LiteralPath $checksumPath -Encoding UTF8

Write-Host "Artifacts:" -ForegroundColor Green
Get-ChildItem -LiteralPath $OutputDir -Recurse -File |
    Sort-Object FullName |
    ForEach-Object { "  {0,10:N1} MB  {1}" -f ($_.Length / 1MB), $_.FullName.Substring($OutputDir.Length + 1) }

Write-Host ""
Write-Host "Checksums: $checksumPath" -ForegroundColor Green
$checksumLines | ForEach-Object { "  $_" }

$results
