import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// 工具栏动作按钮:圆角矩形轮廓,上方文字,下方虚拟键盘风格快捷键键帽
ToolButton {
    id: root

    property string caption: ""
    property var keyCaps: []      // 字符串数组,如 ["Ctrl", "N"]
    property string tooltipText: ""

    ToolTip.visible: hovered && tooltipText.length > 0
    ToolTip.text: tooltipText
    ToolTip.delay: 500

    padding: 5
    horizontalPadding: 10
    opacity: enabled ? 1 : 0.5

    background: Rectangle {
        radius: 6
        border.width: 1
        border.color: root.pressed ? "#4D000000" : "#33000000"
        color: root.pressed ? "#14000000"
             : root.hovered ? "#0A000000"
             : "transparent"
    }

    contentItem: ColumnLayout {
        spacing: 3

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: root.caption
            color: themeColors.toolbarText
            font.pixelSize: 12
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2
            Repeater {
                model: root.keyCaps
                delegate: KeyCap {
                    caption: modelData
                }
            }
        }
    }
}
