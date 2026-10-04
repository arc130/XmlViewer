# Pixel-level verification of the multi-row screenshot.
# Anchor-based: finds the bar origin and row-0 y from the blue frame-header
# segment inside the bar area (left message-list panel excluded), then asserts
# x-intervals per row against theoretical bit geometry, tear wave edges, and
# ruler ticks. Row count is adaptive (viewport width changes with layout).
# Usage: .\tools\verify-shot.ps1 [png path]
param([string]$Path = "D:/Qt/idlview/artifacts/xmlviewer.png")

Add-Type -AssemblyName System.Drawing

$bmp = New-Object System.Drawing.Bitmap($Path)
$w = $bmp.Width
$h = $bmp.Height

# Demo message segment colors. The two greens are detected into one bucket:
# their 0.8-darkened border pixels fall inside each other's tolerance.
$targets = @(
    @{ Name = "blue-uint8";   R = 0x2f; G = 0x7e; B = 0xd8; Bucket = "blue-uint8" },
    @{ Name = "green-uint16"; R = 0x1e; G = 0x8e; B = 0x4e; Bucket = "green-any" },
    @{ Name = "green-int16";  R = 0x27; G = 0xae; B = 0x60; Bucket = "green-any" },
    @{ Name = "orange-bit";   R = 0xe6; G = 0x7e; B = 0x22; Bucket = "orange-bit" },
    @{ Name = "teal-uint32";  R = 0x0f; G = 0x7a; B = 0x65; Bucket = "teal-uint32" },
    @{ Name = "purple-float"; R = 0x8e; G = 0x44; B = 0xad; Bucket = "purple-float" },
    @{ Name = "gray-raw";     R = 0x7f; G = 0x8c; B = 0x8d; Bucket = "gray-raw" }
)
$tol = 14
# scan only the bar area: left message-list panel (mini preview strips) and
# any right-side UI pollute detection
$scanX0 = 200
$scanW = 1270

$rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
$data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bytes = New-Object byte[] ($data.Stride * $h)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
$bmp.UnlockBits($data)

$rows = @{
    "blue-uint8"   = New-Object 'int[,]' ($h, $scanW)
    "green-any"    = New-Object 'int[,]' ($h, $scanW)
    "orange-bit"   = New-Object 'int[,]' ($h, $scanW)
    "teal-uint32"  = New-Object 'int[,]' ($h, $scanW)
    "purple-float" = New-Object 'int[,]' ($h, $scanW)
    "gray-raw"     = New-Object 'int[,]' ($h, $scanW)
}
$darkPx = New-Object 'int[,]' ($h, $scanW)   # dark pixels (tear mark detection)
$textPixels = 0

for ($y = 0; $y -lt $h; $y++) {
    $row = $y * $data.Stride
    for ($x = $scanX0; $x -lt $scanW; $x++) {
        $i = $row + $x * 4
        $bb = $bytes[$i]
        $gg = $bytes[$i+1]
        $rr = $bytes[$i+2]
        foreach ($t in $targets) {
            $d1 = [Math]::Abs($rr - $t.R)
            $d2 = [Math]::Abs($gg - $t.G)
            $d3 = [Math]::Abs($bb - $t.B)
            if ($d1 -le $tol -and $d2 -le $tol -and $d3 -le $tol) {
                $rows[$t.Bucket][$y, $x] = 1
                break
            }
        }
        if ($rr + $gg + $bb -lt 330) { $darkPx[$y, $x] = 1 }
        if ($rr -gt 252 -and $gg -gt 252 -and $bb -gt 252) { $textPixels = $textPixels + 1 }
    }
}

# anchor: smallest y of the blue frame-header segment (bar area)
$y0 = -1
for ($y = 0; $y -lt $h; $y++) {
    for ($x = $scanX0 + 2; $x -le $scanX0 + 32; $x++) {
        if ($rows["blue-uint8"][$y, $x] -eq 1) { $y0 = $y; break }
    }
    if ($y0 -ge 0) { break }
}
Write-Output "row0 track top anchor y0=$y0"

# bar origin shift: frame-header matched left edge is 27 in bar coords
$anchorY = $y0 + 10
$barLeft = -1
for ($x = $scanX0; $x -lt $scanW; $x++) {
    if ($rows["blue-uint8"][$anchorY, $x] -eq 1) { $barLeft = $x; break }
}
$shift = $barLeft - 27
Write-Output "bar origin shift=$shift (frame-header left edge at $barLeft)"

$rowH = 110
$trackH = 44

# x-intervals of a color inside row band k (track strip only, drop noise < 3px)
function Get-BandInts($mat, [int]$band, [int]$yTop, [int]$yH) {
    $y0 = $yTop + $band * $yH
    $y1 = $y0 + $trackH
    $colHit = New-Object bool[] $scanW
    for ($y = $y0; $y -le $y1; $y++) {
        if ($y -lt 0 -or $y -ge $mat.GetLength(0)) { continue }
        for ($x = $scanX0; $x -lt $scanW; $x++) {
            if ($mat[$y, $x] -eq 1) { $colHit[$x] = $true }
        }
    }
    $ints = @()
    $start = -1
    $prev = -1
    for ($x = $scanX0; $x -lt $scanW; $x++) {
        if ($colHit[$x]) {
            if ($start -lt 0) { $start = $x }
            $prev = $x
        } elseif ($start -ge 0) {
            $len = $prev - $start + 1
            if ($len -ge 3) { $ints += ,@($start, $prev) }
            $start = -1
        }
    }
    if ($start -ge 0) {
        $len = $prev - $start + 1
        if ($len -ge 3) { $ints += ,@($start, $prev) }
    }
    return ,$ints
}

Write-Output "== intervals per row =="
$ok = $true
function Expect-Ints([string]$name, [int]$band, [int[]]$lefts, [int[]]$rights, $rowsRef, [int]$yTop, [int]$yH, [int]$takeOnly = -1) {
    # expectations are in bar coordinates; shift to window coordinates
    $lefts = @($lefts | ForEach-Object { $_ + $script:shift })
    $rights = @($rights | ForEach-Object { $_ + $script:shift })
    $is = Get-BandInts $rowsRef[$name] $band $yTop $yH
    if ($takeOnly -ge 0) {
        $trimmed = @()
        for ($k = 0; $k -lt $is.Count -and $k -lt $takeOnly; $k++) { $trimmed += ,@($is[$k][0], $is[$k][1]) }
        $is = $trimmed
    }
    if ($is.Count -ne $lefts.Count) {
        $got = ($is | ForEach-Object { "[$($_[0])-$($_[1])]" }) -join " "
        Write-Output "FAIL $name band$band : interval count $($is.Count) != $($lefts.Count) got=[$got]"
        $script:ok = $false
        return
    }
    for ($k = 0; $k -lt $is.Count; $k++) {
        $l = $is[$k][0]
        $r = $is[$k][1]
        $dl = [Math]::Abs($l - $lefts[$k])
        $dr = [Math]::Abs($r - $rights[$k])
        if ($dl -gt 2 -or $dr -gt 2) {
            Write-Output "FAIL $name band$band int$k : got [$l-$r] expected [$($lefts[$k])-$($rights[$k])]"
            $script:ok = $false
        } else {
            Write-Output "PASS $name band$band int$k : [$l-$r] ~ [$($lefts[$k])-$($rights[$k])]"
        }
    }
}

# Theory: pxPerByte=32 -> 4px/bit. Matched interval = [L+1, R-2] (1px border);
# selected field 0 has 3px border -> [L+3, R-4].
# Row 0 (bit offsets < 216): fixed geometry independent of viewport width
Expect-Ints "blue-uint8"   0 @(27, 57)      @(52, 86)         $rows $y0 $rowH
Expect-Ints "green-any"    0 @(89, 186, 250) @(150, 245, 309) $rows $y0 $rowH
Expect-Ints "orange-bit"   0 @(153, 165)    @(162, 182)       $rows $y0 $rowH
Expect-Ints "teal-uint32"  0 @(313, 441)    @(438, 566)       $rows $y0 $rowH
Expect-Ints "purple-float" 0 @(569, 697)    @(694, 822)       $rows $y0 $rowH
# gray row0: [825, breakX-2]; infer breakX from its right edge
$g0 = Get-BandInts $rows["gray-raw"] 0 $y0 $rowH
$breakX = -1
if ($g0.Count -gt 0) { $breakX = $g0[0][1] + 2 }
Write-Output "inferred row-break x: $breakX"
$gr0 = $breakX - 2 - $shift
Expect-Ints "gray-raw" 0 @(825) @($gr0) $rows $y0 $rowH

# adaptive row count: count consecutive gray bands
$grayBands = 0
for ($k = 0; $k -lt 8; $k++) {
    $is = Get-BandInts $rows["gray-raw"] $k $y0 $rowH
    if ($is.Count -gt 0) { $grayBands++ } else { break }
}
Write-Output "gray bands: $grayBands"

# row width from the break x (in bar coords): rowBits = round((breakX-24)/4)
$rowBits = [Math]::Round((($breakX - $shift) - 24) / 4)

# middle full-gray rows (bands 1 .. grayBands-2)
for ($k = 1; $k -lt $grayBands - 1; $k++) {
    $gr1 = $breakX - 2 - $shift
    Expect-Ints "gray-raw" $k @(25) @($gr1) $rows $y0 $rowH
}
# last row: data tail segment (456 - last*rowBits bits) + checksum (8 bits)
$lastBand = $grayBands - 1
$grayBitsLast = 456 - $lastBand * $rowBits
$gL = 26
$gR = 24 + $grayBitsLast * 4 - 2
$bL = 24 + $grayBitsLast * 4 + 2
$bR = 24 + $grayBitsLast * 4 + 30
Expect-Ints "gray-raw"   $lastBand @($gL) @($gR) $rows $y0 $rowH
Expect-Ints "blue-uint8" $lastBand @($bL) @($bR) $rows $y0 $rowH

# tear edges drawn INTO segments: wave notch, crest at y=h/4, trough at y=3h/4,
# amplitude 4px. Check gray edge positions at crest/trough rows differ >=4px.
function Get-RightEdgeAtY([string]$colorName, [int]$y) {
    $edge = -1
    if ($y -lt 0 -or $y -ge $h) { return $edge }
    for ($x = $scanX0; $x -lt $scanW; $x++) {
        if ($rows[$colorName][$y, $x] -eq 1) { $edge = $x }
    }
    return $edge
}
function Get-LeftEdgeAtY([string]$colorName, [int]$y) {
    if ($y -lt 0 -or $y -ge $h) { return -1 }
    for ($x = $scanX0; $x -lt $scanW; $x++) {
        if ($rows[$colorName][$y, $x] -eq 1) { return $x }
    }
    return -1
}
function Check-TearEdge([string]$label, [string]$colorName, [int]$yCrest, [int]$yTrough, [bool]$isLeft) {
    $e1 = 0; $e2 = 0
    if ($isLeft) { $e1 = Get-LeftEdgeAtY $colorName $yCrest; $e2 = Get-LeftEdgeAtY $colorName $yTrough }
    else { $e1 = Get-RightEdgeAtY $colorName $yCrest; $e2 = Get-RightEdgeAtY $colorName $yTrough }
    $diff = [Math]::Abs($e1 - $e2)
    if ($e1 -lt 0 -or $e2 -lt 0 -or $diff -lt 4) {
        Write-Output "FAIL $label : crest=$e1 trough=$e2 diff=$diff"
        $script:ok = $false
    } else {
        Write-Output "PASS $label : crest=$e1 trough=$e2 diff=$diff"
    }
}
Check-TearEdge "tear row0 right edge" "gray-raw" ($y0 + 11) ($y0 + 33) $false
Check-TearEdge "tear row1 left edge"  "gray-raw" ($y0 + $rowH + 11) ($y0 + $rowH + 33) $true
for ($k = 1; $k -lt $grayBands - 1; $k++) {
    Check-TearEdge "tear row$k right edge" "gray-raw" ($y0 + $k * $rowH + 11) ($y0 + $k * $rowH + 33) $false
    Check-TearEdge "tear row$($k+1) left edge" "gray-raw" ($y0 + ($k+1) * $rowH + 11) ($y0 + ($k+1) * $rowH + 33) $true
}

# ruler ticks per row: tick #757575 (dark theme)
function Get-TickCols([int]$yStart, [int]$yEnd) {
    $cols = @()
    for ($x = $scanX0; $x -lt $scanW; $x++) {
        $hit = $false
        for ($y = $yStart; $y -le $yEnd; $y++) {
            if ($y -lt 0 -or $y -ge $h) { continue }
            $i = $y * $data.Stride + $x * 4
            $rr = $bytes[$i+2]; $gg = $bytes[$i+1]; $bb = $bytes[$i]
            if ([Math]::Abs($rr - 117) -le 14 -and [Math]::Abs($gg - 117) -le 14 -and [Math]::Abs($bb - 117) -le 14) { $hit = $true; break }
        }
        if ($hit) { $cols += $x }
    }
    return ,$cols
}
function Get-LabelPx([int]$yStart, [int]$yEnd) {
    $cnt = 0
    for ($y = $yStart; $y -le $yEnd; $y++) {
        if ($y -lt 0 -or $y -ge $h) { continue }
        $row = $y * $data.Stride
        for ($x = $scanX0; $x -lt $scanW; $x++) {
            $i = $row + $x * 4
            $rr = $bytes[$i+2]; $gg = $bytes[$i+1]; $bb = $bytes[$i]
            if ([Math]::Abs($rr - 117) -le 14 -and [Math]::Abs($gg - 117) -le 14 -and [Math]::Abs($bb - 117) -le 14) { $cnt = $cnt + 1 }
        }
    }
    return $cnt
}
Write-Output "== ruler per row =="
$tickExp = @(24, 56, 88, 120)
for ($k = 0; $k -lt $grayBands; $k++) {
    $ty = $y0 + 44 + 8 - 2 + $k * $rowH
    $ticks = Get-TickCols $ty ($ty + 11)
    foreach ($ex in $tickExp) {
        $exw = $ex + $shift
        $near = $false
        foreach ($tx in $ticks) {
            if ([Math]::Abs($tx - $exw) -le 2) { $near = $true }
        }
        if ($near) { Write-Output "PASS ruler row$k tick x~$exw" }
        else { Write-Output "FAIL ruler row$k missing tick x~$exw"; $ok = $false }
    }
    $tyy = $y0 + 44 + 18 + $k * $rowH
    $labelPx = Get-LabelPx $tyy ($tyy + 14)
    if ($labelPx -ge 10) { Write-Output "PASS ruler row$k labels ($labelPx px)" }
    else { Write-Output "FAIL ruler row$k no label text ($labelPx px)"; $ok = $false }
}

if ($textPixels -lt 300) { Write-Output "FAIL too few white text pixels ($textPixels)"; $ok = $false }
else { Write-Output "PASS white text rendered ($textPixels px)" }

# == UI chrome: dark titlebar / white toolbar / rounded button outlines ==
function Sample-Px([int]$x, [int]$y) {
    $i = $y * $data.Stride + $x * 4
    return @($bytes[$i+2], $bytes[$i+1], $bytes[$i])   # r,g,b
}
$p = Sample-Px 640 20
if ([Math]::Abs($p[0]-8) -le 14 -and [Math]::Abs($p[1]-51) -le 14 -and [Math]::Abs($p[2]-68) -le 14) {
    Write-Output "PASS titlebar dark #083344 at (640,20)"
} else { Write-Output "FAIL titlebar color ($($p[0]),$($p[1]),$($p[2]))"; $ok = $false }
# toolbar white: near-white dominates the toolbar band (buttons are sparse)
$toolWhite = 0
for ($y = 50; $y -le 90; $y++) {
    for ($x = 10; $x -le 1100; $x++) {
        $p = Sample-Px $x $y
        if ($p[0] -ge 248 -and $p[1] -ge 248 -and $p[2] -ge 248) { $toolWhite++ }
    }
}
if ($toolWhite -ge 10000) {
    Write-Output "PASS toolbar white ($toolWhite px)"
} else { Write-Output "FAIL toolbar not white ($toolWhite px)"; $ok = $false }
# titlebar light text (#E0F7FA) present in title area and in window buttons
$lightText = 0
$btnLight = 0
for ($y = 8; $y -le 36; $y++) {
    for ($x = 10; $x -le 500; $x++) {
        $p = Sample-Px $x $y
        if ([Math]::Abs($p[0]-224) -le 20 -and [Math]::Abs($p[1]-247) -le 20 -and [Math]::Abs($p[2]-250) -le 20) { $lightText++ }
    }
    for ($x = 1080; $x -le 1278; $x++) {
        $p = Sample-Px $x $y
        if ([Math]::Abs($p[0]-224) -le 20 -and [Math]::Abs($p[1]-247) -le 20 -and [Math]::Abs($p[2]-250) -le 20) { $btnLight++ }
    }
}
if ($lightText -ge 100) { Write-Output "PASS titlebar light text ($lightText px)" }
else { Write-Output "FAIL titlebar light text ($lightText px)"; $ok = $false }
if ($btnLight -ge 20) { Write-Output "PASS window buttons light glyphs ($btnLight px)" }
else { Write-Output "FAIL window buttons light glyphs ($btnLight px)"; $ok = $false }
# toolbar button outlines: ~#CCCCCC border pixels across toolbar rows
$outline = 0
for ($y = 50; $y -le 90; $y++) {
    for ($x = 10; $x -le 1100; $x++) {
        $p = Sample-Px $x $y
        if ([Math]::Abs($p[0]-204) -le 16 -and [Math]::Abs($p[1]-204) -le 16 -and [Math]::Abs($p[2]-204) -le 16) { $outline++ }
    }
}
if ($outline -ge 200) { Write-Output "PASS toolbar button outlines ($outline px)" }
else { Write-Output "FAIL toolbar outlines ($outline px)"; $ok = $false }

$bmp.Dispose()
if ($ok) { Write-Output "SHOT-VERIFY OK"; exit 0 } else { Write-Output "SHOT-VERIFY FAIL"; exit 1 }
