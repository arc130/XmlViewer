#include "filedialoghelper.h"

#include <QFileDialog>

QString FileDialogHelper::openFileName()
{
    return QFileDialog::getOpenFileName(nullptr, QStringLiteral("打开报文结构"),
                                        QString(),
                                        QStringLiteral("报文结构 (*.json);;所有文件 (*)"));
}

QString FileDialogHelper::saveFileName()
{
    return QFileDialog::getSaveFileName(nullptr, QStringLiteral("保存报文结构"),
                                        QString(),
                                        QStringLiteral("报文结构 (*.json);;所有文件 (*)"));
}
