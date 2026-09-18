import QtQuick
import Quickshell
import qs.theme
import qs.services

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

        // No marquee/scroll for a long title in this slice, deliberately:
        // elided and clamped instead. A real marquee is Haziq's
        // design-phase polish, not functional scope.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Media.available
            color: Media.isPlaying ? Theme.ink : Theme.inkFaint
            font.family: Theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 160)
            text: Media.artist ? (Media.artist + " · " + Media.title) : Media.title
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
