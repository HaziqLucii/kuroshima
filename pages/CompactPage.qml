import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.ui

Item {
    id: root

    // Page contract (docs/NOTES.md): implicitWidth/Height + payload.
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
            // Media.isPlaying, not Media.available: a paused-but-loaded
            // player (e.g. a YouTube tab you tabbed away from) used to
            // leave the divider (and a static EQ) stuck on screen
            // indefinitely. Haziq wanted the pill to collapse back to
            // clock-only the instant playback actually stops, not just
            // when the player disappears entirely.
            visible: Media.isPlaying
        }

        // Matches the design's real compact/idle pill: no title/artist
        // text at all (that only appears in the expanded media section),
        // just this animated EQ glyph signaling "media is here, and
        // whether it's playing". Haziq specifically called this out as his
        // favorite piece of the design after seeing the title/artist
        // version this project had built before.
        EqualizerBars {
            anchors.verticalCenter: parent.verticalCenter
            visible: Media.isPlaying
            active: Media.isPlaying
            barHeight: 11
        }

        Rectangle {
            width: 1
            height: 11
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.divider
            visible: Notifs.history.length > 0
        }

        // Same "gone when there's genuinely nothing to show" pattern as
        // the media divider/EQ above. "Unread" here just means "history
        // isn't empty" - there's no separate read/unread tracking
        // anywhere else in this project, and CLEAR ALL in the expanded
        // INBOX (Notifs.clearHistory()) is the only thing that empties
        // it, so that's also what makes this disappear. A single icon,
        // not a separate bell+counter-bubble pair: cod-bell_dot already
        // draws the "unread" indicator as a dot on the bell's own
        // top-right corner - codepoint verified against this font's
        // actual cmap via fontTools, then visually confirmed against two
        // other bell-badge candidates before picking this one.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifs.history.length > 0
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 13
            text: String.fromCodePoint(0xeb9a)
        }
    }

    // MediaExpanded stopped being just the media view once CONTROLS,
    // TOGGLES, SYSTEM, INBOX and SESSION landed - it's the whole
    // dashboard now, useful with or without anything playing. Gating this
    // on Media.available (an early-slice leftover from when it really was
    // media-only) made the compact pill silently unclickable whenever no
    // player was active, which is most of the time.
    TapHandler {
        onTapped: root.requestExpand("MediaExpanded")
    }
}
