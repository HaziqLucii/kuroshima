#include "NiriEventStream.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QDebug>

NiriEventStream::NiriEventStream(QObject *parent)
    : QObject(parent)
{
    connect(&m_socket, &QLocalSocket::connected, this, &NiriEventStream::onConnected);
    connect(&m_socket, &QLocalSocket::readyRead, this, &NiriEventStream::onReadyRead);
    connect(&m_socket, &QLocalSocket::errorOccurred, this, [](QLocalSocket::LocalSocketError) {
        qWarning() << "niri IPC socket error:" << "connection lost or refused";
    });
}

void NiriEventStream::start()
{
    // niri sets this for its own child processes; when spawned via a niri
    // keybind, our process inherits it the same way `niri msg` does.
    const QByteArray path = qgetenv("NIRI_SOCKET");
    if (path.isEmpty()) {
        qWarning() << "NIRI_SOCKET is not set, not running inside niri";
        return;
    }
    m_socket.connectToServer(QString::fromLocal8Bit(path));
}

void NiriEventStream::onConnected()
{
    m_awaitingAck = true;
    m_socket.write("\"EventStream\"\n");
}

void NiriEventStream::onReadyRead()
{
    m_buffer += m_socket.readAll();

    int newlineIndex;
    while ((newlineIndex = m_buffer.indexOf('\n')) != -1) {
        const QByteArray line = m_buffer.left(newlineIndex);
        m_buffer.remove(0, newlineIndex + 1);
        handleLine(line);
    }
}

void NiriEventStream::handleLine(const QByteArray &line)
{
    // First line is the {"Ok":"Handled"} ack for our EventStream request,
    // not an event.
    if (m_awaitingAck) {
        m_awaitingAck = false;
        return;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(line);
    if (!doc.isObject()) {
        return;
    }
    handleEvent(doc.object());
}

void NiriEventStream::handleEvent(const QJsonObject &event)
{
    if (event.contains(QStringLiteral("WindowsChanged"))) {
        m_windowTitles.clear();
        m_focusedWindowId = -1;

        const QJsonArray windows = event.value(QStringLiteral("WindowsChanged")).toObject()
                                        .value(QStringLiteral("windows")).toArray();
        for (const QJsonValue &value : windows) {
            const QJsonObject window = value.toObject();
            const quint64 id = static_cast<quint64>(window.value(QStringLiteral("id")).toDouble());
            m_windowTitles.insert(id, window.value(QStringLiteral("title")).toString());
            if (window.value(QStringLiteral("is_focused")).toBool()) {
                m_focusedWindowId = static_cast<qint64>(id);
            }
        }
        updateFocusedTitle();
    } else if (event.contains(QStringLiteral("WindowOpenedOrChanged"))) {
        const QJsonObject window = event.value(QStringLiteral("WindowOpenedOrChanged")).toObject()
                                        .value(QStringLiteral("window")).toObject();
        const quint64 id = static_cast<quint64>(window.value(QStringLiteral("id")).toDouble());
        m_windowTitles.insert(id, window.value(QStringLiteral("title")).toString());
        if (window.value(QStringLiteral("is_focused")).toBool()) {
            m_focusedWindowId = static_cast<qint64>(id);
        }
        updateFocusedTitle();
    } else if (event.contains(QStringLiteral("WindowClosed"))) {
        const quint64 id = static_cast<quint64>(event.value(QStringLiteral("WindowClosed")).toObject()
                                        .value(QStringLiteral("id")).toDouble());
        m_windowTitles.remove(id);
        if (m_focusedWindowId == static_cast<qint64>(id)) {
            m_focusedWindowId = -1;
        }
        updateFocusedTitle();
    } else if (event.contains(QStringLiteral("WindowFocusChanged"))) {
        const QJsonValue idValue = event.value(QStringLiteral("WindowFocusChanged")).toObject()
                                        .value(QStringLiteral("id"));
        m_focusedWindowId = idValue.isNull() ? -1 : static_cast<qint64>(idValue.toDouble());
        updateFocusedTitle();
    }
}

void NiriEventStream::updateFocusedTitle()
{
    const QString title = (m_focusedWindowId >= 0)
        ? m_windowTitles.value(static_cast<quint64>(m_focusedWindowId))
        : QString();

    if (title != m_focusedWindowTitle) {
        m_focusedWindowTitle = title;
        emit focusedWindowTitleChanged();
    }
}
