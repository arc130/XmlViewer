QT += quick quickcontrols2 widgets
CONFIG += c++11 qtquickcompiler

TARGET = xmlviewer
TEMPLATE = app

SOURCES += \
    src/main.cpp \
    src/typecatalog.cpp \
    src/messagemodel.cpp \
    src/barlayout.cpp \
    src/listmodel.cpp \
    src/themes.cpp \
    src/pinyin.cpp \
    src/pinyin_data.cpp \
    src/filedialoghelper.cpp

HEADERS += \
    src/field.h \
    src/typecatalog.h \
    src/messagemodel.h \
    src/barlayout.h \
    src/listmodel.h \
    src/themes.h \
    src/pinyin.h \
    src/filedialoghelper.h

RESOURCES += qml.qrc

# 让生成的可执行文件直接找到 Qt 5.15 的运行库(系统 ldconfig 中没有该前缀)
QMAKE_RPATHDIR += $$[QT_INSTALL_LIBS]
