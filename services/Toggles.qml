pragma Singleton
import QtQuick
import Quickshell.Io

// Backs the design's "04 TOGGLES" grid. WIFI, BT, and IDLE here: DND lives
// in services/Notifs.qml (it needs the notification server, not this
// file), NIGHT has no gamma daemon installed on this machine (checked: no
// gammastep/wlsunset/redshift), VPN has no connection profile configured
// at all, and CAPS is a passive indicator (not sensibly a click-toggle).
// MIC reuses services/Audio.qml directly rather than duplicating it here.
//
// idleInhibit is state only, no protocol object: a QtObject singleton has
// no window to bind an IdleInhibitor to. niri exposes
// zwp_idle_inhibit_manager_v1 (confirmed via wayland-info), so
// ui/IslandWindow.qml hosts the actual IdleInhibitor as a child of its
// PanelWindow, bound to this property.
//
// State isn't event-driven (no live D-Bus signal wired up for either),
// just polled every 5s plus an immediate re-poll right after this page's
// own toggle actions, since nmcli/bluetoothctl are the only interfaces
// used and neither pushes change notifications to a plain Process.
QtObject {
    id: root

    property bool wifiAvailable: false
    property bool wifiOn: false
    property bool btAvailable: false
    property bool btOn: false
    property bool idleInhibit: false

    function setWifi(on) {
        root.wifiOn = on // optimistic; the next poll corrects it if the command failed
        _wifiSetProc.command = ["nmcli", "radio", "wifi", on ? "on" : "off"]
        _wifiSetProc.running = true
    }

    function setBt(on) {
        root.btOn = on
        _btSetProc.command = ["bluetoothctl", "power", on ? "on" : "off"]
        _btSetProc.running = true
    }

    property Process _wifiPollProc: Process {
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = text.trim()
                root.wifiAvailable = (s === "enabled" || s === "disabled")
                root.wifiOn = (s === "enabled")
            }
        }
    }

    property Process _btPollProc: Process {
        command: ["sh", "-c", "bluetoothctl show | grep -i Powered"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = text.trim().toLowerCase()
                root.btAvailable = s.length > 0
                root.btOn = s.includes("yes")
            }
        }
    }

    property Process _wifiSetProc: Process {
        onExited: (code, status) => root._wifiPollProc.running = true
    }

    property Process _btSetProc: Process {
        onExited: (code, status) => root._btPollProc.running = true
    }

    property Timer _pollTimer: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root._wifiPollProc.running = true
            root._btPollProc.running = true
        }
    }
}
