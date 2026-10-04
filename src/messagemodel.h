#pragma once

#include <QAbstractListModel>
#include <QVector>
#include <QVariantMap>
#include <QVariantList>
#include "field.h"

// 一个报文:帧名称 + 帧 ID + 帧类型 + 字段列表
struct Message
{
    QString name = QStringLiteral("报文1");   // 帧名称
    QString frameId;                          // 帧 ID(如 0x01)
    QString frameType;                        // 帧类型(如 心跳)
    QString description;
    QVector<Field> fields;
};

// 项目结构模型:多报文(当前报文 = 模型视图)+ 派生的位偏移 + 全部编辑操作。
// 字段操作全部作用于当前报文;切换报文触发模型整体重置。
// 位偏移是派生量(前缀和缓存),任何变更后失效重建,杜绝不一致。
class MessageModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int totalBits READ totalBits NOTIFY totalBitsChanged)
    Q_PROPERTY(int totalBytes READ totalBytes NOTIFY totalBitsChanged)
    Q_PROPERTY(bool byteAligned READ byteAligned NOTIFY totalBitsChanged)
    Q_PROPERTY(int selectedRow READ selectedRow WRITE setSelectedRow NOTIFY selectedRowChanged)
    Q_PROPERTY(QVariantMap selectedField READ selectedField NOTIFY selectedFieldChanged)
    Q_PROPERTY(QVariantList typeCatalog READ typeCatalog CONSTANT)
    Q_PROPERTY(QString filePath READ filePath NOTIFY filePathChanged)
    Q_PROPERTY(bool modified READ modified NOTIFY modifiedChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(int messageCount READ messageCount NOTIFY messageCountChanged)
    Q_PROPERTY(int currentMessageIndex READ currentMessageIndex NOTIFY currentMessageChanged)
    Q_PROPERTY(QString currentMessageName READ currentMessageName NOTIFY currentMessageChanged)
    Q_PROPERTY(int previewRevision READ previewRevision NOTIFY previewRevisionChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        EnglishNameRole,
        TypeRole,
        BitsRole,
        BitOffsetRole,
        ByteOffsetRole,
        UnitRole,
        RatioRole,
        ObserveRole,
        ValidRole,
        DescriptionRole,
        ValueDescriptionsRole,
        TypeColorRole,
        CustomBitsRole
    };

    explicit MessageModel(QObject *parent = nullptr);

    // QAbstractItemModel
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    bool setData(const QModelIndex &index, const QVariant &value, int role) override;
    QHash<int, QByteArray> roleNames() const override;

    // QML 属性
    int count() const { return curMessage().fields.size(); }
    int messageCount() const { return m_messages.size(); }
    int currentMessageIndex() const { return m_current; }
    QString currentMessageName() const { return m_messages.at(m_current).name; }
    int previewRevision() const { return m_previewRevision; }
    int totalBits() const;
    int totalBytes() const;
    bool byteAligned() const;
    int selectedRow() const { return m_selectedRow; }
    void setSelectedRow(int row);
    QVariantMap selectedField() const;
    QVariantList typeCatalog() const;
    QString filePath() const { return m_filePath; }
    bool modified() const { return m_modified; }
    QString lastError() const { return m_lastError; }
    void setModified(bool modified);   // main.cpp 的演示数据加载后复位脏标记

    // QML 操作入口
    Q_INVOKABLE void newMessage();
    Q_INVOKABLE void insertField(int row);
    Q_INVOKABLE void removeField(int row);
    Q_INVOKABLE void moveField(int row, int delta);
    Q_INVOKABLE bool setFieldAttribute(int row, const QString &key, const QVariant &value);
    Q_INVOKABLE QVariantMap fieldAt(int row) const;
    Q_INVOKABLE int bitOffsetOf(int row) const;   // row == count 时返回末尾边界(totalBits)
    Q_INVOKABLE int fieldIndexAtBit(int bit) const; // 位位置所属字段索引(拖动落点换算)
    Q_INVOKABLE QString chineseToPinyin(const QString &text) const; // 中文名→拼音(代码名,符号保留)
    Q_INVOKABLE int snapBitToFieldBoundary(int bit) const; // 吸附到最近字段边界
    Q_INVOKABLE int targetIndexAtBit(int bit) const; // 吸附后的插入位置索引 [0, count]
    Q_INVOKABLE bool saveTo(const QString &path);
    Q_INVOKABLE bool loadFrom(const QString &path);

    // 多报文管理
    Q_INVOKABLE void addMessage();                       // 新建报文并切换过去
    Q_INVOKABLE bool removeMessage(int index);           // 至少保留一个
    Q_INVOKABLE void setCurrentMessage(int index);
    Q_INVOKABLE bool setMessageAttribute(int index, const QString &key, const QVariant &value);
                                                         // key: name / frameId / frameType
    Q_INVOKABLE QVariantMap messageInfo(int index) const;    // {name, frameId, frameType, fieldCount, totalBits, totalBytes}
    Q_INVOKABLE QVariantList messagePreview(int index) const; // [{color, ratio}] 迷你预览

signals:
    void countChanged();
    void totalBitsChanged();
    void selectedRowChanged();
    void selectedFieldChanged();
    void filePathChanged();
    void modifiedChanged();
    void lastErrorChanged();
    void messageCountChanged();
    void currentMessageChanged();
    void previewRevisionChanged();

private:
    Message &curMessage() { return m_messages[m_current]; }
    const Message &curMessage() const { return m_messages.at(m_current); }
    void emitPreviewChanged();
    void ensureLayout() const;
    void invalidateLayout() const { m_layoutDirty = true; }
    void emitDownstreamOffsets(int fromRow);
    QVariantMap toMap(int row) const;
    // 位域字节完整覆盖:含 bit1-8 的字节内空位自动补占位(valid=false),
    // 并清理与其它字段重叠或位于无位域字节的占位。所有模型变更后调用。
    void enforceBytePacking();
    bool isPlaceholderField(int row) const;

    QVector<Message> m_messages;
    int m_current = 0;
    mutable QVector<int> m_prefixBits;   // 长度 count+1;prefixBits[i] = 前 i 个字段位长之和
    mutable bool m_layoutDirty = true;
    int m_selectedRow = -1;
    QString m_filePath;
    QString m_lastError;
    bool m_modified = false;
    int m_nameCounter = 0;
    int m_previewRevision = 0;
};
