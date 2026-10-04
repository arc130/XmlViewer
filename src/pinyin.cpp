#include "pinyin.h"

#include <QLibrary>
#include <QStringList>
#include <QVector>
#include <cstdint>

// 中文 → 拼音双路径:
//   1. ICU(优先,与既有行为一致):动态解析 Transliterator API;
//   2. 内置码表(兜底):pinyinLookup()(pinyin_data.cpp,Unihan kMandarin)。
//      Windows 官方 Qt 不自带 ICU,靠此路径保证拼音功能在 Windows 上可用。
//
// ICU 符号版本后缀:Debian/Ubuntu/麒麟 打包 ICU 时用 U_DISABLE_RENAMING
// 把导出符号改名为 utrans_openU_66(带主版本号后缀),直接 -licui18n 链接
// 会失败;官方 Windows / Fedora / Arch 构建导出无后缀符号 —— Windows 上
// 不存在该问题,版本号体现在 DLL 文件名(icuin66.dll)上。正确做法是运行时
// 探测:库名按平台枚举候选,符号先试无后缀、失败再枚举 _99.._40。

using UCharT = uint16_t;              // ICU UChar = UTF-16 单元
using UTransT = void *;
using UErrorT = int32_t;              // U_ZERO_ERROR == 0;U_FAILURE(x) == (x > 0)

typedef UTransT (*UtranOpenFn)(const UCharT *id, int32_t idLength, int32_t dir,
                               const UCharT *rules, int32_t rulesLength,
                               void *parseError, UErrorT *status);
typedef int32_t (*UtranTransFn)(UTransT trans, UCharT *text, int32_t *textLength,
                                int32_t textCapacity, int32_t start,
                                int32_t *limit, UErrorT *status);
typedef void (*UtranCloseFn)(UTransT trans);

namespace {

// 符号探测:先试无后缀,失败则枚举 Debian 系版本后缀 _99.._40
QFunctionPointer resolveAny(QLibrary *lib, const char *base)
{
    if (QFunctionPointer p = lib->resolve(base))
        return p;
    for (int v = 99; v >= 40; --v) {
        const QByteArray name = QByteArray(base) + '_' + QByteArray::number(v);
        if (QFunctionPointer p = lib->resolve(name.constData()))
            return p;
    }
    return nullptr;
}

// 库名候选:Windows 官方 ICU 二进制为 icuin.dll / icuin66.dll(版本在文件名,
// 符号无后缀);Linux 为 libicui18n.so.N。
QStringList libraryCandidates()
{
    QStringList l;
#ifdef Q_OS_WIN
    l << QStringLiteral("icuin.dll");
    for (int v = 99; v >= 40; --v)
        l << QStringLiteral("icuin%1.dll").arg(v);
#else
    for (int v = 99; v >= 40; --v)
        l << QStringLiteral("libicui18n.so.%1").arg(v);
    l << QStringLiteral("libicui18n.so");
#endif
    return l;
}

struct Api
{
    bool resolved = false;
    QLibrary *lib = nullptr;          // 持久持有:析构会卸载库使函数指针悬空
    UtranOpenFn open = nullptr;
    UtranTransFn trans = nullptr;
    UtranCloseFn close = nullptr;

    void resolve()
    {
        if (resolved)
            return;
        resolved = true;
        const QStringList libs = libraryCandidates();
        for (const QString &name : libs) {
            QLibrary *cand = new QLibrary(name);
            if (!cand->load()) {
                delete cand;
                continue;
            }
            open = reinterpret_cast<UtranOpenFn>(resolveAny(cand, "utrans_openU"));
            trans = reinterpret_cast<UtranTransFn>(resolveAny(cand, "utrans_transUChars"));
            close = reinterpret_cast<UtranCloseFn>(resolveAny(cand, "utrans_close"));
            if (open && trans && close) {
                lib = cand;
                return;
            }
            delete cand;
            open = nullptr;
            trans = nullptr;
            close = nullptr;
        }
    }

    bool usable() const { return open && trans && close; }
};

Api &api()
{
    static Api s_api;
    return s_api;
}

// XMLVIEWER_PINYIN_TABLE_ONLY=1 强制走内置码表(smoke 验证无 ICU 环境路径)
bool icuEnabled()
{
    return !qEnvironmentVariableIsSet("XMLVIEWER_PINYIN_TABLE_ONLY");
}

// 单段转换(ICU 路径):规则 "Han-Latin/Names; Latin-ASCII" 输出无调拼音
QString convertWithIcu(const QString &text)
{
    if (!api().usable())
        return text;

    const QString rule = QStringLiteral("Han-Latin/Names; Latin-ASCII");
    QVector<UCharT> ruleU(rule.size());
    const ushort *ruleSrc = rule.utf16();
    for (int i = 0; i < rule.size(); ++i)
        ruleU[i] = static_cast<UCharT>(ruleSrc[i]);

    UErrorT status = 0;   // U_ZERO_ERROR
    UTransT trans = api().open(ruleU.constData(), static_cast<int32_t>(rule.size()),
                               0, nullptr, 0, nullptr, &status);
    if (!trans || status > 0)
        return text;

    const int cap = qMax(16, text.size() * 8 + 8);
    QVector<UCharT> buf(cap, 0);
    const ushort *src = text.utf16();
    for (int i = 0; i < text.size(); ++i)
        buf[i] = static_cast<UCharT>(src[i]);
    int32_t len = static_cast<int32_t>(text.size());
    int32_t limit = len;
    status = 0;
    api().trans(trans, buf.data(), &len, static_cast<int32_t>(cap), 0, &limit, &status);
    api().close(trans);

    if (status > 0)
        return text;
    return QString::fromUtf16(reinterpret_cast<const ushort *>(buf.constData()), len);
}

} // namespace

QString PinyinHelper::toPinyin(const QString &text)
{
    // 逐字符处理:汉字转拼音(单字转换无分词空格),数字/字母/符号原样保留
    QString out;
    out.reserve(text.size() * 4);
    api().resolve();
    const bool useIcu = icuEnabled() && api().usable();
    for (const QChar &c : text) {
        const ushort u = c.unicode();
        if (u >= 0x4E00 && u <= 0x9FFF) {
            // 逐字符回退:ICU(可用时)→ 内置码表 → 原字符。
            // 任何一级失败(ICU 缺失/数据损坏、码表未收录)都只是翻译失效,
            // 程序其余功能不受影响。
            QString p;
            if (useIcu)
                p = convertWithIcu(QString(c));
            if (p.isEmpty()) {
                const char *py = pinyinLookup(u);
                if (py)
                    p = QString::fromLatin1(py);
            }
            out += p.isEmpty() ? QString(c) : p;
        } else {
            out += c;
        }
    }
    return out;
}
