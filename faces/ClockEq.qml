import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.ui

// The default face, id "clockEq" - byte-for-byte the same content
// pages/CompactPage.qml always showed before Island Faces existed. First in
// the list (see faces/ClockDate.qml, faces/MediaFace.qml for the others).
Item {
    id: root

    // Unused, but ui/PageHost.qml (reused as-is for faces, not a bespoke
    // host) unconditionally assigns `.payload` on whatever it loads,
    // matching the page contract it was actually built for - same
    // "declared but unused" precedent pages/MediaExpanded.qml already sets
    // for a page that doesn't need one either.
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
            // Media.isPlaying, not Media.available: a paused-but-loaded
            // player (e.g. a YouTube tab tabbed away from) shouldn't leave
            // this divider (and a static EQ) stuck on screen indefinitely.
            visible: Media.isPlaying
        }

        // No title/artist text here on purpose - that's faces/MediaFace.qml's
        // job now. This face signals "media is here, and whether it's
        // playing" only, via the EQ glyph alone.
        EqualizerBars {
            anchors.verticalCenter: parent.verticalCenter
            visible: Media.isPlaying
            active: Media.isPlaying
            barHeight: 11
        }
    }
}
