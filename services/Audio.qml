pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire
import qs.theme

QtObject {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool available: sink !== null && sink.ready && sink.audio !== null
    readonly property real volume: available ? sink.audio.volume : 0
    readonly property bool muted: available ? sink.audio.muted : false

    function setVolume(pct) {
        if (!available) return
        sink.audio.volume = Math.max(0, Math.min(1, pct / 100))
    }

    // Mic: same shape as the sink above, but the input device. No OSD/
    // debounce/changed() signal for it (nothing currently pops a peek on
    // mic volume changing), it's read for the expanded view's CONTROLS
    // section only.
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micAvailable: source !== null && source.ready && source.audio !== null
    readonly property real micVolume: micAvailable ? source.audio.volume : 0
    readonly property bool micMuted: micAvailable ? source.audio.muted : false

    function setMicVolume(pct) {
        if (!micAvailable) return
        source.audio.volume = Math.max(0, Math.min(1, pct / 100))
    }

    // Fires after Motion.debounceOsd once volume/muted settles, and only
    // once Pipewire itself has been ready for 500ms: without this gate,
    // enumerating existing devices at startup fires a burst of volume
    // changes that would otherwise each pop an OSD.
    signal changed()

    property bool _pastStartupBurst: false
    property PwObjectTracker _tracker: PwObjectTracker {
        // Both sink and source need tracking for their `.audio` sub-object
        // (volume/muted) to actually populate; the mic slider silently
        // reading zero forever was the failure mode without this.
        objects: (root.sink ? [root.sink] : []).concat(root.source ? [root.source] : [])
    }

    property Timer _startupGate: Timer {
        interval: 500
        running: Pipewire.ready
        repeat: false
        onTriggered: root._pastStartupBurst = true
    }

    // Re-arms the gate on a real Pipewire reconnect (pipewire/wireplumber
    // restart): readyChanged going false->true restarts _startupGate
    // (its `running: Pipewire.ready` binding), but without also resetting
    // this flag, it was already true from the first launch, so the
    // re-enumeration burst that follows a reconnect wasn't suppressed at
    // all.
    property Connections _pipewireReadiness: Connections {
        target: Pipewire
        function onReadyChanged() {
            if (!Pipewire.ready) {
                root._pastStartupBurst = false
            }
        }
    }

    property Timer _debounce: Timer {
        interval: Motion.debounceOsd
        repeat: false
        onTriggered: {
            // Also gated on `available`: losing the sink (unplugged,
            // switched, not yet bound) synthesizes volume/muted defaults
            // above, and firing changed() on that synthetic value would
            // pop an OSD reporting a volume change that never happened.
            if (root._pastStartupBurst && root.available) {
                root.changed()
            }
        }
    }

    onVolumeChanged: _debounce.restart()
    onMutedChanged: _debounce.restart()
}
