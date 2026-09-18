#pragma once

#include <QHash>
#include <QLocalSocket>
#include <QObject>
#include <QString>

class QJsonObject;

// Talks the niri IPC event-stream protocol directly over its Unix socket
// (see niri-ipc/src/socket.rs): newline-delimited JSON, one ack line after
// the "EventStream" request, then one Event object per line forever.
class NiriEventStream : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString focusedWindowTitle READ focusedWindowTitle NOTIFY focusedWindowTitleChanged)

public:
    explicit NiriEventStream(QObject *parent = nullptr);

    QString focusedWindowTitle() const { return m_focusedWindowTitle; }

    void start();

signals:
    void focusedWindowTitleChanged();

private slots:
    void onConnected();
    void onReadyRead();

private:
    void handleLine(const QByteArray &line);
    void handleEvent(const QJsonObject &event);
    void updateFocusedTitle();

    QLocalSocket m_socket;
    QByteArray m_buffer;
    bool m_awaitingAck = true;

    QHash<quint64, QString> m_windowTitles;
    qint64 m_focusedWindowId = -1;
    QString m_focusedWindowTitle;
};
