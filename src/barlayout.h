#pragma once

#include <QObject>
#include <QVariantList>
#include <QVector>
#include <QVariantMap>
#include "messagemodel.h"
#include "listmodel.h"

// 柱状图行布局:把位流按视口宽度折行(字节边界换行),字段跨行时切成多个行段。
// 纯视图计算,不修改 MessageModel。
// 行段/断点/锚点通过三个 ListModel(QAbstractListModel)暴露给 QML —— 标准
// model-view 架构:MessageModel 是领域模型,ListModel 是派生的视图模型,
// QML Repeater 是视图;delegate 用 required property 绑定角色。
class BarLayout : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QObject* segmentsModel READ segmentsModel CONSTANT)      // 行段: fieldIndex,row,bitInRow,bits,fieldBits,bitOffset,byteOffset,name,type,unit,description,typeColor,customBits
    Q_PROPERTY(QObject* breakpointsModel READ breakpointsModel CONSTANT) // 断行点: row,bitInRow
    Q_PROPERTY(QObject* anchorsModel READ anchorsModel CONSTANT)         // 字段起点: fieldIndex,row,bitInRow
    Q_PROPERTY(int rowCount READ rowCount NOTIFY layoutChanged)
    Q_PROPERTY(int rowBits READ rowBits NOTIFY layoutChanged)        // 每行位长(8 的倍数)
    Q_PROPERTY(int lastRowBits READ lastRowBits NOTIFY layoutChanged) // 末行内容位长

public:
    explicit BarLayout(QObject *parent = nullptr);

    void setMessageModel(MessageModel *model);   // 建立信号连接并立即计算一次
    Q_INVOKABLE void setGeometry(int viewportWidth, int pxPerByte);
    Q_INVOKABLE void rebuild() { recompute(); }

    QObject *segmentsModel() const { return m_segmentsModel; }
    QObject *breakpointsModel() const { return m_breakpointsModel; }
    QObject *anchorsModel() const { return m_anchorsModel; }
    int rowCount() const { return m_rowCount; }
    int rowBits() const { return m_rowBits; }
    int lastRowBits() const { return m_lastRowBits; }

    // 供 smoke 自测的便捷查询
    Q_INVOKABLE QVariantMap segmentAt(int i) const { return m_segmentsModel->itemAt(i); }
    Q_INVOKABLE QVariantMap breakpointAt(int i) const { return m_breakpointsModel->itemAt(i); }
    Q_INVOKABLE QVariantMap anchorAt(int i) const { return m_anchorsModel->itemAt(i); }

signals:
    void layoutChanged();

private:
    void recompute();

    MessageModel *m_model = nullptr;
    int m_viewportWidth = 800;
    int m_pxPerByte = 32;
    int m_rowBits = 8;
    int m_rowCount = 1;
    int m_lastRowBits = 8;
    ListModel *m_segmentsModel = nullptr;
    ListModel *m_breakpointsModel = nullptr;
    ListModel *m_anchorsModel = nullptr;
};
