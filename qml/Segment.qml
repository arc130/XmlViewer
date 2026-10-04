import QtQuick 2.15
import QtQuick.Controls 2.15
import "LayoutMath.js" as L

// 柱状图分段(行段):一个字段在一行内的连续部分。
// 跨行字段的段端部直接画成撕纸撕口(波浪形,一峰一谷):首段右端撕口、
// 中间段两端撕口、尾段左端撕口 —— 撕掉的部分露出背景,形似撕开的便签纸。
Canvas {
    id: seg
    required property int fieldIndex
    required property int row
    required property int bitInRow
    required property int bits
    required property int fieldBits
    required property int bitOffset
    required property int byteOffset
    required property string name
    required property string type
    required property string unit
    required property string description
    required property string typeColor
    required property bool customBits
    required property bool breakLeft
    required property bool breakRight
    required property bool valid

    property real pxPerBit: 4
    property real originX: 24
    property real trackHeight: 44

    readonly property bool isSelected: messageModel.selectedRow === fieldIndex
    readonly property color accentColor: themeColors.accent
    readonly property color segBorderColor: themeColors.segBorder
    readonly property color tearLineColor: themeColors.tearLine
    readonly property color fiberLineColor: themeColors.fiberLine

    x: L.xForBit(bitInRow, pxPerBit, originX)
    y: 0
    width: L.xForBit(bitInRow + bits, pxPerBit, originX) - x
    height: trackHeight

    onTypeColorChanged: seg.requestPaint()
    onIsSelectedChanged: seg.requestPaint()
    onBreakLeftChanged: seg.requestPaint()
    onBreakRightChanged: seg.requestPaint()
    onValidChanged: seg.requestPaint()
    onAccentColorChanged: seg.requestPaint()
    onSegBorderColorChanged: seg.requestPaint()
    onTearLineColorChanged: seg.requestPaint()
    onFiberLineColorChanged: seg.requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        var amp = 4                      // 撕口波浪幅度
        var w = width
        var h = height
        ctx.beginPath()
        ctx.moveTo(0, 0)
        ctx.lineTo(w, 0)                 // 顶边
        if (breakRight) {
            // 右端撕口:右缘向内波浪(一峰一谷)
            for (var y = 0; y <= h; y++) {
                var ph = 2 * Math.PI * y / h
                ctx.lineTo(w - amp + amp * Math.sin(ph), y)
            }
        } else {
            ctx.lineTo(w, h)
        }
        if (breakLeft) {
            // 左端撕口:左缘向内波浪(与右端互补)
            for (var yy = h; yy >= 0; yy--) {
                var ph2 = 2 * Math.PI * yy / h
                ctx.lineTo(amp - amp * Math.sin(ph2), yy)
            }
        } else {
            ctx.lineTo(0, h)
        }
        ctx.closePath()
        ctx.fillStyle = typeColor
        ctx.globalAlpha = valid ? 1 : 0.4   // 无效 = 占位字段,淡显
        ctx.fill()
        ctx.globalAlpha = 1

        ctx.save()
        ctx.clip()
        if (isSelected) {
            // 选中态:完整高亮轮廓(强调色,线宽加倍,裁剪后内侧保留 3px)
            ctx.strokeStyle = accentColor
            ctx.lineWidth = 6
            ctx.stroke()
        } else {
            // 常态不画顶/底边(撕纸无封口,消除矩形框轮廓):
            // 只画纵向分隔线 + 撕口撕痕(深色撕痕 + 白色纸纤维内线)
            ctx.lineWidth = 2
            ctx.strokeStyle = segBorderColor
            if (!breakLeft) {
                ctx.beginPath()
                ctx.moveTo(0.5, 0)
                ctx.lineTo(0.5, h)
                ctx.stroke()
            }
            if (!breakRight) {
                ctx.beginPath()
                ctx.moveTo(w - 0.5, 0)
                ctx.lineTo(w - 0.5, h)
                ctx.stroke()
            }
            if (breakRight) {
                drawTear(ctx, 1, tearLineColor, 2)               // 撕痕
                drawTear(ctx, 0, fiberLineColor, 1)              // 纸纤维
            }
            if (breakLeft) {
                drawTearLeft(ctx, 1, tearLineColor, 2)
                drawTearLeft(ctx, 0, fiberLineColor, 1)
            }
        }
        ctx.restore()
    }

    function drawTear(ctx, inset, color, lineWidth) {
        ctx.strokeStyle = color
        ctx.lineWidth = lineWidth
        ctx.beginPath()
        for (var y = 0; y <= height; y++) {
            var ph = 2 * Math.PI * y / height
            ctx.lineTo(width - 4 + 4 * Math.sin(ph) - inset, y)
        }
        ctx.stroke()
    }

    function drawTearLeft(ctx, inset, color, lineWidth) {
        ctx.strokeStyle = color
        ctx.lineWidth = lineWidth
        ctx.beginPath()
        for (var y = 0; y <= height; y++) {
            var ph = 2 * Math.PI * y / height
            ctx.lineTo(4 - 4 * Math.sin(ph) + inset, y)
        }
        ctx.stroke()
    }

    // 长按左键拖动 → 拖到其他位置松开即可重排字段
    Drag.active: seg.dragActive
    Drag.dragType: Drag.Automatic
    Drag.source: seg
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2
    property bool dragActive: false
    property bool suppressClick: false

    Text {
        anchors.fill: parent
        anchors.margins: 4
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        visible: seg.width > 34
        text: name + " · " + fieldBits + "位" + (valid ? "" : " · 占位")
        elide: Text.ElideRight
        color: "white"
        opacity: valid ? 1 : 0.55
        font.pixelSize: 11
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressAndHold: {
            seg.suppressClick = false
            messageModel.selectedRow = seg.fieldIndex
            seg.dragActive = true
        }
        onReleased: {
            if (seg.dragActive) {
                seg.dragActive = false
                seg.suppressClick = true
            }
        }
        onClicked: {
            if (seg.suppressClick) { seg.suppressClick = false; return }
            if (mouse.button === Qt.LeftButton) {
                messageModel.selectedRow = seg.fieldIndex
                bar.inlineEditRequested(seg.fieldIndex)
                bar.forceActiveFocus()
            } else {
                bar.openContext(seg.fieldIndex, seg.x + mouse.x, seg.y + mouse.y)
            }
        }
    }

    ToolTip {
        visible: ma.containsMouse
        delay: 500
        text: qsTr("%1\n类型: %2  位长: %3 位\n位偏移: %4 (字节 %5, 第 %6 位)\n单位: %7\n说明: %8")
            .arg(name).arg(type).arg(fieldBits).arg(bitOffset).arg(byteOffset).arg(bitOffset % 8)
            .arg(unit === "" ? "—" : unit).arg(description === "" ? "—" : description)
    }
}
