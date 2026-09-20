import QtQuick
import Quickshell
import qs.theme

// Bundled placeholder widget: proves the widget-canvas mechanics
// (add/move/delete/persist) end to end. Not the "good night" greeting
// widget - that's a separate follow-up once this framework lands.
Item {
    id: root

    // Fixed natural size, deliberately NOT derived from the label below -
    // see the font.pixelSize binding's own comment for why that matters.
    // The host frame (ui/WidgetFrame.qml) fills this item to whatever size
    // it's actually given (this natural size, or a user-resized one);
    // binding width/height here would fight that.
    implicitWidth: 160
    implicitHeight: 40

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: Theme.ink
        font.family: Theme.fontFamily
        // Scales with the box so a resize is actually visible, not just a
        // bigger frame around a still-tiny clock. Deliberately derived from
        // root.width/height, NEVER the other way around (implicitWidth/
        // Height above do not reference this label) - font size affecting
        // its own implicit size would feed back into root's size and back
        // into this binding again, an infinite binding loop.
        font.pixelSize: Math.max(10, Math.min(root.height * 0.4, root.width * 0.12))
        font.letterSpacing: 1
        text: Qt.formatDateTime(clock.date, "hh:mm:ss")
    }
}
