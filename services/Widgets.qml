pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Desktop widget canvas state: which widgets are placed, where, and
// whether the edit-mode chrome (ui/WidgetCanvas.qml, ui/WidgetFrame.qml) is
// currently showing. `placed` is STATE (changes via drag/add/delete in the
// UI), not user config to hand-edit - same distinction Wallpaper.qml draws
// against Config.qml, hence its own file rather than a config.json key.
//
// Widget content itself is explicitly NOT held to this project's bone-on-
// black/no-accent-hue rule - Haziq: "widget should be open and up to user
// of their own creativity." Only the edit-mode chrome this file drives
// follows house style.
QtObject {
    id: root

    property bool editMode: false

    // Which single widget currently shows its border/resize-handle/delete
    // badge (ui/WidgetFrame.qml). Empty outside edit mode and right after
    // entering it - a widget only shows its own editing chrome once
    // clicked, not for the whole canvas at once. `<Enter>` clears this
    // (defocus, stay in edit mode); `<Escape>` clears editMode itself,
    // which also clears this via onEditModeChanged below.
    property string focusedWidgetId: ""

    function focusWidget(id) {
        root.focusedWidgetId = id
    }

    function clearFocus() {
        root.focusedWidgetId = ""
    }

    onEditModeChanged: {
        if (editMode) rescanCustomTypes()
        else root.focusedWidgetId = ""
    }

    // Each entry: { id, type, custom, x, y, w, h }. `custom` picks which
    // directory urlFor() resolves `type` against. `w`/`h` are absent (or 0)
    // until the widget's been resized at least once - WidgetFrame falls
    // back to the widget's own implicitWidth/Height until then.
    property var placed: []

    // Known at commit time - kuroshima's own bundled widgets/*.qml files.
    // Unlike customTypes below, no need to list the repo's own directory
    // at runtime just to discover files that only change when this file
    // itself changes.
    readonly property var bundledTypes: ["Clock"]

    // Arbitrary user-dropped files ARE unknown ahead of time, so this one
    // genuinely needs a runtime directory listing - same shell-out-for-
    // system-data pattern services/Brightness.qml already uses for
    // ddcutil, rather than inventing a new mechanism.
    property var customTypes: []

    function rescanCustomTypes() {
        _customScanProc.running = true
    }

    property Process _customScanProc: Process {
        command: ["sh", "-c", "ls ~/.config/kuroshima/widgets/*.qml 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\\.qml$//'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.customTypes = text.trim().length > 0 ? text.trim().split("\n") : []
            }
        }
    }

    function urlFor(type, custom) {
        return custom
            ? "file://" + Quickshell.env("HOME") + "/.config/kuroshima/widgets/" + type + ".qml"
            : Qt.resolvedUrl("../widgets/" + type + ".qml")
    }

    function addWidget(type, custom) {
        const id = "w" + Date.now() + "-" + Math.floor(Math.random() * 10000)
        // Default offset: staggers new widgets so adding several in a row
        // doesn't stack them exactly on top of each other.
        const n = root.placed.length
        root.placed = root.placed.concat([{
            id: id,
            type: type,
            custom: !!custom,
            x: 80 + (n % 6) * 24,
            y: 80 + (n % 6) * 24
        }])
        // Focused immediately - otherwise a just-added widget shows no
        // border/handles at all until separately clicked, which reads as
        // broken rather than "not focused yet".
        root.focusedWidgetId = id
        _persist()
    }

    function removeWidget(id) {
        root.placed = root.placed.filter(w => w.id !== id)
        if (root.focusedWidgetId === id) root.focusedWidgetId = ""
        _persist()
    }

    function moveWidget(id, x, y) {
        root.placed = root.placed.map(w => w.id === id ? Object.assign({}, w, { x: x, y: y }) : w)
        _persist()
    }

    function resizeWidget(id, w, h) {
        root.placed = root.placed.map(item => item.id === id ? Object.assign({}, item, { w: w, h: h }) : item)
        _persist()
    }

    function _persist() {
        root._file.setText(JSON.stringify({ placed: root.placed }))
    }

    property FileView _file: FileView {
        path: Quickshell.env("HOME") + "/.config/kuroshima/widgets.json"
        blockLoading: true
        printErrors: false
        Component.onCompleted: {
            try {
                const parsed = JSON.parse(text())
                if (Array.isArray(parsed.placed)) {
                    root.placed = parsed.placed
                }
            } catch (e) {
                // Missing file or invalid JSON: no widgets placed yet.
            }
        }
    }
}
