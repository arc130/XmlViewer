# tools/gen-icon.ps1  (pure ASCII: PS 5.1 reads no-BOM files as GBK)
# Generate icons/pinyin.png: the pinyin button icon = dark "pin" glyph +
# amber circular refresh arrow at the top-right corner (22x22, transparent).
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'icons'
New-Item -ItemType Directory -Force $outDir | Out-Null
$outFile = Join-Path $outDir 'pinyin.png'

$w = 22; $h = 22
$bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::Transparent)

# dark glyph "pin" (U+62FC)
$font = New-Object System.Drawing.Font('Microsoft YaHei', 13, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(33, 33, 33))
$g.DrawString([string][char]0x62FC, $font, $brush, 2.5, 3.5)

# amber circular arrow (gap at top, arrowhead at the end pointing clockwise)
$amber = [System.Drawing.Color]::FromArgb(255, 179, 0)
$pen = New-Object System.Drawing.Pen($amber, 1.7)
$pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$cx = 15.0; $cy = 7.0; $r = 4.8
$g.DrawArc($pen, $cx - $r, $cy - $r, 2 * $r, 2 * $r, 25, 310)

$ar = (25 + 310) * [Math]::PI / 180
$ex = $cx + $r * [Math]::Cos($ar)
$ey = $cy + $r * [Math]::Sin($ar)
$tx = -[Math]::Sin($ar); $ty = [Math]::Cos($ar)
$px = -$ty; $py = $tx
$tip = New-Object System.Drawing.PointF(($ex + $tx * 3.0), ($ey + $ty * 3.0))
$b1 = New-Object System.Drawing.PointF(($ex - $px * 1.8), ($ey - $py * 1.8))
$b2 = New-Object System.Drawing.PointF(($ex + $px * 1.8), ($ey + $py * 1.8))
$g.FillPolygon($brush, [System.Drawing.PointF[]]@($tip, $b1, $b2))

$g.Dispose()
$bmp.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# self-check: amber arc + dark glyph pixels present
$chk = New-Object System.Drawing.Bitmap($outFile)
$amber = 0; $dark = 0
for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
        $c = $chk.GetPixel($x, $y)
        if ([Math]::Abs($c.R - 255) -le 25 -and [Math]::Abs($c.G - 179) -le 25 -and $c.B -le 30) { $amber++ }
        if ($c.R -lt 80 -and $c.G -lt 80 -and $c.B -lt 80 -and $c.A -gt 200) { $dark++ }
    }
}
$chk.Dispose()
Write-Output "icon: $outFile amber=$amber dark=$dark"
if ($amber -lt 25 -or $dark -lt 30) { throw "icon self-check failed" }
Write-Output "ICON OK"
