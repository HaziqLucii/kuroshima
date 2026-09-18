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
    //
    // It stopped being true: a browser tab shows up as TWO simultaneously
    // "isPlaying" players at once (confirmed live via `playerctl -l`) -
    // the browser's own raw MPRIS handle (`chromium.instanceNNNN`) and
    // Plasma's browser-integration extension (`plasma-browser-integration`)
    // both mirror the same tab. The raw handle's artUrl is just a generic
    // per-session icon (literally the Chrome logo, in a temp file), not the
    // actual video thumbnail; plasma-browser-integration exists
    // specifically to supply richer per-tab metadata for exactly this
    // reason, so it wins whenever both are live.
    readonly property var player: {
        const players = Mpris.players.values
        if (players.length === 0) return null

        const playing = players.filter(p => p.isPlaying)
        if (playing.length === 0) return players[0]

        const integrated = playing.find(p => p.dbusName.includes("plasma-browser-integration"))
        return integrated || playing[0]
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

    // MPRIS has no explicit "this is a live stream" flag, and players
    // signal an unknown/live duration inconsistently: confirmed live on a
    // YouTube livestream, Chromium's own raw MPRIS handle reports the
    // documented sentinel for "unknown length" (int64 max microseconds,
    // ~292471 years), while plasma-browser-integration (preferred above
    // for richer metadata) instead reports some arbitrary large placeholder
    // (13 hours, that same stream) rather than the sentinel or 0. Matching
    // both without hardcoding either convention: no real track/video runs
    // longer than a few hours, so anything past this threshold isn't a
    // real duration regardless of which sentinel (or non-sentinel) a given
    // player used to say so.
    readonly property bool isLive: available && length > 4 * 60 * 60

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
