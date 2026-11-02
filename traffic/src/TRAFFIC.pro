QT += core gui widgets network serialport

CONFIG += c++17
TEMPLATE = app
TARGET = TRAFFIC

SOURCES += \
    main.cpp \
    mainwindow.cpp \
    mqttclient.cpp \
    onenetclient.cpp \
    trafficcontrolpanel.cpp

HEADERS += \
    mainwindow.h \
    mqttclient.h \
    onenetclient.h \
    trafficcontrolpanel.h

qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target
