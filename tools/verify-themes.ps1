# Verify each theme screenshot applied its title-bar color.
Add-Type -AssemblyName System.Drawing

$expect = @{
    "light-indigo"  = @(0x37, 0x47, 0x4F)
    "light-blue"    = @(0x15, 0x65, 0xC0)
    "warm-orange"   = @(0x5D, 0x40, 0x37)
    "emerald"       = @(0x00, 0x4D, 0x40)
    "lavender"      = @(0x45, 0x27, 0xA0)
    "classic-amber" = @(0x0D, 0x47, 0xA1)
    "cyan"          = @(0x00, 0x60, 0x64)
    "pink"          = @(0x88, 0x0E, 0x4F)
    "slate"         = @(0x1E, 0x29, 0x3B)
}
$ok = $true
foreach ($name in $expect.Keys) {
    $path = "D:/Qt/idlview/artifacts/themes/theme-$name.png"
    $bmp = New-Object System.Drawing.Bitmap($path)
    $px = $bmp.GetPixel(400, 10)   # title bar area (x=400 y=10)
    $bmp.Dispose()
    $e = $expect[$name]
    $d = [Math]::Abs($px.R - $e[0]) + [Math]::Abs($px.G - $e[1]) + [Math]::Abs($px.B - $e[2])
    if ($d -le 12) { Write-Output "PASS $name titlebar=#$($px.R.ToString('X2'))$($px.G.ToString('X2'))$($px.B.ToString('X2'))" }
    else { Write-Output "FAIL $name got #$($px.R.ToString('X2'))$($px.G.ToString('X2'))$($px.B.ToString('X2')) expected #$($e[0].ToString('X2'))$($e[1].ToString('X2'))$($e[2].ToString('X2'))"; $ok = $false }
}
if ($ok) { Write-Output "THEMES-VERIFY OK"; exit 0 } else { Write-Output "THEMES-VERIFY FAIL"; exit 1 }
