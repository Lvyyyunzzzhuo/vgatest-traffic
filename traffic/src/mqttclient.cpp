#include "mqttclient.h"

#include <QAbstractSocket>
#include <QSslError>
#include <QSslSocket>
#include <QTcpSocket>
#include <QTimer>

MqttClient::MqttClient(QObject *parent) : QObject(parent)
{
    m_keepAlive = new QTimer(this);
    m_keepAlive->setInterval(25000);
    connect(m_keepAlive, &QTimer::timeout, this, &MqttClient::sendPing);
}

QByteArray MqttClient::mqttString(const QByteArray &text)
{
    QByteArray out;
    out.append(char((text.size() >> 8) & 0xff));
    out.append(char(text.size() & 0xff));
    out.append(text);
    return out;
}

QByteArray MqttClient::remainingLength(int value)
{
    QByteArray out;
    do {
        int digit = value % 128;
        value /= 128;
        if (value > 0) digit |= 0x80;
        out.append(char(digit));
    } while (value > 0);
    return out;
}

void MqttClient::connectToHost(const QString &host, quint16 port, bool tls,
                               const QString &clientId, const QString &username,
                               const QString &password)
{
    disconnectFromHost();
    m_clientId = clientId;
    m_username = username;
    m_password = password;
    m_mqttConnected = false;
    m_buffer.clear();

    if (tls) {
        auto *ssl = new QSslSocket(this);
        m_socket = ssl;
        connect(ssl, &QSslSocket::encrypted, this, &MqttClient::socketConnected);
        connect(ssl, &QSslSocket::sslErrors, this, [this](const QList<QSslError> &errors) {
            QStringList messages;
            for (const QSslError &error : errors) messages << error.errorString();
            emit errorOccurred(QStringLiteral("TLS 证书错误：%1").arg(messages.join(QStringLiteral("；"))));
        });
        ssl->connectToHostEncrypted(host, port);
    } else {
        m_socket = new QTcpSocket(this);
        connect(m_socket, &QTcpSocket::connected, this, &MqttClient::socketConnected);
        m_socket->connectToHost(host, port);
    }
    connect(m_socket, &QTcpSocket::readyRead, this, &MqttClient::readSocket);
    connect(m_socket, &QTcpSocket::disconnected, this, &MqttClient::socketDisconnected);
    connect(m_socket, &QTcpSocket::errorOccurred, this, &MqttClient::socketError);
}

void MqttClient::disconnectFromHost()
{
    m_keepAlive->stop();
    m_mqttConnected = false;
    if (!m_socket) return;
    if (m_socket->state() == QAbstractSocket::ConnectedState)
        sendPacket(0xe0, QByteArray());
    m_socket->disconnect(this);
    m_socket->disconnectFromHost();
    m_socket->deleteLater();
    m_socket = nullptr;
}

bool MqttClient::isConnected() const { return m_mqttConnected; }

void MqttClient::socketConnected() { sendConnectPacket(); }

void MqttClient::sendConnectPacket()
{
    QByteArray body;
    body += mqttString("MQTT");
    body.append(char(0x04));
    quint8 flags = 0x02;
    if (!m_username.isEmpty()) flags |= 0x80;
    if (!m_password.isEmpty()) flags |= 0x40;
    body.append(char(flags));
    body.append(char(0));
    body.append(char(60));
    body += mqttString(m_clientId.toUtf8());
    if (!m_username.isEmpty()) body += mqttString(m_username.toUtf8());
    if (!m_password.isEmpty()) body += mqttString(m_password.toUtf8());
    sendPacket(0x10, body);
}

void MqttClient::sendPacket(quint8 header, const QByteArray &body)
{
    if (!m_socket || m_socket->state() != QAbstractSocket::ConnectedState) return;
    QByteArray packet;
    packet.append(char(header));
    packet += remainingLength(body.size());
    packet += body;
    m_socket->write(packet);
}

void MqttClient::subscribe(const QString &topic)
{
    QByteArray body;
    const quint16 id = m_packetId++;
    body.append(char(id >> 8));
    body.append(char(id & 0xff));
    body += mqttString(topic.toUtf8());
    body.append(char(0));
    sendPacket(0x82, body);
}

void MqttClient::publish(const QString &topic, const QByteArray &payload, bool retain)
{
    sendPacket(retain ? 0x31 : 0x30, mqttString(topic.toUtf8()) + payload);
}

void MqttClient::readSocket()
{
    if (!m_socket) return;
    m_buffer += m_socket->readAll();
    parsePackets();
}

void MqttClient::parsePackets()
{
    while (m_buffer.size() >= 2) {
        int multiplier = 1, length = 0, pos = 1;
        quint8 digit = 0;
        do {
            if (pos >= m_buffer.size() || pos > 4) return;
            digit = quint8(m_buffer.at(pos++));
            length += (digit & 0x7f) * multiplier;
            multiplier *= 128;
        } while (digit & 0x80);
        if (m_buffer.size() < pos + length) return;

        const quint8 header = quint8(m_buffer.at(0));
        const quint8 type = header >> 4;
        const QByteArray body = m_buffer.mid(pos, length);
        m_buffer.remove(0, pos + length);

        if (type == 2) {
            if (body.size() < 2) {
                emit errorOccurred(QStringLiteral("MQTT CONNACK 数据不完整"));
                continue;
            }
            const quint8 result = quint8(body.at(1));
            if (result == 0) {
                m_mqttConnected = true;
                m_keepAlive->start();
                emit connected();
            } else {
                static const QStringList errors = {
                    QStringLiteral("连接成功"), QStringLiteral("协议版本不支持"),
                    QStringLiteral("客户端 ID 被拒绝"), QStringLiteral("服务器不可用"),
                    QStringLiteral("用户名或密码错误"), QStringLiteral("未授权")};
                const QString detail = result < errors.size() ? errors.at(result)
                                                             : QStringLiteral("错误码 %1").arg(result);
                emit errorOccurred(QStringLiteral("OneNET MQTT 登录失败：%1").arg(detail));
            }
        } else if (type == 3) {
            if (body.size() < 2) continue;
            const int topicLength = (quint8(body.at(0)) << 8) | quint8(body.at(1));
            if (body.size() < 2 + topicLength) continue;
            const QString topic = QString::fromUtf8(body.mid(2, topicLength));
            int payloadPos = 2 + topicLength;
            const int qos = (header >> 1) & 0x03;
            quint16 packetId = 0;
            if (qos > 0 && body.size() >= payloadPos + 2) {
                packetId = (quint8(body.at(payloadPos)) << 8) | quint8(body.at(payloadPos + 1));
                payloadPos += 2;
            }
            emit messageReceived(topic, body.mid(payloadPos));
            if (qos == 1) {
                QByteArray ack;
                ack.append(char(packetId >> 8));
                ack.append(char(packetId & 0xff));
                sendPacket(0x40, ack);
            }
        }
    }
}

void MqttClient::socketDisconnected()
{
    const bool notify = m_mqttConnected;
    m_mqttConnected = false;
    m_keepAlive->stop();
    if (notify) emit disconnected();
}

void MqttClient::socketError()
{
    if (m_socket) emit errorOccurred(QStringLiteral("网络连接失败：%1").arg(m_socket->errorString()));
}

void MqttClient::sendPing() { sendPacket(0xc0, QByteArray()); }
