import QtQuick
import QtQuick.Window

Window {
    id: root
    width: content.implicitWidth + 32
    height: 36
    visible: false
    color: "transparent"
    flags: Qt.FramelessWindowHint

    readonly property color ink: "#cdc4ba"
    readonly property color hairline: Qt.rgba(0.804, 0.769, 0.729, 0.2)

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: "#0b0a09"
        border.width: 1
        border.color: root.hairline

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 12

            Text {
                id: clockText
                anchors.verticalCenter: parent.verticalCenter
                color: root.ink
                font.family: "monospace"
                font.pixelSize: 12
                font.letterSpacing: 2
                text: Qt.formatDateTime(new Date(), "hh:mm:ss")

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clockText.text = Qt.formatDateTime(new Date(), "hh:mm:ss")
                }
            }

            Rectangle {
                width: 1
                height: 14
                anchors.verticalCenter: parent.verticalCenter
                color: root.hairline
                visible: titleText.text.length > 0
            }

            Text {
                id: titleText
                anchors.verticalCenter: parent.verticalCenter
                color: root.ink
                font.family: "monospace"
                font.pixelSize: 12
                font.letterSpacing: 1
                text: Niri.focusedWindowTitle
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 320)
            }
        }
    }
}
