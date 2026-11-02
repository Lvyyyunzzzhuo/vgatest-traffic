#ifndef TRAFFICCONTROLPANEL_H
#define TRAFFICCONTROLPANEL_H

#include <QJsonObject>
#include <QWidget>

class QCheckBox;
class QComboBox;
class QLabel;
class QPlainTextEdit;
class QStackedWidget;

class TrafficControlPanel : public QWidget
{
    Q_OBJECT
public:
    explicit TrafficControlPanel(QWidget *parent = nullptr);
    void handleFrame(const QByteArray &frame);
    void handleAsciiLine(const QByteArray &line);
    void setSerialConnected(bool connected, const QString &port = QString());
    QJsonObject cloudProperties() const;

public slots:
    void applyCloudProperty(const QString &identifier, const QJsonValue &value);
    void invokeCloudService(const QString &identifier, int value = 1);

signals:
    void sendFrame(const QByteArray &frame);
    void activity(const QString &text);

private:
    QByteArray makeFrame(quint8 type, quint8 page, quint8 item, quint16 value);
    void sendCommand(quint8 type, quint8 page, quint8 item, int value, const QString &text);
    void appendLog(const QString &text);
    QComboBox *makeValueBox(const QStringList &labels, const QList<int> &values);
    static int comboValue(const QComboBox *box);
    static bool setComboValue(QComboBox *box, int value);
    void addTidalPage();
    void addGreenWavePage();
    void addSinglePage();
    void addCrossPage();
    void addLabPage();
    void sendTidal();
    void sendCross();
    void sendLab();
    void readAllValues();
    void updateLabMetrics();
    void updateCrossTime(int item, int value);
    bool applyWritableValue(const QString &identifier, int value, bool fromCloud);

    QComboBox *m_pageBox = nullptr;
    QStackedWidget *m_pages = nullptr;
    QLabel *m_serialStatus = nullptr;
    QLabel *m_lastStatus = nullptr;
    QPlainTextEdit *m_log = nullptr;

    QComboBox *m_tidalMode = nullptr;
    QComboBox *m_tidalLeft = nullptr;
    QComboBox *m_tidalRight = nullptr;
    QCheckBox *m_tidalLock = nullptr;
    QComboBox *m_singleSpeed = nullptr;
    QComboBox *m_crossHorizontal = nullptr;
    QComboBox *m_crossVertical = nullptr;
    QComboBox *m_crossPedestrians = nullptr;
    QComboBox *m_crossAdaptive = nullptr;
    QLabel *m_crossTimes[6] = {};
    int m_crossTimeValues[6] = {40, 30, 20, 40, 30, 20};
    QComboBox *m_labGreen = nullptr;
    QComboBox *m_labRed = nullptr;
    QComboBox *m_labLength = nullptr;
    QComboBox *m_labRate = nullptr;
    QComboBox *m_labPhase = nullptr;
    QComboBox *m_labControl = nullptr;
    QLabel *m_labMetrics[6] = {};
    int m_metricAvgDelay = 26;
    int m_metricMaxQueue = 21;
    int m_metricFlow = 520;
    int m_metricOverflow = 18;
    double m_metricStops = 1.8;
    int m_metricQueueNow = 7;
    quint8 m_sequence = 1;
};

#endif
