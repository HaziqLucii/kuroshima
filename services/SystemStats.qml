pragma Singleton
import QtQuick
import Quickshell.Io

// Backs the design's "05 SYSTEM" grid (CPU/MEM/TEMP/DISK). Read-only,
// unlike CONTROLS: no destructive-action or latency tradeoffs here, just
// periodic polling of /proc and hwmon, so all four land in one pass.
// Each stat is independent and hides itself (-1 / "") if its source isn't
// there, same rule as everything else on this page.
QtObject {
    id: root

    readonly property int pollInterval: 3000

    property real cpuPercent: -1
    property real memPercent: -1
    property string memUsedLabel: ""
    property real diskPercent: -1
    property real tempCelsius: -1

    property real _prevIdle: -1
    property real _prevTotal: -1

    // Verified live (scratch qmltestrunner probe, not assumed): re-setting
    // `running: true` on an already-exited Process genuinely re-spawns it
    // with a fresh stdout capture each time, not a cached first result, so
    // one Process instance per stat is reused every poll rather than
    // constructed fresh each tick.
    property Process _cpuProc: Process {
        command: ["cat", "/proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                // First line: "cpu  user nice system idle iowait irq softirq steal guest guest_nice"
                const parts = text.split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
                if (parts.length < 5 || parts.some(isNaN)) return
                const idle = parts[3] + parts[4]
                const total = parts.reduce((a, b) => a + b, 0)
                // First sample has no prior point to delta against; CPU%
                // needs two, so it just stays -1 (hidden) for one tick.
                // Haziq: "the cpu stats thing comes in late" - waiting for
                // the full 3s pollInterval to get that second sample felt
                // sluggish, so a quick one-off follow-up (250ms) gets a
                // real CPU% almost immediately instead, then normal
                // polling resumes on its usual cadence.
                const hadPrior = root._prevTotal >= 0
                if (hadPrior) {
                    const deltaTotal = total - root._prevTotal
                    if (deltaTotal > 0) {
                        root.cpuPercent = Math.round((1 - (idle - root._prevIdle) / deltaTotal) * 100)
                    }
                }
                root._prevIdle = idle
                root._prevTotal = total
                if (!hadPrior) {
                    root._cpuQuickFollowup.start()
                }
            }
        }
    }

    property Timer _cpuQuickFollowup: Timer {
        interval: 250
        onTriggered: root._cpuProc.running = true
    }

    property Process _memProc: Process {
        command: ["cat", "/proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                const kb = (key) => {
                    const line = lines.find(l => l.startsWith(key + ":"))
                    return line ? parseInt(line.trim().split(/\s+/)[1]) : NaN
                }
                const total = kb("MemTotal")
                const avail = kb("MemAvailable")
                if (isNaN(total) || isNaN(avail) || total <= 0) return
                const used = total - avail
                root.memPercent = Math.round((used / total) * 100)
                root.memUsedLabel = (used / (1024 * 1024)).toFixed(1) + "G"
            }
        }
    }

    property Process _diskProc: Process {
        command: ["df", "-B1", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                if (lines.length < 2) return
                const parts = lines[1].trim().split(/\s+/)
                const total = parseInt(parts[1])
                const used = parseInt(parts[2])
                if (isNaN(total) || isNaN(used) || total <= 0) return
                root.diskPercent = Math.round((used / total) * 100)
            }
        }
    }

    // hwmon indices aren't stable across reboots/kernels, so the actual
    // sensor (k10temp on this AMD desktop) is found by name once at
    // startup rather than hardcoding "hwmon4". Falls back to acpitz (a
    // generic ACPI thermal zone present on more systems) if k10temp isn't
    // found; stays "" (hidden) if neither is.
    property string _tempPath: ""
    property Process _tempDiscoverProc: Process {
        command: ["sh", "-c", "for n in k10temp acpitz; do p=$(grep -l \"$n\" /sys/class/hwmon/hwmon*/name 2>/dev/null | head -1); if [ -n \"$p\" ]; then dirname \"$p\"; break; fi; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path) {
                    root._tempPath = path + "/temp1_input"
                    root._tempProc.running = true
                }
            }
        }
        Component.onCompleted: running = true
    }

    property Process _tempProc: Process {
        command: ["cat", root._tempPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const millideg = parseInt(text.trim())
                if (!isNaN(millideg)) root.tempCelsius = Math.round(millideg / 1000)
            }
        }
    }

    property Timer _pollTimer: Timer {
        interval: root.pollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root._cpuProc.running = true
            root._memProc.running = true
            root._diskProc.running = true
            if (root._tempPath !== "") {
                root._tempProc.running = true
            }
        }
    }
}
