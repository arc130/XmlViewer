# Locate the inline panel popup in the --open-panel shot:
#  1) diff against the main shot
#  2) amber clusters (selected outline / slider handle / badge / switches)
#  3) per-10-row dark & amber profile across the panel area (maps internal rows)
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

$pa = Load-Bytes $Panel
$ma = Load-Bytes $Main
$pb = $pa[0]; $pw = $pa[1]; $ph = $pa[2]; $ps = $pa[3]
$mb = $ma[0]; $mw = $ma[1]; $mh = $ma[2]; $ms = $ma[3]

# 1) diff overlap region (window at screen 0,0)
$ovW = [Math]::Min($pw, $mw)
$ovH = [Math]::Min($ph, $mh)
$diff = 0; $minX = 99999; $maxX = -1; $minY = 99999; $maxY = -1
for ($y = 0; $y -lt $ovH; $y++) {
    $prow = $y * $ps; $mrow = $y * $ms
    for ($x = 0; $x -lt $ovW; $x++) {
        $pi = $prow + $x * 4; $mi = $mrow + $x * 4
        $d = [Math]::Abs($pb[$pi+2] - $mb[$mi+2]) + [Math]::Abs($pb[$pi+1] - $mb[$mi+1]) + [Math]::Abs($pb[$pi] - $mb[$mi])
        if ($d -gt 24) {
            $diff++
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}
Write-Output "diff px=$diff bbox=[$minX..$maxX]x[$minY..$maxY]"

# 2) amber clusters (flat-int BFS)
$mask = New-Object 'bool[,]' ($ph, $pw)
for ($y = 0; $y -lt $ph; $y++) {
    $prow = $y * $ps
    for ($x = 0; $x -lt $pw; $x++) {
        $i = $prow + $x * 4
        $rr = $pb[$i+2]; $gg = $pb[$i+1]; $bb = $pb[$i]
        if ([Math]::Abs($rr-255) -le 25 -and [Math]::Abs($gg-179) -le 25 -and [Math]::Abs($bb-0) -le 25) { $mask[$y,$x] = $true }
    }
}
$visited = New-Object 'bool[,]' ($ph, $pw)
$clusters = @()
for ($y = 0; $y -lt $ph; $y++) {
    for ($x = 0; $x -lt $pw; $x++) {
        if ($mask[$y,$x] -and -not $visited[$y,$x]) {
            $queue = New-Object 'System.Collections.Generic.Queue[int]'
            $queue.Enqueue($y * $pw + $x)
            $visited[$y,$x] = $true
            $cnt = 0; $minX = $x; $maxX = $x; $minY = $y; $maxY = $y
            while ($queue.Count -gt 0) {
                $p = [int]$queue.Dequeue()
                $qx = $p % $pw
                $qy = [int](($p - $qx) / $pw)
                $cnt++
                if ($qx -lt $minX) { $minX = $qx }
                if ($qx -gt $maxX) { $maxX = $qx }
                if ($qy -lt $minY) { $minY = $qy }
                if ($qy -gt $maxY) { $maxY = $qy }
                $l = $p - 1; $r = $p + 1; $u = $p - $pw; $d = $p + $pw
                $neighbors = @($l, $r, $u, $d)
                foreach ($np in $neighbors) {
                    $nx = $np % $pw
                    $ny = [int](($np - $nx) / $pw)
                    if ($nx -ge 0 -and $nx -lt $pw -and $ny -ge 0 -and $ny -lt $ph -and $mask[$ny,$nx] -and -not $visited[$ny,$nx]) {
                        $visited[$ny,$nx] = $true
                        $queue.Enqueue($np)
                    }
                }
            }
            $clusters += [pscustomobject]@{ Count = $cnt; Box = "[$minX..$maxX]x[$minY..$maxY]" }
        }
    }
}
Write-Output "amber clusters: $($clusters.Count)"
$clusters | Sort-Object Count -Descending | Select-Object -First 8 | ForEach-Object { "amber: count=$($_.Count) bbox=$($_.Box)" }

# 3) dark & amber per-10-row profile across the panel area
Write-Output "row profile (y: dark amber) over x 230..545"
for ($yy = 200; $yy -lt 720; $yy += 10) {
    $dark = 0; $amb = 0
    for ($y = $yy; $y -lt ($yy + 10) -and $y -lt $ph; $y++) {
        $prow = $y * $ps
        for ($x = 230; $x -le 545; $x++) {
            $i = $prow + $x * 4
            $rr = $pb[$i+2]; $gg = $pb[$i+1]; $bb = $pb[$i]
            if ($rr -lt 80 -and $gg -lt 80 -and $bb -lt 80) { $dark++ }
            if ([Math]::Abs($rr-255) -le 25 -and [Math]::Abs($gg-179) -le 25 -and [Math]::Abs($bb-0) -le 25) { $amb++ }
        }
    }
    Write-Output ("y {0}: dark {1} amber {2}" -f $yy, $dark, $amb)
}
