# Generate one screenshot per theme and stitch them into an overview image.
# Usage: .\tools\theme-shots.ps1
$ErrorActionPreference = "Stop"
$R = "ac130@127.0.0.1"
$S = "D:/Qt/idlview"

$RemoteHome = (ssh $R "echo `$HOME").Trim()
$buildPath = "$RemoteHome/idlview-build"

$themes = @(
    @{ n = "light-indigo";  l = "1 bluegrey+indigo" },
    @{ n = "light-blue";    l = "2 fresh blue" },
    @{ n = "warm-orange";   l = "3 warm brown" },
    @{ n = "emerald";       l = "4 emerald green" },
    @{ n = "lavender";      l = "5 lavender purple" },
    @{ n = "classic-amber"; l = "6 classic blue+amber" },
    @{ n = "cyan";          l = "7 cyan" },
    @{ n = "pink";          l = "8 pink" },
    @{ n = "slate";         l = "9 linear slate" }
)

New-Item -ItemType Directory -Force "$S/artifacts/themes" | Out-Null

foreach ($t in $themes) {
    $name = $t.n
    Write-Output "== screenshot theme $name"
    ssh $R "cd $buildPath && QT_QUICK_BACKEND=software xvfb-run -a -s '-screen 0 1600x900x24' timeout 40 ./idlview --theme $name --screenshot /tmp/theme-$name.png --size 1280x800"
    if ($LASTEXITCODE -ne 0) { Write-Error "shot $name failed"; exit 1 }
    scp "${R}:/tmp/theme-$name.png" "$S/artifacts/themes/theme-$name.png" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "scp $name failed" }
}

# ---- stitch: 3 cols, each cell 640x400 + 30px label ----
Add-Type -AssemblyName System.Drawing
$cols = 3
$cw = 640
$ch = 400
$labelH = 30
$rows = [Math]::Ceiling($themes.Count / $cols)
$totalW = $cols * $cw
$totalH = $rows * ($ch + $labelH)
$canvas = New-Object System.Drawing.Bitmap($totalW, $totalH)
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.Clear([System.Drawing.Color]::White)
$font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(33, 33, 33))
for ($i = 0; $i -lt $themes.Count; $i++) {
    $col = $i % $cols
    $row = [Math]::Floor($i / $cols)
    $x0 = $col * $cw
    $y0 = $row * ($ch + $labelH)
    $img = [System.Drawing.Image]::FromFile("$S/artifacts/themes/theme-$($themes[$i].n).png")
    $g.DrawImage($img, $x0, $y0 + $labelH, $cw, $ch)
    $img.Dispose()
    $g.DrawString($themes[$i].l, $font, $brush, $x0 + 8, $y0 + 6)
}
$g.Dispose()
$canvas.Save("$S/artifacts/themes-overview.png", [System.Drawing.Imaging.ImageFormat]::Png)
$canvas.Dispose()
Write-Output "OVERVIEW SAVED: $S\artifacts\themes-overview.png"
