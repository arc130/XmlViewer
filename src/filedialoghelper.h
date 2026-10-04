#pragma once

#include <QObject>
#include <QString>

// Qt 5.15 没有 Qt Quick Controls 2 的 FileDialog,用 QFileDialog(需要 QApplication)。
class FileDialogHelper : public QObject
{
    Q_OBJECT
public:
    explicit FileDialogHelper(QObject *parent = nullptr) : QObject(parent) {}

    Q_INVOKABLE QString openFileName();
    Q_INVOKABLE QString saveFileName();
};
