#include "onenetclient.h"
#include "mqttclient.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QJsonDocument>
#include <QMessageAuthenticationCode>
#include <QUrl>

OneNetClient::OneNetClient(QObject *parent) : QObject(parent)
{
    m_mqtt = new MqttClient(this);
    connect(m_mqtt, &MqttClient::connected, this, [this] {
        m_mqtt->subscribe(m_topicPrefix + QStringLiteral("/thing/property/set"));
        m_mqtt->subscribe(m_topicPrefix + QStringLiteral("/thing/property/get"));
        m_mqtt->subscribe(m_topicPrefix + QStringLiteral("/thing/service/+/invoke"));
        emit statusChanged(QStringLiteral("OneNET 已连接，正在同步数据"), false);
        emit connected();
    });
    connect(m_mqtt, &MqttClient::disconnected, this, [this] {
        emit statusChanged(QStringLiteral("OneNET 已断开"), true);
        emit disconnected();
    });
    connect(m_mqtt, &MqttClient::errorOccurred, this,
            [this](const QString &text) { emit statusChanged(text, true); });
    connect(m_mqtt, &MqttClient::messageReceived,
            this, &OneNetClient::handleMessage);
}

void OneNetClient::connectCloud(const QString &host, quint16 port, bool tls,
                                const QString &productId, const QString &deviceName,
                                const QString &accessKeyOrToken)
{
    m_productId = productId.trimmed();
    m_deviceName = deviceName.trimmed();
    m_topicPrefix = QStringLiteral("$sys/%1/%2").arg(m_productId, m_deviceName);
    const QString input = accessKeyOrToken.trimmed();
    const QString password = input.startsWith(QStringLiteral("version=")) ? input : createToken(input);
    emit statusChanged(QStringLiteral("正在连接 OneNET..."), false);
    m_mqtt->connectToHost(host.trimmed(), port, tls, m_deviceName, m_productId, password);
}

void OneNetClient::disconnectCloud() { m_mqtt->disconnectFromHost(); }
bool OneNetClient::isConnected() const { return m_mqtt->isConnected(); }

QString OneNetClient::createToken(const QString &accessKey) const
{
    const QString version = QStringLiteral("2018-10-31");
    const QString method = QStringLiteral("sha256");
    const QString resource = QStringLiteral("products/%1/devices/%2").arg(m_productId, m_deviceName);
    const qint64 expiry = QDateTime::currentSecsSinceEpoch() + 30LL * 24 * 3600;
    QByteArray key = QByteArray::fromBase64(accessKey.toUtf8());
    if (key.isEmpty()) key = accessKey.toUtf8();
    const QByteArray source = QStringLiteral("%1\n%2\n%3\n%4")
            .arg(expiry).arg(method, resource, version).toUtf8();
    const QByteArray signature = QMessageAuthenticationCode::hash(
                source, key, QCryptographicHash::Sha256).toBase64();
    return QStringLiteral("version=%1&res=%2&et=%3&method=%4&sign=%5")
            .arg(version,
                 QString::fromLatin1(QUrl::toPercentEncoding(resource)),
                 QString::number(expiry), method,
                 QString::fromLatin1(QUrl::toPercentEncoding(QString::fromLatin1(signature))));
}

QString OneNetClient::nextMessageId() { return QString::number(m_messageId++); }

void OneNetClient::publishProperties(const QJsonObject &properties)
{
    m_lastProperties = properties;
    if (!isConnected()) return;
    QJsonObject params;
    for (auto it = properties.begin(); it != properties.end(); ++it)
        params.insert(it.key(), QJsonObject{{QStringLiteral("value"), it.value()}});
    const QJsonObject root{{QStringLiteral("id"), nextMessageId()},
                           {QStringLiteral("version"), QStringLiteral("1.0")},
                           {QStringLiteral("params"), params}};
    m_mqtt->publish(m_topicPrefix + QStringLiteral("/thing/property/post"),
                    QJsonDocument(root).toJson(QJsonDocument::Compact));
}

void OneNetClient::publishReply(const QString &topic, const QJsonValue &id, int code,
                                const QString &message, const QJsonObject &data)
{
    QJsonObject root{{QStringLiteral("id"), id}, {QStringLiteral("code"), code},
                     {QStringLiteral("msg"), message}};
    if (!data.isEmpty()) root.insert(QStringLiteral("data"), data);
    m_mqtt->publish(topic, QJsonDocument(root).toJson(QJsonDocument::Compact));
}

void OneNetClient::handleMessage(const QString &topic, const QByteArray &payload)
{
    QJsonParseError error;
    const QJsonDocument document = QJsonDocument::fromJson(payload, &error);
    if (error.error != QJsonParseError::NoError || !document.isObject()) {
        emit statusChanged(QStringLiteral("收到无法解析的 OneNET 指令"), true);
        return;
    }
    const QJsonObject root = document.object();
    const QJsonValue id = root.value(QStringLiteral("id"));

    if (topic.endsWith(QStringLiteral("/thing/property/set"))) {
        const QJsonObject params = root.value(QStringLiteral("params")).toObject();
        for (auto it = params.begin(); it != params.end(); ++it) {
            QJsonValue value = it.value();
            if (value.isObject() && value.toObject().contains(QStringLiteral("value")))
                value = value.toObject().value(QStringLiteral("value"));
            emit propertySet(it.key(), value);
        }
        publishReply(m_topicPrefix + QStringLiteral("/thing/property/set/reply"),
                     id, 0, QStringLiteral("success"));
        emit statusChanged(QStringLiteral("已执行 OneNET 参数下发"), false);
        return;
    }

    if (topic.endsWith(QStringLiteral("/thing/property/get"))) {
        QJsonObject data;
        for (auto it = m_lastProperties.begin(); it != m_lastProperties.end(); ++it)
            data.insert(it.key(), QJsonObject{{QStringLiteral("value"), it.value()}});
        publishReply(m_topicPrefix + QStringLiteral("/thing/property/get/reply"),
                     id, 0, QStringLiteral("success"), data);
        return;
    }

    const QString marker = QStringLiteral("/thing/service/");
    const int markerPos = topic.indexOf(marker);
    if (markerPos >= 0 && topic.endsWith(QStringLiteral("/invoke"))) {
        const int begin = markerPos + marker.size();
        const QString identifier = topic.mid(begin, topic.size() - begin - 7);
        int value = 1;
        const QJsonObject params = root.value(QStringLiteral("params")).toObject();
        if (!params.isEmpty()) {
            QJsonValue first = params.begin().value();
            if (first.isObject()) first = first.toObject().value(QStringLiteral("value"));
            value = first.toInt(1);
        }
        emit serviceInvoked(identifier, value);
        publishReply(m_topicPrefix + QStringLiteral("/thing/service/%1/invoke/reply").arg(identifier),
                     id, 0, QStringLiteral("success"));
        emit statusChanged(QStringLiteral("已执行云端服务：%1").arg(identifier), false);
    }
}
