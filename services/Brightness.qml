pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// This desktop has no laptop backlight (no /sys/class/backlight), but the
// external monitor supports DDC/CI over I2C (`ddcutil`), confirmed working:
// `ddcutil detect` finds it, and getvcp/setvcp both round-trip correctly.
//
// The ~8s-per-call latency this originally shipped with (Haziq: "brightness
// ... comes in late" every time the island restarted) turned out to be pure
// auto-detection overhead, not real DDC/CI protocol latency: measured
// `ddcutil detect --brief` alone at ~8.1s, and `ddcutil getvcp --bus N`
// (skipping detection entirely) at ~0.05s - a ~170x difference, confirmed
// repeatable across several runs, --sleep-multiplier and dynamic-sleep
// flags made no difference at all (ruling out DDC retry/backoff timing as
// the cause). So every read/write after the bus is known should be
// near-instant; only discovering the bus in the first place is slow.
//
// The bus number isn't guaranteed stable across reboots/hardware changes
// (same caution SystemStats.qml already applies to hwmon sensor paths, or
// niri-lockscreen's own "never trust a stale identifier" instinct), so
// it's discovered via `ddcutil detect --brief`, not hardcoded - but unlike
// a hwmon path (rediscovered every launch, cheap), a fresh detect is the
// one genuinely slow step here, so the discovered bus is persisted to
// disk and reused on every future launch. Only the very first run ever
// (or a hardware change invalidating the cached bus) pays the ~8s cost.
QtObject {
    id: root

    property real value: -1
    property string _bus: ""

    // Not re-confirmed via a fresh read after every set: doing a
    // set-then-verify round trip would double every adjustment. Trusts
    // the optimistic value; a silently-failed setvcp (rare on a working
    // DDC/CI link) would leave this briefly wrong until the next real
    // interaction - an accepted tradeoff, cheaper now that a normal
    // adjustment is ~0.1s instead of ~8s, but still not worth doubling.
    function setBrightness(pct) {
        const clamped = Math.max(0, Math.min(100, Math.round(pct)))
        root.value = clamped / 100
        _setProc.command = root._bus !== ""
            ? ["ddcutil", "setvcp", "10", String(clamped), "--bus", root._bus]
            : ["ddcutil", "setvcp", "10", String(clamped)]
        _setProc.running = true
    }

    property Process _setProc: Process {}

    property Process _getProc: Process {
        command: root._bus !== ""
            ? ["ddcutil", "getvcp", "10", "--brief", "--bus", root._bus]
            : ["ddcutil", "getvcp", "10", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Real observed format: "VCP 10 C <current> <max>"
                const parts = text.trim().split(/\s+/)
                const current = parseInt(parts[3])
                const max = parseInt(parts[4])
                if (!isNaN(current) && !isNaN(max) && max > 0) {
                    root.value = current / max
                } else if (root._bus !== "") {
                    // A cached bus that no longer works (monitor moved to
                    // a different port, cable swapped, etc.) - drop it
                    // and fall back to a fresh detect rather than staying
                    // silently broken until someone notices and manually
                    // clears the cache file.
                    root._bus = ""
                    root._busDiscoverProc.running = true
                }
            }
        }
    }

    property FileView _busCache: FileView {
        path: Quickshell.env("HOME") + "/.config/kuroshima/brightness-bus.json"
        blockLoading: true
        printErrors: false
        Component.onCompleted: {
            try {
                const parsed = JSON.parse(text())
                if (typeof parsed.bus === "string" && parsed.bus !== "") {
                    root._bus = parsed.bus
                }
            } catch (e) {
                // Missing file or invalid JSON: no cached bus yet, fall
                // through to a real detect below.
            }
            if (root._bus !== "") {
                root._getProc.running = true
            } else {
                root._busDiscoverProc.running = true
            }
        }
    }

    // The one genuinely slow step (~8s) - only reached on the very first
    // run ever, or if a previously cached bus stops working.
    property Process _busDiscoverProc: Process {
        command: ["sh", "-c", "ddcutil detect --brief | grep -oP '(?<=/dev/i2c-)[0-9]+' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const bus = text.trim()
                if (bus !== "") {
                    root._bus = bus
                    root._busCache.setText(JSON.stringify({ bus: bus }))
                }
                root._getProc.running = true
            }
        }
    }
}
