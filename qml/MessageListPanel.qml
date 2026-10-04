import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// 左侧报文列表:PPT 幻灯片预览样式。每张卡片 = 帧名称 + 帧ID/类型 +
// 迷你结构预览条 + 字段数/总长信息;点击切换当前报文,双击编辑报文属性
// (帧名称/帧ID/帧类型),悬停显示删除按钮,"+ 新建报文"弹出创建对话框。
Frame {
    id: panel

    // -1 = 新建模式;>=0 = 编辑该索引的报文
    property int editTarget: -1

    function openNewDialog(anchorX, anchorY) {
        editTarget = -1
        msgNameInput.text = ""
        msgIdInput.text = ""
        msgTypeInput.text = ""
        msgDlg.title = "新建报文"
        msgDlg.openAt(anchorX, anchorY)
    }

    function openEditDialog(index, anchorX, anchorY) {
        editTarget = index
        var info = messageModel.messageInfo(index)
        msgNameInput.text = info.name
        msgIdInput.text = info.frameId
        msgTypeInput.text = info.frameType
        msgDlg.title = "报文属性"
        msgDlg.openAt(anchorX, anchorY)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        Label {
            text: "报文"
            font.bold: true
            font.pixelSize: 14
        }

        Button {
            id: newMsgBtn
            Layout.fillWidth: true
            text: "+ 新建报文"
            onClicked: {
                var p = newMsgBtn.mapToItem(null, newMsgBtn.width / 2, newMsgBtn.height)
                panel.openNewDialog(p.x, p.y)
            }
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: messageModel.messageCount

            delegate: Rectangle {
                id: card
                property int msgIndex: index
                readonly property var info: messageModel.messageInfo(msgIndex)

                width: listView.width
                height: 104
                radius: 4
                color: msgIndex === messageModel.currentMessageIndex ? themeColors.cardSel : themeColors.cardBg
                border.width: msgIndex === messageModel.currentMessageIndex ? 2 : 1
                border.color: msgIndex === messageModel.currentMessageIndex ? themeColors.accent : themeColors.cardBorder

                MouseArea {
                    id: cardMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: messageModel.setCurrentMessage(msgIndex)
                    onDoubleClicked: {
                        var p = card.mapToItem(null, mouse.x, mouse.y)
                        panel.openEditDialog(msgIndex, p.x, p.y)
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            text: info.name
                            color: themeColors.cardText
                            font.bold: msgIndex === messageModel.currentMessageIndex
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            visible: cardMa.containsMouse && messageModel.messageCount > 1
                            width: 18
                            height: 18
                            radius: 9
                            color: closeMa.containsMouse ? "#e53935" : "#bdbdbd"
                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: "white"
                                font.pixelSize: 10
                                font.bold: true
                            }
                            MouseArea {
                                id: closeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: messageModel.removeMessage(msgIndex)
                            }
                        }
                    }

                    Label {
                        text: "ID: " + (info.frameId === "" ? "—" : info.frameId) +
                              "  ·  类型: " + (info.frameType === "" ? "—" : info.frameType)
                        font.pixelSize: 10
                        color: themeColors.cardSub
                        elide: Text.ElideRight
                    }

                    // 迷你结构预览条(各字段按位长比例着色)
                    Item {
                        id: previewStrip
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12
                        clip: true
                        Repeater {
                            // 逗号表达式:依赖 previewRevision,内容变化时重算
                            model: (messageModel.previewRevision,
                                    messageModel.messagePreview(msgIndex))
                            delegate: Rectangle {
                                // 累加前缀:本段起点 = 前面字段比例之和 × 条宽
                                readonly property real prefix: {
                                    var s = 0
                                    var m = messageModel.messagePreview(msgIndex)
                                    for (var k = 0; k < index; ++k)
                                        s += m[k].ratio
                                    return s
                                }
                                x: prefix * previewStrip.width
                                width: modelData.ratio * previewStrip.width
                                height: 10
                                color: modelData.color
                            }
                        }
                    }

                    Label {
                        text: info.fieldCount + " 个字段 · " + info.totalBits + " 位 / " +
                              info.totalBytes + " 字节"
                        font.pixelSize: 10
                        color: themeColors.cardSub
                    }
                }
            }
        }
    }

    // ---- 报文属性对话框(新建 / 编辑共用,在鼠标位置弹出)---------------
    Dialog {
        id: msgDlg
        title: "报文属性"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel

        property real _ax: 0
        property real _ay: 0

        function openAt(anchorX, anchorY) {
            _ax = anchorX
            _ay = anchorY
            open()
        }

        onOpened: {
            // 锚点 = 鼠标位置,弹窗放在其右下方并 clamp 到窗口内
            var w = Math.max(width, 300)
            var h = Math.max(height, 300)
            x = Math.min(_ax + 8, win.width - w - 8)
            y = Math.min(_ay + 8, win.height - h - 8)
            x = Math.max(8, x)
            y = Math.max(8, y)
        }

        ColumnLayout {
            width: 280
            spacing: 6
            Label { text: "帧名称"; font.pixelSize: 12 }
            TextField {
                id: msgNameInput
                Layout.fillWidth: true
                placeholderText: "如 心跳包"
            }
            Label { text: "帧 ID"; font.pixelSize: 12 }
            TextField {
                id: msgIdInput
                Layout.fillWidth: true
                placeholderText: "如 0x01"
            }
            Label { text: "帧类型"; font.pixelSize: 12 }
            TextField {
                id: msgTypeInput
                Layout.fillWidth: true
                placeholderText: "如 心跳"
            }
        }

        onAccepted: {
            if (panel.editTarget < 0) {
                messageModel.addMessage()
                var idx = messageModel.messageCount - 1
                messageModel.setMessageAttribute(idx, "name", msgNameInput.text)
                messageModel.setMessageAttribute(idx, "frameId", msgIdInput.text)
                messageModel.setMessageAttribute(idx, "frameType", msgTypeInput.text)
            } else {
                var i = panel.editTarget
                messageModel.setMessageAttribute(i, "name", msgNameInput.text)
                messageModel.setMessageAttribute(i, "frameId", msgIdInput.text)
                messageModel.setMessageAttribute(i, "frameType", msgTypeInput.text)
            }
        }
    }
}
