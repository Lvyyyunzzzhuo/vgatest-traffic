#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QByteArray>
#include <QMainWindow>
#include <QQueue>

class QCheckBox;
class QComboBox;
class QLabel;
class QLineEdit;
class QPushButton;
class QSerialPort;
class QSpinBox;
class QTimer;
class OneNetClient;
class TrafficControlPanel;

class MainWindow : public QMainWindow
{
    Q_OBJECT
public:
    explicit MainWindow(QWidget *parent = nullptr);
    ~MainWindow() override;

private slots:
    void scanSerialPorts();
    void toggleSerial();
    void readSerial();
    void toggleCloud();
    void publishCloudState();

private:
    void buildUi();
    void loadCloudSettings();
    void saveCloudSettings();
    void processTrafficFrames();
    void writeSerialFrame(const QByteArray &frame);
    void pumpSerialQueue();
    void finishSerialFrame(const QByteArray &frame);
    void serialFrameTimeout();
    void setCloudStatus(const QString &text, bool error);

    QSerialPort *m_serial = nullptr;
    QByteArray m_protocolBuffer;
    QByteArray m_asciiBuffer;
    QQueue<QByteArray> m_serialQueue;
    QByteArray m_serialInFlight;
    int m_serialRetries = 0;
    QComboBox *m_serialBox = nullptr;
    QPushButton *m_serialButton = nullptr;
    QLabel *m_serialDetail = nullptr;

    OneNetClient *m_oneNet = nullptr;
    QLineEdit *m_hostEdit = nullptr;
    QSpinBox *m_portSpin = nullptr;
    QCheckBox *m_tlsCheck = nullptr;
    QLineEdit *m_productEdit = nullptr;
    QLineEdit *m_deviceEdit = nullptr;
    QLineEdit *m_keyEdit = nullptr;
    QPushButton *m_cloudButton = nullptr;
    QLabel *m_cloudStatus = nullptr;
    QTimer *m_publishTimer = nullptr;

    TrafficControlPanel *m_trafficPanel = nullptr;
};

#endif
