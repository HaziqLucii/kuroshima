import QtQuick
import qs.theme
import qs.services

// No payload needed: reads the live services/Battery.qml singleton
// directly, same pattern as WorkspacePeek/NotificationPeek/MediaExpanded.
// Real caveat, expected: this is a desktop (no battery hardware at all),
// so Battery.available reads false permanently here - this page is built
// for correctness/portability and is only reachable via the demo/IPC path
// on this machine, matching the plan's own expectation.
Item {
    id: root

    property var payload: null
    // Declared but unused: present so ui/Capsule.qml's generic
    // Connections to whatever page is current doesn't warn about a
    // missing signal every time this page is shown.
    signal requestExpand(string pageId)
    readonly property real cornerRadius: Theme.radius

    readonly property string timeLabel: {
        const secs = Battery.charging ? Battery.timeToFull : Battery.timeToEmpty
        if (!secs || secs <= 0) return ""
        const h = Math.floor(secs / 3600)
        const m = Math.floor((secs % 3600) / 60)
        return h > 0 ? (h + "H " + m + "M") : (m + "M")
    }

    implicitWidth: Theme.batteryW
    implicitHeight: Theme.peekH
    width: implicitWidth
    height: implicitHeight

    Row {
        anchors.centerIn: parent
        spacing: 11

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.inkFaint
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.letterSpacing: 2
            text: Battery.charging ? "CHARGING" : "BATTERY"
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 10
            radius: 1
            color: "transparent"
            border.width: 1
            border.color: Theme.divider

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 1
                width: (parent.width - 2) * Math.max(0, Math.min(1, Battery.percentage / 100))
                color: Theme.ink
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 11
            text: Math.round(Battery.percentage) + "%"
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.timeLabel !== ""
            color: Theme.inkSubtle
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.letterSpacing: 1
            text: root.timeLabel
        }
    }
}
