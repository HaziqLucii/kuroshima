pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Slice 5. Which Island Faces (pages/CompactPage.qml's own nested PageHost)
// are enabled and in what order, plus which one is currently showing -
// persisted across real restarts, unlike app/Island.qml's own
// PersistentProperties (hot-reload only). Bundled-only for now: user
// drop-in faces (a `~/.config/kuroshima/faces/*.qml` directory scan, same
// idea as services/Widgets.qml's customTypes) were part of the original
// plan for this slice but deliberately dropped - wiring a dynamically
// `Qt.createComponent()`-built Component into ui/PageHost.qml's pageMap
// alongside the bundled ones is a real async-race problem (the scan
// finishes after CompactPage's own pageMap is already built), nobody has
// actually written a custom face yet, and the plan's own text names this
// exact escape hatch: "if wiring created Components into PageHost.pageMap
// proves awkward, ship bundled-only and log it; do not build a plugin API
// around it." See docs/NOTES.md's Slice 5 entry.
QtObject {
    id: root

    // Display labels live here, not duplicated per-consumer - both
    // pages/CompactPage.qml's Component list and
    // pages/SettingsFacesPanel.qml's preview list still each declare their
    // own `id -> Component` mapping (real QML types need a real import
    // site; a QtObject singleton can't hold arbitrary visual children
    // without another named-property Component per face, which would make
    // this file import qs.faces and create a services->faces->services
    // module cycle for no real benefit - see docs/NOTES.md). This list is
    // just the metadata both of those already reference instead of
    // hardcoding labels twice.
    readonly property var bundled: [
        { id: "clockEq", label: "CLOCK" },
        { id: "clockDate", label: "CLOCK + DATE" },
        { id: "statusFace", label: "STATUS" },
        { id: "systemFace", label: "SYSTEM" },
        { id: "weatherFace", label: "WEATHER" },
        { id: "focusFace", label: "FOCUS" },
        { id: "media", label: "MEDIA" },
        { id: "clipboard", label: "CLIPBOARD" }
    ]
    readonly property var defaultOrder: root.bundled.map(f => f.id)

    function labelFor(id) {
        const entry = root.bundled.find(f => f.id === id)
        return entry ? entry.label : id
    }

    // refuter-caught: both the FileView load path and setOrder() used to
    // only check `typeof id === "string"`, with no dedupe and no check
    // against `bundled` at all. Two concrete ways that broke the "order
    // never reaches zero valid entries" guarantee setEnabled() below
    // exists to protect: a persisted file containing a stale id (the exact
    // rename/removal case pages/CompactPage.qml's own comment already
    // anticipates) let setEnabled() disable the one remaining REAL face
    // and leave `order` holding only the stale id; a persisted file with a
    // duplicate id (`["clockEq","clockEq"]`) passed the old `length > 0`
    // check on load but collapsed to an empty array the moment anything
    // deduplicated it. Either way, pages/CompactPage.qml's pageMap filter
    // then silently fell back to every bundled face re-enabled - exactly
    // the "quietly undo the user's own choices" outcome that fallback was
    // never supposed to reach. One sanitizer, used by both the load path
    // and setOrder(), so this can't drift back out of sync between them.
    function _sanitizeOrder(ids) {
        if (!Array.isArray(ids)) return []
        const validIds = new Set(root.bundled.map(f => f.id))
        const seen = new Set()
        const result = []
        for (const id of ids) {
            if (typeof id === "string" && validIds.has(id) && !seen.has(id)) {
                seen.add(id)
                result.push(id)
            }
        }
        return result
    }

    // Bound to defaultOrder until the very first real mutation (a
    // FileView load, or any setOrder/setEnabled/moveUp/moveDown call)
    // assigns a concrete array and severs the binding - so a fresh
    // install with no faces.json yet genuinely means "every bundled face,
    // default order", not an ambiguous empty array. Never deliberately
    // emptied either: setEnabled() below refuses to disable the last
    // remaining entry, so pages/CompactPage.qml's own "order filtered
    // against pageMap is empty -> fall back to defaultOrder" rule only
    // ever fires for genuine corruption (a persisted id no longer in
    // pageMap), not as a way to silently re-enable everything a user just
    // turned off one at a time.
    property var order: root.defaultOrder
    property string current: "clockEq"

    function setOrder(ids) {
        const sanitized = root._sanitizeOrder(ids)
        if (sanitized.length === 0) return
        root.order = sanitized
        root._persist()
    }

    function setEnabled(id, on) {
        if (on) {
            if (root.order.indexOf(id) !== -1) return
            root.order = root.order.concat([id])
        } else {
            if (root.order.length <= 1) return
            root.order = root.order.filter(x => x !== id)
        }
        root._persist()
    }

    function moveUp(id) {
        const idx = root.order.indexOf(id)
        if (idx <= 0) return
        const next = root.order.slice()
        const tmp = next[idx - 1]
        next[idx - 1] = next[idx]
        next[idx] = tmp
        root.order = next
        root._persist()
    }

    function moveDown(id) {
        const idx = root.order.indexOf(id)
        if (idx === -1 || idx >= root.order.length - 1) return
        const next = root.order.slice()
        const tmp = next[idx + 1]
        next[idx + 1] = next[idx]
        next[idx] = tmp
        root.order = next
        root._persist()
    }

    // Called from app/Island.qml's onCompactFaceChanged, once per swipe -
    // bounded by discrete user action, not a timer, same "infrequent
    // enough, no debounce needed" reasoning services/Widgets.qml and
    // services/Favorites.qml already apply to their own on-every-mutation
    // FileView.setText() calls.
    function setCurrent(id) {
        if (root.current === id) return
        root.current = id
        root._persist()
    }

    function _persist() {
        root._file.setText(JSON.stringify({ order: root.order, current: root.current }))
    }

    property FileView _file: FileView {
        path: Quickshell.env("HOME") + "/.config/kuroshima/faces.json"
        blockLoading: true
        printErrors: false
        Component.onCompleted: {
            try {
                const parsed = JSON.parse(text())
                const sanitized = root._sanitizeOrder(parsed.order)
                if (sanitized.length > 0) {
                    root.order = sanitized
                }
                // Else: a stale/corrupt/empty-after-sanitizing persisted
                // order leaves `order` bound to `defaultOrder` (its
                // declared default) rather than assigning an empty array -
                // genuine corruption recovery, not a way to reach a
                // deliberately-empty state.
                if (typeof parsed.current === "string" && root.bundled.some(f => f.id === parsed.current)) {
                    root.current = parsed.current
                }
            } catch (e) {
                // Missing file or invalid JSON: keep the defaults above.
            }
        }
    }
}
