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
    // onTrackKeyChanged handler syntax below is unambiguous.
    readonly property string trackKey: available ? (player.dbusName + "|" + player.trackTitle) : ""

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
            if (root._pastStartupBurst) {
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

    onTrackKeyChanged: {
        position = available ? player.position : 0
        _debounce.restart()
    }
}
