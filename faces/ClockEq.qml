import QtQuick
import Quickshell
import qs.theme

// The default face, id "clockEq" (name kept as-is - just the file/id, not
// a rename - even though it's plain clock-only now, to avoid churning
// pages/CompactPage.qml's faceOrder/persisted compactFace string for a
// content-only change). Was clock + an EqualizerBars glyph signaling
// "media is here" - dropped per the maintainer: "no need equalizer, just
// clock." The dedicated faces/MediaFace.qml already covers media
// signaling on its own face now, so this one no longer needs to.
Item {
    id: root

    // Unused, but ui/PageHost.qml (reused as-is for faces, not a bespoke
    // host) unconditionally assigns `.payload` on whatever it loads,
    // matching the page contract it was actually built for - same
    // "declared but unused" precedent pages/MediaExpanded.qml already sets
    // for a page that doesn't need one either.
    property var payload: null

    implicitWidth: clockText.implicitWidth
    implicitHeight: Theme.compactH

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Text {
        id: clockText
        anchors.centerIn: parent
        color: Theme.ink
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: Font.Medium
        font.letterSpacing: 1
        text: Qt.formatDateTime(clock.date, "hh:mm:ss")
    }
}
