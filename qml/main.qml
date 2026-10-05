import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import "LayoutMath.js" as L

ApplicationWindow {
    id: win
    visible: true
    width: 1280
    height: 760
    minimumWidth: 900
    minimumHeight: 480
    // 无系统标题栏:自绘 Material 标题栏(TitleBar)负责拖动/最小化/最大化/关闭
    flags: Qt.Window | Qt.FramelessWindowHint
    // 主题:由 --theme 参数经 context property themeColors 注入
    Material.theme: Material.Light
    Material.primary: themeColors.primary
    Material.accent: themeColors.accent
    title: "序列报文结构编辑器"
           + (messageModel.modified ? " *" : "")
           + (messageModel.filePath.length > 0 ? " — " + messageModel.filePath : "")

    property string pendingAction: ""

    // ---- 文件操作 ----------------------------------------------------
    function doNew() {
        if (messageModel.modified) {
            pendingAction = "new"
            confirmDlg.open()
        } else {
            executePending("new")
        }
    }
    function doOpen() {
        if (messageModel.modified) {
            pendingAction = "open"
            confirmDlg.open()
        } else {
            executePending("open")
        }
    }
    function doSave() {
        if (messageModel.filePath.length > 0) {
            if (!messageModel.saveTo(messageModel.filePath))
                errorDlg.open()
        } else {
            doSaveAs()
        }
    }
    function doSaveAs() {
        var p = fileDialogHelper.saveFileName()
        if (p.length > 0 && !messageModel.saveTo(p))
            errorDlg.open()
    }
    function finishConfirm(choice) {
        confirmDlg.close()
        if (choice === "save") {
            if (messageModel.filePath.length === 0) {
                var p = fileDialogHelper.saveFileName()
                if (p.length === 0)
                    return
                if (!messageModel.saveTo(p)) {
                    errorDlg.open()
                    return
                }
            } else if (!messageModel.saveTo(messageModel.filePath)) {
                errorDlg.open()
                return
            }
        }
        executePending(pendingAction)
    }
    function executePending(action) {
        if (action === "new") {
            messageModel.newMessage()
        } else if (action === "open") {
            var p = fileDialogHelper.openFileName()
            if (p.length > 0) {
                if (messageModel.loadFrom(p)) {
                    if (messageModel.lastError.length > 0)
                        warnDlg.open()
                } else {
                    errorDlg.open()
                }
            }
        }
        pendingAction = ""
    }

    // 切换字段并打开就地编辑面板(与点击字段段效果一致)
    function selectField(row) {
        messageModel.selectedRow = row
        openInlinePanel()
    }

    // ---- 就地属性编辑:定位选中字段段的左缘(窗口坐标)并弹出 ----------
    function openInlinePanel() {
        var row = messageModel.selectedRow
        if (row < 0)
            return
        var ax = -1
        var ay = -1
        for (var i = 0; i < barLayout.anchorsModel.count; ++i) {
            var a = barLayout.anchorAt(i)
            if (a.fieldIndex === row) {
                ax = L.xForBit(a.bitInRow, bar.pxPerBit, bar.originX)
                ay = bar.rowY(a.row) + bar.trackH
                break
            }
        }
        if (ax < 0)
            return
        var p = bar.mapToItem(null, ax, ay)
        inlinePanel.openAt(p.x, p.y)
    }

    // ---- 帮助页 --------------------------------------------------------
    // 打开前先关闭就地编辑面板与类型筛选框:两者会抢占焦点并消费 Esc/方向键
    function openHelp() {
        if (inlinePanel.opened)
            inlinePanel.close()
        if (typeFilterPopup.opened)
            typeFilterPopup.close()
        helpPage.open()   // 覆盖层持有焦点,自行处理 Esc
    }

    // ---- smoke 自测入口(由 main.cpp --smoke 调用)--------------------
    function smokeCheck() {
        var fails = []
        // 固定行宽:24+48+3*32=168px → 每行 3 字节 = 24 位
        barLayout.setGeometry(168, 32)
        messageModel.newMessage()
        messageModel.setFieldAttribute(0, "name", "帧头")
        messageModel.insertField(1)
        messageModel.setFieldAttribute(1, "name", "温度")
        messageModel.setFieldAttribute(1, "type", "int16")
        messageModel.setFieldAttribute(1, "unit", "0.1℃")
        messageModel.insertField(2)
        messageModel.setFieldAttribute(2, "name", "状态")
        messageModel.setFieldAttribute(2, "type", "bit3")
        // 末字节自动补占位:帧头、温度、状态、保留5
        if (messageModel.count !== 4) fails.push("pad count=" + messageModel.count)
        if (messageModel.fieldAt(3)["valid"] !== false ||
                messageModel.fieldAt(3)["bits"] !== 5 ||
                messageModel.fieldAt(3)["type"] !== "bit5")
            fails.push("pad field wrong")

        if (messageModel.totalBits !== 32) fails.push("totalBits=" + messageModel.totalBits)
        if (messageModel.totalBytes !== 4) fails.push("totalBytes=" + messageModel.totalBytes)
        if (!messageModel.byteAligned) fails.push("32位应字节对齐")
        // 标尺数字为十进制
        if (L.byteLabel(0) !== "0") fails.push("byteLabel(0)=" + L.byteLabel(0))
        if (L.byteLabel(10) !== "10") fails.push("byteLabel(10)=" + L.byteLabel(10))
        if (L.byteLabel(58) !== "58") fails.push("byteLabel(58)=" + L.byteLabel(58))
        // 类型筛选:按 id/标签包含匹配
        var fu = typeFilterPopup.filtered("uint")
        if (fu.length !== 4) fails.push("filter uint -> " + fu.length + " (want 4)")
        var f16 = typeFilterPopup.filtered("16")
        if (f16.length !== 2) fails.push("filter 16 -> " + f16.length + " (want 2)")
        var fbf = typeFilterPopup.filtered("bit")
        if (fbf.length !== 8) fails.push("filter bit -> " + fbf.length + " (want 8)")
        var fb3 = typeFilterPopup.filtered("bit3")
        if (fb3.length !== 1 || fb3[0].id !== "bit3") fails.push("filter bit3 -> bit3")
        if (typeFilterPopup.filtered("zzz").length !== 0) fails.push("filter zzz -> 0")
        if (messageModel.bitOffsetOf(1) !== 8) fails.push("bitOffsetOf(1)=" + messageModel.bitOffsetOf(1))
        if (messageModel.bitOffsetOf(2) !== 24) fails.push("bitOffsetOf(2)=" + messageModel.bitOffsetOf(2))
        if (messageModel.bitOffsetOf(3) !== 27) fails.push("bitOffsetOf(3)=" + messageModel.bitOffsetOf(3))
        if (messageModel.bitOffsetOf(4) !== 32) fails.push("bitOffsetOf(end)=" + messageModel.bitOffsetOf(4))

        // 行布局:32 位 / 每行 24 位 → 2 行,无跨行字段
        if (barLayout.rowBits !== 24) fails.push("rowBits=" + barLayout.rowBits)
        if (barLayout.rowCount !== 2) fails.push("rowCount=" + barLayout.rowCount)
        if (barLayout.lastRowBits !== 8) fails.push("lastRowBits=" + barLayout.lastRowBits)
        if (barLayout.segmentsModel.count !== 4) fails.push("segments=" + barLayout.segmentsModel.count)
        if (barLayout.breakpointsModel.count !== 0) fails.push("breakpoints=" + barLayout.breakpointsModel.count)
        if (barLayout.anchorsModel.count !== 4) fails.push("anchors=" + barLayout.anchorsModel.count)
        var s1 = barLayout.segmentAt(1), s2 = barLayout.segmentAt(2), s3 = barLayout.segmentAt(3)
        if (s1.row !== 0 || s1.bitInRow !== 8 || s1.bits !== 16) fails.push("seg1 温度 row0 bit8 len16")
        if (s2.row !== 1 || s2.bitInRow !== 0 || s2.bits !== 3) fails.push("seg2 状态 row1 bit0 len3")
        if (s3.row !== 1 || s3.bitInRow !== 3 || s3.bits !== 5) fails.push("seg3 占位 row1 bit3 len5")
        if (s3.valid !== false) fails.push("seg3 valid 应为 false")
        if (barLayout.anchorAt(1).row !== 0 || barLayout.anchorAt(1).bitInRow !== 8)
            fails.push("anchor1 温度应在行0位8")
        if (barLayout.anchorAt(2).row !== 1 || barLayout.anchorAt(2).bitInRow !== 0)
            fails.push("anchor2 状态应在行1位0")
        if (barLayout.anchorAt(3).row !== 1 || barLayout.anchorAt(3).bitInRow !== 3)
            fails.push("anchor3 占位应在行1位3")

        // 行段渲染几何:pxPerByte=32 → pxPerBit=4;行高 = 22+44+8+20+16 = 110
        var rh = bar.rowHeight
        if (rh !== 110) fails.push("rowHeight=" + rh)
        var x0 = bar.xInRow(0), x8 = bar.xInRow(8), x24 = bar.xInRow(24), x3 = bar.xInRow(3)
        var exp = "0:0@" + x0.toFixed(1) + ",22.0," + (x8 - x0).toFixed(1)
                + ";1:0@" + x8.toFixed(1) + ",22.0," + (x24 - x8).toFixed(1)
                + ";2:1@" + x0.toFixed(1) + ",132.0," + (x3 - x0).toFixed(1)
                + ";3:1@" + x3.toFixed(1) + ",132.0," + (x8 - x3).toFixed(1)
        var rep = bar.geometryReport()
        if (rep !== exp) fails.push("geometry got=[" + rep + "] want=[" + exp + "]")

        // 插入点渲染位置(加号 20px 宽,中心对齐字段边界)
        var aexp = "0:14.0,0.0;1:46.0,0.0;2:14.0,110.0;3:26.0,110.0"
        var arep = bar.anchorReport()
        if (arep !== aexp) fails.push("anchors got=[" + arep + "] want=[" + aexp + "]")

        // 帮助页:打开 → 可见且正文非空;F1/Esc 快捷键接线 → 激活即开关
        // (无头环境下合成按键不进入 Qt 快捷键表,故直接断言快捷键对象状态,
        //  并用 activated() 模拟激活 —— 与用户按键共用同一条 onActivated 路径)
        win.openHelp()
        if (!helpPage.visible) fails.push("helpPage 未打开")
        if (helpPage.sections.length !== 6) fails.push("helpPage sections=" + helpPage.sections.length)
        if (helpPage.shortcuts.length !== 13) fails.push("helpPage shortcuts=" + helpPage.shortcuts.length)
        if (helpPage.bodyText.indexOf("基本概念") < 0) fails.push("helpPage 缺少基本概念章节")
        if (helpPage.bodyText.indexOf("快捷键") < 0) fails.push("helpPage 缺少快捷键章节")
        if (helpPage.bodyText.indexOf("拖动重排") < 0) fails.push("helpPage 缺少拖动说明")
        if (!escShortcut.enabled) fails.push("帮助页打开时 Esc 快捷键应启用")
        escShortcut.activated()
        if (helpPage.visible) fails.push("Esc 快捷键未关闭帮助页")
        if (escShortcut.enabled) fails.push("帮助页关闭后 Esc 快捷键应禁用")
        f1Shortcut.activated()
        if (!helpPage.visible) fails.push("F1 快捷键未打开帮助页")
        helpPage.close()
        if (helpPage.visible) fails.push("helpPage 未关闭")

        if (fails.length > 0)
            return "FAIL " + fails.join(" | ")
        return "OK count=4 totalBits=32 rows=2 geometry=" + rep + " anchors=" + arep
    }

    // ---- 顶部:自绘标题栏 + Material 工具栏 ------------------------------
    header: ColumnLayout {
        spacing: 0
        TitleBar {
            Layout.fillWidth: true
            titleText: win.title
        }
        ToolBar {
            Layout.fillWidth: true
            // 白色底 + 深色文字(与背景一致;按钮带圆角轮廓)
            Material.background: themeColors.toolbarBg
            Material.foreground: themeColors.toolbarText
            leftPadding: 8
            rightPadding: 8
            RowLayout {
                spacing: 6
                ToolActionButton { caption: "新建"; keyCaps: ["Ctrl", "N"]; tooltipText: "新建报文 (Ctrl+N)"; onClicked: win.doNew() }
                ToolActionButton { caption: "打开"; keyCaps: ["Ctrl", "O"]; tooltipText: "打开项目 (Ctrl+O)"; onClicked: win.doOpen() }
                ToolActionButton { caption: "保存"; keyCaps: ["Ctrl", "S"]; tooltipText: "保存 (Ctrl+S)"; enabled: messageModel.modified; onClicked: win.doSave() }
                ToolActionButton { caption: "另存为"; keyCaps: ["Ctrl", "⇧", "S"]; tooltipText: "另存为 (Ctrl+Shift+S)"; onClicked: win.doSaveAs() }
                ToolSeparator { }
                ToolActionButton {
                    caption: "插入字段"
                    keyCaps: ["＋"]
                    tooltipText: "在选中字段前插入(悬停柱状图上方点 + 可在任意位置插入)"
                    enabled: messageModel.selectedRow >= 0
                    onClicked: messageModel.insertField(messageModel.selectedRow)
                }
                ToolActionButton {
                    caption: "删除字段"
                    keyCaps: ["Del"]
                    tooltipText: "删除选中字段 (Del)"
                    enabled: messageModel.count > 1 && messageModel.selectedRow >= 0
                    onClicked: messageModel.removeField(messageModel.selectedRow)
                }
                ToolActionButton {
                    caption: "左移"
                    keyCaps: ["Alt", "←"]
                    tooltipText: "左移字段 (Alt+←)"
                    enabled: messageModel.selectedRow > 0
                    onClicked: messageModel.moveField(messageModel.selectedRow, -1)
                }
                ToolActionButton {
                    caption: "右移"
                    keyCaps: ["Alt", "→"]
                    tooltipText: "右移字段 (Alt+→)"
                    enabled: messageModel.selectedRow >= 0 &&
                             messageModel.selectedRow < messageModel.count - 1
                    onClicked: messageModel.moveField(messageModel.selectedRow, 1)
                }
                ToolActionButton {
                    caption: "上个字段"
                    keyCaps: ["←"]
                    tooltipText: "上一个字段并打开编辑窗 (←)"
                    enabled: messageModel.selectedRow > 0
                    onClicked: win.selectField(messageModel.selectedRow - 1)
                }
                ToolActionButton {
                    caption: "下个字段"
                    keyCaps: ["→"]
                    tooltipText: "下一个字段并打开编辑窗 (→)"
                    enabled: messageModel.selectedRow >= 0 &&
                             messageModel.selectedRow < messageModel.count - 1
                    onClicked: win.selectField(messageModel.selectedRow + 1)
                }
                ToolActionButton {
                    caption: "上个报文"
                    keyCaps: ["↑"]
                    tooltipText: "上一个报文 (↑)"
                    enabled: messageModel.currentMessageIndex > 0
                    onClicked: {
                        messageModel.setCurrentMessage(messageModel.currentMessageIndex - 1)
                        messageModel.selectedRow = 0
                    }
                }
                ToolActionButton {
                    caption: "下个报文"
                    keyCaps: ["↓"]
                    tooltipText: "下一个报文 (↓)"
                    enabled: messageModel.currentMessageIndex < messageModel.messageCount - 1
                    onClicked: {
                        messageModel.setCurrentMessage(messageModel.currentMessageIndex + 1)
                        messageModel.selectedRow = 0
                    }
                }
                ToolSeparator { }
                ToolActionButton {
                    caption: "帮助"
                    keyCaps: ["F1"]
                    tooltipText: "使用帮助 (F1)"
                    onClicked: helpPage.visible ? helpPage.close() : win.openHelp()
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: "悬停柱状图上方可插入 + | 右键分段弹出菜单"
                    color: themeColors.toolbarText
                    opacity: 0.7
                    font.pixelSize: 11
                }
            }
        }
    }

    // ---- 主体:柱状图 + 属性面板 ----------------------------------------
    SplitView {
        anchors.fill: parent

        MessageListPanel {
            SplitView.preferredWidth: 190
            SplitView.minimumWidth: 150
            SplitView.fillHeight: true
        }

        ColumnLayout {
            SplitView.fillWidth: true
            SplitView.fillHeight: true

            RowLayout {
                Label { text: "缩放"; font.pixelSize: 11 }
                Slider {
                    id: zoomSlider
                    Layout.preferredWidth: 140
                    from: 8
                    to: 64
                    stepSize: 4
                    value: bar.pxPerByte
                    onValueChanged: bar.pxPerByte = value
                }
                Label {
                    text: zoomSlider.value + " px/字节"
                    font.pixelSize: 11
                    color: "#757575"
                }
                Item { Layout.fillWidth: true }
            }

            ScrollView {
                id: sv
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AlwaysOn

                MessageBar {
                    id: bar
                    viewportWidth: sv.width
                    inputFilterEnabled: !inlinePanel.opened && !helpPage.visible
                    onTypeInputStarted: typeFilterPopup.openWith(initialText)
                    onInlineEditRequested: {
                        messageModel.selectedRow = fieldIndex
                        win.openInlinePanel()
                    }
                    onInlineEditDismissed: inlinePanel.close()
                }
            }
        }
    }

    // ---- 底部状态条 ----------------------------------------------------
    footer: Frame {
        RowLayout {
            Label {
                text: "总长 " + messageModel.totalBits + " 位 / " + messageModel.totalBytes + " 字节"
                font.pixelSize: 12
            }
            Label {
                visible: !messageModel.byteAligned
                text: "⚠ 未按字节对齐(最后 " + (messageModel.totalBits % 8) + " 位)"
                color: "#c62828"
                font.pixelSize: 12
            }
            Item { Layout.fillWidth: true }
            Label {
                visible: messageModel.selectedRow >= 0
                text: "选中: " + messageModel.selectedField.name +
                      "  (位偏移 " + messageModel.selectedField.bitOffset + ")"
                font.pixelSize: 12
                color: "#757575"
            }
        }
    }

    // ---- 无边框窗口:边缘调整大小手柄 -----------------------------------
    MouseArea { anchors.top: parent.top; anchors.left: parent.left; width: 6; height: 6; cursorShape: Qt.SizeFDiagCursor; onPressed: win.startSystemResize(Qt.TopEdge | Qt.LeftEdge) }
    MouseArea { anchors.top: parent.top; anchors.right: parent.right; width: 6; height: 6; cursorShape: Qt.SizeBDiagCursor; onPressed: win.startSystemResize(Qt.TopEdge | Qt.RightEdge) }
    MouseArea { anchors.bottom: parent.bottom; anchors.left: parent.left; width: 6; height: 6; cursorShape: Qt.SizeBDiagCursor; onPressed: win.startSystemResize(Qt.BottomEdge | Qt.LeftEdge) }
    MouseArea { anchors.bottom: parent.bottom; anchors.right: parent.right; width: 6; height: 6; cursorShape: Qt.SizeFDiagCursor; onPressed: win.startSystemResize(Qt.BottomEdge | Qt.RightEdge) }
    MouseArea { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 5; cursorShape: Qt.SizeVerCursor; onPressed: win.startSystemResize(Qt.TopEdge) }
    MouseArea { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 5; cursorShape: Qt.SizeVerCursor; onPressed: win.startSystemResize(Qt.BottomEdge) }
    MouseArea { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 5; cursorShape: Qt.SizeHorCursor; onPressed: win.startSystemResize(Qt.LeftEdge) }
    MouseArea { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 5; cursorShape: Qt.SizeHorCursor; onPressed: win.startSystemResize(Qt.RightEdge) }

    // ---- 快捷键 --------------------------------------------------------
    // 帮助页打开时(Esc 除外)全部禁用,避免误改遮罩后的报文
    Shortcut { sequence: StandardKey.New; enabled: !helpPage.visible; onActivated: win.doNew() }
    Shortcut { sequence: StandardKey.Open; enabled: !helpPage.visible; onActivated: win.doOpen() }
    Shortcut { sequence: StandardKey.Save; enabled: !helpPage.visible; onActivated: win.doSave() }
    Shortcut { sequence: "Ctrl+Shift+S"; enabled: !helpPage.visible; onActivated: win.doSaveAs() }
    Shortcut {
        sequences: [StandardKey.Delete]
        enabled: messageModel.selectedRow >= 0 && messageModel.count > 1 &&
                 !inlinePanel.anyEditorFocused && !helpPage.visible
        onActivated: messageModel.removeField(messageModel.selectedRow)
    }
    Shortcut {
        sequence: "Alt+Left"
        enabled: messageModel.selectedRow > 0 && !helpPage.visible
        onActivated: messageModel.moveField(messageModel.selectedRow, -1)
    }
    Shortcut {
        sequence: "Alt+Right"
        enabled: messageModel.selectedRow >= 0 &&
                 messageModel.selectedRow < messageModel.count - 1 && !helpPage.visible
        onActivated: messageModel.moveField(messageModel.selectedRow, 1)
    }
    // ↑/↓:切换上一个/下一个报文;←/→:切换上一个/下一个字段
    Shortcut {
        sequence: "Up"
        enabled: messageModel.currentMessageIndex > 0 &&
                 !inlinePanel.opened && !typeFilterPopup.opened && !helpPage.visible
        onActivated: {
            messageModel.setCurrentMessage(messageModel.currentMessageIndex - 1)
            messageModel.selectedRow = 0
        }
    }
    Shortcut {
        sequence: "Down"
        enabled: messageModel.currentMessageIndex < messageModel.messageCount - 1 &&
                 !inlinePanel.opened && !typeFilterPopup.opened && !helpPage.visible
        onActivated: {
            messageModel.setCurrentMessage(messageModel.currentMessageIndex + 1)
            messageModel.selectedRow = 0
        }
    }
    // 面板打开时方向键由 InlinePanel 内容区处理(弹窗抢焦点,窗口级快捷键收不到按键)
    Shortcut {
        sequence: "Left"
        enabled: messageModel.selectedRow > 0 &&
                 !inlinePanel.opened && !typeFilterPopup.opened && !helpPage.visible
        onActivated: win.selectField(messageModel.selectedRow - 1)
    }
    Shortcut {
        sequence: "Right"
        enabled: messageModel.selectedRow < messageModel.count - 1 &&
                 !inlinePanel.opened && !typeFilterPopup.opened && !helpPage.visible
        onActivated: win.selectField(messageModel.selectedRow + 1)
    }
    // F1 打开帮助;仅帮助页可见时 Esc 才接管(避免抢占就地编辑面板的 Esc)。
    // 用 ApplicationShortcut:Popup 是独立子窗口,占焦点时 WindowShortcut 的
    // 上下文匹配(obj == focusWindow 严格相等)会失配 —— 弹窗打开时 F1/Esc 会失灵
    Shortcut { id: f1Shortcut; sequence: "F1"; context: Qt.ApplicationShortcut; onActivated: win.openHelp() }
    Shortcut {
        id: escShortcut
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: helpPage.visible
        onActivated: helpPage.close()
    }

    // ---- 就地属性编辑面板(点击段后在段附近弹出)-----------------------
    InlinePanel { id: inlinePanel; objectName: "inlinePanel" }

    Connections {
        target: messageModel
        function onSelectedRowChanged() {
            // 面板已打开时跟随选中字段重定位
            if (inlinePanel.opened)
                win.openInlinePanel()
        }
    }

    // ---- 类型筛选弹窗(点击段后直接键入类型名,输入即过滤)---------------
    Popup {
        id: typeFilterPopup
        x: Math.round((win.width - width) / 2)
        y: Math.round(win.height / 3)
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        function openWith(initialText) {
            typeFilterInput.text = initialText
            open()
            // 初始高亮当前字段的类型
            var cur = messageModel.selectedField.type
            var m = typeFilterList.model
            for (var i = 0; i < m.length; ++i) {
                if (m[i].id === cur) {
                    typeFilterList.currentIndex = i
                    break
                }
            }
            typeFilterInput.forceActiveFocus()
            typeFilterInput.cursorPosition = typeFilterInput.text.length
        }

        // 参数显式传入,保证绑定追踪输入框变化
        function filtered(t) {
            var q = t.toLowerCase()
            var out = []
            var cat = messageModel.typeCatalog
            for (var i = 0; i < cat.length; ++i) {
                var item = cat[i]
                if (item.id.toLowerCase().indexOf(q) >= 0 ||
                        item.label.toLowerCase().indexOf(q) >= 0)
                    out.push(item)
            }
            return out
        }

        function applyCurrent() {
            var m = typeFilterList.model
            var idx = typeFilterList.currentIndex
            if (idx >= 0 && idx < m.length) {
                messageModel.setFieldAttribute(messageModel.selectedRow, "type", m[idx].id)
                close()
            }
        }

        ColumnLayout {
            width: 280
            spacing: 4
            TextField {
                id: typeFilterInput
                Layout.fillWidth: true
                placeholderText: "输入类型名筛选(如 uint、16、float)…"
                onTextChanged: typeFilterList.currentIndex = 0
                Keys.onUpPressed: typeFilterList.decrementCurrentIndex()
                Keys.onDownPressed: typeFilterList.incrementCurrentIndex()
                Keys.onReturnPressed: typeFilterPopup.applyCurrent()
                Keys.onEscapePressed: typeFilterPopup.close()
            }
            ListView {
                id: typeFilterList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(260, count * 26 + 2)
                clip: true
                keyNavigationWraps: true
                model: typeFilterPopup.filtered(typeFilterInput.text)
                delegate: Item {
                    width: typeFilterList.width
                    height: 26
                    Rectangle {
                        anchors.fill: parent
                        color: index === typeFilterList.currentIndex ? themeColors.accent : "transparent"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        text: modelData.label
                        color: index === typeFilterList.currentIndex ? "white" : "#333333"
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            typeFilterList.currentIndex = index
                            typeFilterPopup.applyCurrent()
                        }
                    }
                }
            }
            Label {
                visible: typeFilterList.count === 0
                text: "无匹配类型"
                color: "#757575"
                font.pixelSize: 12
            }
        }
    }

    // ---- 对话框 --------------------------------------------------------
    Dialog {
        id: confirmDlg
        title: "未保存的更改"
        modal: true
        standardButtons: Dialog.NoButton
        x: Math.round((win.width - 360) / 2)
        y: Math.round(win.height / 3)

        ColumnLayout {
            spacing: 12
            Label {
                Layout.preferredWidth: 320
                wrapMode: Text.Wrap
                text: "当前结构有未保存的更改,继续前是否保存?"
            }
            RowLayout {
                Item { Layout.fillWidth: true }
                Button { text: "保存"; onClicked: win.finishConfirm("save") }
                Button { text: "不保存"; onClicked: win.finishConfirm("discard") }
                Button { text: "取消"; onClicked: confirmDlg.close() }
            }
        }
    }

    Dialog {
        id: errorDlg
        title: "错误"
        modal: true
        standardButtons: Dialog.Ok
        width: 420   // 显式宽度,避免 Qt 5.15 的 implicitWidth 绑定循环
        x: Math.round((win.width - width) / 2)
        y: Math.round(win.height / 3)
        Label {
            width: 380
            wrapMode: Text.Wrap
            text: messageModel.lastError
        }
    }

    Dialog {
        id: warnDlg
        title: "警告"
        modal: true
        standardButtons: Dialog.Ok
        width: 420   // 显式宽度,避免 Qt 5.15 的 implicitWidth 绑定循环
        x: Math.round((win.width - width) / 2)
        y: Math.round(win.height / 3)
        Label {
            width: 380
            wrapMode: Text.Wrap
            text: messageModel.lastError
        }
    }

    // ---- 帮助页(窗口内覆盖层,非 Popup;声明在最后 → 位于内容区顶层)----
    HelpPage {
        id: helpPage
        // 关闭后把焦点还给柱状图(方向键切换字段/键入筛选依赖它)
        onClosed: bar.forceActiveFocus()
    }
}
