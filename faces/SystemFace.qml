import QtQuick
import qs.theme
import qs.services

// Face id "systemFace". Slice 1. CPU / MEM / TEMP as three tabular-number
// cells with a 1px hairline mini-bar under each, same visual shape as
// pages/MediaExpanded.qml's own "05 SYSTEM" section, just compact-pill
// sized. Read-only, no handlers. A cell hides itself when its value is
// unavailable, same rule SystemStats.qml's own -1/"" sentinel already
// backs in MediaExpanded.
Item {
    id: root

    // Unused - see faces/ClockEq.qml's own comment on why this is here
    // despite the face contract otherwise not needing one.
    property var payload: null

    implicitWidth: content.width
    implicitHeight: content.height + 16

    Row {
        id: content
        anchors.centerIn: parent
        width: 180
        spacing: 14

        Column {
            width: (parent.width - 2 * 14) / 3
            spacing: 5
            visible: SystemStats.cpuPercent >= 0

            Item {
                width: parent.width
                height: cpuValue.implicitHeight
                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; color: Theme.inkFaint; font.family: Theme.fontFamily; font.pixelSize: 8; font.letterSpacing: 1; text: "CPU" }
                Text { id: cpuValue; anchors.right: parent.right; color: Theme.ink; font.family: Theme.fontFamily; font.pixelSize: 11; text: SystemStats.cpuPercent + "%" }
            }
            Rectangle {
                width: parent.width; height: 2; color: Theme.trackBg
                Rectangle { width: parent.width * Math.min(1, SystemStats.cpuPercent / 100); height: parent.height; color: Qt.rgba(1, 1, 1, 0.45) }
            }
        }

        Column {
            width: (parent.width - 2 * 14) / 3
            spacing: 5
            visible: SystemStats.memPercent >= 0

            Item {
                width: parent.width
                height: memValue.implicitHeight
                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; color: Theme.inkFaint; font.family: Theme.fontFamily; font.pixelSize: 8; font.letterSpacing: 1; text: "MEM" }
                Text { id: memValue; anchors.right: parent.right; color: Theme.ink; font.family: Theme.fontFamily; font.pixelSize: 11; text: SystemStats.memPercent + "%" }
            }
            Rectangle {
                width: parent.width; height: 2; color: Theme.trackBg
                Rectangle { width: parent.width * Math.min(1, SystemStats.memPercent / 100); height: parent.height; color: Qt.rgba(1, 1, 1, 0.45) }
            }
        }

        Column {
            width: (parent.width - 2 * 14) / 3
            spacing: 5
            visible: SystemStats.tempCelsius >= 0

            Item {
                width: parent.width
                height: tempValue.implicitHeight
                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; color: Theme.inkFaint; font.family: Theme.fontFamily; font.pixelSize: 8; font.letterSpacing: 1; text: "TEMP" }
                Text { id: tempValue; anchors.right: parent.right; color: Theme.ink; font.family: Theme.fontFamily; font.pixelSize: 11; text: SystemStats.tempCelsius + "°C" }
            }
            Rectangle {
                width: parent.width; height: 2; color: Theme.trackBg
                // 90C as the top of the bar, not 100 - same reasoning as
                // MediaExpanded.qml's own TEMP cell: a "full" reading well
                // below the real throttle point makes the bar useless as
                // an at-a-glance signal.
                Rectangle { width: parent.width * Math.min(1, SystemStats.tempCelsius / 90); height: parent.height; color: Qt.rgba(1, 1, 1, 0.45) }
            }
        }
    }
}
