#pragma once

#include <QVariantMap>
#include <QStringList>

// 配色方案表:--theme 参数选择,经 context property themeColors 提供给 QML。
// 键:primary/accent(控件主色与强调色)、titleBar(标题栏)、
// barBg/rowBg/rowBorder/grid/tick/rulerText(柱状图)、
// cardBg/cardSel/cardBorder/cardText/cardSub(报文卡片)、
// segBorder/tearLine/fiberLine(段描边与撕痕)、textSecondary(辅助文字)。
namespace Themes
{
QStringList names();
QVariantMap colors(const QString &name);
QString defaultName();
}
