import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// 就地属性编辑面板:点击字段段后在段附近弹出,实时编辑字段属性。
// 与右侧 PropertyPanel 共享同一模型,两处编辑实时同步。
Popup {
    id: panel

    padding: 10
    // 面板打开且焦点不在输入框时,窗口级 ←/→ 快捷键(见 main.qml)切换字段,
    // 面板通过 onSelectedRowChanged 跟随保持显示

    readonly property int row: messageModel.selectedRow
    readonly property bool anyEditorFocused:
        nameField.activeFocus || englishField.activeFocus || typeCombo.activeFocus ||
        bitsSpin.activeFocus || unitField.activeFocus || ratioField.activeFocus ||
        descArea.activeFocus || valueDescArea.activeFocus ||
        validSwitch.activeFocus || observeSwitch.activeFocus

    property real _anchorX: 0
    property real _anchorY: 0

    function syncTypeCombo() {
        var t = messageModel.selectedField.type
        for (var i = 0; i < typeCombo.model.length; ++i) {
            if (typeCombo.model[i].id === t) {
                typeCombo.currentIndex = i
                return
            }
        }
        typeCombo.currentIndex = -1
    }

    function openAt(anchorX, anchorY) {
        _anchorX = anchorX
        _anchorY = anchorY
        if (!opened)
            open()
        else
            positionAt(anchorX, anchorY)
    }

    // 锚点 = 段左缘(窗口坐标);面板优先放段下方,放不下时放到段上方,并 clamp 到窗口内
    function positionAt(anchorX, anchorY) {
        var w = Math.max(width, 300)
        var h = Math.max(height, 420)
        var px = anchorX + 8
        var py = anchorY + 6
        if (px + w > win.width - 8)
            px = Math.max(8, win.width - w - 8)
        if (py + h > win.height - 8)
            py = Math.max(8, anchorY - h - 6)
        x = px
        y = py
    }

    onOpened: {
        positionAt(_anchorX, _anchorY)
        // 弹窗打开时 Qt 会把焦点自动给首个输入框(PopupFocusReason),
        // 抢回焦点到面板内容区:方向键即可切换字段/报文,面板保持打开
        panelContent.forceActiveFocus()
    }

    ColumnLayout {
        id: panelContent
        width: 280
        spacing: 3
        // 面板持有焦点(弹窗 focus:true 会抢走窗口级快捷键的按键):
        // 焦点不在输入框时,方向键在此切换字段/报文,面板保持打开;
        // 输入框聚焦时方向键被编辑器消费(光标移动),不会到达这里。
        focus: true
        Keys.onLeftPressed: {
            if (messageModel.selectedRow > 0)
                win.selectField(messageModel.selectedRow - 1)
        }
        Keys.onRightPressed: {
            if (messageModel.selectedRow < messageModel.count - 1)
                win.selectField(messageModel.selectedRow + 1)
        }
        Keys.onUpPressed: {
            if (messageModel.currentMessageIndex > 0) {
                messageModel.setCurrentMessage(messageModel.currentMessageIndex - 1)
                messageModel.selectedRow = 0
            }
        }
        Keys.onDownPressed: {
            if (messageModel.currentMessageIndex < messageModel.messageCount - 1) {
                messageModel.setCurrentMessage(messageModel.currentMessageIndex + 1)
                messageModel.selectedRow = 0
            }
        }

        Label {
            text: panel.row >= 0
                  ? ("字段 #" + panel.row + "  ·  位偏移 " + messageModel.selectedField.bitOffset +
                     "  ·  字节 " + messageModel.selectedField.byteOffset)
                  : "未选中字段"
            font.bold: true
            font.pixelSize: 13
        }

        GridLayout {
            columns: 2
            columnSpacing: 6
            rowSpacing: 2
            Layout.fillWidth: true

            Label { text: "中文名称"; font.pixelSize: 12 }
            TextField {
                id: nameField
                Layout.fillWidth: true
                text: messageModel.selectedField.name
                placeholderText: "字段名称"
                onTextEdited: messageModel.setFieldAttribute(panel.row, "name", text)
                KeyNavigation.tab: englishField
                Keys.onEscapePressed: panel.close()
            }

            Label { text: "英文名称"; font.pixelSize: 12 }
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                TextField {
                    id: englishField
                    Layout.fillWidth: true
                    text: messageModel.selectedField.englishName
                    placeholderText: "程序读取用,如 state"
                    onTextEdited: messageModel.setFieldAttribute(panel.row, "englishName", text)
                    KeyNavigation.tab: typeCombo
                    Keys.onEscapePressed: panel.close()
                }
                Button {
                    id: pinyinButton
                    implicitWidth: 36
                    implicitHeight: 28
                    // 图标:拼字 + 右上角琥珀色圆形刷新箭头
                    // (icons/pinyin.png,tools/gen-icon.ps1 生成)
                    icon.source: "qrc:/icons/pinyin.png"
                    icon.width: 22
                    icon.height: 22
                    icon.color: "transparent"   // 禁用 Material 前景色染色,保留原图颜色
                    display: Button.IconOnly
                    ToolTip.visible: hovered
                    ToolTip.text: "按中文名称自动生成拼音(仅转换汉字,符号保留)"
                    onClicked: messageModel.setFieldAttribute(panel.row, "englishName",
                                messageModel.chineseToPinyin(messageModel.selectedField.name))
                }
            }

            Label { text: "数据类型"; font.pixelSize: 12 }
            ComboBox {
                id: typeCombo
                Layout.fillWidth: true
                model: messageModel.typeCatalog
                textRole: "label"
                valueRole: "id"
                onActivated: messageModel.setFieldAttribute(panel.row, "type", currentValue)
                KeyNavigation.tab: bitsSpin
            }

            Label { text: "位长"; font.pixelSize: 12 }
            SpinBox {
                id: bitsSpin
                Layout.fillWidth: true
                from: 1
                to: 512
                editable: true
                enabled: messageModel.selectedField.customBits
                value: messageModel.selectedField.bits
                onValueModified: messageModel.setFieldAttribute(panel.row, "bits", value)
                KeyNavigation.tab: unitField
            }

            Label { text: "单位"; font.pixelSize: 12 }
            TextField {
                id: unitField
                Layout.fillWidth: true
                text: messageModel.selectedField.unit
                placeholderText: "任意字符串,如 mV、rpm"
                onTextEdited: messageModel.setFieldAttribute(panel.row, "unit", text)
                KeyNavigation.tab: ratioField
                Keys.onEscapePressed: panel.close()
            }

            Label { text: "比率"; font.pixelSize: 12 }
            TextField {
                id: ratioField
                Layout.fillWidth: true
                text: messageModel.selectedField.ratio
                placeholderText: "读取值 × 比率 = 实际值,如 0.1"
                onTextEdited: messageModel.setFieldAttribute(panel.row, "ratio", text)
                KeyNavigation.tab: validSwitch
                Keys.onEscapePressed: panel.close()
            }

            Label { text: "有效"; font.pixelSize: 12 }
            RowLayout {
                Switch {
                    id: validSwitch
                    checked: messageModel.selectedField.valid
                    onToggled: messageModel.setFieldAttribute(panel.row, "valid", checked)
                    KeyNavigation.tab: observeSwitch
                }
                Label {
                    text: "关闭 = 占位字段"
                    font.pixelSize: 10
                    color: themeColors.textSecondary
                }
            }

            Label { text: "观察"; font.pixelSize: 12 }
            RowLayout {
                Switch {
                    id: observeSwitch
                    checked: messageModel.selectedField.observe
                    enabled: messageModel.selectedField.valid
                    onToggled: messageModel.setFieldAttribute(panel.row, "observe", checked)
                    KeyNavigation.tab: descArea
                }
                Label {
                    text: "观察者模式监听此字段(仅有效字段可观察)"
                    font.pixelSize: 10
                    color: themeColors.textSecondary
                }
            }
        }

        Label { text: "说明"; font.pixelSize: 12 }
        TextArea {
            id: descArea
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            wrapMode: TextEdit.Wrap
            text: messageModel.selectedField.description
            placeholderText: "字段说明"
            onTextChanged: messageModel.setFieldAttribute(panel.row, "description", text)
            KeyNavigation.tab: valueDescArea
            Keys.onEscapePressed: panel.close()
        }

        Label { text: "值含义(每行一条:数值 含义)"; font.pixelSize: 12 }
        TextArea {
            id: valueDescArea
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            wrapMode: TextEdit.Wrap
            text: messageModel.selectedField.valueDescriptions
            placeholderText: "0 关闭\n1 开启\n2 故障"
            onTextChanged: messageModel.setFieldAttribute(panel.row, "valueDescriptions", text)
            KeyNavigation.tab: nameField
            Keys.onEscapePressed: panel.close()
        }

        RowLayout {
            spacing: 4
            Button { text: "上方插入"; onClicked: messageModel.insertField(panel.row) }
            Button { text: "下方插入"; onClicked: messageModel.insertField(panel.row + 1) }
            Button {
                text: "删除"
                enabled: messageModel.count > 1
                onClicked: messageModel.removeField(panel.row)
            }
            Item { Layout.fillWidth: true }
            Label {
                text: "Esc 关闭"
                font.pixelSize: 10
                color: themeColors.textSecondary
            }
        }
    }

    Connections {
        target: messageModel
        function onSelectedFieldChanged() { panel.syncTypeCombo() }
    }
    Component.onCompleted: panel.syncTypeCombo()
}
