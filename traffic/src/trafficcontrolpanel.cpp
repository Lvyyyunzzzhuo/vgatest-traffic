#include "trafficcontrolpanel.h"

#include <QCheckBox>
#include <QComboBox>
#include <QDateTime>
#include <QFormLayout>
#include <QGridLayout>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QJsonValue>
#include <QLabel>
#include <QPlainTextEdit>
#include <QPushButton>
#include <QSignalBlocker>
#include <QStackedWidget>
#include <QVBoxLayout>
#include <QtGlobal>

namespace {
quint8 crc8(const QByteArray &bytes)
{
    quint8 crc = 0;
    for (char ch : bytes) {
        crc ^= quint8(ch);
        for (int i = 0; i < 8; ++i)
            crc = (crc & 0x80) ? quint8((crc << 1) ^ 0x07) : quint8(crc << 1);
    }
    return crc;
}

QLabel *sectionTitle(const QString &text)
{
    auto *label = new QLabel(text);
    label->setObjectName(QStringLiteral("sectionTitle"));
    return label;
}
}

TrafficControlPanel::TrafficControlPanel(QWidget *parent) : QWidget(parent)
{
    auto *root = new QVBoxLayout(this);
    root->setContentsMargins(0, 0, 0, 0);
    root->setSpacing(10);

    auto *pageGroup = new QGroupBox(QStringLiteral("页面控制"));
    auto *pageRow = new QHBoxLayout(pageGroup);
    pageRow->addWidget(new QLabel(QStringLiteral("当前页面")));
    m_pageBox = makeValueBox({QStringLiteral("潮汐车道"), QStringLiteral("绿波车道"),
                              QStringLiteral("单横向车道"), QStringLiteral("十字路口"),
                              QStringLiteral("交通流实验")}, {0, 1, 2, 3, 4});
    pageRow->addWidget(m_pageBox, 1);
    auto *switchPage = new QPushButton(QStringLiteral("切换页面"));
    auto *readAll = new QPushButton(QStringLiteral("读取全部状态"));
    pageRow->addWidget(switchPage);
    auto *dumpLog = new QPushButton(QStringLiteral("Read event log"));
    auto *clearLog = new QPushButton(QStringLiteral("Clear event log"));
    pageRow->addWidget(readAll);
    pageRow->addWidget(dumpLog);
    pageRow->addWidget(clearLog);
    root->addWidget(pageGroup);

    m_pages = new QStackedWidget;
    addTidalPage();
    addGreenWavePage();
    addSinglePage();
    addCrossPage();
    addLabPage();
    root->addWidget(m_pages, 1);

    auto *statusRow = new QHBoxLayout;
    m_serialStatus = new QLabel(QStringLiteral("串口未连接"));
    m_serialStatus->setObjectName(QStringLiteral("badStatus"));
    m_lastStatus = new QLabel(QStringLiteral("等待操作"));
    statusRow->addWidget(m_serialStatus);
    statusRow->addStretch();
    statusRow->addWidget(m_lastStatus);
    root->addLayout(statusRow);

    m_log = new QPlainTextEdit;
    m_log->setReadOnly(true);
    m_log->setMaximumBlockCount(300);
    m_log->setMaximumHeight(125);
    m_log->setPlaceholderText(QStringLiteral("串口应答、云端操作和错误信息会显示在这里"));
    root->addWidget(m_log);

    connect(m_pageBox, qOverload<int>(&QComboBox::currentIndexChanged),
            m_pages, &QStackedWidget::setCurrentIndex);
    connect(switchPage, &QPushButton::clicked, this, [this] {
        sendCommand(0x10, 0xff, 0, comboValue(m_pageBox),
                    QStringLiteral("切换页面：%1").arg(m_pageBox->currentText()));
    });
    connect(readAll, &QPushButton::clicked, this, &TrafficControlPanel::readAllValues);
    connect(dumpLog, &QPushButton::clicked, this, [this] {
        emit sendFrame(QByteArray("D\n"));
        appendLog(QStringLiteral("Requested event log"));
    });
    connect(clearLog, &QPushButton::clicked, this, [this] {
        emit sendFrame(QByteArray("C\n"));
        appendLog(QStringLiteral("Sent clear event log command"));
    });
    updateLabMetrics();
}

QComboBox *TrafficControlPanel::makeValueBox(const QStringList &labels, const QList<int> &values)
{
    auto *box = new QComboBox;
    for (int i = 0; i < labels.size(); ++i) box->addItem(labels.at(i), values.at(i));
    return box;
}

int TrafficControlPanel::comboValue(const QComboBox *box) { return box->currentData().toInt(); }

bool TrafficControlPanel::setComboValue(QComboBox *box, int value)
{
    const int index = box->findData(value);
    if (index < 0) return false;
    const QSignalBlocker blocker(box);
    box->setCurrentIndex(index);
    return true;
}

void TrafficControlPanel::addTidalPage()
{
    auto *page = new QWidget;
    auto *root = new QVBoxLayout(page);
    root->addWidget(sectionTitle(QStringLiteral("潮汐车道控制")));
    auto *form = new QFormLayout;
    m_tidalMode = makeValueBox({QStringLiteral("自适应"), QStringLiteral("早高峰"),
                                QStringLiteral("晚高峰"), QStringLiteral("应急保持")}, {0,1,2,3});
    m_tidalLeft = makeValueBox({QStringLiteral("低"), QStringLiteral("中"), QStringLiteral("高")}, {0,1,2});
    m_tidalRight = makeValueBox({QStringLiteral("低"), QStringLiteral("中"), QStringLiteral("高")}, {0,1,2});
    m_tidalLock = new QCheckBox(QStringLiteral("锁定当前车道方向"));
    form->addRow(QStringLiteral("控制模式"), m_tidalMode);
    form->addRow(QStringLiteral("左侧流量"), m_tidalLeft);
    form->addRow(QStringLiteral("右侧流量"), m_tidalRight);
    form->addRow(QStringLiteral("车道锁定"), m_tidalLock);
    root->addLayout(form);
    auto *buttons = new QHBoxLayout;
    auto *apply = new QPushButton(QStringLiteral("应用潮汐参数"));
    auto *safeSwitch = new QPushButton(QStringLiteral("安全换向"));
    buttons->addWidget(apply);
    buttons->addWidget(safeSwitch);
    buttons->addStretch();
    root->addLayout(buttons);
    root->addStretch();
    connect(apply, &QPushButton::clicked, this, &TrafficControlPanel::sendTidal);
    connect(safeSwitch, &QPushButton::clicked, this, [this] {
        sendCommand(0x12, 0, 4, 1, QStringLiteral("请求潮汐车道安全换向"));
    });
    m_pages->addWidget(page);
}

void TrafficControlPanel::addGreenWavePage()
{
    auto *page = new QWidget;
    auto *layout = new QVBoxLayout(page);
    layout->addWidget(sectionTitle(QStringLiteral("绿波车道")));
    auto *text = new QLabel(QStringLiteral("该页面保持 FPGA 现有动画和红绿灯联动，当前没有可调参数。\n可通过顶部页面控制远程切换到此页面。"));
    text->setWordWrap(true);
    layout->addWidget(text);
    layout->addStretch();
    m_pages->addWidget(page);
}

void TrafficControlPanel::addSinglePage()
{
    auto *page = new QWidget;
    auto *layout = new QVBoxLayout(page);
    layout->addWidget(sectionTitle(QStringLiteral("单横向车道")));
    auto *form = new QFormLayout;
    m_singleSpeed = makeValueBox({"35 km/h", "40 km/h", "45 km/h", "50 km/h", "55 km/h", "60 km/h"},
                                 {35,40,45,50,55,60});
    form->addRow(QStringLiteral("车辆速度"), m_singleSpeed);
    auto *apply = new QPushButton(QStringLiteral("应用速度"));
    form->addRow(QString(), apply);
    layout->addLayout(form);
    layout->addStretch();
    connect(apply, &QPushButton::clicked, this, [this] {
        sendCommand(0x10, 2, 0, comboValue(m_singleSpeed),
                    QStringLiteral("设置单车道速度：%1").arg(m_singleSpeed->currentText()));
    });
    m_pages->addWidget(page);
}

void TrafficControlPanel::addCrossPage()
{
    auto *page = new QWidget;
    auto *root = new QVBoxLayout(page);
    root->addWidget(sectionTitle(QStringLiteral("十字路口")));
    auto *columns = new QHBoxLayout;
    auto *controlBox = new QGroupBox(QStringLiteral("车辆与行人"));
    auto *form = new QFormLayout(controlBox);
    m_crossHorizontal = makeValueBox({QStringLiteral("少"), QStringLiteral("多")}, {0,1});
    m_crossVertical = makeValueBox({QStringLiteral("少"), QStringLiteral("多")}, {0,1});
    m_crossPedestrians = makeValueBox({QStringLiteral("4 人"), QStringLiteral("10 人")}, {4,10});
    m_crossAdaptive = makeValueBox({QStringLiteral("固定配时"), QStringLiteral("自适应配时")}, {0,1});
    form->addRow(QStringLiteral("横向车辆密度"), m_crossHorizontal);
    form->addRow(QStringLiteral("纵向车辆密度"), m_crossVertical);
    form->addRow(QStringLiteral("行人数量"), m_crossPedestrians);
    form->addRow(QStringLiteral("控制模式"), m_crossAdaptive);
    auto *apply = new QPushButton(QStringLiteral("应用十字路口参数"));
    form->addRow(QString(), apply);
    columns->addWidget(controlBox, 1);

    auto *timeBox = new QGroupBox(QStringLiteral("当前绿灯配时"));
    auto *timeGrid = new QGridLayout(timeBox);
    const QStringList names = {QStringLiteral("横向直行"), QStringLiteral("横向左转"), QStringLiteral("横向右转"),
                               QStringLiteral("纵向直行"), QStringLiteral("纵向左转"), QStringLiteral("纵向右转")};
    for (int i = 0; i < 6; ++i) {
        timeGrid->addWidget(new QLabel(names.at(i)), i, 0);
        m_crossTimes[i] = new QLabel(QStringLiteral("%1 秒").arg(m_crossTimeValues[i]));
        m_crossTimes[i]->setObjectName(QStringLiteral("valueLabel"));
        timeGrid->addWidget(m_crossTimes[i], i, 1);
    }
    auto *read = new QPushButton(QStringLiteral("读取实际配时"));
    timeGrid->addWidget(read, 6, 0, 1, 2);
    columns->addWidget(timeBox, 1);
    root->addLayout(columns);
    root->addStretch();
    connect(apply, &QPushButton::clicked, this, &TrafficControlPanel::sendCross);
    connect(read, &QPushButton::clicked, this, [this] {
        for (int i = 0; i < 6; ++i) sendCommand(0x11, 3, 0x10 + i, 0, QString());
        appendLog(QStringLiteral("正在读取六项绿灯配时"));
    });
    m_pages->addWidget(page);
}

void TrafficControlPanel::addLabPage()
{
    auto *page = new QWidget;
    auto *root = new QVBoxLayout(page);
    root->addWidget(sectionTitle(QStringLiteral("交通流实验")));
    auto *columns = new QHBoxLayout;
    auto *controlBox = new QGroupBox(QStringLiteral("实验参数"));
    auto *form = new QFormLayout(controlBox);
    m_labGreen = makeValueBox({QStringLiteral("15 秒"), QStringLiteral("30 秒"), QStringLiteral("45 秒")}, {15,30,45});
    m_labRed = makeValueBox({QStringLiteral("30 秒"), QStringLiteral("45 秒"), QStringLiteral("60 秒")}, {30,45,60});
    m_labLength = makeValueBox({QStringLiteral("80 米"), QStringLiteral("200 米"), QStringLiteral("500 米")}, {80,200,500});
    m_labRate = makeValueBox({QStringLiteral("600 辆/小时"), QStringLiteral("900 辆/小时")}, {600,900});
    m_labPhase = makeValueBox({QStringLiteral("相位差错误"), QStringLiteral("相位差正确")}, {0,1});
    m_labControl = makeValueBox({QStringLiteral("定时控制"), QStringLiteral("自适应控制")}, {0,1});
    setComboValue(m_labGreen, 30);
    setComboValue(m_labPhase, 1);
    form->addRow(QStringLiteral("绿灯时长"), m_labGreen);
    form->addRow(QStringLiteral("红灯时长"), m_labRed);
    form->addRow(QStringLiteral("车道长度"), m_labLength);
    form->addRow(QStringLiteral("到达率"), m_labRate);
    form->addRow(QStringLiteral("相位差"), m_labPhase);
    form->addRow(QStringLiteral("控制方式"), m_labControl);
    auto *apply = new QPushButton(QStringLiteral("应用实验参数"));
    auto *reset = new QPushButton(QStringLiteral("恢复默认"));
    auto *buttonRow = new QHBoxLayout;
    buttonRow->addWidget(apply);
    buttonRow->addWidget(reset);
    form->addRow(QString(), buttonRow);
    columns->addWidget(controlBox, 1);

    auto *metricBox = new QGroupBox(QStringLiteral("实时指标"));
    auto *metricGrid = new QGridLayout(metricBox);
    const QStringList names = {QStringLiteral("平均延误"), QStringLiteral("最大排队"), QStringLiteral("通行量"),
                               QStringLiteral("溢出率"), QStringLiteral("平均停车次数"), QStringLiteral("当前排队")};
    for (int i = 0; i < 6; ++i) {
        metricGrid->addWidget(new QLabel(names.at(i)), i, 0);
        m_labMetrics[i] = new QLabel;
        m_labMetrics[i]->setObjectName(QStringLiteral("valueLabel"));
        metricGrid->addWidget(m_labMetrics[i], i, 1);
    }
    columns->addWidget(metricBox, 1);
    root->addLayout(columns);
    root->addStretch();
    connect(apply, &QPushButton::clicked, this, &TrafficControlPanel::sendLab);
    connect(reset, &QPushButton::clicked, this, [this] {
        setComboValue(m_labGreen, 30); setComboValue(m_labRed, 30);
        setComboValue(m_labLength, 200); setComboValue(m_labRate, 600);
        setComboValue(m_labPhase, 1); setComboValue(m_labControl, 0);
        updateLabMetrics();
        sendCommand(0x12, 4, 6, 1, QStringLiteral("恢复交通流实验默认参数"));
    });
    m_pages->addWidget(page);
}

QByteArray TrafficControlPanel::makeFrame(quint8 type, quint8 page, quint8 item, quint16 value)
{
    QByteArray frame;
    frame.append(char(0xaa)); frame.append(char(0x55)); frame.append(char(0x06));
    frame.append(char(type)); frame.append(char(m_sequence++)); frame.append(char(page));
    frame.append(char(item)); frame.append(char(value & 0xff)); frame.append(char(value >> 8));
    frame.append(char(crc8(frame.mid(2))));
    return frame;
}

void TrafficControlPanel::sendCommand(quint8 type, quint8 page, quint8 item, int value, const QString &text)
{
    const QByteArray frame = makeFrame(type, page, item, quint16(value));
    emit sendFrame(frame);
    const QString kind = type == 0x10 ? QStringLiteral("SET")
                       : type == 0x11 ? QStringLiteral("GET")
                       : type == 0x12 ? QStringLiteral("ACTION")
                                      : QStringLiteral("CMD");
    appendLog(QStringLiteral("TX %1 | page=%2 item=%3 value=%4 | %5")
                  .arg(kind).arg(page, 2, 16, QLatin1Char('0'))
                  .arg(item, 2, 16, QLatin1Char('0')).arg(value)
                  .arg(QString::fromLatin1(frame.toHex(' ').toUpper())));
    if (!text.isEmpty()) appendLog(text);
}

void TrafficControlPanel::sendTidal()
{
    sendCommand(0x10, 0, 0, comboValue(m_tidalMode), QString());
    sendCommand(0x10, 0, 1, comboValue(m_tidalLeft), QString());
    sendCommand(0x10, 0, 2, comboValue(m_tidalRight), QString());
    sendCommand(0x10, 0, 3, m_tidalLock->isChecked() ? 1 : 0, QString());
    appendLog(QStringLiteral("已发送潮汐车道全部参数"));
}

void TrafficControlPanel::sendCross()
{
    sendCommand(0x10, 3, 0, comboValue(m_crossHorizontal), QString());
    sendCommand(0x10, 3, 1, comboValue(m_crossVertical), QString());
    sendCommand(0x10, 3, 2, comboValue(m_crossPedestrians), QString());
    sendCommand(0x10, 3, 3, comboValue(m_crossAdaptive), QString());
    appendLog(QStringLiteral("已发送十字路口全部参数"));
}

void TrafficControlPanel::sendLab()
{
    const QList<QPair<int,int>> values = {{0,comboValue(m_labGreen)}, {1,comboValue(m_labRed)},
        {2,comboValue(m_labLength)}, {3,comboValue(m_labRate)}, {4,comboValue(m_labPhase)},
        {5,comboValue(m_labControl)}};
    for (const auto &entry : values) sendCommand(0x10, 4, entry.first, entry.second, QString());
    updateLabMetrics();
    appendLog(QStringLiteral("已发送交通流实验全部参数"));
}

void TrafficControlPanel::readAllValues()
{
    sendCommand(0x11, 0xff, 0, 0, QString());
    for (int item = 0; item <= 3; ++item) sendCommand(0x11, 0, item, 0, QString());
    sendCommand(0x11, 2, 0, 0, QString());
    for (int item = 0; item <= 3; ++item) sendCommand(0x11, 3, item, 0, QString());
    for (int item = 0x10; item <= 0x15; ++item) sendCommand(0x11, 3, item, 0, QString());
    for (int item = 0; item <= 5; ++item) sendCommand(0x11, 4, item, 0, QString());
    for (int item = 0x20; item <= 0x25; ++item) sendCommand(0x11, 4, item, 0, QString());
    appendLog(QStringLiteral("已请求 FPGA 返回全部可读取状态"));
}

void TrafficControlPanel::setSerialConnected(bool connected, const QString &port)
{
    m_serialStatus->setText(connected ? QStringLiteral("串口已连接：%1").arg(port) : QStringLiteral("串口未连接"));
    m_serialStatus->setObjectName(connected ? QStringLiteral("goodStatus") : QStringLiteral("badStatus"));
    m_serialStatus->style()->unpolish(m_serialStatus);
    m_serialStatus->style()->polish(m_serialStatus);
}

void TrafficControlPanel::appendLog(const QString &text)
{
    const QString line = QStringLiteral("[%1] %2").arg(QDateTime::currentDateTime().toString("HH:mm:ss"), text);
    m_log->appendPlainText(line);
    m_lastStatus->setText(text);
    emit activity(text);
}

void TrafficControlPanel::updateCrossTime(int item, int value)
{
    const int index = item - 0x10;
    if (index < 0 || index >= 6) return;
    m_crossTimeValues[index] = value;
    m_crossTimes[index]->setText(QStringLiteral("%1 秒").arg(value));
}

void TrafficControlPanel::updateLabMetrics()
{
    const int green = comboValue(m_labGreen), red = comboValue(m_labRed);
    const int length = comboValue(m_labLength), rate = comboValue(m_labRate);
    const bool correctPhase = comboValue(m_labPhase) == 1;
    const bool adaptive = comboValue(m_labControl) == 1;
    const int lengthDelay = length == 80 ? 18 : (length == 500 ? -6 : 0);
    const int lengthQueue = length == 80 ? 15 : (length == 500 ? -5 : 0);
    m_metricAvgDelay = qBound(0, int(26 + (30-green)*0.6 + (red-30)*0.5
                                    + (rate-600)/30.0 + lengthDelay
                                    + (correctPhase ? -5 : 12) + (adaptive ? -7 : 0)), 999);
    m_metricMaxQueue = qBound(0, int(21 + (30-green)/2.0 + (red-30)/2.0
                                    + (rate-600)/20.0 + lengthQueue
                                    + (correctPhase ? -4 : 10) + (adaptive ? -6 : 0)), 999);
    m_metricFlow = qBound(0, int(520 + (green-30)*5 - (red-30)*2
                                + (rate-600)/2.0 + (correctPhase ? 40 : -60)
                                + (adaptive ? 70 : 0)), 9999);
    m_metricOverflow = qBound(0, int(18 + (30-green) + (red-30)*0.7
                                    + (rate-600)/10.0 + (length == 80 ? 30 : (length == 500 ? -12 : 0))
                                    + (correctPhase ? -5 : 15) + (adaptive ? -8 : 0)), 100);
    m_metricStops = qBound(0.0, 1.8 + (30-green)/30.0 + (red-30)/30.0
                           + (rate-600)/500.0 + (length == 80 ? 0.8 : (length == 500 ? -0.3 : 0.0))
                           + (correctPhase ? -0.5 : 0.8) + (adaptive ? -0.4 : 0.0), 99.0);
    m_metricQueueNow = qBound(0, int(m_metricMaxQueue * (red > 30 ? 0.55 : 0.34)), 999);
    if (!m_labMetrics[0]) return;
    m_labMetrics[0]->setText(QStringLiteral("%1 秒").arg(m_metricAvgDelay));
    m_labMetrics[1]->setText(QStringLiteral("%1 辆").arg(m_metricMaxQueue));
    m_labMetrics[2]->setText(QStringLiteral("%1 辆/小时").arg(m_metricFlow));
    m_labMetrics[3]->setText(QStringLiteral("%1 %").arg(m_metricOverflow));
    m_labMetrics[4]->setText(QStringLiteral("%1 次").arg(m_metricStops, 0, 'f', 1));
    m_labMetrics[5]->setText(QStringLiteral("%1 辆").arg(m_metricQueueNow));
}

QJsonObject TrafficControlPanel::cloudProperties() const
{
    return QJsonObject{{"page", comboValue(m_pageBox)},
        {"tidal_mode", comboValue(m_tidalMode)}, {"tidal_left_flow", comboValue(m_tidalLeft)},
        {"tidal_right_flow", comboValue(m_tidalRight)}, {"tidal_lock", m_tidalLock->isChecked()},
        {"single_speed", comboValue(m_singleSpeed)},
        {"cross_horizontal_density", comboValue(m_crossHorizontal)},
        {"cross_vertical_density", comboValue(m_crossVertical)},
        {"cross_pedestrians", comboValue(m_crossPedestrians)}, {"cross_adaptive", comboValue(m_crossAdaptive)},
        {"horizontal_straight_time", m_crossTimeValues[0]}, {"horizontal_left_time", m_crossTimeValues[1]},
        {"horizontal_right_time", m_crossTimeValues[2]}, {"vertical_straight_time", m_crossTimeValues[3]},
        {"vertical_left_time", m_crossTimeValues[4]}, {"vertical_right_time", m_crossTimeValues[5]},
        {"lab_green", comboValue(m_labGreen)}, {"lab_red", comboValue(m_labRed)},
        {"lab_length", comboValue(m_labLength)}, {"lab_arrival_rate", comboValue(m_labRate)},
        {"lab_phase", comboValue(m_labPhase)}, {"lab_control", comboValue(m_labControl)},
        {"lab_avg_delay", m_metricAvgDelay}, {"lab_max_queue", m_metricMaxQueue},
        {"lab_flow", m_metricFlow}, {"lab_overflow", m_metricOverflow},
        {"lab_stops", m_metricStops}, {"lab_queue_now", m_metricQueueNow}};
}

bool TrafficControlPanel::applyWritableValue(const QString &id, int value, bool fromCloud)
{
    QComboBox *box = nullptr;
    quint8 page = 0, item = 0;
    if (id == "page") { box=m_pageBox; page=0xff; item=0; }
    else if (id == "tidal_mode") { box=m_tidalMode; page=0; item=0; }
    else if (id == "tidal_left_flow") { box=m_tidalLeft; page=0; item=1; }
    else if (id == "tidal_right_flow") { box=m_tidalRight; page=0; item=2; }
    else if (id == "single_speed") { box=m_singleSpeed; page=2; item=0; }
    else if (id == "cross_horizontal_density") { box=m_crossHorizontal; page=3; item=0; }
    else if (id == "cross_vertical_density") { box=m_crossVertical; page=3; item=1; }
    else if (id == "cross_pedestrians") { box=m_crossPedestrians; page=3; item=2; }
    else if (id == "cross_adaptive") { box=m_crossAdaptive; page=3; item=3; }
    else if (id == "lab_green") { box=m_labGreen; page=4; item=0; }
    else if (id == "lab_red") { box=m_labRed; page=4; item=1; }
    else if (id == "lab_length") { box=m_labLength; page=4; item=2; }
    else if (id == "lab_arrival_rate") { box=m_labRate; page=4; item=3; }
    else if (id == "lab_phase") { box=m_labPhase; page=4; item=4; }
    else if (id == "lab_control") { box=m_labControl; page=4; item=5; }
    if (!box || !setComboValue(box, value)) return false;
    if (id == "page") m_pages->setCurrentIndex(value);
    if (page == 4) updateLabMetrics();
    if (fromCloud) sendCommand(0x10, page, item, value, QStringLiteral("云端设置 %1 = %2").arg(id).arg(value));
    return true;
}

void TrafficControlPanel::applyCloudProperty(const QString &identifier, const QJsonValue &value)
{
    if (identifier == QStringLiteral("tidal_lock")) {
        const bool checked = value.isBool() ? value.toBool() : value.toInt() != 0;
        m_tidalLock->setChecked(checked);
        sendCommand(0x10, 0, 3, checked ? 1 : 0,
                    QStringLiteral("云端设置 tidal_lock = %1").arg(checked ? 1 : 0));
        return;
    }
    if (!applyWritableValue(identifier, value.toInt(), true))
        appendLog(QStringLiteral("忽略未知或只读云端属性：%1").arg(identifier));
}

void TrafficControlPanel::invokeCloudService(const QString &identifier, int value)
{
    if (value != 1) {
        appendLog(QStringLiteral("服务 %1 的参数不是 1，已忽略").arg(identifier));
        return;
    }
    if (identifier == QStringLiteral("tidal_safe_switch")) {
        sendCommand(0x12, 0, 4, 1, QStringLiteral("云端请求潮汐车道安全换向"));
    } else if (identifier == QStringLiteral("lab_reset")) {
        setComboValue(m_labGreen, 30); setComboValue(m_labRed, 30);
        setComboValue(m_labLength, 200); setComboValue(m_labRate, 600);
        setComboValue(m_labPhase, 1); setComboValue(m_labControl, 0);
        updateLabMetrics();
        sendCommand(0x12, 4, 6, 1, QStringLiteral("云端请求恢复交通流实验默认参数"));
    } else {
        appendLog(QStringLiteral("忽略未知云端服务：%1").arg(identifier));
    }
}

void TrafficControlPanel::handleFrame(const QByteArray &frame)
{
    if ((frame.size() != 9 && frame.size() != 10) ||
        quint8(frame.at(0)) != 0xaa || quint8(frame.at(1)) != 0x55) return;
    const quint8 type = quint8(frame.at(3)), page = quint8(frame.at(5)), item = quint8(frame.at(6));
    const int value = quint8(frame.at(7)) | (int(quint8(frame.at(8))) << 8);
    if (type == 0x81) {
        appendLog(QStringLiteral("NACK: page %1 / item %2 / value %3").arg(page).arg(item).arg(value));
        return;
    }
    QString name = QStringLiteral("页面 %1 项目 %2").arg(page).arg(item);
    if (page == 0xff && item == 0) { name=QStringLiteral("当前页面"); applyWritableValue("page", value, false); }
    else if (page == 0 && item == 0) { name=QStringLiteral("潮汐控制模式"); applyWritableValue("tidal_mode", value, false); }
    else if (page == 0 && item == 1) { name=QStringLiteral("潮汐左侧流量"); applyWritableValue("tidal_left_flow", value, false); }
    else if (page == 0 && item == 2) { name=QStringLiteral("潮汐右侧流量"); applyWritableValue("tidal_right_flow", value, false); }
    else if (page == 0 && item == 3) { name=QStringLiteral("潮汐车道锁定"); m_tidalLock->setChecked(value != 0); }
    else if (page == 2 && item == 0) { name=QStringLiteral("单车道速度"); applyWritableValue("single_speed", value, false); }
    else if (page == 3 && item == 0) { name=QStringLiteral("横向车辆密度"); applyWritableValue("cross_horizontal_density", value, false); }
    else if (page == 3 && item == 1) { name=QStringLiteral("纵向车辆密度"); applyWritableValue("cross_vertical_density", value, false); }
    else if (page == 3 && item == 2) { name=QStringLiteral("行人数量"); applyWritableValue("cross_pedestrians", value, false); }
    else if (page == 3 && item == 3) { name=QStringLiteral("十字路口模式"); applyWritableValue("cross_adaptive", value, false); }
    else if (page == 3 && item >= 0x10 && item <= 0x15) {
        const QStringList names={QStringLiteral("横向直行绿灯"),QStringLiteral("横向左转绿灯"),QStringLiteral("横向右转绿灯"),
                                 QStringLiteral("纵向直行绿灯"),QStringLiteral("纵向左转绿灯"),QStringLiteral("纵向右转绿灯")};
        name=names.at(item-0x10); updateCrossTime(item,value);
    } else if (page == 4 && item <= 5) {
        const QStringList ids={"lab_green","lab_red","lab_length","lab_arrival_rate","lab_phase","lab_control"};
        const QStringList names={QStringLiteral("实验绿灯时长"),QStringLiteral("实验红灯时长"),QStringLiteral("实验车道长度"),
                                 QStringLiteral("实验到达率"),QStringLiteral("实验相位差"),QStringLiteral("实验控制方式")};
        name=names.at(item); applyWritableValue(ids.at(item),value,false); updateLabMetrics();
    } else if (page == 4 && item >= 0x20 && item <= 0x25) {
        const QStringList names={QStringLiteral("平均延误"),QStringLiteral("最大排队"),QStringLiteral("通行量"),
                                 QStringLiteral("溢出率"),QStringLiteral("平均停车次数"),QStringLiteral("当前排队")};
        name=names.at(item-0x20);
        switch (item) {
        case 0x20: m_metricAvgDelay=value; break;
        case 0x21: m_metricMaxQueue=value; break;
        case 0x22: m_metricFlow=value; break;
        case 0x23: m_metricOverflow=value; break;
        case 0x24: m_metricStops=value/10.0; break;
        case 0x25: m_metricQueueNow=value; break;
        }
        m_labMetrics[0]->setText(QStringLiteral("%1 秒").arg(m_metricAvgDelay));
        m_labMetrics[1]->setText(QStringLiteral("%1 辆").arg(m_metricMaxQueue));
        m_labMetrics[2]->setText(QStringLiteral("%1 辆/小时").arg(m_metricFlow));
        m_labMetrics[3]->setText(QStringLiteral("%1 %").arg(m_metricOverflow));
        m_labMetrics[4]->setText(QStringLiteral("%1 次").arg(m_metricStops,0,'f',1));
        m_labMetrics[5]->setText(QStringLiteral("%1 辆").arg(m_metricQueueNow));
    }
    const QString kind = type == 0x80 ? QStringLiteral("ACK") : type == 0x81 ? QStringLiteral("NACK")
                         : type == 0x90 ? QStringLiteral("STATUS") : QStringLiteral("REPLY");
    const QString wireFormat = frame.size() == 9 ? QStringLiteral("legacy 9-byte")
                                                  : QStringLiteral("CRC 10-byte");
    appendLog(QStringLiteral("RX %1 | %2 = %3 | %4 | %5")
                  .arg(kind, name).arg(value).arg(wireFormat)
                  .arg(QString::fromLatin1(frame.toHex(' ').toUpper())));
}
void TrafficControlPanel::handleAsciiLine(const QByteArray &line)
{
    const QByteArray clean = line.trimmed();
    if (!clean.isEmpty())
        appendLog(QString::fromLatin1(clean));
}
