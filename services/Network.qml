pragma Singleton
import QtQuick
import Quickshell.Networking

// Slice 3 footprint pass. Replaces services/Toggles.qml's own `nmcli`
// polling (a Process spawned every 5s forever, whether or not anything
// ever displayed the toggle) with a direct, event-driven binding to
// Quickshell's own Networking module - zero subprocesses, state pushed
// live instead of polled. Read property + separate write function, not a
// two-way bound property - matches this project's own established
// convention (services/Toggles.qml's own wifiOn/setWifi shape), and a
// QtObject-rooted singleton can't `property alias` to another singleton's
// property directly the way an Item-rooted component could.
QtObject {
    id: root

    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property bool wifiEnabled: Networking.wifiEnabled

    function setWifiEnabled(on) {
        Networking.wifiEnabled = on
    }
}
