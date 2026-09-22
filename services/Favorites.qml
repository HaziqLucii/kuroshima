pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Favorited apps for ui/AppLauncher.qml's FAVORITES section, capped at 4.
// ids are desktop-file IDs (services/Apps.qml / scripts/list-apps.py's own
// `id` field) - a stable, unique key derived from the .desktop file's own
// path, not an array index or hash.
QtObject {
    id: root

    property var ids: []

    // No-op past the cap, not an eviction of the oldest favorite -
    // starring a 5th app does nothing until one is unstarred first, rather
    // than silently bumping an existing favorite out from under the user.
    function toggle(id) {
        if (root.ids.includes(id)) {
            root.ids = root.ids.filter(i => i !== id)
        } else if (root.ids.length < 4) {
            root.ids = root.ids.concat([id])
        } else {
            return
        }
        _persist()
    }

    function _persist() {
        root._file.setText(JSON.stringify({ ids: root.ids }))
    }

    property FileView _file: FileView {
        path: Quickshell.env("HOME") + "/.config/kuroshima/favorites.json"
        blockLoading: true
        printErrors: false
        Component.onCompleted: {
            try {
                const parsed = JSON.parse(text())
                if (Array.isArray(parsed.ids)) {
                    // The cap only lives in toggle() - a hand-edited file
                    // with more than 4 ids would otherwise render that many
                    // cards in the FAVORITES row (a plain Row, no clip, no
                    // width constraint), overflowing the capsule.
                    root.ids = parsed.ids.slice(0, 4)
                }
            } catch (e) {
                // Missing file or invalid JSON: no favorites yet.
            }
        }
    }
}
