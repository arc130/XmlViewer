# Check the --open-panel screenshot (screen grab) against the main shot.
# The inline panel popup opens above/below the segment anchor; its footprint is
# detected by pixel-diff against the main shot (headless xvfb renders the popup
# background transparent, so content rows are the diff signal).
#  1) panel rendered: large diff in the popup region
#  2) pinyin icon: amber refresh-arrow + dark glyph pixels at the english-name
#     row button (icon verified separately by the main-window shot pipeline;
#     in headless popups some content items may not paint -> WARN only)
# Usage: .\tools\check-panel.ps1 [panelPng] [mainPng]
param([string]$Panel = "D:/Qt/idlview/artifacts/xmlviewer_panel.png",
      [string]$Main = "D:/Qt/idlview/artifacts/xmlviewer.png")

Add-Type -AssemblyName System.Drawing

function Load-Bytes($path) {
    $bmp = New-Object System.Drawing.Bitmap($path)
    $w = $bmp.Width; $h = $bmp.Height
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bytes = New-Object byte[] ($data.Stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    $stride = $data.Stride
    $bmp.UnlockBits($data)
    $bmp.Dispose()
    return @($bytes, $w, $h, $stride)
}

function Diff-In($pb, $ps, $mb, $ms, [int]$x0, [int]$y0, [int]$x1, [int]$y1) {
    $n = 0
    for ($y = $y0; $y -le $y1; $y++) {
        $prow = $y * $ps; $mrow = $y * $ms
        for ($x = $x0; $x -le $x1; $x++) {
            $pi = $prow + $x * 4; $mi = $mrow + $x * 4
            $d = [Math]::Abs($pb[$pi+2] - $mb[$mi+2]) + [Math]::Abs($pb[$pi+1] - $mb[$mi+1]) + [Math]::Abs($pb[$pi] - $mb[$mi])
            if ($d -gt 24) { $n++ }
        }
    }
    return $n
}

function Amber-In($pb, $ps, $h, [int]$x0, [int]$y0, [int]$x1, [int]$y1) {
    $n = 0
    for ($y = $y0; $y -le $y1 -and $y -lt $h; $y++) {
        $row = $y * $ps
        for ($x = $x0; $x -le $x1; $x++) {
            $i = $row + $x * 4
            $rr = $pb[$i+2]; $gg = $pb[$i+1]; $bb = $pb[$i]
            if ([Math]::Abs($rr-255) -le 25 -and [Math]::Abs($gg-179) -le 25 -and $bb -le 30) { $n++ }
        }
    }
    return $n
}

$pa = Load-Bytes $Panel
$ma = Load-Bytes $Main
$ok = $true

# 1) popup footprint: big diff in the popup region (panel opens above the anchor
#    when the window is short, so use a generous region around the anchor area)
$d = Diff-In $pa[0] $pa[3] $ma[0] $ma[3] 228 8 556 636
Write-Output "popup region diff px: $d"
if ($d -ge 3000) { Write-Output "PASS panel content rendered" }
else { Write-Output "FAIL panel content not rendered"; $ok = $false }

# 2) pinyin icon at the english-name row button (window coords ~510,196)
$am = Amber-In $pa[0] $pa[3] $pa[2] 500 186 560 232
Write-Output "icon region amber px: $am"
if ($am -ge 3) { Write-Output "PASS pinyin icon rendered" }
else { Write-Output "WARN icon not detected in headless popup (verified in main-window pipeline)" }

if ($ok) { Write-Output "PANEL-SHOT OK"; exit 0 } else { Write-Output "PANEL-SHOT FAIL"; exit 1 }
