#include "themes.h"

namespace {

struct Entry
{
    const char *name;
    const char *label;
    const char *primary;
    const char *accent;
    const char *titleBar;
    const char *titleText;
    const char *toolbarBg;
    const char *toolbarText;
    const char *barBg;
    const char *rowBg;
    const char *rowBorder;
    const char *cardBg;
    const char *cardSel;
    const char *cardBorder;
};

const Entry kThemes[] = {
    // 0) 当前方案(浅色 BlueGrey + Indigo)
    { "light-indigo", "蓝灰 + 靛蓝",
      "#607D8B", "#6366F1", "#37474F", "#FFFFFF", "#607D8B", "#FFFFFF",
      "#FAFAFA", "#E8E8E8", "#999999",
      "#FFFFFF", "#E8EAF6", "#DDDDDD" },
    // 1) 清爽蓝白
    { "light-blue", "清爽蓝白",
      "#1976D2", "#1E88E5", "#1565C0", "#FFFFFF", "#1976D2", "#FFFFFF",
      "#FAFAFA", "#EEF2F6", "#B0BEC5",
      "#FFFFFF", "#E3F2FD", "#DDE4EA" },
    // 2) 暖白橙棕(咖啡暖调)
    { "warm-orange", "暖白橙棕",
      "#EF6C00", "#FF7043", "#5D4037", "#FFFFFF", "#EF6C00", "#FFFFFF",
      "#FFFBF7", "#F5ECE4", "#D7CCC2",
      "#FFFFFF", "#FFF3E0", "#ECE0D6" },
    // 3) 翡翠绿
    { "emerald", "翡翠绿",
      "#00796B", "#10B981", "#004D40", "#FFFFFF", "#00796B", "#FFFFFF",
      "#F8FAF9", "#E8F0EC", "#B2CCC1",
      "#FFFFFF", "#E0F2F1", "#D5E7E0" },
    // 4) 薰衣草紫
    { "lavender", "薰衣草紫",
      "#5E35B1", "#7C4DFF", "#4527A0", "#FFFFFF", "#5E35B1", "#FFFFFF",
      "#FBFAFF", "#EEEAF8", "#CFC4E8",
      "#FFFFFF", "#EDE7F6", "#E0D9EF" },
    // 5) 经典工程蓝 + 琥珀(用户选定,微调:深青标题栏 + 白色工具栏)
    { "classic-amber", "工程蓝 + 琥珀",
      "#22A2C3", "#FFB300", "#083344", "#E0F7FA", "#FFFFFF", "#083344",
      "#FAFAFA", "#EFF3F7", "#C3CED9",
      "#FFFFFF", "#FFF8E1", "#E5EAF0" },
    // 6) 青碧
    { "cyan", "青碧",
      "#00838F", "#00ACC1", "#006064", "#FFFFFF", "#00838F", "#FFFFFF",
      "#F8FCFD", "#E4F2F4", "#B2DFE5",
      "#FFFFFF", "#E0F7FA", "#D3EBEF" },
    // 7) 玫粉(Material 经典粉)
    { "pink", "玫粉",
      "#D81B60", "#E91E63", "#880E4F", "#FFFFFF", "#D81B60", "#FFFFFF",
      "#FDF8FA", "#F5E9EE", "#E3CBD6",
      "#FFFFFF", "#FCE4EC", "#EED8E1" },
    // 8) Linear 浅(灰蓝 + Slate 靛)
    { "slate", "Linear 灰蓝",
      "#334155", "#6366F1", "#1E293B", "#FFFFFF", "#334155", "#FFFFFF",
      "#F8FAFC", "#EBEFF4", "#CBD5E1",
      "#FFFFFF", "#EEF2FF", "#E2E8F0" },
};

QVariantMap buildColors(const Entry &e)
{
    QVariantMap m;
    m["name"] = QString::fromLatin1(e.name);
    m["label"] = QString::fromUtf8(e.label);
    m["primary"] = QString::fromLatin1(e.primary);
    m["accent"] = QString::fromLatin1(e.accent);
    m["titleBar"] = QString::fromLatin1(e.titleBar);
    m["titleText"] = QString::fromLatin1(e.titleText);
    m["toolbarBg"] = QString::fromLatin1(e.toolbarBg);
    m["toolbarText"] = QString::fromLatin1(e.toolbarText);
    m["barBg"] = QString::fromLatin1(e.barBg);
    m["rowBg"] = QString::fromLatin1(e.rowBg);
    m["rowBorder"] = QString::fromLatin1(e.rowBorder);
    m["cardBg"] = QString::fromLatin1(e.cardBg);
    m["cardSel"] = QString::fromLatin1(e.cardSel);
    m["cardBorder"] = QString::fromLatin1(e.cardBorder);
    // 通用键(浅色方案共享)
    m["grid"] = QStringLiteral("#33000000");
    m["tick"] = QStringLiteral("#757575");
    m["rulerText"] = QStringLiteral("#757575");
    m["cardText"] = QStringLiteral("#212121");
    m["cardSub"] = QStringLiteral("#757575");
    m["textSecondary"] = QStringLiteral("#757575");
    m["segBorder"] = QStringLiteral("rgba(0,0,0,0.2)");
    m["tearLine"] = QStringLiteral("rgba(0,0,0,0.45)");
    m["fiberLine"] = QStringLiteral("rgba(255,255,255,0.85)");
    m["placeholder"] = QStringLiteral("#757575");
    return m;
}

} // namespace

QStringList Themes::names()
{
    QStringList out;
    for (const Entry &e : kThemes)
        out << QString::fromLatin1(e.name);
    return out;
}

QVariantMap Themes::colors(const QString &name)
{
    for (const Entry &e : kThemes) {
        if (QLatin1String(e.name) == name)
            return buildColors(e);
    }
    return buildColors(kThemes[0]);
}

QString Themes::defaultName()
{
    // 用户选定方案:经典工程蓝 + 琥珀(标题栏深青 #083344,工具栏白 #FFFFFF)
    return QStringLiteral("classic-amber");
}
