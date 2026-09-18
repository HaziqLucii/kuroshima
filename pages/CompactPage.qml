import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.ui

Item {
    id: root

    // Page contract (docs/HANDOFF.md): implicitWidth/Height + payload.
    property var payload: null
    signal requestExpand(string pageId)
    // Page contract addition: per-state radius (design's IDLE state, r15).
    readonly property real cornerRadius: 15

    implicitWidth: content.implicitWidth + 28
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

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 11

        Text {
            id: clockText
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
            visible: Media.available
        }

        // Matches the design's real compact/idle pill: no title/artist
        // text at all (that only appears in the expanded media section),
        // just this animated EQ glyph signaling "media is here, and
        // whether it's playing". Haziq specifically called this out as his
        // favorite piece of the design after seeing the title/artist
        // version this project had built before.
        EqualizerBars {
            anchors.verticalCenter: parent.verticalCenter
            visible: Media.available
            active: Media.isPlaying
            barHeight: 11
        }
    }

    // Compact is where the now-playing marquee actually lives most of the
    // time (MediaPeek is only a brief transient right when a track
    // changes), so this is the natural place to click to see the full
    // media view, not just during that narrow window.
    TapHandler {
        enabled: Media.available
        onTapped: root.requestExpand("MediaExpanded")
    }
}
