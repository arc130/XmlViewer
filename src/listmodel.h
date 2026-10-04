#pragma once

#include <QAbstractListModel>
#include <QVector>
#include <QVariantMap>
#include <QHash>
#include <QByteArray>

// 通用 QVariantMap 列表模型:行段/断点/锚点等派生视图数据的标准 model-view 载体。
// 数据整体重建(setItems 内部 begin/endResetModel),QML delegate 用 required
// property 绑定角色(创建时角色已就绪,无 modelData 时序问题)。
class ListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    explicit ListModel(QObject *parent = nullptr);

    int count() const { return m_items.size(); }
    void setItems(const QVector<QVariantMap> &items);

signals:
    void countChanged();

public:
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    const QVector<QVariantMap> &items() const { return m_items; }
    QVariantMap itemAt(int row) const;   // 越界返回空 map

private:
    QVector<QVariantMap> m_items;
    QHash<int, QByteArray> m_roles;
};
