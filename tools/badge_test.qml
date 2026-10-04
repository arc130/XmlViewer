import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15

// 独立验证 icon-only Button 的无头渲染
Window {
    id: win
    visible: true
    width: 200
    height: 80
    Material.theme: Material.Light
    Material.accent: "#FFB300"

    Row {
        anchors.centerIn: parent
        spacing: 8
        Button {
            icon.source: "file:///tmp/pinyin.png"
            icon.width: 22
            icon.height: 22
            display: Button.IconOnly
        }
        Button {
            text: "textbtn"
        }
    }

    Timer {
        interval: 1200
        running: true
        onTriggered: {
            win.contentItem.grabToImage(function(result) {
                result.saveToFile("/tmp/badge_test.png")
                Qt.quit()
            })
        }
    }
}
