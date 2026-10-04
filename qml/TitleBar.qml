import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// Material 风格自绘标题栏(无边框窗口):深色底浅色字(themeColors),
// 支持拖动移动、双击最大化、最小化/最大化/关闭按钮。
Rectangle {
    id: titleBar

    height: 44
    color: themeColors.titleBar

    property alias titleText: titleLabel.text

    // 拖动移动 + 双击最大化(位于按钮下层,不拦截按钮)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressed: win.startSystemMove()
        onDoubleClicked: win.visibility === Window.Maximized
                         ? win.showNormal() : win.showMaximized()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Label {
            id: titleLabel
            Layout.leftMargin: 16
            Layout.fillWidth: true
            text: "序列报文结构编辑器"
            color: themeColors.titleText
            font.pixelSize: 14
            elide: Text.ElideRight
        }

        WindowButton {
            buttonText: "–"
            onClicked: win.showMinimized()
        }
        WindowButton {
            buttonText: "□"
            onClicked: win.visibility === Window.Maximized
                       ? win.showNormal() : win.showMaximized()
        }
        WindowButton {
            buttonText: "✕"
            isClose: true
            onClicked: win.close()
        }
    }
}
