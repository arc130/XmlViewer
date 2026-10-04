#include "listmodel.h"

ListModel::ListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

void ListModel::setItems(const QVector<QVariantMap> &items)
{
    // 角色集从首条 map 的键建立(应用内键集合固定),整体重置
    QHash<int, QByteArray> roles;
    int roleId = Qt::UserRole + 1;
    if (!items.isEmpty()) {
        for (auto it = items.first().cbegin(); it != items.first().cend(); ++it)
            roles[roleId++] = it.key().toUtf8();
    }
    beginResetModel();
    m_roles = roles;
    m_items = items;
    endResetModel();
    emit countChanged();
}

int ListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_items.size();
}

QVariant ListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return QVariant();
    const QVariantMap &m = m_items.at(index.row());
    const QByteArray name = m_roles.value(role);
    if (name.isEmpty())
        return QVariant();
    return m.value(QString::fromUtf8(name));
}

QHash<int, QByteArray> ListModel::roleNames() const
{
    return m_roles;
}

QVariantMap ListModel::itemAt(int row) const
{
    if (row < 0 || row >= m_items.size())
        return QVariantMap();
    return m_items.at(row);
}
