import QtQuick 2.15
import QtQuick.Controls 2.15
import "LayoutMath.js" as L

// 悬停插入点:位于字段 fieldIndex 的左边界(行内位置由 anchorsModel 角色给定),
// 点击在 fieldIndex 处插入新字段
Item {
    id: root
    required property int fieldIndex
    required property int row
    required property int bitInRow

    property bool stripHovered: false

    x: L.xForBit(bitInRow, bar.pxPerBit, bar.originX) - width / 2
    y: bar.rowY(row)
    width: 20
    height: 20
    // 位宽过小时插入点会相互重叠,此时改用右键菜单插入。
    // 可见性同时看 strip 悬停与自身悬停:鼠标移到加号上时 hover 事件被
    // 本 MouseArea 接管(底层 stripMa.containsMouse 变 false),若不把自身
    // 悬停计入会导致加号反复消失/出现(闪烁)。
    visible: (stripHovered || ma.containsMouse) && bar.pxPerBit >= 4

    Rectangle {
        anchors.centerIn: parent
        width: 18
        height: 18
        radius: 9
        color: ma.containsMouse ? Qt.darker(themeColors.accent, 1.25) : themeColors.accent
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
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            messageModel.insertField(fieldIndex)
            bar.inlineEditRequested(fieldIndex)
            bar.forceActiveFocus()
        }
    }

    ToolTip {
        visible: ma.containsMouse
        text: "在此位置插入字段"
    }
}
