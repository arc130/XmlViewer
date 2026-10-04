#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QScreen>
#include <QKeyEvent>
#include <QTimer>
#include <QThread>
#include <QImage>
#include <QFont>
#include <QRegularExpression>
#include <QDir>
#include <QFile>
#include <QVariant>
#include <cstdio>

#include "messagemodel.h"
#include "barlayout.h"
#include "themes.h"
#include "filedialoghelper.h"

// ---- QML 错误统计:无头 smoke 测试要求为 0 --------------------------------
static int g_qmlWarnings = 0;
static const QRegularExpression g_qmlErrorRe(QStringLiteral("\\.qml:\\d+"));

static void messageHandler(QtMsgType type, const QMessageLogContext &, const QString &msg)
{
    if (type == QtWarningMsg || type == QtCriticalMsg || type == QtFatalMsg) {
        if (msg.contains(g_qmlErrorRe))
            ++g_qmlWarnings;
    }
    std::fprintf(stderr, "%s\n", qPrintable(msg));
}

// ---- 模型自测:纯 C++ 断言,无 GUI 依赖 -----------------------------------
static bool check(bool cond, const char *what)
{
    std::printf("%s %s\n", cond ? "PASS" : "FAIL", what);
    return cond;
}

static bool runModelSelfTest(MessageModel &m, BarLayout &layout)
{
    bool ok = true;
    auto ck = [&ok](bool cond, const char *what) { if (!check(cond, what)) ok = false; };

    m.newMessage();
    ck(m.count() == 1, "newMessage count==1");
    ck(m.totalBits() == 8 && m.totalBytes() == 1, "newMessage 8 bits / 1 byte");
    ck(m.byteAligned(), "newMessage byteAligned");

    m.insertField(0);
    m.insertField(2);
    m.insertField(3);
    ck(m.count() == 4, "three inserts -> count==4");

    m.setFieldAttribute(0, "name", "A");
    m.setFieldAttribute(1, "name", "B");
    m.setFieldAttribute(1, "type", "bit3");
    m.setFieldAttribute(2, "name", "C");
    m.setFieldAttribute(3, "name", "D");
    // D 改为位域(offset 19-22):字节2 空位 22-24 自动补占位 bit2
    m.setFieldAttribute(3, "type", "bit3");
    ck(m.count() == 5, "bit3 byte auto-padded -> count==5");
    ck(m.fieldAt(4)["valid"].toBool() == false && m.fieldAt(4)["bits"].toInt() == 2
           && m.fieldAt(4)["type"].toString() == QLatin1String("bit2"),
       "placeholder bit2 valid=false at row4");
    ck(m.bitOffsetOf(4) == 22, "bitOffsetOf(4)==22 (placeholder)");
    ck(m.totalBits() == 24 && m.byteAligned(), "padding fills gap: 24 bits aligned");
    ck(!m.data(m.index(1, 0), MessageModel::CustomBitsRole).toBool(), "bit3 customBits false (fixed length)");
    ck(!m.data(m.index(0, 0), MessageModel::CustomBitsRole).toBool(), "uint8 customBits false");
    // 占位可转为有效位域
    m.setFieldAttribute(4, "valid", true);
    ck(m.fieldAt(4)["valid"].toBool(), "placeholder can become valid bitfield");
    m.setFieldAttribute(4, "valid", false);   // 恢复占位状态
    // 位域移除 → 占位自动清除
    m.setFieldAttribute(3, "type", "uint8");
    ck(m.count() == 4, "placeholder removed when no bitfield in byte");
    m.setFieldAttribute(1, "type", "uint8");
    ck(m.bitOffsetOf(2) == 16, "offsets restored after bit3 -> uint8");

    // raw 字节块位长修改带动下游偏移
    m.setFieldAttribute(1, "type", "raw");
    m.setFieldAttribute(1, "bits", 24);
    ck(m.bitOffsetOf(2) == 32, "raw 24 bits shifts downstream offsets");
    m.setFieldAttribute(1, "type", "uint8");
    ck(m.bitOffsetOf(2) == 16, "offsets restored after raw -> uint8");

    // 位位置 → 字段索引(拖动落点换算,纯字节布局 offset 0/8/16/24)
    ck(m.fieldIndexAtBit(0) == 0 && m.fieldIndexAtBit(7) == 0, "fieldIndexAtBit(0..7)==0");
    ck(m.fieldIndexAtBit(8) == 1, "fieldIndexAtBit(8)==1");
    ck(m.fieldIndexAtBit(11) == 1, "fieldIndexAtBit(11)==1");
    ck(m.fieldIndexAtBit(26) == 3 && m.fieldIndexAtBit(1000) == 3, "fieldIndexAtBit clamp end");

    m.moveField(0, 1);
    ck(m.fieldAt(1)["name"].toString() == QLatin1String("A"), "moveField(0,+1) moves A to row1");
    ck(m.selectedRow() == 1, "selection follows move");
    m.moveField(3, -1);
    ck(m.fieldAt(2)["name"].toString() == QLatin1String("D"), "moveField(3,-1) moves D to row2");

    // 拖动落点吸附(此时布局经 moveField 后为 B[0,8) A[8,16) D[16,24) C[24,32))
    ck(m.snapBitToFieldBoundary(5) == 8, "snap(5)->8 (near B end)");
    ck(m.snapBitToFieldBoundary(10) == 8, "snap(10)->8 (near B end)");
    ck(m.snapBitToFieldBoundary(15) == 16, "snap(15)->16 (near A end)");
    ck(m.snapBitToFieldBoundary(0) == 0 && m.snapBitToFieldBoundary(1000) == 32, "snap clamp");
    ck(m.targetIndexAtBit(5) == 1 && m.targetIndexAtBit(10) == 1, "targetIndex 5->1 10->1");
    ck(m.targetIndexAtBit(15) == 2, "targetIndex 15->2");
    ck(m.targetIndexAtBit(0) == 0 && m.targetIndexAtBit(1000) == 4, "targetIndex clamp");

    m.setFieldAttribute(2, "type", "uint32");
    ck(m.fieldAt(2)["bits"].toInt() == 32, "type change resets bits to natural");

    // 新属性:英文名/比率/观察/有效/值含义
    m.setFieldAttribute(0, "englishName", "frameHeader");
    m.setFieldAttribute(0, "ratio", "0.1");
    m.setFieldAttribute(0, "observe", true);
    m.setFieldAttribute(0, "valueDescriptions", "0 关闭\n1 开启");
    ck(m.fieldAt(0)["englishName"].toString() == QLatin1String("frameHeader"), "englishName set");
    ck(m.fieldAt(0)["ratio"].toString() == QLatin1String("0.1"), "ratio set");
    ck(m.fieldAt(0)["observe"].toBool(), "observe set");
    ck(m.fieldAt(0)["valueDescriptions"].toString() == QStringLiteral("0 关闭\n1 开启"),
       "valueDescriptions text");
    // 无效 → 强制取消观察;无效时观察写入被拒
    m.setFieldAttribute(0, "valid", false);
    ck(!m.fieldAt(0)["valid"].toBool() && !m.fieldAt(0)["observe"].toBool(),
       "valid=false forces observe=false");
    m.setFieldAttribute(0, "observe", true);
    ck(!m.fieldAt(0)["observe"].toBool(), "observe=true rejected when invalid");
    m.setFieldAttribute(0, "valid", true);
    m.setFieldAttribute(0, "observe", true);
    ck(m.fieldAt(0)["observe"].toBool(), "observe ok when valid again");

    m.removeField(1);
    ck(m.count() == 3, "removeField -> count==3");
    m.removeField(0);
    m.removeField(0);
    ck(m.count() == 1, "cannot remove last field");

    // JSON 往返(含自动占位字段的持久化)
    m.setFieldAttribute(0, "name", "roundtrip");
    m.setFieldAttribute(0, "type", "bit3");
    ck(m.count() == 2, "bit3 roundtrip: auto-padded to 2 fields");
    const QString path = QDir::tempPath() + QStringLiteral("/xmlviewer_smoke.json");
    ck(m.saveTo(path), "saveTo temp file");
    m.newMessage();
    ck(m.loadFrom(path), "loadFrom temp file");
    ck(m.count() == 2 && m.fieldAt(0)["name"].toString() == QLatin1String("roundtrip")
           && m.fieldAt(0)["type"].toString() == QLatin1String("bit3")
           && m.fieldAt(0)["bits"].toInt() == 3,
       "JSON round-trip content");
    ck(!m.fieldAt(1)["valid"].toBool() && m.fieldAt(1)["bits"].toInt() == 5,
       "placeholder persisted in JSON");

    // 版本拒载
    const QString v2Path = QDir::tempPath() + QStringLiteral("/xmlviewer_smoke_v2.json");
    {
        QFile f(v2Path);
        f.open(QIODevice::WriteOnly);
        f.write("{\"format\":\"idlview.message\",\"version\":2,\"fields\":[{\"name\":\"x\"}]}");
    }
    ck(!m.loadFrom(v2Path), "version 2 refused");

    // 未知类型降级
    const QString unkPath = QDir::tempPath() + QStringLiteral("/xmlviewer_smoke_unknown.json");
    {
        QFile f(unkPath);
        f.open(QIODevice::WriteOnly);
        f.write("{\"format\":\"idlview.message\",\"version\":1,"
                "\"fields\":[{\"name\":\"x\",\"type\":\"mystery\",\"bits\":5}]}");
    }
    // loadFrom 触发的行布局重建必须立即正确(回归:缓存须在 modelReset 前失效)
    layout.setGeometry(168, 32);   // 每行 3 字节 = 24 位
    ck(layout.segmentAt(0)["bits"].toInt() == 3, "layout reflects model before load");
    ck(m.loadFrom(unkPath), "unknown type loads");
    ck(m.data(m.index(0, 0), MessageModel::CustomBitsRole).toBool(), "unknown type degrades to custom bits");
    // 旧文件无新属性键:默认有效、比率为 1
    ck(m.fieldAt(0)["valid"].toBool(), "old file defaults valid=true");
    ck(m.fieldAt(0)["ratio"].toString() == QLatin1String("1"), "old file defaults ratio=1");

    // 中文名 → 拼音(代码名):汉字转拼音,符号保留
    const QString py = m.chineseToPinyin(QStringLiteral("温度1_状态"));
    std::printf("pinyin sample: %s\n", py.toUtf8().constData());
    ck(!py.isEmpty(), "pinyin non-empty");
    bool hasHan = false;
    for (const QChar &c : py) {
        if (c.unicode() >= 0x4E00 && c.unicode() <= 0x9FFF)
            hasHan = true;
    }
    ck(!hasHan, "pinyin contains no han chars");
    ck(py.contains(QLatin1String("1_")), "pinyin keeps symbols (1_)");
    ck(m.chineseToPinyin(QStringLiteral("abc_123")) == QLatin1String("abc_123"), "symbols unchanged");
    ck(m.chineseToPinyin(QString()).isEmpty(), "pinyin empty input");

    // 内置码表路径(无 ICU 环境,如 Windows 官方 Qt):输出须与 ICU 路径一致
    qputenv("XMLVIEWER_PINYIN_TABLE_ONLY", "1");
    const QString pyTable = m.chineseToPinyin(QStringLiteral("温度1_状态"));
    std::printf("pinyin table sample: %s\n", pyTable.toUtf8().constData());
    ck(pyTable == py, "table path matches ICU path");
    ck(m.chineseToPinyin(QStringLiteral("abc_123")) == QLatin1String("abc_123"), "table path keeps symbols");
    ck(m.chineseToPinyin(QString()).isEmpty(), "table path empty input");
    // 码表未收录的罕见汉字(U+5161):翻译失效 → 原样保留,程序不受影响
    const QString rare(QChar(0x5161));
    ck(m.chineseToPinyin(rare) == rare, "unmapped han char kept verbatim (table path)");
    qunsetenv("XMLVIEWER_PINYIN_TABLE_ONLY");
    ck(layout.rowCount() == 1 && layout.lastRowBits() == 5, "layout rowCount/lastRowBits after load");
    ck(layout.segmentAt(0)["bits"].toInt() == 5, "layout segment bits==5 after load");

    // 多报文管理
    ck(m.messageCount() == 1 && m.currentMessageIndex() == 0, "v1 file loads as 1-message project");
    ck(m.setMessageAttribute(0, "name", QStringLiteral("原报文")), "setMessageAttribute name");
    ck(m.setMessageAttribute(0, "frameId", QStringLiteral("0x01")), "setMessageAttribute frameId");
    ck(m.setMessageAttribute(0, "frameType", QStringLiteral("心跳")), "setMessageAttribute frameType");
    ck(!m.setMessageAttribute(0, "bogus", 1), "setMessageAttribute unknown key refused");
    ck(m.messageInfo(0)["name"].toString() == QStringLiteral("原报文"), "messageInfo name");
    ck(m.messageInfo(0)["frameId"].toString() == QLatin1String("0x01"), "messageInfo frameId");
    ck(m.messageInfo(0)["frameType"].toString() == QStringLiteral("心跳"), "messageInfo frameType");
    m.addMessage();
    ck(m.messageCount() == 2 && m.currentMessageIndex() == 1, "addMessage switches to new");
    m.setFieldAttribute(0, "name", QStringLiteral("新报文字段"));
    m.setFieldAttribute(0, "type", QStringLiteral("bit3"));
    ck(m.messageInfo(1)["fieldCount"].toInt() == 2, "new message: field + auto placeholder");
    m.setCurrentMessage(0);
    ck(m.fieldAt(0)["name"].toString() == QLatin1String("x"), "messages keep independent fields");
    ck(m.messagePreview(1).size() == 2, "preview of message1 has 2 segments");
    ck(m.messageInfo(1)["totalBytes"].toInt() == 1, "message1 totalBytes==1 (padded byte)");
    m.removeMessage(1);
    ck(m.messageCount() == 1, "removeMessage");
    ck(!m.removeMessage(0), "remove last message refused");
    // frameId/frameType 持久化(JSON v2)
    ck(m.saveTo(path), "saveTo with frame attrs");
    m.newMessage();
    ck(m.loadFrom(path), "loadFrom with frame attrs");
    ck(m.messageCount() == 1 && m.messageInfo(0)["frameId"].toString() == QLatin1String("0x01")
           && m.messageInfo(0)["frameType"].toString() == QStringLiteral("心跳"),
       "frame attrs round-trip");

    QFile::remove(path);
    QFile::remove(v2Path);
    QFile::remove(unkPath);
    return ok;
}

// ---- 截图模式的演示项目(两个报文,覆盖多行换行 + 跨行字段)---------------
static void populateDemo(MessageModel &m)
{
    // 报文1:心跳包(短)
    m.newMessage();
    m.setMessageAttribute(0, "name", QStringLiteral("心跳包"));
    m.setMessageAttribute(0, "frameId", QStringLiteral("0x01"));
    m.setMessageAttribute(0, "frameType", QStringLiteral("心跳"));
    m.setFieldAttribute(0, "name", QStringLiteral("帧头"));
    m.setFieldAttribute(0, "description", QStringLiteral("固定 0xAA"));
    m.insertField(1);
    m.setFieldAttribute(1, "name", QStringLiteral("序列号"));
    m.setFieldAttribute(1, "type", QStringLiteral("uint16"));
    m.insertField(2);
    m.setFieldAttribute(2, "name", QStringLiteral("校验"));

    // 报文2:遥测数据(长)
    m.addMessage();
    m.setMessageAttribute(1, "name", QStringLiteral("遥测数据"));
    m.setMessageAttribute(1, "frameId", QStringLiteral("0x02"));
    m.setMessageAttribute(1, "frameType", QStringLiteral("遥测"));
    int row = 0;
    auto add = [&m, &row](const QString &name, const QString &type, int bits,
                          const QString &unit, const QString &desc) {
        if (row > 0)
            m.insertField(row);
        m.setFieldAttribute(row, "name", name);
        m.setFieldAttribute(row, "type", type);
        if (bits > 0)
            m.setFieldAttribute(row, "bits", bits);
        m.setFieldAttribute(row, "unit", unit);
        m.setFieldAttribute(row, "description", desc);
        ++row;
    };
    add(QStringLiteral("帧头"), QStringLiteral("uint8"), 0, QString(), QStringLiteral("固定 0xAA"));
    add(QStringLiteral("长度"), QStringLiteral("uint8"), 0, QString(), QStringLiteral("数据区字节数"));
    add(QStringLiteral("命令"), QStringLiteral("uint16"), 0, QString(), QString());
    add(QStringLiteral("状态"), QStringLiteral("bit3"), 3, QString(), QString());
    add(QStringLiteral("保留"), QStringLiteral("bit5"), 5, QString(), QString());
    add(QStringLiteral("温度"), QStringLiteral("int16"), 0, QStringLiteral("0.1℃"), QString());
    add(QStringLiteral("湿度"), QStringLiteral("int16"), 0, QStringLiteral("%RH"), QString());
    add(QStringLiteral("压力"), QStringLiteral("uint32"), 0, QStringLiteral("Pa"), QString());
    add(QStringLiteral("时间"), QStringLiteral("uint32"), 0, QStringLiteral("ms"), QString());
    add(QStringLiteral("电压"), QStringLiteral("float"), 0, QStringLiteral("V"), QString());
    add(QStringLiteral("电流"), QStringLiteral("float"), 0, QStringLiteral("A"), QString());
    add(QStringLiteral("数据"), QStringLiteral("raw"), 256, QString(), QStringLiteral("载荷(跨行)"));
    add(QStringLiteral("校验"), QStringLiteral("uint8"), 0, QString(), QStringLiteral("CRC8"));
    m.setSelectedRow(0);
    m.setModified(false);
}

int main(int argc, char *argv[])
{
    QApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QApplication app(argc, argv);
    qInstallMessageHandler(messageHandler);

    bool smokeMode = false;
    bool shotMode = false;
    bool shotOpenPanel = false;
    QString shotPath;
    QSize shotSize(1280, 800);
    QString themeName = Themes::defaultName();
    const QStringList args = app.arguments();
    for (int i = 1; i < args.size(); ++i) {
        if (args[i] == QLatin1String("--smoke")) {
            smokeMode = true;
        } else if (args[i] == QLatin1String("--screenshot") && i + 1 < args.size()) {
            shotMode = true;
            shotPath = args[++i];
        } else if (args[i] == QLatin1String("--size") && i + 1 < args.size()) {
            const QString s = args[++i];
            const int w = s.section(QLatin1Char('x'), 0, 0).toInt();
            const int h = s.section(QLatin1Char('x'), 1, 1).toInt();
            if (w > 0 && h > 0)
                shotSize = QSize(w, h);
        } else if (args[i] == QLatin1String("--theme") && i + 1 < args.size()) {
            themeName = args[++i];
        } else if (args[i] == QLatin1String("--open-panel")) {
            shotOpenPanel = true;
        }
    }

    QFont font = app.font();
    font.setFamilies(QStringList() << QStringLiteral("Noto Sans CJK SC")
                                   << QStringLiteral("WenQuanYi Micro Hei"));
    app.setFont(font);

    MessageModel model;
    BarLayout layout;
    layout.setMessageModel(&model);
    FileDialogHelper dialogs;

    if (shotMode)
        populateDemo(model);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("messageModel"), &model);
    engine.rootContext()->setContextProperty(QStringLiteral("barLayout"), &layout);
    engine.rootContext()->setContextProperty(QStringLiteral("fileDialogHelper"), &dialogs);
    engine.rootContext()->setContextProperty(QStringLiteral("themeColors"), Themes::colors(themeName));
    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));
    if (engine.rootObjects().isEmpty()) {
        std::fprintf(stderr, "QML load failed\n");
        return 2;
    }
    QObject *root = engine.rootObjects().first();

    if (shotMode) {
        QQuickWindow *win = qobject_cast<QQuickWindow *>(root);
        if (win)
            win->resize(shotSize);
        QTimer::singleShot(800, [root, shotPath, &model, shotOpenPanel]() {
            QQuickWindow *win = qobject_cast<QQuickWindow *>(root);
            std::printf("DIAG visible=%d exposed=%d size=%dx%d\n",
                        int(win->isVisible()), int(win->isExposed()),
                        win->width(), win->height());
            win->show();
            win->requestActivate();
            // --open-panel:截图前打开就地编辑面板(目检面板 UI)。
            // Popup 在 Qt 5.15 渲染于独立 popup 窗口,主窗口 grabWindow 拍不到,
            // 因此等待渲染后改抓整个虚拟屏。
            if (shotOpenPanel) {
                model.setSelectedRow(0);
                const bool op = QMetaObject::invokeMethod(root, "openInlinePanel");
                std::printf("DIAG open-panel invoke=%d\n", int(op));
                for (int i = 0; i < 10; ++i) {
                    win->requestUpdate();
                    QCoreApplication::processEvents();
                    QThread::msleep(50);
                }
                // 弹窗是主窗口的子 QQuickWindow(不出现在 topLevelWindows):
                // 逐个抓取每个窗口自身内容,直接检验弹窗背景与徽标渲染
                int idx = 0;
                const QList<QWindow *> wins = QGuiApplication::allWindows();
                for (QWindow *w : wins) {
                    if (QQuickWindow *qw = qobject_cast<QQuickWindow *>(w)) {
                        const QString p = QStringLiteral("/tmp/win_%1.png").arg(idx++);
                        qw->grabWindow().save(p);
                        std::printf("DIAG saved %s type=%d visible=%d pos=%d,%d size=%dx%d\n",
                                    qPrintable(p), int(w->type()), int(w->isVisible()),
                                    w->x(), w->y(), w->width(), w->height());
                    }
                }
            }
            QImage img;
            if (shotOpenPanel)
                img = QGuiApplication::primaryScreen()->grabWindow(0).toImage();
            // 无头环境下首帧可能尚未渲染,主动请求并轮询抓帧
            for (int i = 0; i < 40 && img.isNull(); ++i) {
                win->requestUpdate();
                QCoreApplication::processEvents();
                img = win->grabWindow();
                if (img.isNull())
                    QThread::msleep(50);
            }
            if (img.isNull()) {
                std::fprintf(stderr, "screenshot grab returned null image\n");
                qApp->exit(3);
                return;
            }
            if (!img.save(shotPath)) {
                std::fprintf(stderr, "screenshot save failed: %s\n", qPrintable(shotPath));
                qApp->exit(3);
                return;
            }
            std::printf("SCREENSHOT %s %dx%d\n", qPrintable(shotPath), img.width(), img.height());
            qApp->exit(0);
        });
        return app.exec();
    }

    if (smokeMode) {
        QTimer::singleShot(150, [root, &model, &layout]() {
            const bool modelOk = runModelSelfTest(model, layout);
            QVariant res;
            bool invoked = QMetaObject::invokeMethod(root, "smokeCheck",
                                                     Q_RETURN_ARG(QVariant, res));
            const QString qmlResult = res.toString();
            const bool qmlOk = invoked && qmlResult.startsWith(QLatin1String("OK"));
            std::printf("SMOKE_QML %s\n", qPrintable(qmlResult));
            std::printf("QML_WARNINGS %d\n", g_qmlWarnings);

            // 面板打开时按 ←:应切换到上一个字段且面板保持打开
            bool panelArrowOk = true;
            QObject *panel = root->findChild<QObject *>(QStringLiteral("inlinePanel"));
            if (panel) {
                auto sendLeft = [root]() {
                    QKeyEvent press(QEvent::KeyPress, Qt::Key_Left, Qt::NoModifier);
                    QKeyEvent release(QEvent::KeyRelease, Qt::Key_Left, Qt::NoModifier);
                    QCoreApplication::sendEvent(root, &press);
                    QCoreApplication::sendEvent(root, &release);
                    QCoreApplication::processEvents();
                };
                // 激活窗口,建立真实焦点链(窗口级 Shortcut 与面板 Keys 均依赖焦点)
                if (QQuickWindow *win = qobject_cast<QQuickWindow *>(root)) {
                    win->requestActivate();
                    QCoreApplication::processEvents();
                }
                // 对照:面板关闭时按 ←:切换字段并打开面板(等效点击字段段)
                model.setSelectedRow(1);
                sendLeft();
                const int rowCtl = model.selectedRow();
                for (int i = 0; i < 30 && !panel->property("opened").toBool(); ++i) {
                    QCoreApplication::processEvents();
                    QThread::msleep(20);
                }
                const bool openedCtl = panel->property("opened").toBool();
                // 面板已打开时按 ←:切换字段且面板保持打开
                model.setSelectedRow(1);
                for (int i = 0; i < 30 && !panel->property("opened").toBool(); ++i) {
                    QCoreApplication::processEvents();
                    QThread::msleep(20);
                }
                const bool opened1 = panel->property("opened").toBool();
                const bool editorFocused = panel->property("anyEditorFocused").toBool();
                const int row1 = model.selectedRow();
                sendLeft();
                const bool opened2 = panel->property("opened").toBool();
                const int row2 = model.selectedRow();
                std::printf("SMOKE_PANEL_ARROW ctlRow=%d ctlOpened=%d opened1=%d editorFocused=%d row1=%d opened2=%d row2=%d\n",
                            rowCtl, int(openedCtl), int(opened1), int(editorFocused), row1, int(opened2), row2);
                panelArrowOk = rowCtl == 0 && openedCtl && opened1 && row1 == 1 && row2 == 0 && opened2;
            }

            const bool ok = modelOk && qmlOk && panelArrowOk && g_qmlWarnings == 0;
            std::printf("%s\n", ok ? "SMOKE OK" : "SMOKE FAIL");
            qApp->exit(ok ? 0 : 2);
        });
        return app.exec();
    }

    return app.exec();
}
