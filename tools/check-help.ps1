# Check the --open-help screenshot (help overlay) against the main shot.
# The help overlay is a plain in-window Rectangle (NOT a popup), so the main
# window grab contains it. Assertions:
#  1) card rendered: a wide near-white band centered in the content area
#     (everything outside the card is dimmed by the scrim, so pure white
#     only exists on the card; all themes use cardBg = #FFFFFF)
#  2) title text painted just below the card top
#  3) body content (prose + shortcut table) painted
#  4) scrim dims the content area vs the main shot (titlebar/footer untouched)
#  5) scrollbar handle present (soft: WARN only)
# Usage: .\tools\check-help.ps1 [helpPng] [mainPng]
param([string]$Help = "D:/Qt/idlview/artifacts/xmlviewer_help.png",
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

# cardBg is pure white (#FFFFFF); toolbar/status bar are #FAFAFA (250), so
# require >= 253 to keep chrome out of the card scans.
function Is-White($pb, $ps, $x, $y) {
    $i = $y * $ps + $x * 4
    return ($pb[$i] -ge 253 -and $pb[$i+1] -ge 253 -and $pb[$i+2] -ge 253)
}

function Count-Dark($pb, $ps, [int]$x0, [int]$y0, [int]$x1, [int]$y1) {
    $n = 0
    for ($y = $y0; $y -le $y1; $y++) {
        $row = $y * $ps
        for ($x = $x0; $x -le $x1; $x++) {
            $i = $row + $x * 4
            if ([int]$pb[$i] + [int]$pb[$i+1] + [int]$pb[$i+2] -lt 300) { $n++ }
        }
    }
    return $n
}

function Brightness($pb, $ps, $x, $y) {
    $i = $y * $ps + $x * 4
    return [int]$pb[$i] + [int]$pb[$i+1] + [int]$pb[$i+2]
}

$ha = Load-Bytes $Help
$ma = Load-Bytes $Main
$ok = $true

$hw = $ha[1]; $hh = $ha[2]
Write-Output "help shot ${hw}x${hh}"

# 1) card: white columns in the vertical middle band
$my = [int]($hh / 2)
$cardL = -1; $cardR = -1
for ($x = 0; $x -lt $hw; $x++) {
    $white = $false
    for ($y = $my - 8; $y -le $my + 8 -and -not $white; $y++) {
        if (Is-White $ha[0] $ha[3] $x $y) { $white = $true }
    }
    if ($white) {
        if ($cardL -lt 0) { $cardL = $x }
        $cardR = $x
    }
}
if ($cardL -lt 0) {
    Write-Output "FAIL no white card found in middle band"
    Write-Output "HELP-SHOT FAIL"; exit 1
}
$cardW = $cardR - $cardL + 1
$cardC = ($cardL + $cardR) / 2
Write-Output "card x $cardL..$cardR (w=$cardW center=$cardC)"
if ($cardW -ge $hw * 0.5) { Write-Output "PASS card rendered" }
else { Write-Output "FAIL card too narrow ($cardW < $($hw * 0.5))"; $ok = $false }
if ([Math]::Abs($cardC - $hw / 2) -le 40) { Write-Output "PASS card centered" }
else { Write-Output "FAIL card off-center (center=$cardC want $($hw / 2))"; $ok = $false }

# 2) card top + title text
$cardTop = -1
for ($y = 100; $y -lt $hh - 40 -and $cardTop -lt 0; $y++) {
    if (Is-White $ha[0] $ha[3] ([int]($hw / 2)) $y) { $cardTop = $y }
}
if ($cardTop -lt 0) { Write-Output "FAIL card top not found"; $ok = $false }
else {
    $t = Count-Dark $ha[0] $ha[3] ($cardL + 20) ($cardTop + 4) ($cardL + 400) ($cardTop + 50)
    Write-Output "title dark px: $t (cardTop=$cardTop)"
    if ($t -ge 60) { Write-Output "PASS title text painted" }
    else { Write-Output "FAIL title text missing"; $ok = $false }
}

# 3) body content
if ($cardTop -ge 0) {
    $cardBottom = -1
    for ($y = $hh - 40; $y -gt $cardTop -and $cardBottom -lt 0; $y--) {
        if (Is-White $ha[0] $ha[3] ([int]($hw / 2)) $y) { $cardBottom = $y }
    }
    Write-Output "card bottom: $cardBottom"
    $b = Count-Dark $ha[0] $ha[3] ($cardL + 16) ($cardTop + 60) ($cardR - 16) ($cardBottom - 16)
    Write-Output "body dark px: $b"
    if ($b -ge 1200) { Write-Output "PASS body content painted" }
    else { Write-Output "FAIL body content missing"; $ok = $false }

    # 5) scrollbar handle (soft): handle is #B5B5B5 (sum 543), track #F1F1F1
    #    (sum 723), card #FFFFFF (sum 765) -> window on the handle only
    $sb = 0
    for ($y = $cardTop + 60; $y -le $cardBottom - 16; $y++) {
        for ($x = $cardR - 30; $x -le $cardR - 2; $x++) {
            $v = Brightness $ha[0] $ha[3] $x $y
            if ($v -ge 450 -and $v -le 650) { $sb++ }
        }
    }
    Write-Output "scrollbar px: $sb"
    if ($sb -ge 30) { Write-Output "PASS scrollbar handle rendered" }
    else { Write-Output "WARN scrollbar handle not detected" }
}

# 4) scrim: content area outside the card dimmed vs main shot; titlebar untouched
$dimmed = 0; $bright = 0
for ($y = $my - 100; $y -le $my + 100; $y++) {
    for ($x = 6; $x -le 44; $x++) {
        $mb = Brightness $ma[0] $ma[3] $x $y
        if ($mb -ge 600) {
            $bright++
            if ($mb - (Brightness $ha[0] $ha[3] $x $y) -ge 90) { $dimmed++ }
        }
    }
}
Write-Output "scrim: $dimmed / $bright bright baseline px dimmed"
if ($bright -ge 500 -and $dimmed -ge $bright * 0.6) { Write-Output "PASS scrim dims content area" }
else { Write-Output "FAIL scrim missing (baseline=$bright dimmed=$dimmed)"; $ok = $false }

$ti = 20 * $ha[3] + 640 * 4
$tbR = [int]$ha[0][$ti + 2]; $tbG = [int]$ha[0][$ti + 1]; $tbB = [int]$ha[0][$ti]
if ([Math]::Abs($tbR - 8) -le 14 -and [Math]::Abs($tbG - 51) -le 14 -and [Math]::Abs($tbB - 68) -le 14) {
    Write-Output "PASS titlebar untouched"
} else {
    Write-Output "FAIL titlebar changed ($tbR,$tbG,$tbB)"; $ok = $false
}

$fi = ($hh - 20) * $ha[3] + 640 * 4
$fsum = [int]$ha[0][$fi] + [int]$ha[0][$fi+1] + [int]$ha[0][$fi+2]
if ($fsum -ge 600) { Write-Output "PASS status bar untouched" }
else { Write-Output "FAIL status bar covered (sum=$fsum)"; $ok = $false }

if ($ok) { Write-Output "HELP-SHOT OK"; exit 0 } else { Write-Output "HELP-SHOT FAIL"; exit 1 }
