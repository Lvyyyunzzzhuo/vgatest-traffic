#ifndef MQTTCLIENT_H
#define MQTTCLIENT_H

#include <QObject>
#include <QByteArray>

class QTcpSocket;
class QTimer;

class MqttClient : public QObject
{
    Q_OBJECT
public:
    explicit MqttClient(QObject *parent = nullptr);
    void connectToHost(const QString &host, quint16 port, bool tls,
                       const QString &clientId, const QString &username,
                       const QString &password);
    void disconnectFromHost();
    bool isConnected() const;
    void subscribe(const QString &topic);
    void publish(const QString &topic, const QByteArray &payload, bool retain = false);

signals:
    void connected();
    void disconnected();
    void errorOccurred(const QString &message);
    void messageReceived(const QString &topic, const QByteArray &payload);

private slots:
    void socketConnected();
    void readSocket();
    void socketDisconnected();
    void socketError();
    void sendPing();

private:
    static QByteArray mqttString(const QByteArray &text);
    static QByteArray remainingLength(int value);
    void sendPacket(quint8 header, const QByteArray &body);
    void parsePackets();
    void sendConnectPacket();

    QTcpSocket *m_socket = nullptr;
    QTimer *m_keepAlive = nullptr;
    QByteArray m_buffer;
    QString m_clientId;
    QString m_username;
    QString m_password;
    quint16 m_packetId = 1;
    bool m_mqttConnected = false;
};

#endif
