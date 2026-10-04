import QtQuick 2.15

// Material Design 扁平键帽:白色半透明底 + 细描边 + 圆角,深灰文字
Rectangle {
    id: root

    property string caption: ""

    width: Math.max(20, caption.length * 8 + 12)
    height: 20
    radius: 4
    color: "#D9FFFFFF"
    border.width: 1
    border.color: "#26000000"

    Text {
        anchors.centerIn: parent
        text: root.caption
        font.pixelSize: 10
        font.weight: Font.Medium
        color: "#3C4043"
    }
}
