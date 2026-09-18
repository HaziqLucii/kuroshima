pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Backs the design's "01 IDENTITY" header row (user@host, uptime, compositor
// version). Each field degrades independently and silently to "" when its
// source isn't available, per the design's own rule: "Each module hides
// itself when its source is absent." host/niri are read once (they don't
// change mid-session); uptime is derived from one read of /proc/uptime plus
// a live wall-clock offset, not re-read on a timer.
QtObject {
    id: root

    property string hostname: ""
    readonly property string userHost: {
        const user = Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
        return (user && hostname) ? (user + "@" + hostname) : ""
    }

    property real _bootUptimeSecs: -1
    property real _bootReadAtMs: 0
    property real _nowMs: Date.now()
    readonly property string uptimeLabel: {
        if (_bootUptimeSecs < 0) return ""
        const secs = _bootUptimeSecs + (_nowMs - _bootReadAtMs) / 1000
        const h = Math.floor(secs / 3600)
        const m = Math.floor((secs % 3600) / 60)
        return "UP " + h + "H " + m + "M"
    }

    property string niriVersion: ""

    // QtObject has no default property (found 3 times already in this
    // codebase, see docs/HANDOFF.md's standing reminder): every child below
    // needs a named property, not a bare unnamed child, or this fails to
    // load with "Cannot assign to non-existent default property".
    property FileView _hostnameFile: FileView {
        path: "/etc/hostname"
        blockLoading: true
        printErrors: false
        Component.onCompleted: root.hostname = text().trim()
    }

    property FileView _uptimeFile: FileView {
        path: "/proc/uptime"
        blockLoading: true
        printErrors: false
        Component.onCompleted: {
            const secs = parseFloat(text().split(" ")[0])
            if (!isNaN(secs)) {
                root._bootUptimeSecs = secs
                root._bootReadAtMs = Date.now()
            }
        }
    }

    property Timer _clockTimer: Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root._nowMs = Date.now()
    }

    // niri-only: on Hyprland (Haziq's other target compositor) this command
    // doesn't exist, exec fails, niriVersion just stays "" and the header
    // row's compositor field hides itself, same as any other absent module.
    property Process _niriVersionProc: Process {
        command: ["niri", "msg", "--json", "version"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text)
                    root.niriVersion = parsed.compositor || ""
                } catch (e) {
                    root.niriVersion = ""
                }
            }
        }
        Component.onCompleted: running = true
    }
}
