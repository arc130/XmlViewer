# 序列报文结构编辑器 (XmlViewer)

基于 Qt 5.15 / QML 的序列报文(串行数据帧)结构编辑器。报文由字段组成,
每个字段可编辑**名称、数据类型、单位、说明**;字段以**分段柱状图**显示,
**按位分段**(支持位域:一个字节可包含多个字段);可在**任意位置动态插入/删除**字段。

## 功能

- **多报文项目**:左侧 PPT 预览风格报文卡片列表(迷你结构预览条按字段类型
  着色),点击切换、悬停删除;**每个报文有帧名称/帧 ID/帧类型属性**,
  "+ 新建报文"弹出创建对话框,双击卡片弹出属性编辑对话框;
  中间显示当前报文的分段柱状图;项目保存为 JSON v2(多报文),
  兼容打开 v1 单报文文件

- 分段柱状图:段宽按字段位长比例显示(4 px/位 @ 默认缩放),按类型着色
- **超宽自动换行**:报文长度超出可视宽度时按字节边界折行(行宽随窗口/缩放自适应);
  跨行字段被切开成多段,段端部直接呈**撕纸撕口**:波浪形(一峰一谷)缺口露出
  背景,撕口缘为深色撕痕 + 白色纸纤维线;常态无顶/底轮廓线(选中态才显示
  完整高亮框);字节标尺随每行重复,编号全局连续(十进制)
- 字段类型:uint8/int8/uint16/int16/uint32/int32/uint64/int64/float/double、
  **位域 bit1~bit8**(固定位长,改长度即换类型,键入筛选可快速设置)、
  字节块(8 的倍数)
- **位域字节完整覆盖**:含位域的字节内未说明的位自动生成"保留N"占位字段
  (bitN、无效、柱状图淡显)——所有编辑操作后自动重算;占位可改名/设为有效
  变成真实位域;位域移除后占位自动清除;旧 JSON 的 bitfield 类型自动映射 bitN
- **字段属性**:中文名称、英文名称(程序读取用)、数据类型、位长、单位(任意
  字符串)、比率(读取值×比率=实际值)、是否观察(观察者模式监听,**仅有效
  字段可观察**)、是否有效(无效=占位字段,柱状图淡显)、说明、值含义表
  (多行文本,每行一条"数值 含义",零按钮直接输入)
- **中文名→拼音**:英文名称旁的"拼音"按钮把中文名称转成无调拼音写入英文名称,
  仅转换汉字、数字/符号原样保留(如 温度1_状态 → wendu1_zhuangtai);
  ICU 与内置码表双路径,无 ICU 环境(如 Windows 官方 Qt)零依赖可用
- 末字节不满 8 位时显示填充区
- 动态编辑:
  - 悬停柱状图上方 → 每个字段左边界出现 "+" 插入点(位宽过小时用右键菜单)
  - **长按左键拖动字段 → 拖到目标位置松开即可重排**:落点**吸附到最近字段边界**
    (整字段移动,不改变任何字段长度),拖动中橙色指示线同步吸附
  - **点击段 → 在段附近弹出就地编辑面板**(浮动卡片:名称/类型/位长/单位/
    说明 + 上方/下方插入、删除按钮),实时编辑,Esc 或点击空白关闭,
    ↑/↓ 切换选中时面板跟随;面板打开期间键入筛选自动禁用
  - **点击段后直接键盘键入类型名 → 弹出类型筛选框**(输入即过滤,匹配类型
    id 或中文标签;↑↓ 选择、Enter 选中、Esc 关闭、鼠标点击列表项直接应用)
  - 右键分段 → 在此前/后插入、删除、左移、右移
  - 单击选中(黄色描边);右侧属性面板与就地面板共享同一模型、实时同步
  - 快捷键:Del 删除、Alt+←/→ 移动字段、←/→ 切换字段(并打开编辑面板)、
    ↑/↓ 切换报文、Ctrl+N/O/S 文件操作
- **帮助页(F1 / 工具栏"帮助")**:窗口内覆盖层(非 Popup,便于无头截图校验),
  六节中文使用说明(基本概念 / 报文管理 / 编辑字段 / 选择与调整 / 文件与视图 /
  快捷键总表,键帽用 KeyCap 渲染);Esc、✕、点击遮罩均可关闭,打开时自动
  关闭就地编辑面板与类型筛选框,关闭后焦点还给柱状图
- 位偏移自动派生:字段 N 的位偏移 = 前序字段位长之和(纯打包位流,无对齐填充)
- 保存/加载 JSON 结构文件;未保存更改提示;未知类型降级为自定义位长(向前兼容)

## 架构:三层 model-view

- **领域模型层(C++)** `MessageModel`:多报文项目(帧名称/帧ID/帧类型 + 字段列表),
  位偏移前缀和派生、字段增删移/属性编辑(模型即控制器,唯一写入口)、
  位域字节自动补全(enforceBytePacking)、JSON v2 持久化(v1 兼容)。
  `TypeCatalog` 数据驱动类型目录(加类型 = 加一行表项)
- **视图模型层(C++)** `BarLayout` + `ListModel`×3:监听模型信号,把位流按视口宽度
  折行切成行段(segments)、断行点(breakpoints)、字段锚点(anchors),标准
  QAbstractListModel 载体,变化时整体重建快照
- **视图层(QML)** `Repeater` + delegate(Segment/InsertPoint/InlinePanel 等),
  delegate 全部 `required property` 角色绑定
- **拼音模块(PinyinHelper)**:双路径——ICU Transliterator(Han-Latin/Names;
  Latin-ASCII,运行时探测库名与符号后缀,兼容 Debian 系 `_66` 符号重命名、
  Windows 的 `icuin*.dll` 命名)优先;内置 Unihan kMandarin 码表
  (src/pinyin_data.cpp,tools/gen-pinyin.ps1 生成)兜底;smoke 断言两路径输出一致

### 关键设计约束(踩坑沉淀)

1. **几何单一来源**:所有 x = `originX + round(bit×pxPerBit)`,任何缩放/换行下
   相邻段不重叠不留缝
2. **绑定追踪**:QML 绑定不追踪函数内部属性读取——参数必须显式写在绑定表达式
   (如 `filtered(text)`、`L.xForBit(b, bar.pxPerBit, bar.originX)`)
3. **delegate 必须 required 角色绑定**:QVariantList 的 modelData 在 delegate
   创建瞬间未就绪(曾致插入点全部挤到最前)
4. **模型信号时序**:位偏移缓存失效必须在任何模型信号之前(曾致加载后首行消失)
5. **嵌套 hover 可见性须把自身 hover 计入**(曾致加号闪烁)
6. 位域字节完整覆盖由模型自动维护(占位字段可转为有效位域)
7. **帮助页为何不用 Popup**:Qt 5.15 的 Popup 渲染在独立子窗口,主窗口
   `grabWindow` 拍不到,且无头 xvfb 下背景透明/内容缺失 —— 覆盖层用普通
   Item(Rectangle)随主窗口一起渲染与截图;`ApplicationWindow` 的子项只
   铺满 contentItem(页眉页脚之外),故遮罩不覆盖标题栏/工具栏/状态栏
   (窗口按钮保持可点,校验脚本据此断言"标题栏/状态栏未被覆盖")
8. **覆盖层必须显式 `anchors.fill: parent`,且打开时自持焦点处理 Esc**:
   漏掉填充会导致尺寸 0×0、卡片宽高为负(只剩错位子文本);窗口级快捷键
   在焦点被覆盖层/弹窗接管时收不到按键(带 escapePressed 的项会先接受
   ShortcutOverride),故 Esc 由覆盖层 `Keys.onEscapePressed` 处理,
   main.qml 的同名 Shortcut 仅作兜底

## 界面风格

**青蓝 + 琥珀强调**(用户选定方案 6,微调):
- 主题:Light,标题栏淡青 #51C4D3(深青字 #083344),工具栏蓝 #22A2C3,
  强调色琥珀 #FFB300
- 窗口背景 #FAFAFA,行槽 #EFF3F7,卡片白色(选中 #FFF8E1 淡琥珀底);
  主文字 #212121,次要文字 #757575
- **无边框窗口 + 自绘 Material 标题栏**(拖动移动、双击最大化、
  最小化/最大化/关闭按钮);8 个窗口边缘 resize 手柄(startSystemResize)
- 选中字段高亮、类型筛选高亮、插入点 "+"、拖动指示线均为琥珀 #FFB300
  (悬停变深);撕纸撕痕深色线 + 白色纸纤维
- 插入点 "+" 为 20px 圆形按钮(琥珀,白色描边),悬停柱状图上方显示
- **主题可切换**:`./xmlviewer --theme <name>`(9 套调色板见 src/themes.cpp,
  对比示意图 tools/theme-shots.ps1 生成)

## 环境

- 源码目录:本机 `D:\Qt\idlview`(Windows,编辑即可)
- 构建机:SSH `127.0.0.1:2222`(用户 ac130,免密),麒麟 ky10 / aarch64
- Qt 5.15.10:`/opt/qt5.15.10_full`(注意:裸 `qmake` 是系统 Qt 5.12.8,勿用)

## 构建与验证(在 Windows 本机执行)

```powershell
.\tools\sync-build.ps1                 # 同步 + 远程构建
.\tools\sync-build.ps1 -Smoke          # + 无头自测(模型断言 + QML 几何断言)
.\tools\sync-build.ps1 -Shot           # + xvfb 截图回传 + 像素级布局验证
.\tools\sync-build.ps1 -Shot -Help     # + 帮助页截图(--open-help)与覆盖层像素校验
.\tools\sync-build.ps1 -Clean          # 强制清空远程构建目录
```

- 远程源在 `~/xmlviewer`,构建在 `~/xmlviewer-build`,可执行文件 `~/xmlviewer-build/xmlviewer`
  (已内嵌 RPATH,直接运行,无需 LD_LIBRARY_PATH)
- smoke 通过标准:全部模型/QML 断言 PASS 且 QML 警告为 0,输出 `SMOKE OK`
  (含帮助页断言:openHelp 可见/持焦点/关闭遗留面板、Esc 投递焦点项即关闭、
  F1 平台按键路径可打开、close 幂等)
- 截图为 `artifacts\xmlviewer.png`;`tools\verify-shot.ps1` 按已知分段颜色逐像素
  校验布局与理论位级几何一致(输出 `SHOT-VERIFY OK`)
- `-Help` 另截 `artifacts\xmlviewer_help.png`(--open-help),`tools\check-help.ps1`
  校验卡片白底居中/标题正文绘制/滚动条/遮罩压暗内容区且标题栏与状态栏未被覆盖
  (输出 `HELP-SHOT OK`);`-Help` 隐含 `-Shot`(需同尺寸主截图作遮罩基准)

## 运行

在远程机器桌面终端执行:

```bash
~/xmlviewer-build/xmlviewer
```

## 项目 JSON 格式(v2)

> 格式标识 `format` 沿用 `idlview.project` / `idlview.message`(兼容改名前的文件)。

```json
{
  "format": "idlview.project",
  "version": 2,
  "bitOrder": "msb0",
  "messages": [
    {
      "name": "心跳包",
      "frameId": "0x01",
      "frameType": "心跳",
      "fields": [
        { "name": "帧头", "englishName": "frameHeader", "type": "uint8", "bits": 8,
          "unit": "", "ratio": "1", "observe": false, "valid": true,
          "description": "固定 0xAA", "valueDescriptions": "" }
      ]
    },
    {
      "name": "遥测数据",
      "fields": [
        { "name": "状态", "englishName": "state", "type": "bit3", "bits": 3,
          "unit": "", "ratio": "1", "observe": true, "valid": true,
          "description": "", "valueDescriptions": "0 关闭\n1 开启\n2 故障" }
      ]
    }
  ]
}
```

- `fields` 顺序即报文顺序;位偏移不存储,由位长累加派生
- `bits` 对定长类型仅作记录(以类型表为准);bit1-8/raw 以 `bits` 为准
- `valueDescriptions` 为多行文本,每行一条 "数值 含义"
- `valid=false` 时 `observe` 强制 false;旧文件缺新键时默认 `valid=true`、`ratio="1"`
- **v1 兼容**:旧单报文文件(format=idlview.message)加载为含一个报文的项目
- 未识别键忽略;未识别 `type` 降级为自定义位长并告警;`version > 2` 拒绝加载
- `bitOrder` 为后续报文解析预留(当前仅记录,不参与解析)

## 扩展字段属性

新属性(如默认值/枚举/字节序)需要 6 处机械修改:
`src/field.h`(Field 结构 + toJson/fromJson)、`src/messagemodel.h/.cpp`(角色 +
roleNames + data/setData + setFieldAttribute + toMap/selectedField 默认)、
`qml/InlinePanel.qml` 与 `qml/PropertyPanel.qml`(各一个编辑控件)、
`src/main.cpp` 自测断言。

## 目录结构

```
xmlviewer.pro           qmake 工程(QT += quick quickcontrols2 widgets, RPATH, qtquickcompiler)
src/field.h             Field 结构 + JSON
src/typecatalog.*       类型目录(新增类型只需加表项)
src/messagemodel.*      领域模型:位偏移派生、增删移、选中、JSON 持久化
src/listmodel.*         通用 QVariantMap 列表模型(行段等派生数据的 model-view 载体)
src/barlayout.*         行布局计算:按视口宽度折行,字段切成行段,填充三个 ListModel
src/filedialoghelper.*  QFileDialog 封装(Qt 5.15 无 Controls2 FileDialog)
src/pinyin.*            中文名→拼音:ICU 运行时探测 + 内置码表双路径
src/pinyin_data.cpp     内置拼音码表(gen-pinyin.ps1 生成,勿手改;mozillazg/pinyin-data MIT)
src/main.cpp            QApplication + 上下文属性 + --smoke/--screenshot(--open-panel/--open-help)
qml/main.qml            窗口骨架:工具栏/快捷键/状态条/对话框/smokeCheck
qml/MessageBar.qml      柱状图宿主:多行渲染(行背景/网格/标尺/段/插入点/右键菜单)
qml/Segment.qml         行段 delegate(Canvas 绘制,撕口画在段端部,required 角色绑定)
qml/InsertPoint.qml     悬停 "+" 插入点(required 角色绑定定位)
qml/InlinePanel.qml     就地属性编辑面板(点击段后段附近弹出)
qml/MessageListPanel.qml 左侧报文卡片列表(迷你结构预览/新建/删除/重命名)
qml/HelpPage.qml        使用帮助页(窗口内覆盖层:遮罩 + 卡片 + ScrollView,含快捷键表)
qml/LayoutMath.js       位→像素坐标纯函数(所有元素共用,防缝隙)
tools/sync-build.ps1    一键同步+构建+验证
tools/verify-shot.ps1   截图像素级布局验证(锚定行带 + 撕纸标记检测)
tools/check-help.ps1    帮助页截图像素校验(卡片白底居中/标题正文/滚动条/遮罩变暗)
tools/gen-pinyin.ps1    从 pinyin-data.txt 生成 src/pinyin_data.cpp(需先下载数据源)
tools/pinyin-data.txt   拼音码表数据源(mozillazg/pinyin-data,MIT)
tools/pinyin-data-LICENSE.txt 数据源许可证
```
