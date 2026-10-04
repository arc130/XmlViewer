#include "barlayout.h"

BarLayout::BarLayout(QObject *parent)
    : QObject(parent)
    , m_segmentsModel(new ListModel(this))
    , m_breakpointsModel(new ListModel(this))
    , m_anchorsModel(new ListModel(this))
{
}

void BarLayout::setMessageModel(MessageModel *model)
{
    if (m_model)
        m_model->disconnect(this);
    m_model = model;
    if (!m_model)
        return;
    connect(m_model, &QAbstractItemModel::rowsInserted, this, &BarLayout::rebuild);
    connect(m_model, &QAbstractItemModel::rowsRemoved, this, &BarLayout::rebuild);
    connect(m_model, &QAbstractItemModel::rowsMoved, this, &BarLayout::rebuild);
    connect(m_model, &QAbstractItemModel::modelReset, this, &BarLayout::rebuild);
    connect(m_model, &QAbstractItemModel::dataChanged, this, &BarLayout::rebuild);
    recompute();
}

void BarLayout::setGeometry(int viewportWidth, int pxPerByte)
{
    if (m_viewportWidth == viewportWidth && m_pxPerByte == pxPerByte)
        return;
    m_viewportWidth = viewportWidth;
    m_pxPerByte = pxPerByte;
    recompute();
}

void BarLayout::recompute()
{
    // 每行位长:按可用像素计算完整字节数(至少 1 字节)
    int rowBits = 8;
    if (m_pxPerByte > 0) {
        const int margin = 24 /*originX*/ + 48 /*行尾留白*/;
        const int avail = m_viewportWidth - margin;
        const int bytes = qMax(1, avail / m_pxPerByte);
        rowBits = bytes * 8;
    }
    m_rowBits = rowBits;

    QVector<QVariantMap> segments;
    QVector<QVariantMap> breakpoints;
    QVector<QVariantMap> anchors;

    const int totalBits = m_model ? m_model->totalBits() : 0;
    m_rowCount = qMax(1, (totalBits + m_rowBits - 1) / m_rowBits);
    m_lastRowBits = totalBits == 0 ? 0 : ((totalBits - 1) % m_rowBits) + 1;

    if (m_model) {
        for (int i = 0; i < m_model->count(); ++i) {
            const QVariantMap f = m_model->fieldAt(i);
            const int off = f["bitOffset"].toInt();
            const int fieldBits = f["bits"].toInt();

            int row = off / m_rowBits;
            int pos = off;
            int remaining = fieldBits;

            {
                QVariantMap a;
                a["fieldIndex"] = i;
                a["row"] = row;
                a["bitInRow"] = pos % m_rowBits;
                anchors.append(a);
            }

            int segCount = 0;
            while (remaining > 0) {
                const int rowEnd = (row + 1) * m_rowBits;
                const int segBits = qMin(remaining, rowEnd - pos);
                QVariantMap s = f;                  // 携带字段全部显示属性
                s["fieldIndex"] = i;
                s["row"] = row;
                s["bitInRow"] = pos % m_rowBits;
                s["bits"] = segBits;               // 本段位长(覆盖字段总位长)
                s["fieldBits"] = fieldBits;        // 字段总位长
                s["breakLeft"] = (segCount > 0);   // 非首段:左端撕口
                s["breakRight"] = (remaining > segBits); // 非尾段:右端撕口
                segments.append(s);
                ++segCount;

                pos += segBits;
                remaining -= segBits;
                if (remaining > 0) {
                    // 断行点 = 两半撕纸:左半在上一行行尾,右半在下一行行首
                    QVariantMap bLeft;
                    bLeft["row"] = row;
                    bLeft["bitInRow"] = m_rowBits;
                    bLeft["half"] = QStringLiteral("left");
                    breakpoints.append(bLeft);
                    QVariantMap bRight;
                    bRight["row"] = row + 1;
                    bRight["bitInRow"] = 0;
                    bRight["half"] = QStringLiteral("right");
                    breakpoints.append(bRight);
                }
                ++row;
            }
        }
    }

    m_segmentsModel->setItems(segments);
    m_breakpointsModel->setItems(breakpoints);
    m_anchorsModel->setItems(anchors);
    emit layoutChanged();
}
