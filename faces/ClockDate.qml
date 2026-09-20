import QtQuick
import Quickshell
import qs.theme

// Face id "clockDate" - clock plus a short date, no media/notification
// awareness at all (that's what faces/ClockEq.qml and the shared bell
// indicator in pages/CompactPage.qml are for). A short built-in
// Qt.formatDateTime cut, not MediaExpanded.qml's own "DAY · DATE" ceremonial
// format - that one's sized for the expanded header, this needs to read at a
// glance in a small pill.
Item {
    id: root

    // Unused - see faces/ClockEq.qml's own comment on why this is here
    // despite the face contract otherwise not needing one.
    property var payload: null

    implicitWidth: content.implicitWidth
    implicitHeight: Theme.compactH

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 11

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            font.letterSpacing: 1
            text: Qt.formatDateTime(clock.date, "hh:mm:ss")
        }

        Rectangle {
            width: 1
            height: 11
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.divider
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.inkFaint
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 1
            text: Qt.formatDateTime(clock.date, "ddd, d MMM").toUpperCase()
        }
    }
}
