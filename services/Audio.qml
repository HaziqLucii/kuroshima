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

    // Fires after Motion.debounceOsd once volume/muted settles, and only
    // once Pipewire itself has been ready for 500ms: without this gate,
    // enumerating existing devices at startup fires a burst of volume
    // changes that would otherwise each pop an OSD.
    signal changed()

    property bool _pastStartupBurst: false
    property PwObjectTracker _tracker: PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    property Timer _startupGate: Timer {
        interval: 500
        running: Pipewire.ready
        repeat: false
        onTriggered: root._pastStartupBurst = true
    }

    property Timer _debounce: Timer {
        interval: Motion.debounceOsd
        repeat: false
        onTriggered: {
            if (root._pastStartupBurst) {
                root.changed()
            }
        }
    }

    onVolumeChanged: _debounce.restart()
    onMutedChanged: _debounce.restart()
}
