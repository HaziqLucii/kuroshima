import QtQuick
import Quickshell
import qs.theme

// Bundled placeholder widget: proves the widget-canvas mechanics
// (add/move/delete/persist) end to end. Not the "good night" greeting
// widget - that's a separate follow-up once this framework lands.
Item {
    id: root

    // implicitWidth/Height only - no width/height binding. The host frame
    // (ui/WidgetFrame.qml) fills this item to whatever size it's actually
    // given (natural or user-resized); binding width/height here would
    // fight that. anchors.centerIn on the label below is what makes this
    // widget adapt reasonably to a resize instead of just sitting in a
    // corner of a bigger box.
    implicitWidth: label.implicitWidth + 24
    implicitHeight: label.implicitHeight + 16

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
