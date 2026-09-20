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

    function toggleMuted() {
        if (!available) return
        sink.audio.muted = !sink.audio.muted
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

    function toggleMicMuted() {
        if (!micAvailable) return
        source.audio.muted = !source.audio.muted
    }

    // Settings > Audio panel: every output/input device and every app's
    // own playback stream, not just the two defaults above. Pipewire.nodes
    // is Quickshell's full live node list (devices AND per-app streams
    // together, undifferentiated) - `.values` is the plain reactive array
    // this can .filter() on, `.type` is a bitflag (PwNodeType.Flag) telling
    // them apart. No app-icon resolution exists in this codebase or in
    // Quickshell.Services.Pipewire itself - `.properties["application.name"]`
    // is the only per-app label available, used as-is.
    //
    // `(n.type & X) !== 0` (any bit overlap) is wrong here, not just
    // imprecise - refuter caught it live against quickshell 0.3.1's real
    // enum values (Audio=1, Stream=4, Sink=16, Source=8, AudioSink=17,
    // AudioSource=9, AudioOutStream=21, AudioInStream=13): every composite
    // shares the Audio bit, so `& AudioSink !== 0` matched AudioSource,
    // AudioOutStream, AND AudioInStream too - `sinks` was "every audio
    // node", not sinks. Mask-equality (`& X === X`) requires every bit of
    // X present rather than just one, which is what these actually need;
    // sinks/sources additionally exclude the Stream bit so a stream that
    // happens to share bits with AudioSink/AudioSource can't leak in.
    readonly property var sinks: Pipewire.nodes.values.filter(n =>
        (n.type & PwNodeType.Stream) === 0 && (n.type & PwNodeType.AudioSink) === PwNodeType.AudioSink)
    readonly property var sources: Pipewire.nodes.values.filter(n =>
        (n.type & PwNodeType.Stream) === 0 && (n.type & PwNodeType.AudioSource) === PwNodeType.AudioSource)
    readonly property var appStreams: Pipewire.nodes.values.filter(n =>
        (n.type & PwNodeType.AudioOutStream) === PwNodeType.AudioOutStream)

    function setDefaultSink(node) {
        Pipewire.preferredDefaultAudioSink = node
    }

    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node
    }

    // Fires after Motion.debounceOsd once volume/muted settles, and only
    // once Pipewire itself has been ready for 500ms: without this gate,
    // enumerating existing devices at startup fires a burst of volume
    // changes that would otherwise each pop an OSD.
    signal changed()

    property bool _pastStartupBurst: false
    property PwObjectTracker _tracker: PwObjectTracker {
        // Every node whose `.audio` sub-object (volume/muted) this file or
        // the Settings > Audio panel reads needs tracking, not just the 2
        // defaults - the mic slider silently reading zero forever was the
        // original failure mode without this, and it applies identically
        // to every device/app-stream row in sinks/sources/appStreams.
        objects: (root.sink ? [root.sink] : [])
            .concat(root.source ? [root.source] : [])
            .concat(root.sinks)
            .concat(root.sources)
            .concat(root.appStreams)
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
