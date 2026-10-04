# 本地一键:同步源码到远程 → 用 /opt 下的 Qt 5.15.10 构建 → 可选 smoke / 截图
# 用法:
#   .\tools\sync-build.ps1                仅同步+构建
#   .\tools\sync-build.ps1 -Smoke         构建后跑无头自测
#   .\tools\sync-build.ps1 -Shot          构建后截图回传到 artifacts\xmlviewer.png
#   .\tools\sync-build.ps1 -Clean         强制清空远程构建目录
param([switch]$Clean, [switch]$Smoke, [switch]$Shot, [string]$Size = "1280x800")

$ErrorActionPreference = "Stop"
$R = "ac130@127.0.0.1"
$S = "D:/Qt/idlview"

# 获取远程 HOME(scp 用绝对路径,避免 sftp 协议不展开 ~ 的问题)
$RemoteHome = (ssh $R "echo `$HOME").Trim()
if (-not $RemoteHome) { throw "无法获取远程 HOME" }
$src = "$RemoteHome/xmlviewer"
$build = "$RemoteHome/xmlviewer-build"
$Q = "/opt/qt5.15.10_full/bin/qmake"

Write-Output "== 同步源码 -> $R : $src"
ssh $R "rm -rf $src && mkdir -p $src $build"
if ($LASTEXITCODE -ne 0) { throw "ssh mkdir 失败" }
if ($Clean) {
    ssh $R "rm -rf $build"
    if ($LASTEXITCODE -ne 0) { throw "ssh clean 失败" }
}
scp -r "$S/src" "$S/qml" "$S/icons" "$S/xmlviewer.pro" "$S/qml.qrc" "$S/qtquickcontrols2.conf" "${R}:${src}/" | Out-Null
if ($LASTEXITCODE -ne 0) { throw "scp 失败" }

Write-Output "== 远程构建 ($Q)"
$remoteScript = @'
V=$(/opt/qt5.15.10_full/bin/qmake -query QT_VERSION)
if [ "$V" != "5.15.10" ]; then echo "BAD_QMAKE: $V"; exit 9; fi
cd ~/xmlviewer-build || exit 1
if ! /opt/qt5.15.10_full/bin/qmake ~/xmlviewer/xmlviewer.pro >/dev/null; then
    echo "QMAKE_FAILED"; /opt/qt5.15.10_full/bin/qmake ~/xmlviewer/xmlviewer.pro; exit 8
fi
make -j16
'@
ssh $R $remoteScript
if ($LASTEXITCODE -ne 0) { Write-Error "构建失败"; exit 1 }

if ($Smoke) {
    Write-Output "== 无头自测 (--smoke, xvfb 提供真实焦点链)"
    ssh $R "cd $build && QT_QUICK_BACKEND=software xvfb-run -a -s '-screen 0 1920x1080x24' timeout 60 ./xmlviewer --smoke"
    if ($LASTEXITCODE -ne 0) { Write-Error "smoke 失败"; exit 1 }
}

if ($Shot) {
    Write-Output "== 无头截图 (--screenshot, xvfb-run)"
    ssh $R "cd $build && QT_QUICK_BACKEND=software xvfb-run -a -s '-screen 0 1920x1080x24' timeout 40 ./xmlviewer --screenshot /tmp/xmlviewer.png --size $Size"
    if ($LASTEXITCODE -ne 0) { Write-Error "截图失败"; exit 1 }
    New-Item -ItemType Directory -Force "$S/artifacts" | Out-Null
    scp "${R}:/tmp/xmlviewer.png" "$S/artifacts/xmlviewer.png" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "截图回传失败" }
    Write-Output "截图已保存: $S\artifacts\xmlviewer.png"
    Write-Output "== 像素级布局验证 =="
    powershell -ExecutionPolicy Bypass -File "$S/tools/verify-shot.ps1" "$S/artifacts/xmlviewer.png"
    if ($LASTEXITCODE -ne 0) { Write-Error "截图布局验证失败"; exit 1 }
}

Write-Output "SYNC-BUILD OK"
