pragma Singleton
import QtQuick
import Quickshell.Io

// Desktop echo of the maintainer's own ~/Projects/kuro-focus "expedition
// timer" - same dossier aesthetic, no sync between the two apps. Slice 2.
// Bare QtObject singleton, same as every other services/*.qml file except
// app/Island.qml (see that file's own comment on why it's the one
// Singleton-rooted exception) - state resets on hot reload and restart,
// not persisted, matching services/Notifs.qml's dnd and
// services/Toggles.qml's idleInhibit from Slice 1.
QtObject {
    id: root

    readonly property var presets: [25, 50, 5] // minutes

    property int totalSeconds: 0
    property int remaining: 0
    property bool running: false
    property string phaseLabel: "FOCUS"

    function start(minutes) {
        root.totalSeconds = minutes * 60
        root.remaining = root.totalSeconds
        root.running = true
        // 5 minutes reads as a break in this presets list (25/50 work, 5
        // short break) - a simple heuristic, not user-configurable.
        root.phaseLabel = minutes === 5 ? "BREAK" : "FOCUS"
    }

    // Doubles as resume - a single glyph in faces/FocusFace.qml swaps
    // between pause/play depending on `running`, same idiom
    // faces/MediaFace.qml's own transport button already uses.
    function pause() {
        if (root.remaining > 0) root.running = !root.running
    }

    function reset() {
        root.running = false
        root.remaining = 0
        root.totalSeconds = 0
        // Only start() otherwise ever writes this - harmless today since
        // the idle state renders a hardcoded "FOCUS" string rather than
        // reading it, but resetting it here means it can't go stale (stay
        // "BREAK" after a break) for whatever reads it next.
        root.phaseLabel = "FOCUS"
    }

    property Timer _tick: Timer {
        interval: 1000
        repeat: true
        running: root.running && root.remaining > 0
        onTriggered: {
            root.remaining -= 1
            if (root.remaining <= 0) {
                root.running = false
                _notifyProc.running = true
            }
        }
    }

    // Lands in INBOX and fires the existing NotificationPeek bridge like
    // any other notification - no new core/Kinds.qml row, no new peek
    // page needed.
    property Process _notifyProc: Process {
        command: ["notify-send", "-a", "kuroshima", "Focus",
            root.phaseLabel === "BREAK" ? "Break's over" : "Session done"]
    }
}
