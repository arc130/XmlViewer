import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// 使用帮助页:窗口内覆盖层(普通 Item,非 Popup)。
// 不用 Popup/Dialog 的原因:Qt 5.15 的 Popup 渲染在独立子窗口,
// --screenshot 的主窗口 grabWindow 拍不到,且无头 xvfb 下背景透明/内容缺失;
// 普通 Item 覆盖层随主窗口一起渲染与截图,可做像素级校验。
// 注意:它是 ApplicationWindow 的子项,只覆盖内容区(contentItem 不含
// 标题栏/工具栏/状态栏),遮罩不遮挡页眉页脚 —— 标题栏与工具栏保持可见可点。
Rectangle {
    id: help
    objectName: "helpPage"

    // 覆盖整个内容区(作为 ApplicationWindow 子项,parent = contentItem:
    // 不含标题栏/工具栏/状态条)。漏掉此绑定会导致尺寸 0×0:遮罩与卡片
    // 背景都不绘制,只留下错位的子文本
    anchors.fill: parent
    visible: false
    color: "#66000000"          // 40% 黑遮罩;点击遮罩空白处关闭

    // 打开时持有焦点并自行处理 Esc(与 InlinePanel 同款策略:窗口级快捷键在
    // 焦点被覆盖层/弹窗接管时收不到按键;带 escapePressed 的项会先接受
    // ShortcutOverride,快捷键表根本轮不到)。main.qml 的 Esc 快捷键作兜底。
    focus: true
    Keys.onEscapePressed: help.close()

    // 帮助正文(界面渲染与 smoke 断言共用同一数据源)
    readonly property var sections: [
        { title: "一、基本概念", lines: [
            "报文由若干「字段」按顺序组成;每个字段有名称、数据类型、位长、单位、比率、说明等属性。",
            "中间的柱状图按位排布字段:段宽 = 位长 ×(缩放 px/字节 ÷ 8)。报文过长时自动按字节边界换行,断开处画成撕纸撕口。",
            "每行下方是字节标尺,显示全局字节编号(十进制,跨行连续)。",
            "含位域的字节中未被字段覆盖的位会自动生成淡显的「保留N」占位字段,保证每字节 8 位完整覆盖;占位字段可改为真实字段,位域移除后自动清除。"
        ] },
        { title: "二、报文管理(左侧列表)", lines: [
            "点击卡片切换当前报文;双击卡片弹出属性对话框,填写帧名称 / 帧 ID / 帧类型;卡片上的迷你结构条按位长比例显示各字段。",
            "「+ 新建报文」新增报文;悬停卡片右上角 ✕ 删除该报文(至少保留一个)。",
            "工具栏「上个报文 / 下个报文」或 ↑ / ↓ 快捷键切换报文。"
        ] },
        { title: "三、编辑字段", lines: [
            "插入:鼠标悬停柱状图,字段左边界出现琥珀色「+」,点击插入;行尾「+」在报文末尾追加字段。字段太窄时可用右键菜单插入。",
            "编辑:点击字段段,在段附近弹出就地编辑面板,所有修改即时生效。",
            "面板属性:中文名称、英文名称、数据类型、位长、单位、比率、有效、观察、说明、值含义。",
            "英文名称右侧的拼音按钮可按中文名自动生成拼音(仅汉字转换,数字与符号保留)。",
            "数据类型:uint8/16/32/64、int8/16/32/64、float、double、位域 bit1~bit8、字节块(8 的整数倍)。",
            "「有效」关闭后字段变为占位字段(柱状图淡显);只有有效字段可以勾选「观察」。",
            "「值含义」每行一条「数值 含义」,如 0 关闭 / 1 开启,供后续数据解析使用。",
            "面板内 Tab 在各编辑项间循环;Esc 或点击柱状图空白处关闭面板。"
        ] },
        { title: "四、选择与调整字段", lines: [
            "选择:单击字段段(选中态为琥珀色描边);← / → 切换上一个 / 下一个字段并打开编辑面板。",
            "移动:Alt+← / Alt+→ 左右移动选中字段;Del 或右键菜单「删除该字段」删除字段。",
            "拖动重排:长按字段拖动,落点自动吸附到最近的字段边界,松开完成整字段移动(字段长度不变)。",
            "右键字段段弹出菜单:在此前插入字段 / 在此后插入字段 / 删除该字段 / 左移 / 右移。",
            "键入筛选:选中字段后直接键入类型名(如 uint、16、bit3)弹出筛选框,输入即过滤;↑↓ 选择、Enter 应用、Esc 关闭。"
        ] },
        { title: "五、文件与视图", lines: [
            "新建 Ctrl+N / 打开 Ctrl+O / 保存 Ctrl+S / 另存为 Ctrl+Shift+S;项目保存为 JSON 文件,一个文件可包含多个报文。",
            "有未保存的更改时,新建 / 打开前会提示先保存。",
            "缩放:工具栏滑块调整柱状图比例(8~64 px/字节)。",
            "主题:启动参数 --theme <名称> 选择配色方案(默认「工程蓝 + 琥珀」)。",
            "底部状态栏显示报文总长与选中字段的位偏移;未按字节对齐时给出警告。"
        ] },
        { title: "六、快捷键", table: true, lines: [] }
    ]

    // 快捷键总表(键帽用 KeyCap 渲染,与工具栏一致)
    readonly property var shortcuts: [
        { keys: ["Ctrl", "N"],      text: "新建项目" },
        { keys: ["Ctrl", "O"],      text: "打开项目" },
        { keys: ["Ctrl", "S"],      text: "保存" },
        { keys: ["Ctrl", "⇧", "S"], text: "另存为" },
        { keys: ["↑"],              text: "上一个报文" },
        { keys: ["↓"],              text: "下一个报文" },
        { keys: ["←"],              text: "上一个字段(并打开编辑面板)" },
        { keys: ["→"],              text: "下一个字段(并打开编辑面板)" },
        { keys: ["Alt", "←"],       text: "左移选中字段" },
        { keys: ["Alt", "→"],       text: "右移选中字段" },
        { keys: ["Del"],            text: "删除选中字段" },
        { keys: ["F1"],             text: "打开本帮助页" },
        { keys: ["Esc"],            text: "关闭本帮助页 / 就地编辑面板 / 筛选框" }
    ]

    // 全部正文纯文本(供 smoke 断言内容非空)
    readonly property string bodyText: {
        var out = []
        for (var i = 0; i < sections.length; ++i) {
            out.push(sections[i].title)
            for (var j = 0; j < sections[i].lines.length; ++j)
                out.push(sections[i].lines[j])
        }
        for (var k = 0; k < shortcuts.length; ++k)
            out.push(shortcuts[k].text)
        return out.join("\n")
    }

    signal closed()             // main.qml 据此把焦点还给柱状图

    function open() {
        visible = true
        forceActiveFocus()
    }
    function close() {
        if (!visible)
            return
        visible = false
        closed()
    }

    // 遮罩:点击空白关闭;吞掉滚轮,避免穿透到下层柱状图
    MouseArea {
        anchors.fill: parent
        onClicked: help.close()
        onWheel: wheel.accepted = true
    }

    // 帮助卡片:居中,尺寸随窗口收缩但不超过 860×600
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(help.width - 100, 860)
        height: Math.min(help.height - 60, 600)
        radius: 8
        color: themeColors.cardBg
        border.width: 1
        border.color: themeColors.cardBorder

        // 吞掉卡片区域的点击,避免穿透到遮罩而误关闭
        MouseArea {
            anchors.fill: parent
            onWheel: wheel.accepted = true
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            // 标题行 + 关闭按钮
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 14
                Layout.bottomMargin: 10
                spacing: 8

                Label {
                    text: "使用帮助"
                    font.bold: true
                    font.pixelSize: 16
                    color: themeColors.cardText
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: closeMa.containsMouse ? "#e53935" : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 13
                        color: closeMa.containsMouse ? "white" : themeColors.cardSub
                    }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: help.close()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: themeColors.cardBorder
            }

            ScrollView {
                id: helpScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 14
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AlwaysOn

                // 内容宽度必须绑定 availableWidth(减去滚动条),否则长行被裁剪
                Column {
                    width: helpScroll.availableWidth
                    spacing: 12

                    Repeater {
                        model: help.sections
                        delegate: Column {
                            id: secCol
                            property var section: modelData
                            width: parent.width
                            spacing: 5

                            Text {
                                width: parent.width
                                text: secCol.section.title
                                font.bold: true
                                font.pixelSize: 14
                                color: themeColors.cardText
                            }

                            Repeater {
                                model: secCol.section.lines
                                delegate: Text {
                                    width: secCol.width
                                    text: modelData
                                    wrapMode: Text.Wrap
                                    lineHeight: 1.3
                                    font.pixelSize: 12
                                    color: themeColors.cardText
                                }
                            }

                            // 快捷键表(仅 table 节渲染;KeyCap 是白底键帽,需浅色衬底)
                            Rectangle {
                                id: keyPanel
                                visible: secCol.section.table === true
                                width: secCol.width
                                height: secCol.section.table === true ? keyCol.height + 16 : 0
                                radius: 6
                                color: themeColors.rowBg
                                border.width: 1
                                border.color: themeColors.cardBorder

                                Column {
                                    id: keyCol
                                    x: 8
                                    y: 8
                                    width: parent.width - 16
                                    spacing: 4

                                    Repeater {
                                        model: help.shortcuts
                                        delegate: Item {
                                            id: keyRow
                                            property var entry: modelData
                                            width: keyCol.width
                                            height: 22

                                            Row {
                                                id: keysRow
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 3
                                                Repeater {
                                                    model: keyRow.entry.keys
                                                    delegate: KeyCap { caption: modelData }
                                                }
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: 150
                                                width: parent.width - 150
                                                text: keyRow.entry.text
                                                elide: Text.ElideRight
                                                font.pixelSize: 12
                                                color: themeColors.cardText
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { width: 1; height: 6 }   // 底部留白
                }
            }
        }
    }
}
