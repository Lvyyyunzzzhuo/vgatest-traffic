#include "mainwindow.h"
#include "onenetclient.h"
#include "trafficcontrolpanel.h"

#include <QApplication>
#include <QCheckBox>
#include <QComboBox>
#include <QCoreApplication>
#include <QFileInfo>
#include <QFormLayout>
#include <QGridLayout>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QMessageBox>
#include <QPushButton>
#include <QSerialPort>
#include <QSerialPortInfo>
#include <QSettings>
#include <QSpinBox>
#include <QStatusBar>
#include <QTimer>
#include <QVBoxLayout>

namespace {
quint8 frameCrc(const QByteArray &frame)
{
    quint8 crc = 0;
    for (int i = 2; i < 9; ++i) {
        crc ^= quint8(frame.at(i));
        for (int bit = 0; bit < 8; ++bit)
            crc = (crc & 0x80) ? quint8((crc << 1) ^ 0x07) : quint8(crc << 1);
    }
    return crc;
}

QString settingsPath()
{
    return QCoreApplication::applicationDirPath() + QStringLiteral("/onenet.ini");
}
}

MainWindow::MainWindow(QWidget *parent) : QMainWindow(parent)
{
    m_serial = new QSerialPort(this);
    m_oneNet = new OneNetClient(this);
    m_publishTimer = new QTimer(this);
    m_publishTimer->setInterval(1000);
    buildUi();
    loadCloudSettings();
    scanSerialPorts();

    connect(m_serial, &QSerialPort::readyRead, this, &MainWindow::readSerial);
    connect(m_serial, &QSerialPort::errorOccurred, this, [this](QSerialPort::SerialPortError error) {
        if (error != QSerialPort::NoError && error != QSerialPort::NotOpenError)
            statusBar()->showMessage(QStringLiteral("串口错误：%1").arg(m_serial->errorString()), 5000);
    });
    connect(m_trafficPanel, &TrafficControlPanel::sendFrame,
            this, &MainWindow::writeSerialFrame);
    connect(m_oneNet, &OneNetClient::propertySet,
            m_trafficPanel, &TrafficControlPanel::applyCloudProperty);
    connect(m_oneNet, &OneNetClient::serviceInvoked,
            m_trafficPanel, &TrafficControlPanel::invokeCloudService);
    connect(m_oneNet, &OneNetClient::statusChanged,
            this, &MainWindow::setCloudStatus);
    connect(m_oneNet, &OneNetClient::connected, this, [this] {
        m_cloudButton->setText(QStringLiteral("断开云平台"));
        m_publishTimer->start();
        publishCloudState();
    });
    connect(m_oneNet, &OneNetClient::disconnected, this, [this] {
        m_cloudButton->setText(QStringLiteral("连接 OneNET"));
        m_publishTimer->stop();
    });
    connect(m_publishTimer, &QTimer::timeout, this, &MainWindow::publishCloudState);
}

MainWindow::~MainWindow()
{
    saveCloudSettings();
}

void MainWindow::buildUi()
{
    setWindowTitle(QStringLiteral("FPGA 交通仿真控制与 OneNET 网关"));
    setMinimumSize(1020, 760);
    resize(1180, 860);
    auto *central = new QWidget(this);
    auto *root = new QVBoxLayout(central);
    root->setContentsMargins(18, 14, 18, 14);
    root->setSpacing(12);

    auto *titleRow = new QHBoxLayout;
    auto *title = new QLabel(QStringLiteral("交通仿真控制台"));
    title->setObjectName(QStringLiteral("appTitle"));
    auto *subtitle = new QLabel(QStringLiteral("FPGA 串口控制  ·  OneNET 实时监控"));
    subtitle->setObjectName(QStringLiteral("subtitle"));
    titleRow->addWidget(title);
    titleRow->addStretch();
    titleRow->addWidget(subtitle);
    root->addLayout(titleRow);

    auto *connectionRow = new QHBoxLayout;
    auto *serialGroup = new QGroupBox(QStringLiteral("FPGA 串口"));
    auto *serialLayout = new QGridLayout(serialGroup);
    m_serialBox = new QComboBox;
    auto *scanButton = new QPushButton(QStringLiteral("扫描"));
    m_serialButton = new QPushButton(QStringLiteral("打开串口"));
    m_serialDetail = new QLabel(QStringLiteral("115200 / 8N1 | FPGA 约 200 ms 上报 | 串口助手不要同时打开"));
    m_serialDetail->setObjectName(QStringLiteral("mutedText"));
    serialLayout->addWidget(new QLabel(QStringLiteral("端口")), 0, 0);
    serialLayout->addWidget(m_serialBox, 0, 1);
    serialLayout->addWidget(scanButton, 0, 2);
    serialLayout->addWidget(m_serialButton, 1, 1);
    serialLayout->addWidget(m_serialDetail, 1, 2);
    connectionRow->addWidget(serialGroup, 2);

    auto *cloudGroup = new QGroupBox(QStringLiteral("OneNET 云平台"));
    auto *cloudGrid = new QGridLayout(cloudGroup);
    m_hostEdit = new QLineEdit;
    m_portSpin = new QSpinBox;
    m_portSpin->setRange(1, 65535);
    m_tlsCheck = new QCheckBox(QStringLiteral("TLS"));
    m_productEdit = new QLineEdit;
    m_deviceEdit = new QLineEdit;
    m_keyEdit = new QLineEdit;
    m_keyEdit->setEchoMode(QLineEdit::Password);
    m_keyEdit->setPlaceholderText(QStringLiteral("粘贴 Product AccessKey 或完整 Token"));
    auto *showKey = new QCheckBox(QStringLiteral("显示"));
    m_cloudButton = new QPushButton(QStringLiteral("连接 OneNET"));
    m_cloudStatus = new QLabel(QStringLiteral("云平台未连接"));
    m_cloudStatus->setObjectName(QStringLiteral("badStatus"));
    cloudGrid->addWidget(new QLabel(QStringLiteral("服务器")), 0, 0);
    cloudGrid->addWidget(m_hostEdit, 0, 1, 1, 3);
    cloudGrid->addWidget(new QLabel(QStringLiteral("端口")), 0, 4);
    cloudGrid->addWidget(m_portSpin, 0, 5);
    cloudGrid->addWidget(m_tlsCheck, 0, 6);
    cloudGrid->addWidget(new QLabel(QStringLiteral("产品 ID")), 1, 0);
    cloudGrid->addWidget(m_productEdit, 1, 1);
    cloudGrid->addWidget(new QLabel(QStringLiteral("设备名称")), 1, 2);
    cloudGrid->addWidget(m_deviceEdit, 1, 3);
    cloudGrid->addWidget(new QLabel(QStringLiteral("AccessKey / Token")), 2, 0);
    cloudGrid->addWidget(m_keyEdit, 2, 1, 1, 3);
    cloudGrid->addWidget(showKey, 2, 4);
    cloudGrid->addWidget(m_cloudButton, 1, 5, 1, 2);
    cloudGrid->addWidget(m_cloudStatus, 2, 5, 1, 2);
    connectionRow->addWidget(cloudGroup, 5);
    root->addLayout(connectionRow);

    m_trafficPanel = new TrafficControlPanel;
    root->addWidget(m_trafficPanel, 1);
    setCentralWidget(central);

    connect(scanButton, &QPushButton::clicked, this, &MainWindow::scanSerialPorts);
    connect(m_serialButton, &QPushButton::clicked, this, &MainWindow::toggleSerial);
    connect(m_cloudButton, &QPushButton::clicked, this, &MainWindow::toggleCloud);
    connect(showKey, &QCheckBox::toggled, this, [this](bool checked) {
        m_keyEdit->setEchoMode(checked ? QLineEdit::Normal : QLineEdit::Password);
    });
    connect(m_tlsCheck, &QCheckBox::toggled, this, [this](bool checked) {
        if (checked && m_portSpin->value() == 1883) m_portSpin->setValue(8883);
        if (!checked && m_portSpin->value() == 8883) m_portSpin->setValue(1883);
    });
    connect(m_productEdit, &QLineEdit::textChanged, this, [this](const QString &productId) {
        // Keep the standard OneNET endpoint in sync when the product changes.
        // Custom endpoints are left untouched.
        const QString suffix = QStringLiteral(".mqtts.acc.cmcconenet.cn");
        const QString host = m_hostEdit->text().trimmed();
        if (host.endsWith(suffix))
            m_hostEdit->setText(productId.trimmed() + suffix);
    });

    setStyleSheet(QStringLiteral(R"(
        QMainWindow, QWidget { background: #f4f6f8; color: #17212b; font-size: 14px; }
        QLabel#appTitle { font-size: 26px; font-weight: 700; color: #137c49; }
        QLabel#subtitle, QLabel#mutedText { color: #68737d; }
        QGroupBox { background: white; border: 1px solid #d8dee4; border-radius: 6px;
                    margin-top: 12px; padding: 12px 10px 10px 10px; font-weight: 600; }
        QGroupBox::title { subcontrol-origin: margin; left: 10px; padding: 0 5px; }
        QLineEdit, QComboBox, QSpinBox, QPlainTextEdit { background: white; border: 1px solid #cbd3da;
                    border-radius: 4px; padding: 6px; min-height: 22px; }
        QPushButton { background: #137c49; color: white; border: none; border-radius: 4px;
                      padding: 8px 15px; min-height: 20px; }
        QPushButton:hover { background: #0f683d; }
        QLabel#sectionTitle { font-size: 20px; font-weight: 700; color: #137c49; }
        QLabel#valueLabel { font-size: 16px; font-weight: 700; color: #1261a0; }
        QLabel#goodStatus { color: #137c49; font-weight: 600; }
        QLabel#badStatus { color: #b3261e; font-weight: 600; }
    )"));
}

void MainWindow::loadCloudSettings()
{
    QSettings settings(settingsPath(), QSettings::IniFormat);
    m_hostEdit->setText(settings.value("onenet/host", "GXF8j2l1pC.mqtts.acc.cmcconenet.cn").toString());
    m_portSpin->setValue(settings.value("onenet/port", 1883).toInt());
    m_tlsCheck->setChecked(settings.value("onenet/tls", false).toBool());
    m_productEdit->setText(settings.value("onenet/productId", "GXF8j2l1pC").toString());
    m_deviceEdit->setText(settings.value("onenet/deviceName", "traffic_device_01").toString());
    m_keyEdit->setText(settings.value("onenet/accessKeyOrToken").toString());
}

void MainWindow::saveCloudSettings()
{
    QSettings settings(settingsPath(), QSettings::IniFormat);
    settings.setValue("onenet/host", m_hostEdit->text().trimmed());
    settings.setValue("onenet/port", m_portSpin->value());
    settings.setValue("onenet/tls", m_tlsCheck->isChecked());
    settings.setValue("onenet/productId", m_productEdit->text().trimmed());
    settings.setValue("onenet/deviceName", m_deviceEdit->text().trimmed());
    settings.setValue("onenet/accessKeyOrToken", m_keyEdit->text().trimmed());
}

void MainWindow::scanSerialPorts()
{
    const QString selected = m_serialBox->currentData().toString();
    m_serialBox->clear();
    for (const QSerialPortInfo &info : QSerialPortInfo::availablePorts())
        m_serialBox->addItem(QStringLiteral("%1  —  %2").arg(info.portName(), info.description()), info.portName());
    const int oldIndex = m_serialBox->findData(selected);
    if (oldIndex >= 0) m_serialBox->setCurrentIndex(oldIndex);
    statusBar()->showMessage(QStringLiteral("发现 %1 个串口").arg(m_serialBox->count()), 2500);
}

void MainWindow::toggleSerial()
{
    if (m_serial->isOpen()) {
        m_serial->close();
        m_serialQueue.clear();
        m_serialInFlight.clear();
        m_serialRetries = 0;
        m_serialButton->setText(QStringLiteral("打开串口"));
        m_serialBox->setEnabled(true);
        m_trafficPanel->setSerialConnected(false);
        return;
    }
    if (m_serialBox->currentIndex() < 0) {
        QMessageBox::warning(this, QStringLiteral("串口"), QStringLiteral("没有可用串口，请连接设备后重新扫描。"));
        return;
    }
    const QString port = m_serialBox->currentData().toString();
    m_serial->setPortName(port);
    m_serial->setBaudRate(QSerialPort::Baud115200);
    m_serial->setDataBits(QSerialPort::Data8);
    m_serial->setParity(QSerialPort::NoParity);
    m_serial->setStopBits(QSerialPort::OneStop);
    m_serial->setFlowControl(QSerialPort::NoFlowControl);
    if (!m_serial->open(QIODevice::ReadWrite)) {
        QMessageBox::critical(this, QStringLiteral("串口打开失败"), m_serial->errorString());
        return;
    }
    m_protocolBuffer.clear();
    m_asciiBuffer.clear();
    m_serialQueue.clear();
    m_serialInFlight.clear();
    m_serialRetries = 0;
    m_serialButton->setText(QStringLiteral("关闭串口"));
    m_serialBox->setEnabled(false);
    m_trafficPanel->setSerialConnected(true, port);
    statusBar()->showMessage(QStringLiteral("串口 %1 已连接").arg(port), 3000);
}

void MainWindow::writeSerialFrame(const QByteArray &frame)
{
    if (!m_serial->isOpen()) {
        statusBar()->showMessage(QStringLiteral("指令未发送：请先打开 FPGA 串口"), 4000);
        return;
    }
    if (frame.size() >= 2 && quint8(frame.at(0)) == 0xaa && quint8(frame.at(1)) == 0x55) {
        m_serialQueue.enqueue(frame);
        pumpSerialQueue();
        return;
    }
    if (m_serial->write(frame) != frame.size())
        statusBar()->showMessage(QStringLiteral("串口指令发送不完整"), 4000);
}

void MainWindow::pumpSerialQueue()
{
    if (!m_serial->isOpen() || !m_serialInFlight.isEmpty() || m_serialQueue.isEmpty()) return;
    m_serialInFlight = m_serialQueue.dequeue();
    m_serialRetries = 0;
    if (m_serial->write(m_serialInFlight) != m_serialInFlight.size()) {
        m_serialInFlight.clear();
        pumpSerialQueue();
        return;
    }
    QTimer::singleShot(350, this, &MainWindow::serialFrameTimeout);
}

void MainWindow::finishSerialFrame(const QByteArray &frame)
{
    if (m_serialInFlight.isEmpty() || frame.size() < 5) return;
    if (quint8(frame.at(4)) != quint8(m_serialInFlight.at(4))) return;
    m_serialInFlight.clear();
    m_serialRetries = 0;
    QTimer::singleShot(3, this, &MainWindow::pumpSerialQueue);
}

void MainWindow::serialFrameTimeout()
{
    if (m_serialInFlight.isEmpty() || !m_serial->isOpen()) return;
    if (m_serialRetries++ < 2) {
        m_serial->write(m_serialInFlight);
        QTimer::singleShot(350, this, &MainWindow::serialFrameTimeout);
        return;
    }
    statusBar()->showMessage(QStringLiteral("FPGA command timeout: no ACK/NACK"), 5000);
    m_serialInFlight.clear();
    m_serialRetries = 0;
    pumpSerialQueue();
}

void MainWindow::readSerial()
{
    m_protocolBuffer += m_serial->readAll();
    processTrafficFrames();
}

void MainWindow::processTrafficFrames()
{
    while (true) {
        const int start = m_protocolBuffer.indexOf(QByteArray::fromHex("AA55"));
        const int newline = m_protocolBuffer.indexOf('\n');
        if (newline >= 0 && (start < 0 || newline < start)) {
            m_asciiBuffer += m_protocolBuffer.left(newline + 1);
            m_protocolBuffer.remove(0, newline + 1);
            m_trafficPanel->handleAsciiLine(m_asciiBuffer);
            m_asciiBuffer.clear();
            continue;
        }
        if (start < 0) {
            const int keep = (!m_protocolBuffer.isEmpty() &&
                              quint8(m_protocolBuffer.back()) == 0xaa) ? 1 : 0;
            if (m_protocolBuffer.size() > keep)
                m_asciiBuffer += m_protocolBuffer.left(m_protocolBuffer.size() - keep);
            if (keep) m_protocolBuffer = m_protocolBuffer.right(1);
            else m_protocolBuffer.clear();
            if (m_asciiBuffer.size() > 4096) m_asciiBuffer.clear();
            return;
        }
        if (start > 0) {
            m_asciiBuffer += m_protocolBuffer.left(start);
            m_protocolBuffer.remove(0, start);
            continue;
        }
        if (m_protocolBuffer.size() < 9) return;
        if (quint8(m_protocolBuffer.at(2)) != 0x06) {
            m_protocolBuffer.remove(0, 1);
            continue;
        }
        if (m_protocolBuffer.size() < 10) return;
        const quint8 type = quint8(m_protocolBuffer.at(3));
        const bool knownType = type == 0x80 || type == 0x81 || type == 0x90;
        // The current adaptive bitstream emits the original 9-byte response
        // form. Newer UART builds append CRC as byte 10.
        if (knownType && quint8(m_protocolBuffer.at(9)) == 0xaa) {
            const QByteArray frame = m_protocolBuffer.left(9);
            m_protocolBuffer.remove(0, 9);
            finishSerialFrame(frame);
            m_trafficPanel->handleFrame(frame);
            continue;
        }
        const QByteArray frame = m_protocolBuffer.left(10);
        if (frameCrc(frame) == quint8(frame.at(9))) {
            m_protocolBuffer.remove(0, 10);
            finishSerialFrame(frame);
            m_trafficPanel->handleFrame(frame);
        } else {
            m_protocolBuffer.remove(0, 1);
        }
    }
}

void MainWindow::toggleCloud()
{
    if (m_oneNet->isConnected()) {
        m_oneNet->disconnectCloud();
        m_publishTimer->stop();
        m_cloudButton->setText(QStringLiteral("连接 OneNET"));
        setCloudStatus(QStringLiteral("云平台未连接"), true);
        return;
    }
    if (m_hostEdit->text().trimmed().isEmpty() || m_productEdit->text().trimmed().isEmpty()
            || m_deviceEdit->text().trimmed().isEmpty() || m_keyEdit->text().trimmed().isEmpty()) {
        QMessageBox::warning(this, QStringLiteral("OneNET 配置不完整"),
                             QStringLiteral("请填写服务器、产品 ID、设备名称和 Product AccessKey（或 Token）。"));
        return;
    }
    saveCloudSettings();
    m_cloudButton->setEnabled(false);
    QTimer::singleShot(3000, this, [this] { m_cloudButton->setEnabled(true); });
    m_oneNet->connectCloud(m_hostEdit->text(), quint16(m_portSpin->value()), m_tlsCheck->isChecked(),
                           m_productEdit->text(), m_deviceEdit->text(), m_keyEdit->text());
}

void MainWindow::setCloudStatus(const QString &text, bool error)
{
    m_cloudStatus->setText(text);
    m_cloudStatus->setObjectName(error ? QStringLiteral("badStatus") : QStringLiteral("goodStatus"));
    m_cloudStatus->style()->unpolish(m_cloudStatus);
    m_cloudStatus->style()->polish(m_cloudStatus);
    statusBar()->showMessage(text, 5000);
}

void MainWindow::publishCloudState()
{
    m_oneNet->publishProperties(m_trafficPanel->cloudProperties());
}
