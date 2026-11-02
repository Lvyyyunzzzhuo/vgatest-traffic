#ifndef ONENETCLIENT_H
#define ONENETCLIENT_H

#include <QObject>
#include <QJsonObject>

class MqttClient;

class OneNetClient : public QObject
{
    Q_OBJECT
public:
    explicit OneNetClient(QObject *parent = nullptr);
    void connectCloud(const QString &host, quint16 port, bool tls,
                      const QString &productId, const QString &deviceName,
                      const QString &accessKeyOrToken);
    void disconnectCloud();
    bool isConnected() const;
    void publishProperties(const QJsonObject &properties);

signals:
    void connected();
    void disconnected();
    void statusChanged(const QString &text, bool error);
    void propertySet(const QString &identifier, const QJsonValue &value);
    void serviceInvoked(const QString &identifier, int value);

private:
    QString createToken(const QString &accessKey) const;
    void handleMessage(const QString &topic, const QByteArray &payload);
    void publishReply(const QString &topic, const QJsonValue &id, int code,
                      const QString &message, const QJsonObject &data = QJsonObject());
    QString nextMessageId();

    MqttClient *m_mqtt = nullptr;
    QString m_productId;
    QString m_deviceName;
    QString m_topicPrefix;
    quint64 m_messageId = 1;
    QJsonObject m_lastProperties;
};

#endif
