pragma Singleton
import QtQuick

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
// Slice 3 footprint pass: WIFI/BT used to poll nmcli/bluetoothctl every 5s
// forever via two Process subprocesses, whether or not anything ever
// displayed the toggle - the exact "polling subprocess when a Quickshell
// module already exposes the same state" waste the plan's own rule 7
// calls out. Now plain delegating reads/writes to services/Network.qml
// and services/Bluetooth.qml (Quickshell.Networking/Quickshell.Bluetooth,
// event-driven, zero subprocesses) - this file's own public API
// (wifiAvailable/wifiOn/btAvailable/btOn/setWifi/setBt) is unchanged so
// every existing consumer (the TOGGLES grid, faces/StatusFace.qml) needed
// no changes at all.
QtObject {
    id: root

    readonly property bool wifiAvailable: Network.wifiHardwareEnabled
    readonly property bool wifiOn: Network.wifiEnabled
    readonly property bool btAvailable: Bluetooth.available
    readonly property bool btOn: Bluetooth.enabled
    property bool idleInhibit: false

    function setWifi(on) {
        Network.setWifiEnabled(on)
    }

    function setBt(on) {
        Bluetooth.setEnabled(on)
    }
}
