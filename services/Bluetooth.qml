pragma Singleton
import QtQuick
import Quickshell.Bluetooth

// Slice 3 footprint pass. Replaces services/Toggles.qml's own
// `sh -c "bluetoothctl show | grep -i Powered"` polling (a Process spawned
// every 5s forever) with a direct, event-driven binding to Quickshell's
// own Bluetooth module - zero subprocesses. `defaultAdapter` is null when
// there's no adapter at all, guarded on every read/write the same way the
// original `btAvailable` gate did.
//
// Naming note, deliberate: this file is registered as the `Bluetooth`
// singleton under `qs.services` (services/qmldir), and it also imports
// `Quickshell.Bluetooth`, whose OWN singleton is separately named
// `Bluetooth` too. Not a conflict - QML resolves `Bluetooth` inside THIS
// file against THIS file's own imports (Quickshell's), while every other
// file in this project only ever sees THIS wrapper (via `qs.services`)
// under that same name, never both at once. Confusing to read cold,
// worth naming explicitly rather than leaving a future reader to work it
// out.
QtObject {
    id: root

    readonly property bool available: Bluetooth.defaultAdapter !== null
    readonly property bool enabled: root.available && Bluetooth.defaultAdapter.enabled

    function setEnabled(on) {
        if (root.available) Bluetooth.defaultAdapter.enabled = on
    }
}
