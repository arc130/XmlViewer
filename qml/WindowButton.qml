import QtQuick 2.15

// 标题栏窗口控制按钮:Material 风格图标按钮
Rectangle {
    id: root

    property string buttonText: ""
    property bool isClose: false
    signal clicked()

    width: 46
    height: parent ? parent.height : 44

    color: ma.pressed
           ? (isClose ? "#c62828" : "rgba(128,128,128,0.35)")
           : ma.containsMouse
             ? (isClose ? "#e53935" : "rgba(128,128,128,0.25)")
             : "transparent"

    Text {
        anchors.centerIn: parent
        text: root.buttonText
        color: themeColors.titleText
        font.pixelSize: 15
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
