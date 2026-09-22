pragma Singleton
import QtQuick

// Backs faces/ClipboardFace.qml's file-chip row. Pure in-memory staging -
// session-scoped, not persisted across restarts, matching the "drag from
// workspace 1, drag out on workspace 2" ephemeral-clipboard framing Haziq
// described. Drop events are already local data (no external process to
// fetch from), so this is a plain QtObject, not a Process-backed service
// like services/Apps.qml.
QtObject {
    id: root

    // Each entry: {url, name, ext}. ext is the fallback label shown when a
    // chip's own Image thumbnail fails to load (see ClipboardFace.qml) -
    // "DIR" for extensionless drops (folders, or files with no dot in the
    // name).
    property var files: []

    function addFiles(urls) {
        let next = files.slice()
        const existing = new Set(next.map(f => f.url))
        for (const url of urls) {
            const urlStr = url.toString()
            // Re-dropping a file already staged (e.g. dragging it back in
            // after dragging it out - drag-out is a copy, not a move, the
            // chip stays put) would otherwise silently create a second
            // chip for the identical path.
            if (existing.has(urlStr)) continue
            const path = decodeURIComponent(urlStr.replace(/\/$/, ""))
            const name = path.split("/").pop()
            const dot = name.lastIndexOf(".")
            const ext = dot > 0 ? name.slice(dot + 1).toUpperCase() : "DIR"
            next.push({ url: urlStr, name: name, ext: ext })
            existing.add(urlStr)
        }
        root.files = next
    }

    // Splices the in-memory staging list only - never touches the real
    // file on disk. The cross button is for removing something from the
    // clipboard, not deleting it.
    function removeFile(index) {
        let next = files.slice()
        next.splice(index, 1)
        root.files = next
    }
}
