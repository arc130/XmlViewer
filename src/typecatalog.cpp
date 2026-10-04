#include "typecatalog.h"

static const QVector<TypeInfo> kTypes = {
    { "uint8",    "uint8  (无符号 8 位)",  8,  false, "#2f7ed8" },
    { "int8",     "int8   (有符号 8 位)",  8,  false, "#5a9bd8" },
    { "uint16",   "uint16 (无符号 16 位)", 16, false, "#1e8e4e" },
    { "int16",    "int16  (有符号 16 位)", 16, false, "#27ae60" },
    { "uint32",   "uint32 (无符号 32 位)", 32, false, "#0f7a65" },
    { "int32",    "int32  (有符号 32 位)", 32, false, "#148f77" },
    { "uint64",   "uint64 (无符号 64 位)", 64, false, "#0e6655" },
    { "int64",    "int64  (有符号 64 位)", 64, false, "#16a085" },
    { "float",    "float  (单精度浮点)",   32, false, "#8e44ad" },
    { "double",   "double (双精度浮点)",   64, false, "#a569bd" },
    // 位域:bit1..bit8 固定位长;含位域的字节由模型自动补占位确保完整覆盖
    { "bit1",     "bit1   (1 位位域)",     1,  false, "#e67e22" },
    { "bit2",     "bit2   (2 位位域)",     2,  false, "#e67e22" },
    { "bit3",     "bit3   (3 位位域)",     3,  false, "#e67e22" },
    { "bit4",     "bit4   (4 位位域)",     4,  false, "#e67e22" },
    { "bit5",     "bit5   (5 位位域)",     5,  false, "#e67e22" },
    { "bit6",     "bit6   (6 位位域)",     6,  false, "#e67e22" },
    { "bit7",     "bit7   (7 位位域)",     7,  false, "#e67e22" },
    { "bit8",     "bit8   (8 位位域)",     8,  false, "#e67e22" },
    { "raw",      "字节块 (自定义字节数)", -1, true,  "#7f8c8d" },
};

const QVector<TypeInfo> &TypeCatalog::all()
{
    return kTypes;
}

const TypeInfo *TypeCatalog::lookup(const QString &id)
{
    for (const TypeInfo &ti : kTypes) {
        if (QLatin1String(ti.id) == id)
            return &ti;
    }
    return nullptr;
}

int TypeCatalog::defaultBits(const QString &id)
{
    const TypeInfo *ti = lookup(id);
    return ti ? (ti->naturalBits > 0 ? ti->naturalBits : 8) : 8;
}

bool TypeCatalog::allowsCustomBits(const QString &id)
{
    const TypeInfo *ti = lookup(id);
    return !ti || ti->customBits;   // 未知类型按自定义位长处理
}

int TypeCatalog::clampBits(const QString &id, int b)
{
    const TypeInfo *ti = lookup(id);
    if (!ti)
        return qBound(1, b, 63);                    // 未知类型:位域语义
    if (ti->naturalBits > 0)
        return ti->naturalBits;                     // 定长类型不可改
    if (QLatin1String(ti->id) == "raw")
        return qBound(8, ((b + 4) / 8) * 8, 512);   // 字节块:8 的倍数
    return qBound(1, b, 63);                        // bitfield
}

QColor TypeCatalog::colorForType(const QString &id)
{
    const TypeInfo *ti = lookup(id);
    if (ti)
        return QColor(QLatin1String(ti->color));
    // 未知类型:按 id 哈希取稳定颜色
    static const char *kFallback[] = { "#c0392b", "#7d3c98", "#2471a3", "#b7950b", "#5d6d7e" };
    int h = 0;
    for (int i = 0; i < id.size(); ++i)
        h = h * 31 + id.at(i).unicode();
    return QColor(QLatin1String(kFallback[unsigned(h) % 5]));
}

QVariantList TypeCatalog::typeCatalog()
{
    QVariantList list;
    for (const TypeInfo &ti : kTypes) {
        QVariantMap m;
        m["id"] = QString::fromLatin1(ti.id);
        m["label"] = QString::fromUtf8(ti.label);
        list.append(m);
    }
    return list;
}

bool TypeCatalog::isBitType(const QString &id)
{
    if (id.size() != 4 || !id.startsWith(QLatin1String("bit")))
        return false;
    const QChar c = id.at(3);
    return c >= QLatin1Char('1') && c <= QLatin1Char('8');
}
