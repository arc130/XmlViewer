#pragma once

#include <QString>
#include <QVector>
#include <QVariantList>
#include <QColor>

struct TypeInfo
{
    const char *id;        // 存入 JSON 的稳定标识
    const char *label;     // 界面显示名(中文)
    int naturalBits;       // 该类型固有位长;-1 表示自定义
    bool customBits;       // 是否允许用户自定义位长
    const char *color;     // 柱状图分段颜色
};

// 类型目录:新增类型只需在此表加一行 + 无 QML 改动(ComboBox 由 typeCatalog() 驱动)。
namespace TypeCatalog
{
const QVector<TypeInfo> &all();
const TypeInfo *lookup(const QString &id);
int defaultBits(const QString &id);
bool allowsCustomBits(const QString &id);       // 未知类型返回 true(降级为自定义位长)
int clampBits(const QString &id, int b);
QColor colorForType(const QString &id);
QVariantList typeCatalog();                     // [{id, label}] 供 QML ComboBox
bool isBitType(const QString &id);              // bit1..bit8 位域类型
}
