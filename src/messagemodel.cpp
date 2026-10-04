#include "messagemodel.h"
#include "typecatalog.h"
#include "pinyin.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QFile>
#include <QFileInfo>
#include <algorithm>

MessageModel::MessageModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_messages.append(Message());
    newMessage();
}

int MessageModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : curMessage().fields.size();
}

QHash<int, QByteArray> MessageModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[NameRole] = "name";
    roles[EnglishNameRole] = "englishName";
    roles[TypeRole] = "type";
    roles[BitsRole] = "bits";
    roles[BitOffsetRole] = "bitOffset";
    roles[ByteOffsetRole] = "byteOffset";
    roles[UnitRole] = "unit";
    roles[RatioRole] = "ratio";
    roles[ObserveRole] = "observe";
    roles[ValidRole] = "valid";
    roles[DescriptionRole] = "description";
    roles[ValueDescriptionsRole] = "valueDescriptions";
    roles[TypeColorRole] = "typeColor";
    roles[CustomBitsRole] = "customBits";
    return roles;
}

void MessageModel::ensureLayout() const
{
    if (!m_layoutDirty)
        return;
    m_prefixBits.resize(curMessage().fields.size() + 1);
    int sum = 0;
    for (int i = 0; i < curMessage().fields.size(); ++i) {
        m_prefixBits[i] = sum;
        sum += curMessage().fields.at(i).bits;
    }
    m_prefixBits[curMessage().fields.size()] = sum;
    m_layoutDirty = false;
}

int MessageModel::totalBits() const
{
    ensureLayout();
    return m_prefixBits.value(curMessage().fields.size());
}

int MessageModel::totalBytes() const
{
    return (totalBits() + 7) / 8;
}

bool MessageModel::byteAligned() const
{
    return totalBits() % 8 == 0;
}

QVariant MessageModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= curMessage().fields.size())
        return QVariant();
    ensureLayout();
    const Field &f = curMessage().fields.at(index.row());
    const int row = index.row();
    switch (role) {
    case NameRole: return f.name;
    case EnglishNameRole: return f.englishName;
    case TypeRole: return f.type;
    case BitsRole: return f.bits;
    case BitOffsetRole: return m_prefixBits.value(row);
    case ByteOffsetRole: return m_prefixBits.value(row) / 8;
    case UnitRole: return f.unit;
    case RatioRole: return f.ratio;
    case ObserveRole: return f.observe;
    case ValidRole: return f.valid;
    case DescriptionRole: return f.description;
    case ValueDescriptionsRole: return f.valueDescriptions;
    case TypeColorRole: return TypeCatalog::colorForType(f.type).name();
    case CustomBitsRole: return TypeCatalog::allowsCustomBits(f.type);
    default: return QVariant();
    }
}

bool MessageModel::setData(const QModelIndex &index, const QVariant &value, int role)
{
    switch (role) {
    case NameRole: return setFieldAttribute(index.row(), QStringLiteral("name"), value);
    case EnglishNameRole: return setFieldAttribute(index.row(), QStringLiteral("englishName"), value);
    case TypeRole: return setFieldAttribute(index.row(), QStringLiteral("type"), value);
    case BitsRole: return setFieldAttribute(index.row(), QStringLiteral("bits"), value);
    case UnitRole: return setFieldAttribute(index.row(), QStringLiteral("unit"), value);
    case RatioRole: return setFieldAttribute(index.row(), QStringLiteral("ratio"), value);
    case ObserveRole: return setFieldAttribute(index.row(), QStringLiteral("observe"), value);
    case ValidRole: return setFieldAttribute(index.row(), QStringLiteral("valid"), value);
    case DescriptionRole: return setFieldAttribute(index.row(), QStringLiteral("description"), value);
    case ValueDescriptionsRole: return setFieldAttribute(index.row(), QStringLiteral("valueDescriptions"), value);
    default: return false;
    }
}

void MessageModel::setSelectedRow(int row)
{
    if (row < -1)
        row = -1;
    if (row >= curMessage().fields.size())
        row = curMessage().fields.size() - 1;
    if (row == m_selectedRow)
        return;
    m_selectedRow = row;
    emit selectedRowChanged();
    emit selectedFieldChanged();
}

void MessageModel::setModified(bool modified)
{
    if (m_modified == modified)
        return;
    m_modified = modified;
    emit modifiedChanged();
}

QVariantMap MessageModel::toMap(int row) const
{
    ensureLayout();
    const Field &f = curMessage().fields.at(row);
    QVariantMap m;
    m["name"] = f.name;
    m["englishName"] = f.englishName;
    m["type"] = f.type;
    m["bits"] = f.bits;
    m["bitOffset"] = m_prefixBits.value(row);
    m["byteOffset"] = m_prefixBits.value(row) / 8;
    m["unit"] = f.unit;
    m["ratio"] = f.ratio;
    m["observe"] = f.observe;
    m["valid"] = f.valid;
    m["description"] = f.description;
    m["valueDescriptions"] = f.valueDescriptions;
    m["typeColor"] = TypeCatalog::colorForType(f.type).name();
    m["customBits"] = TypeCatalog::allowsCustomBits(f.type);
    return m;
}

QVariantMap MessageModel::selectedField() const
{
    QVariantMap m;
    m["name"] = QString();
    m["englishName"] = QString();
    m["type"] = QStringLiteral("uint8");
    m["bits"] = 8;
    m["bitOffset"] = 0;
    m["byteOffset"] = 0;
    m["unit"] = QString();
    m["ratio"] = QStringLiteral("1");
    m["observe"] = false;
    m["valid"] = true;
    m["description"] = QString();
    m["valueDescriptions"] = QString();
    m["customBits"] = false;
    if (m_selectedRow >= 0 && m_selectedRow < curMessage().fields.size())
        return toMap(m_selectedRow);
    return m;
}

QVariantList MessageModel::typeCatalog() const
{
    return TypeCatalog::typeCatalog();
}

void MessageModel::newMessage()
{
    // 缓存必须在模型信号之前失效:信号槽(如 BarLayout::rebuild)会立即读取偏移
    invalidateLayout();
    beginResetModel();
    Message msg;
    m_nameCounter = 1;
    Field f;
    f.name = QStringLiteral("字段%1").arg(m_nameCounter);
    msg.fields.append(f);
    curMessage() = msg;
    endResetModel();
    m_filePath.clear();
    emit filePathChanged();
    m_lastError.clear();
    emit lastErrorChanged();
    setModified(false);
    setSelectedRow(0);
    emit totalBitsChanged();
    emit countChanged();
    enforceBytePacking();
}

void MessageModel::insertField(int row)
{
    row = qBound(0, row, curMessage().fields.size());
    Field f;
    f.name = QStringLiteral("字段%1").arg(++m_nameCounter);
    invalidateLayout();   // 信号槽 rebuild 会立即读取偏移,缓存须先失效
    beginInsertRows(QModelIndex(), row, row);
    curMessage().fields.insert(row, f);
    endInsertRows();
    if (row + 1 < curMessage().fields.size())
        emitDownstreamOffsets(row + 1);
    emit totalBitsChanged();
    emit countChanged();
    setSelectedRow(row);
    setModified(true);
    enforceBytePacking();
}

void MessageModel::removeField(int row)
{
    if (curMessage().fields.size() <= 1 || row < 0 || row >= curMessage().fields.size())
        return;
    invalidateLayout();   // 信号槽 rebuild 会立即读取偏移,缓存须先失效
    beginRemoveRows(QModelIndex(), row, row);
    curMessage().fields.remove(row);
    endRemoveRows();
    if (row < curMessage().fields.size())
        emitDownstreamOffsets(row);
    emit totalBitsChanged();
    emit countChanged();
    if (m_selectedRow > row)
        setSelectedRow(m_selectedRow - 1);
    else if (m_selectedRow == row)
        setSelectedRow(qMin(row, curMessage().fields.size() - 1));
    emit selectedFieldChanged();   // 同行索引下已是另一字段
    setModified(true);
    enforceBytePacking();
}

void MessageModel::moveField(int row, int delta)
{
    if (row < 0 || row >= curMessage().fields.size())
        return;
    const int target = qBound(0, row + delta, curMessage().fields.size() - 1);
    if (target == row)
        return;
    const bool down = target > row;
    invalidateLayout();   // 信号槽 rebuild 会立即读取偏移,缓存须先失效
    beginMoveRows(QModelIndex(), row, row, QModelIndex(), down ? target + 1 : target);
    curMessage().fields.move(row, target);
    endMoveRows();
    emitDownstreamOffsets(qMin(row, target));
    emit totalBitsChanged();
    setSelectedRow(target);
    setModified(true);
    enforceBytePacking();
}

bool MessageModel::setFieldAttribute(int row, const QString &key, const QVariant &value)
{
    if (row < 0 || row >= curMessage().fields.size())
        return false;
    Field &f = curMessage().fields[row];
    QVector<int> roles;
    if (key == QLatin1String("name")) {
        f.name = value.toString();
        roles << NameRole;
    } else if (key == QLatin1String("englishName")) {
        f.englishName = value.toString();
        roles << EnglishNameRole;
    } else if (key == QLatin1String("type")) {
        f.type = value.toString();
        f.bits = TypeCatalog::clampBits(f.type, f.bits);
        roles << TypeRole << BitsRole << TypeColorRole << CustomBitsRole;
    } else if (key == QLatin1String("bits")) {
        bool ok = false;
        const int b = value.toInt(&ok);
        if (!ok || b < 1)
            return false;
        f.bits = TypeCatalog::clampBits(f.type, b);
        roles << BitsRole;
    } else if (key == QLatin1String("unit")) {
        f.unit = value.toString();
        roles << UnitRole;
    } else if (key == QLatin1String("ratio")) {
        f.ratio = value.toString();
        roles << RatioRole;
    } else if (key == QLatin1String("observe")) {
        f.observe = value.toBool() && f.valid;   // 仅有效字段可观察
        roles << ObserveRole;
    } else if (key == QLatin1String("valid")) {
        f.valid = value.toBool();
        if (!f.valid)
            f.observe = false;                    // 无效即取消观察
        roles << ValidRole << ObserveRole;
    } else if (key == QLatin1String("description")) {
        f.description = value.toString();
        roles << DescriptionRole;
    } else if (key == QLatin1String("valueDescriptions")) {
        f.valueDescriptions = value.toString();
        roles << ValueDescriptionsRole;
    } else {
        return false;
    }
    invalidateLayout();
    emit dataChanged(index(row), index(row), roles);
    if (row + 1 < curMessage().fields.size())
        emitDownstreamOffsets(row + 1);
    emit totalBitsChanged();
    if (row == m_selectedRow)
        emit selectedFieldChanged();
    setModified(true);
    // 类型/位长/有效性变化会影响字节覆盖,重新补全位域字节
    if (roles.contains(TypeRole) || roles.contains(BitsRole) || roles.contains(ValidRole))
        enforceBytePacking();
    return true;
}

void MessageModel::emitDownstreamOffsets(int fromRow)
{
    if (fromRow >= curMessage().fields.size())
        return;
    emit dataChanged(index(fromRow), index(curMessage().fields.size() - 1),
                     QVector<int>() << BitOffsetRole << ByteOffsetRole);
}

QVariantMap MessageModel::fieldAt(int row) const
{
    if (row < 0 || row >= curMessage().fields.size())
        return QVariantMap();
    return toMap(row);
}

int MessageModel::bitOffsetOf(int row) const
{
    ensureLayout();
    if (row < 0)
        return 0;
    if (row >= curMessage().fields.size())
        return m_prefixBits.value(curMessage().fields.size());   // 末尾边界
    return m_prefixBits.value(row);
}

int MessageModel::fieldIndexAtBit(int bit) const
{
    ensureLayout();
    if (curMessage().fields.isEmpty())
        return 0;
    if (bit <= 0)
        return 0;
    for (int i = 0; i + 1 < curMessage().fields.size(); ++i) {
        if (bit < m_prefixBits.value(i + 1))
            return i;
    }
    return curMessage().fields.size() - 1;   // 末尾及越界归最后字段
}

int MessageModel::snapBitToFieldBoundary(int bit) const
{
    ensureLayout();
    if (curMessage().fields.isEmpty())
        return 0;
    const int total = m_prefixBits.value(curMessage().fields.size());
    if (bit <= 0)
        return 0;
    if (bit >= total)
        return total;   // 末尾边界
    const int i = fieldIndexAtBit(bit);
    const int start = m_prefixBits.value(i);
    const int end = m_prefixBits.value(i + 1);
    // 吸附到较近的边界(相等时取起点)
    return (bit - start <= end - bit) ? start : end;
}

QString MessageModel::chineseToPinyin(const QString &text) const
{
    return PinyinHelper::toPinyin(text);
}

int MessageModel::targetIndexAtBit(int bit) const
{
    ensureLayout();
    const int b = snapBitToFieldBoundary(bit);
    for (int i = 0; i < curMessage().fields.size(); ++i) {
        if (m_prefixBits.value(i) == b)
            return i;
    }
    return curMessage().fields.size();   // 末尾边界 → 追加位置
}

// ---- 多报文管理 ---------------------------------------------------------
void MessageModel::emitPreviewChanged()
{
    ++m_previewRevision;
    emit previewRevisionChanged();
}

void MessageModel::addMessage()
{
    Message msg;
    msg.name = QStringLiteral("报文%1").arg(m_messages.size() + 1);
    Field f;
    f.name = QStringLiteral("字段%1").arg(++m_nameCounter);
    msg.fields.append(f);
    m_messages.append(msg);
    emit messageCountChanged();
    emitPreviewChanged();
    setCurrentMessage(m_messages.size() - 1);
    setModified(true);
}

bool MessageModel::removeMessage(int index)
{
    if (m_messages.size() <= 1 || index < 0 || index >= m_messages.size())
        return false;
    m_messages.remove(index);
    if (index < m_current)
        --m_current;
    else if (index == m_current)
        m_current = qMin(m_current, m_messages.size() - 1);
    invalidateLayout();
    beginResetModel();
    endResetModel();
    m_selectedRow = -1;
    emit selectedRowChanged();
    emit selectedFieldChanged();
    emit currentMessageChanged();
    emit messageCountChanged();
    emit totalBitsChanged();
    emit countChanged();
    emitPreviewChanged();
    setModified(true);
    enforceBytePacking();
    return true;
}

void MessageModel::setCurrentMessage(int index)
{
    index = qBound(0, index, m_messages.size() - 1);
    if (index == m_current)
        return;
    m_current = index;
    invalidateLayout();
    beginResetModel();
    endResetModel();
    m_selectedRow = -1;
    emit selectedRowChanged();
    emit selectedFieldChanged();
    emit currentMessageChanged();
    emit totalBitsChanged();
    emit countChanged();
    emitPreviewChanged();
    enforceBytePacking();
}

bool MessageModel::setMessageAttribute(int index, const QString &key, const QVariant &value)
{
    if (index < 0 || index >= m_messages.size())
        return false;
    Message &msg = m_messages[index];
    if (key == QLatin1String("name")) {
        msg.name = value.toString();
    } else if (key == QLatin1String("frameId")) {
        msg.frameId = value.toString();
    } else if (key == QLatin1String("frameType")) {
        msg.frameType = value.toString();
    } else {
        return false;
    }
    if (index == m_current)
        emit currentMessageChanged();
    emitPreviewChanged();
    setModified(true);
    return true;
}

QVariantMap MessageModel::messageInfo(int index) const
{
    QVariantMap m;
    m["name"] = QString();
    m["frameId"] = QString();
    m["frameType"] = QString();
    m["fieldCount"] = 0;
    m["totalBits"] = 0;
    m["totalBytes"] = 0;
    if (index < 0 || index >= m_messages.size())
        return m;
    const Message &msg = m_messages.at(index);
    int bits = 0;
    for (const Field &f : msg.fields)
        bits += f.bits;
    m["name"] = msg.name;
    m["frameId"] = msg.frameId;
    m["frameType"] = msg.frameType;
    m["fieldCount"] = msg.fields.size();
    m["totalBits"] = bits;
    m["totalBytes"] = (bits + 7) / 8;
    return m;
}

QVariantList MessageModel::messagePreview(int index) const
{
    QVariantList out;
    if (index < 0 || index >= m_messages.size())
        return out;
    const Message &msg = m_messages.at(index);
    int bits = 0;
    for (const Field &f : msg.fields)
        bits += f.bits;
    if (bits <= 0)
        return out;
    for (const Field &f : msg.fields) {
        QVariantMap s;
        s["color"] = TypeCatalog::colorForType(f.type).name();
        s["ratio"] = double(f.bits) / double(bits);
        out.append(s);
    }
    return out;
}

// ---- 位域字节完整覆盖 --------------------------------------------------
bool MessageModel::isPlaceholderField(int row) const
{
    if (row < 0 || row >= curMessage().fields.size())
        return false;
    const Field &f = curMessage().fields.at(row);
    return !f.valid && TypeCatalog::isBitType(f.type);
}

void MessageModel::enforceBytePacking()
{
    ensureLayout();
    const int total = m_prefixBits.value(curMessage().fields.size());

    // 1) 清理:与其它字段重叠的占位、以及位于无位域字节内的占位
    QVector<int> removeRows;
    for (int i = 0; i < curMessage().fields.size(); ++i) {
        if (!isPlaceholderField(i))
            continue;
        const int s = m_prefixBits.value(i);
        const int e = s + curMessage().fields.at(i).bits;
        bool remove = false;
        for (int j = 0; j < curMessage().fields.size() && !remove; ++j) {
            if (j == i)
                continue;
            const int js = m_prefixBits.value(j);
            if (js < e && js + curMessage().fields.at(j).bits > s)
                remove = true;   // 与其它字段重叠
        }
        if (!remove) {
            const int bs = (s / 8) * 8;
            bool hasBit = false;
            for (int j = 0; j < curMessage().fields.size() && !hasBit; ++j) {
                if (j == i)
                    continue;   // 占位自身不算"该字节的位域"
                const int js = m_prefixBits.value(j);
                const int je = js + curMessage().fields.at(j).bits;
                if (js < bs + 8 && je > bs && TypeCatalog::isBitType(curMessage().fields.at(j).type))
                    hasBit = true;
            }
            remove = !hasBit;    // 该字节内没有位域 → 占位无意义
        }
        if (remove)
            removeRows.append(i);
    }
    if (!removeRows.isEmpty()) {
        for (int k = removeRows.size() - 1; k >= 0; --k) {
            const int r = removeRows.at(k);
            invalidateLayout();
            beginRemoveRows(QModelIndex(), r, r);
            curMessage().fields.remove(r);
            endRemoveRows();
        }
        ensureLayout();
    }

    // 2) 补全:含位域的字节内,空位区间插入占位字段(bitN, valid=false)
    struct Gap { int start; int len; int insertIndex; };
    QVector<Gap> gaps;
    for (int b = 0; b * 8 < total; ++b) {
        const int bs = b * 8;
        const int be = bs + 8;
        bool hasBit = false;
        for (int i = 0; i < curMessage().fields.size() && !hasBit; ++i) {
            const int s = m_prefixBits.value(i);
            if (s < be && s + curMessage().fields.at(i).bits > bs &&
                    TypeCatalog::isBitType(curMessage().fields.at(i).type))
                hasBit = true;
        }
        if (!hasBit)
            continue;
        // 该字节内字段覆盖区间
        QVector<QPair<int, int>> cov;
        for (int i = 0; i < curMessage().fields.size(); ++i) {
            const int s = m_prefixBits.value(i);
            const int e = s + curMessage().fields.at(i).bits;
            if (s < be && e > bs)
                cov.append(qMakePair(qMax(s, bs), qMin(e, be)));
        }
        std::sort(cov.begin(), cov.end(), [](const QPair<int,int> &a, const QPair<int,int> &b) {
            return a.first < b.first;
        });
        int cursor = bs;
        for (const auto &c : cov) {
            if (c.first > cursor) {
                Gap g;
                g.start = cursor;
                g.len = c.first - cursor;
                g.insertIndex = -1;   // 稍后计算
                gaps.append(g);
            }
            cursor = qMax(cursor, c.second);
        }
        if (cursor < be) {
            Gap g;
            g.start = cursor;
            g.len = be - cursor;
            g.insertIndex = -1;
            gaps.append(g);
        }
    }
    // 计算插入索引并按位置从大到小插入(避免索引漂移)
    for (Gap &g : gaps) {
        int idx = curMessage().fields.size();
        for (int i = 0; i < curMessage().fields.size(); ++i) {
            if (m_prefixBits.value(i) >= g.start + g.len) {
                idx = i;
                break;
            }
        }
        g.insertIndex = idx;
    }
    std::sort(gaps.begin(), gaps.end(), [](const Gap &a, const Gap &b) {
        return a.start > b.start;
    });
    for (const Gap &g : gaps) {
        Field ph;
        ph.name = QStringLiteral("保留%1").arg(g.len);
        ph.type = QStringLiteral("bit%1").arg(g.len);
        ph.bits = g.len;
        ph.valid = false;
        ph.observe = false;
        invalidateLayout();
        beginInsertRows(QModelIndex(), g.insertIndex, g.insertIndex);
        curMessage().fields.insert(g.insertIndex, ph);
        endInsertRows();
    }
    if (!gaps.isEmpty())
        ensureLayout();

    if (!removeRows.isEmpty() || !gaps.isEmpty()) {
        emit countChanged();
        emit totalBitsChanged();
    }
}

bool MessageModel::saveTo(const QString &path)
{
    QJsonObject root;
    root[QStringLiteral("format")] = QStringLiteral("idlview.project");
    root[QStringLiteral("version")] = 2;
    root[QStringLiteral("bitOrder")] = QStringLiteral("msb0");   // 预留:后续解析报文时使用
    QJsonArray msgs;
    for (const Message &msg : m_messages) {
        QJsonObject mo;
        mo["name"] = msg.name;
        mo["frameId"] = msg.frameId;
        mo["frameType"] = msg.frameType;
        QJsonArray arr;
        for (const Field &f : msg.fields)
            arr.append(f.toJson());
        mo["fields"] = arr;
        msgs.append(mo);
    }
    root[QStringLiteral("messages")] = msgs;

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        m_lastError = QStringLiteral("无法写入文件: %1").arg(path);
        emit lastErrorChanged();
        return false;
    }
    file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    if (!file.commit()) {
        m_lastError = QStringLiteral("写入失败: %1").arg(path);
        emit lastErrorChanged();
        return false;
    }
    m_filePath = path;
    emit filePathChanged();
    m_lastError.clear();
    emit lastErrorChanged();
    setModified(false);
    return true;
}

bool MessageModel::loadFrom(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        m_lastError = QStringLiteral("无法打开文件: %1").arg(path);
        emit lastErrorChanged();
        return false;
    }
    QJsonParseError pe;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &pe);
    if (pe.error != QJsonParseError::NoError) {
        m_lastError = QStringLiteral("JSON 解析失败: %1").arg(pe.errorString());
        emit lastErrorChanged();
        return false;
    }
    const QJsonObject root = doc.object();
    const QString format = root["format"].toString();
    QVector<Message> loaded;
    QStringList warns;

    if (format == QLatin1String("idlview.message") ||
            (format.isEmpty() && !root["fields"].isUndefined())) {
        // v1 单报文文件:作为项目中的一个报文加载
        if (root["version"].toInt(1) > 1) {
            m_lastError = QStringLiteral("该文件由更新版本的程序创建,无法打开");
            emit lastErrorChanged();
            return false;
        }
        const QJsonArray arr = root["fields"].toArray();
        Message msg;
        msg.name = QFileInfo(path).completeBaseName();
        if (msg.name.isEmpty())
            msg.name = QStringLiteral("报文1");
        for (const QJsonValue &v : arr) {
            if (!v.isObject()) {
                m_lastError = QStringLiteral("字段条目格式错误");
                emit lastErrorChanged();
                return false;
            }
            QString w;
            msg.fields.append(Field::fromJson(v.toObject(), &w));
            if (!w.isEmpty())
                warns << w;
        }
        if (msg.fields.isEmpty()) {
            m_lastError = QStringLiteral("文件中没有字段");
            emit lastErrorChanged();
            return false;
        }
        loaded.append(msg);
    } else if (format == QLatin1String("idlview.project")) {
        if (root["version"].toInt(2) > 2) {
            m_lastError = QStringLiteral("该文件由更新版本的程序创建,无法打开 (version=%1)")
                              .arg(root["version"].toInt(2));
            emit lastErrorChanged();
            return false;
        }
        const QJsonArray msgs = root["messages"].toArray();
        if (msgs.isEmpty()) {
            m_lastError = QStringLiteral("文件中没有报文");
            emit lastErrorChanged();
            return false;
        }
        int msgNo = 0;
        for (const QJsonValue &mv : msgs) {
            if (!mv.isObject()) {
                m_lastError = QStringLiteral("报文条目格式错误");
                emit lastErrorChanged();
                return false;
            }
            const QJsonObject mo = mv.toObject();
            Message msg;
            msg.name = mo["name"].toString();
            if (msg.name.isEmpty())
                msg.name = QStringLiteral("报文%1").arg(++msgNo);
            msg.frameId = mo["frameId"].toString();
            msg.frameType = mo["frameType"].toString();
            const QJsonArray arr = mo["fields"].toArray();
            for (const QJsonValue &v : arr) {
                if (!v.isObject()) {
                    m_lastError = QStringLiteral("字段条目格式错误");
                    emit lastErrorChanged();
                    return false;
                }
                QString w;
                msg.fields.append(Field::fromJson(v.toObject(), &w));
                if (!w.isEmpty())
                    warns << w;
            }
            loaded.append(msg);
        }
    } else {
        m_lastError = QStringLiteral("不是报文结构文件 (format=%1)").arg(format);
        emit lastErrorChanged();
        return false;
    }

    invalidateLayout();   // 信号槽 rebuild 会立即读取偏移,缓存须先失效
    beginResetModel();
    m_messages = loaded;
    endResetModel();
    m_current = 0;
    m_nameCounter = curMessage().fields.size();
    m_filePath = path;
    emit filePathChanged();
    m_selectedRow = -1;
    emit selectedRowChanged();
    emit selectedFieldChanged();
    setModified(false);
    emit totalBitsChanged();
    emit countChanged();
    emit messageCountChanged();
    emit currentMessageChanged();
    m_lastError = warns.join(QLatin1Char('\n'));
    emit lastErrorChanged();
    emitPreviewChanged();
    enforceBytePacking();
    return true;
}
