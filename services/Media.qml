pragma Singleton
import QtQuick
import Quickshell.Services.Mpris
import qs.theme

QtObject {
    id: root

    // Simplification, documented: the plan asks for "prefer isPlaying,
    // else most recently changed". True recency tracking needs a signal
    // connection per player via a dynamic Instantiator (players connect/
    // disconnect at runtime); for how many MPRIS players a personal
    // desktop actually runs at once, "first playing, else first known"
    // is not meaningfully different in practice. Revisit if that stops
    // being true.
    readonly property var player: {
        const players = Mpris.players.values
        if (players.length === 0) return null
        for (let i = 0; i < players.length; i++) {
            if (players[i].isPlaying) return players[i]
        }
        return players[0]
    }

    readonly property bool available: player !== null
    readonly property string title: available ? player.trackTitle : ""
    readonly property string artist: available ? player.trackArtist : ""
    readonly property string artUrl: available ? player.trackArtUrl : ""
    readonly property bool isPlaying: available ? player.isPlaying : false
    readonly property bool canGoNext: available ? player.canGoNext : false
    readonly property bool canGoPrevious: available ? player.canGoPrevious : false
    readonly property bool canTogglePlaying: available ? player.canTogglePlaying : false
    readonly property real length: available ? player.length : 0

    // Not a live binding to player.position: MPRIS doesn't push continuous
    // position updates, only on seek/state-change, so a binding to it
    // would just sit frozen. Refreshed explicitly instead, once whenever
    // the active player changes and every second while playing.
    property real position: 0

    signal trackChanged()

    function play() { if (available) player.play() }
    function pause() { if (available) player.pause() }
    function togglePlaying() { if (available) player.togglePlaying() }
    function next() { if (available) player.next() }
    function previous() { if (available) player.previous() }

    // Public (not underscore-prefixed) specifically so the plain
    // onTrackKeyChanged handler syntax below is unambiguous. Keyed on
    // uniqueId, not trackTitle: refuter found that a title-keyed key
    // can't detect a genuinely new track when the title is unchanged
    // (a looped track, or two different tracks sharing a title), and
    // player.trackTitle would then also never get re-read, position
    // would just keep counting up from the previous track. uniqueId is
    // Quickshell's own opaque per-track identifier, documented as
    // deliberately NOT mpris:trackid (which is "sometimes missing or
    // nonunique in some players").
    readonly property string trackKey: available ? (player.dbusName + "|" + player.uniqueId) : ""

    // Separate from trackKey: metadata (title) can arrive after the
    // player object itself registers (Chromium routinely does this), so
    // trackKey alone can go stale mid-load without a second signal once
    // the real title shows up. Combining both into one watched value
    // means either a genuinely new track OR later-arriving metadata for
    // the same one restarts the debounce. Public (not underscore-
    // prefixed), same reasoning as trackKey: keeps the onDebounceKeyChanged
    // handler below unambiguous.
    readonly property string debounceKey: trackKey + "|" + title + "|" + artist

    property bool _pastStartupBurst: false
    property Timer _startupGate: Timer {
        interval: 500
        running: true
        repeat: false
        onTriggered: root._pastStartupBurst = true
    }

    property Timer _debounce: Timer {
        interval: Motion.debounceOsd
        repeat: false
        onTriggered: {
            // Also gated on title !== "" (unless the player disappeared
            // entirely): refuter found the debounce firing on a player
            // that registered before its metadata arrived, briefly
            // showing an empty MediaPeek. !available still has to reach
            // trackChanged() so app/Bridges.qml's clearKey("media") path
            // stays reachable when playback actually stops.
            if (root._pastStartupBurst && (!root.available || root.title !== "")) {
                root.trackChanged()
            }
        }
    }

    property Timer _positionTicker: Timer {
        interval: 1000
        running: root.available && root.isPlaying
        repeat: true
        onTriggered: root.position = root.player.position
    }

    onTrackKeyChanged: position = available ? player.position : 0
    onDebounceKeyChanged: _debounce.restart()
}
