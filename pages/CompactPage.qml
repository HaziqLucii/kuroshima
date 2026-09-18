import QtQuick
import Quickshell
import qs.theme

Item {
    id: root

    // Page contract (docs/HANDOFF.md): implicitWidth/Height + payload.
    property var payload: null

    implicitWidth: clockText.implicitWidth + 32
    implicitHeight: Theme.compactH
    // Plain Item doesn't self-size from implicitWidth/Height the way a
    // Control does; the page contract relies on width/height tracking it
    // so a host can anchor/center against this item directly.
    width: implicitWidth
    height: implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Text {
        id: clockText
        anchors.centerIn: parent
        color: Theme.ink
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.letterSpacing: 1
        text: Qt.formatDateTime(clock.date, "hh:mm:ss")
    }
}
