<#
.SYNOPSIS
    对截图中的隐私区域打码，用于生成可公开发布的界面预览图。

.DESCRIPTION
    维护者工具。README 里的界面截图常含第三方用户信息（昵称、头像、地理位置、
    机型）或个人数据，发布前必须遮盖。本脚本提供两种打码样式：

      Bar       实心圆角条 + 虚线框，观感上明确是"已遮盖"（推荐）
      Pixelate  像素化马赛克，保留一点原始色彩

    区域通过 -Region 指定，格式为 "x,y,w,h"（像素坐标，以原图左上角为原点）。
    可传多个区域。不传 -Region 时进入交互提示模式，逐条输入。

.PARAMETER InputPath
    原始截图路径。

.PARAMETER OutputPath
    输出路径。缺省为在原文件名后加 "-redacted"。

.PARAMETER Region
    要遮盖的矩形，格式 "x,y,w,h"。多个区域用**分号**连成一串：
    -Region '86,310,352,44;86,649,262,44'

    （不要重复写 -Region，也不要传 PowerShell 数组：pwsh -File 会把数组压成
     单个字符串。分号写法在命令行与脚本调用下都可靠。）

.PARAMETER Style
    打码样式：Bar（默认）或 Pixelate。

.PARAMETER BlockSize
    Pixelate 样式的马赛克块大小（像素），默认 12。

.EXAMPLE
    # 遮盖一条作者信息行
    pwsh scripts/Redact-Screenshot.ps1 -InputPath shot.png -Region '86,310,352,44'

.EXAMPLE
    # 一次遮盖多处，用分号分隔
    pwsh scripts/Redact-Screenshot.ps1 -InputPath shot.png `
        -Region '86,310,352,44;86,649,262,44'

.EXAMPLE
    # 改用马赛克样式
    pwsh scripts/Redact-Screenshot.ps1 -InputPath shot.png -Region '86,310,352,44' -Style Pixelate
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [string]$OutputPath = "",
    [string[]]$Region = @(),
    [ValidateSet("Bar", "Pixelate")]
    [string]$Style = "Bar",
    [int]$BlockSize = 12
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input image not found: $InputPath"
}
$InputPath = (Resolve-Path -LiteralPath $InputPath).Path

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $dir = Split-Path -Parent $InputPath
    $base = [System.IO.Path]::GetFileNameWithoutExtension($InputPath)
    $ext = [System.IO.Path]::GetExtension($InputPath)
    $OutputPath = Join-Path $dir "$base-redacted$ext"
}

function ConvertTo-Region {
    param([Parameter(Mandatory)][string]$Text)
    $parts = $Text.Split(",") | ForEach-Object { $_.Trim() }
    if ($parts.Count -ne 4) {
        throw "Region must be 'x,y,w,h', got: $Text"
    }
    $vals = @()
    foreach ($p in $parts) {
        $v = 0
        if (-not [int]::TryParse($p, [ref]$v)) { throw "Region component is not an integer: $p (in '$Text')" }
        $vals += $v
    }
    return [pscustomobject]@{ X = $vals[0]; Y = $vals[1]; W = $vals[2]; H = $vals[3] }
}

# 支持单串分号分隔（"a,b,c,d;e,f,g,h"）与数组两种写法。
# 注意：pwsh -File 会把数组参数压成单个字符串，因此分号写法才是可靠入口。
function Expand-RegionText {
    param([string[]]$Texts)
    $list = @()
    foreach ($text in $Texts) {
        foreach ($chunk in ([string]$text).Split(";")) {
            $t = $chunk.Trim()
            if ([string]::IsNullOrWhiteSpace($t)) { continue }
            $list += $t
        }
    }
    return $list
}

if ($Region.Count -eq 0) {
    Write-Host "未通过 -Region 指定区域，进入交互输入。格式 x,y,w,h，直接回车结束。" -ForegroundColor Yellow
    $input = @()
    while ($true) {
        $line = Read-Host "区域 (x,y,w,h)"
        if ([string]::IsNullOrWhiteSpace($line)) { break }
        $input += $line
    }
    $Region = $input
}
if ($Region.Count -eq 0) { throw "至少需要一个区域。" }

$regionTexts = Expand-RegionText -Texts $Region
if ($regionTexts.Count -eq 0) { throw "至少需要一个区域。" }
$regions = $regionTexts | ForEach-Object { ConvertTo-Region $_ }

# 读入后立刻克隆到 24bpp 位图，避免 GDI+ 因源文件被占用而保存失败
$source = New-Object System.Drawing.Bitmap($InputPath)
$width = $source.Width
$height = $source.Height
$canvas = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$init = [System.Drawing.Graphics]::FromImage($canvas)
$init.DrawImage($source, 0, 0, $width, $height)
$init.Dispose()
$source.Dispose()

$graphics = [System.Drawing.Graphics]::FromImage($canvas)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

Write-Host ("图像 {0}x{1}，共 {2} 个区域，样式 {3}" -f $width, $height, $regions.Count, $Style)

foreach ($rg in $regions) {
    # 裁剪到图像范围内
    $x = [Math]::Max(0, $rg.X)
    $y = [Math]::Max(0, $rg.Y)
    $w = [Math]::Min($rg.W, $width - $x)
    $h = [Math]::Min($rg.H, $height - $y)
    if ($w -le 0 -or $h -le 0) {
        Write-Warning "区域越界已跳过: $($rg.X),$($rg.Y),$($rg.W),$($rg.H)"
        continue
    }

    if ($Style -eq "Pixelate") {
        for ($by = $y; $by -lt ($y + $h); $by += $BlockSize) {
            for ($bx = $x; $bx -lt ($x + $w); $bx += $BlockSize) {
                $bw = [Math]::Min($BlockSize, ($x + $w) - $bx)
                $bh = [Math]::Min($BlockSize, ($y + $h) - $by)
                if ($bw -le 0 -or $bh -le 0) { continue }
                $sx = [Math]::Min($bx + [int]($bw / 2), $width - 1)
                $sy = [Math]::Min($by + [int]($bh / 2), $height - 1)
                $brush = New-Object System.Drawing.SolidBrush($canvas.GetPixel($sx, $sy))
                $graphics.FillRectangle($brush, $bx, $by, $bw, $bh)
                $brush.Dispose()
            }
        }
    }
    else {
        # 采样本区域周边像素作为底色，尽量融入原界面
        $sx = [Math]::Min($x + $w + 6, $width - 1)
        $sy = [Math]::Min($y + 3, $height - 1)
        $bg = $canvas.GetPixel($sx, $sy)
        # 避免采到深色文字导致色块过重，偏亮处理
        $bg = [System.Drawing.Color]::FromArgb(
            255,
            [Math]::Min(255, [int]$bg.R + 12),
            [Math]::Min(255, [int]$bg.G + 12),
            [Math]::Min(255, [int]$bg.B + 12))
        $fill = New-Object System.Drawing.SolidBrush($bg)
        $graphics.FillRectangle($fill, $x, $y, $w, $h)

        # 左侧灰色头像占位圆，使遮盖看起来是刻意的
        $avatar = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 198, 198, 198))
        $d = [Math]::Min($h - 8, 34)
        if ($d -gt 8) {
            $graphics.FillEllipse($avatar, $x + 3, $y + [int](($h - $d) / 2), $d, $d)
        }
        $avatar.Dispose()

        $border = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 214, 214, 214), 1)
        $graphics.DrawRectangle($border, $x, $y, $w - 1, $h - 1)
        $border.Dispose()
        $fill.Dispose()
    }
}

$graphics.Dispose()

$outDir = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}
$canvas.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$canvas.Dispose()

[pscustomobject]@{
    Output  = $OutputPath
    Size    = (Get-Item -LiteralPath $OutputPath).Length
    Regions = $regions.Count
    Style   = $Style
} | Format-List

Write-Host "打码完成。请人工复核输出图，确认无遗漏的个人信息。" -ForegroundColor Green
