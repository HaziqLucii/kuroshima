pragma Singleton
import QtQuick
import Quickshell.Io

// This desktop has no laptop backlight (no /sys/class/backlight), but the
// external monitor supports DDC/CI over I2C (`ddcutil`), confirmed working:
// `ddcutil detect` finds it, and getvcp/setvcp both round-trip correctly.
// The catch, and the reason this was originally skipped entirely for the
// CONTROLS section: every single ddcutil call measured ~8s on this
// hardware/monitor combo (consistent to the tenth of a second across
// repeated tests - reads like a fixed retry/backoff policy on ddcutil's
// own side more than raw I2C latency). Haziq decided the delay is fine for
// a "set and let it catch up" control (he sees the same lag setting it
// from KDE), so this backs a commit-on-release slider
// (ui/ScrubBar.qml's scrubFinished, not the continuous scrub signal VOL/
// MIC use) rather than a live-drag one - the exact same latency-avoidance
// pattern already used for media seeking.
QtObject {
    id: root

    // 0..1; -1 until the first real read completes. Not "~8s after
    // startup": Quickshell singletons are lazy, and nothing in the
    // always-loaded tree (shell.qml -> IslandWindow -> Capsule -> Bridges)
    // references this service - only pages/MediaExpanded.qml does, which
    // is only instantiated on demand. The first real ddcutil read (and the
    // ~8s wait for it) happens on the first expand to MediaExpanded, not
    // at launch; this singleton itself survives after that, so only the
    // very first expand pays it.
    property real value: -1

    // Not re-confirmed via a fresh read after every set: doing a
    // set-then-verify round trip would double every adjustment from ~8s to
    // ~16s. Trusts the optimistic value; a silently-failed setvcp (rare on
    // a working DDC/CI link) would leave this briefly wrong until the next
    // real interaction - an accepted tradeoff given how much worse
    // doubling the latency would feel for something this slow already.
    function setBrightness(pct) {
        const clamped = Math.max(0, Math.min(100, Math.round(pct)))
        root.value = clamped / 100
        _setProc.command = ["ddcutil", "setvcp", "10", String(clamped)]
        _setProc.running = true
    }

    property Process _setProc: Process {}

    property Process _getProc: Process {
        command: ["ddcutil", "getvcp", "10", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Real observed format: "VCP 10 C <current> <max>"
                const parts = text.trim().split(/\s+/)
                const current = parseInt(parts[3])
                const max = parseInt(parts[4])
                if (!isNaN(current) && !isNaN(max) && max > 0) {
                    root.value = current / max
                }
            }
        }
        Component.onCompleted: running = true
    }
}
