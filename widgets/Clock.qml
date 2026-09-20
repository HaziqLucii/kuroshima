import QtQuick
import Quickshell
import qs.theme

// Bundled placeholder widget: proves the widget-canvas mechanics
// (add/move/delete/persist) end to end. Not the "good night" greeting
// widget - that's a separate follow-up once this framework lands.
Item {
    id: root

    implicitWidth: label.implicitWidth + 24
    implicitHeight: label.implicitHeight + 16
    width: implicitWidth
    height: implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: Theme.ink
        font.family: Theme.fontFamily
        font.pixelSize: 14
        font.letterSpacing: 1
        text: Qt.formatDateTime(clock.date, "hh:mm:ss")
    }
}
