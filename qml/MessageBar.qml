import QtQuick 2.15
import QtQuick.Controls 2.15
import "LayoutMath.js" as L

// 分段柱状图宿主:按位分段、超宽自动换行(字节边界)、行尾撕纸断行标记、
// 逐行字节标尺、悬停插入点、共享右键菜单。
// 模型:messageModel(领域,QAbstractListModel)+ barLayout 的三个视图模型
// (segmentsModel/breakpointsModel/anchorsModel,QAbstractListModel)。
Item {
    id: bar

    property real pxPerByte: 32
    property real viewportWidth: 800

    readonly property real pxPerBit: pxPerByte / 8
    readonly property real originX: 24
    readonly property real trackY: 22
    readonly property real trackH: 44
    readonly property real rulerOffY: trackY + trackH + 8   // 行内标尺 y 偏移
    readonly property real rulerH: 20
    readonly property real rowGap: 16
    readonly property real rowHeight: rulerOffY + rulerH + rowGap
    readonly property int labelStride: pxPerByte < 16 ? 4 : (pxPerByte < 24 ? 2 : 1)
    readonly property int rowBytes: barLayout.rowBits / 8

    width: viewportWidth
    implicitHeight: barLayout.rowCount * rowHeight + 10
    height: implicitHeight

    // 点击段后柱状图持有焦点,键入可见字符即弹出类型筛选框
    focus: true
    signal typeInputStarted(string initialText)
    signal inlineEditRequested(int fieldIndex)   // 点击段/插入后请求就地编辑
    signal inlineEditDismissed()                 // 点击空白/滚动,关闭就地编辑
    property bool inputFilterEnabled: true       // 就地编辑打开期间禁用键入筛选
    Keys.onPressed: {
        if (!inputFilterEnabled || messageModel.selectedRow < 0)
            return
        var t = event.text
        if (t.length > 0 && t >= " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
            typeInputStarted(t)
            event.accepted = true
        }
    }

    onViewportWidthChanged: barLayout.setGeometry(Math.round(viewportWidth), Math.round(pxPerByte))
    onPxPerByteChanged: barLayout.setGeometry(Math.round(viewportWidth), Math.round(pxPerByte))
    Component.onCompleted: barLayout.setGeometry(Math.round(viewportWidth), Math.round(pxPerByte))

    // 主题背景
    Rectangle {
        anchors.fill: parent
        color: themeColors.barBg
    }

    // 仅供命令式调用(smoke 测试);绑定中必须直接使用 L.xForBit 并显式传参
    function xInRow(b) { return L.xForBit(b, pxPerBit, originX) }
    function rowY(row) { return row * rowHeight }

    function geometryReport() {
        var rows = []
        for (var i = 0; i < segRep.count; ++i) {
            var it = segRep.itemAt(i)
            if (!it) { rows.push(i + ":null"); continue }
            rows.push(i + ":" + it.row + "@" + it.x.toFixed(1) + "," + it.y.toFixed(1) + "," + it.width.toFixed(1))
        }
        return rows.join(";")
    }

    // 插入点渲染位置(验证 delegate 角色绑定正确)
    function anchorReport() {
        var rows = []
        for (var i = 0; i < anchorRep.count; ++i) {
            var it = anchorRep.itemAt(i)
            if (!it) { rows.push(i + ":null"); continue }
            rows.push(i + ":" + it.x.toFixed(1) + "," + it.y.toFixed(1))
        }
        return rows.join(";")
    }

    function openContext(fieldIndex, mx, my) {
        ctxMenu.contextField = fieldIndex
        ctxMenu.x = mx
        ctxMenu.y = my
        ctxMenu.open()
    }

    // 悬停插入条(覆盖整个柱状图,多行);点击空白关闭就地编辑面板
    MouseArea {
        id: stripMa
        anchors.fill: parent
        hoverEnabled: true
        onPressed: {
            bar.forceActiveFocus()
            bar.inlineEditDismissed()
        }
        onWheel: bar.inlineEditDismissed()
    }

    // 0) 行背景 + 行内字节网格 + 行标尺
    Repeater {
        model: barLayout.rowCount
        delegate: Rectangle {
            id: rowHost
            property int row: index
            readonly property int bitsHere: row === barLayout.rowCount - 1
                                             ? barLayout.lastRowBits : barLayout.rowBits

            x: bar.originX
            y: bar.rowY(row) + bar.trackY
            width: L.xForBit(bitsHere, bar.pxPerBit, bar.originX) - bar.originX
            height: bar.trackH
            color: themeColors.rowBg
            border.width: 1
            border.color: themeColors.rowBorder

            // 内层 delegate 在 rowHost 局部坐标系中(行背景从局部 (0,0) 开始),
            // 不能使用 bar 绝对坐标,否则每行标尺被二次偏移
            Repeater {
                model: bar.rowBytes + 1
                delegate: Item {
                    property int k: index
                    property real gx: L.xForBit(k * 8, bar.pxPerBit, bar.originX) - bar.originX

                    // 网格线
                    Rectangle {
                        x: gx
                        y: 0
                        width: 1
                        height: bar.trackH
                        color: themeColors.grid
                    }
                    // 刻度(track 下方)
                    Rectangle {
                        x: gx
                        y: bar.trackH + 8
                        width: 1
                        height: 9
                        color: themeColors.tick
                    }
                    // 字节编号(全局字节号,跨行连续,十进制)
                    Text {
                        visible: k % bar.labelStride === 0
                        x: gx - 20
                        width: 40
                        y: bar.trackH + 18
                        horizontalAlignment: Text.AlignHCenter
                        text: L.byteLabel(rowHost.row * bar.rowBytes + k)
                        font.pixelSize: 9
                        color: themeColors.rulerText
                    }
                }
            }
        }
    }

    // 1) 行段
    Repeater {
        id: segRep
        model: barLayout.segmentsModel
        delegate: Segment {
            y: bar.rowY(row) + bar.trackY
            pxPerBit: bar.pxPerBit
            originX: bar.originX
            trackHeight: bar.trackH
        }
    }

    // 2) 撕纸撕口已直接画在行段端部(Segment Canvas 绘制),无需独立标记

    // 3) 末字节不满 8 位的填充区(最后一行)
    Rectangle {
        visible: !messageModel.byteAligned
        x: L.xForBit(barLayout.lastRowBits, bar.pxPerBit, bar.originX)
        y: bar.rowY(barLayout.rowCount - 1) + bar.trackY
        width: L.xForBit(Math.ceil(barLayout.lastRowBits / 8) * 8, bar.pxPerBit, bar.originX) - x
        height: bar.trackH
        color: "#26111111"
        border.width: 1
        border.color: "#33000000"
    }

    // 4) 插入点(每个字段左边界;行内位置由 anchorsModel 角色给出)
    Repeater {
        id: anchorRep
        model: barLayout.anchorsModel
        delegate: InsertPoint {
            stripHovered: stripMa.containsMouse
        }
    }

    // 5) 拖动重排:落点换算 + 指示线 + DropArea
    function bitAtPosition(x, y) {
        var row = Math.floor(y / bar.rowHeight)
        if (row < 0) row = 0
        if (row > barLayout.rowCount - 1) row = barLayout.rowCount - 1
        var bitInRow = (x - bar.originX) / bar.pxPerBit
        if (bitInRow < 0) bitInRow = 0
        if (bitInRow > barLayout.rowBits) bitInRow = barLayout.rowBits
        var bit = Math.round(row * barLayout.rowBits + bitInRow)
        if (bit < 0) bit = 0
        if (bit > messageModel.totalBits) bit = messageModel.totalBits
        return bit
    }

    Rectangle {
        id: dragIndicator
        visible: false
        property int bit: 0
        property int iRow: 0
        property int iBitInRow: 0
        onBitChanged: {
            iRow = Math.min(Math.floor(bit / barLayout.rowBits), barLayout.rowCount - 1)
            iBitInRow = bit - iRow * barLayout.rowBits
        }
        x: L.xForBit(iBitInRow, bar.pxPerBit, bar.originX) - 1
        y: bar.rowY(iRow) + bar.trackY
        width: 2
        height: bar.trackH
        color: themeColors.accent
    }

    DropArea {
        id: dropArea
        anchors.fill: parent
        onPositionChanged: {
            if (drag.source && drag.source.fieldIndex !== undefined) {
                // 指示线吸附到最近字段边界
                dragIndicator.bit = messageModel.snapBitToFieldBoundary(
                                        bar.bitAtPosition(drag.x, drag.y))
                dragIndicator.visible = true
            }
        }
        onExited: dragIndicator.visible = false
        onDropped: {
            dragIndicator.visible = false
            if (!drag.source || drag.source.fieldIndex === undefined)
                return
            var from = drag.source.fieldIndex
            // 落点吸附字段边界:整字段移动,不改变任何字段长度
            var to = messageModel.targetIndexAtBit(bar.bitAtPosition(drag.x, drag.y))
            if (to !== from)
                messageModel.moveField(from, to - from)
        }
    }

    // 6) 末尾追加 "+"(最后一行末尾)
    Item {
        id: tailPlus
        x: L.xForBit(barLayout.lastRowBits, bar.pxPerBit, bar.originX) - 10
        y: bar.rowY(barLayout.rowCount - 1)
        width: 20
        height: 20
        // 自身悬停计入可见性,避免 hover 事件被本 MouseArea 接管时闪烁
        visible: stripMa.containsMouse || tailMa.containsMouse

        Rectangle {
            anchors.centerIn: parent
            width: 18
            height: 18
            radius: 9
            color: tailMa.containsMouse ? Qt.darker(themeColors.accent, 1.25) : themeColors.accent
            border.color: "white"
            border.width: 1.5
        }

        Text {
            anchors.centerIn: parent
            text: "+"
            color: "white"
            font.pixelSize: 14
            font.bold: true
        }

        MouseArea {
            id: tailMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                messageModel.insertField(messageModel.count)
                bar.inlineEditRequested(messageModel.count - 1)
                bar.forceActiveFocus()
            }
        }

        ToolTip {
            visible: tailMa.containsMouse
            text: "在末尾追加字段"
        }
    }

    // 7) 共享右键菜单(单一实例,避免随行销毁)
    Menu {
        id: ctxMenu
        property int contextField: -1

        MenuItem {
            text: "在此前插入字段"
            enabled: ctxMenu.contextField >= 0
            onTriggered: messageModel.insertField(ctxMenu.contextField)
        }
        MenuItem {
            text: "在此后插入字段"
            enabled: ctxMenu.contextField >= 0
            onTriggered: messageModel.insertField(ctxMenu.contextField + 1)
        }
        MenuItem {
            text: "删除该字段"
            enabled: ctxMenu.contextField >= 0 && messageModel.count > 1
            onTriggered: messageModel.removeField(ctxMenu.contextField)
        }
        MenuSeparator { }
        MenuItem {
            text: "左移"
            enabled: ctxMenu.contextField > 0
            onTriggered: messageModel.moveField(ctxMenu.contextField, -1)
        }
        MenuItem {
            text: "右移"
            enabled: ctxMenu.contextField >= 0 && ctxMenu.contextField < messageModel.count - 1
            onTriggered: messageModel.moveField(ctxMenu.contextField, 1)
        }
    }
}
