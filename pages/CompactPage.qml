import QtQuick
import Quickshell
import qs.theme
import qs.services

Item {
    id: root

    // Page contract (docs/HANDOFF.md): implicitWidth/Height + payload.
    property var payload: null
    signal requestExpand(string pageId)

    implicitWidth: content.implicitWidth + 32
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
        spacing: 10

        Text {
            id: clockText
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.letterSpacing: 1
            text: Qt.formatDateTime(clock.date, "hh:mm:ss")
        }

        Rectangle {
            width: 1
            height: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.hairline
            visible: Media.available
        }

        // No marquee/scroll for a long title in this slice, deliberately:
        // elided and clamped instead. A real marquee is Haziq's
        // design-phase polish, not functional scope.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Media.available
            color: Theme.ink
            opacity: Media.isPlaying ? 1.0 : 0.55
            font.family: Theme.fontFamily
            font.pixelSize: 12
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
