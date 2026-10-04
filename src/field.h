#pragma once

#include <QString>
#include <QtGlobal>
#include <QJsonObject>
#include "typecatalog.h"

// 一个报文字段。位偏移不存储 —— 由 MessageModel 按字段顺序累加位长派生。
struct Field
{
    QString name;            // 中文名称
    QString englishName;     // 英文名称(程序中读取用)
    QString type = QStringLiteral("uint8");   // 类型 id,见 TypeCatalog
    int bits = 8;                             // 位长(定长类型跟随类型表;bitfield/raw 自定义)
    QString unit;                             // 单位(任意字符串)
    QString ratio = QStringLiteral("1");      // 比率(读取值 × 比率 = 实际值,任意字符串如 0.1)
    bool observe = false;                     // 是否被观察者模式监听
    bool valid = true;                        // 是否有效;无效 = 占位字段(仅有效时可 observe)
    QString description;                      // 说明
    QString valueDescriptions;                // 值含义表,每行一条 "数值 含义"(如 "0 关闭\n1 开启")

    QJsonObject toJson() const
    {
        QJsonObject o;
        o["name"] = name;
        o["englishName"] = englishName;
        o["type"] = type;
        o["bits"] = bits;
        o["unit"] = unit;
        o["ratio"] = ratio;
        o["observe"] = observe;
        o["valid"] = valid;
        o["description"] = description;
        o["valueDescriptions"] = valueDescriptions;
        return o;
    }

    static Field fromJson(const QJsonObject &o, QString *warn)
    {
        Field f;
        f.name = o["name"].toString();
        f.englishName = o["englishName"].toString();
        f.type = o["type"].toString();
        // 旧版本的自定义位域类型映射到 bit1..bit8
        if (f.type == QLatin1String("bitfield")) {
            const int b = qBound(1, o["bits"].toInt(1), 8);
            f.type = QStringLiteral("bit%1").arg(b);
        }
        f.bits = TypeCatalog::clampBits(f.type, o["bits"].toInt(8));
        if (f.bits < 1)
            f.bits = TypeCatalog::defaultBits(f.type);
        f.unit = o["unit"].toString();
        f.ratio = o["ratio"].toString();
        if (f.ratio.isEmpty())
            f.ratio = QStringLiteral("1");
        f.observe = o["observe"].toBool();
        f.valid = o["valid"].toBool(true);   // 旧文件无此键:默认有效
        if (!f.valid)
            f.observe = false;
        f.description = o["description"].toString();
        f.valueDescriptions = o["valueDescriptions"].toString();
        if (warn) {
            if (f.type.isEmpty()) {
                f.type = QStringLiteral("uint8");
                *warn = QStringLiteral("字段“%1”缺少类型,按 uint8 处理").arg(f.name);
            } else if (!TypeCatalog::lookup(f.type)) {
                *warn = QStringLiteral("字段“%1”类型 %2 未知,按自定义位长处理").arg(f.name).arg(f.type);
            }
        }
        return f;
    }
};
