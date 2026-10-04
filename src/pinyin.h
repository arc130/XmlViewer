#pragma once

#include <QString>
#include <cstdint>

// 中文 → 拼音(无音调,用于生成代码中的名称)。
// 仅转换汉字(Unicode 基本区 U+4E00..U+9FFF),数字/字母/符号原样保留。
//
// 双路径实现(src/pinyin.cpp):
//   1. ICU(优先):系统装有 ICU 时动态解析 Transliterator API
//      (规则 "Han-Latin/Names; Latin-ASCII"),输出与历史行为一致;
//   2. 内置码表(兜底):pinyin_data.cpp 内置 Unihan kMandarin 码表,
//      零外部依赖 —— Windows 官方 Qt 不自带 ICU,靠此路径保证拼音可用。
namespace PinyinHelper
{
QString toPinyin(const QString &text);
}

// 内置码表查询(实现于 pinyin_data.cpp):返回无调 ASCII 拼音,未收录返回 nullptr
const char *pinyinLookup(uint32_t cp);
