pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Current-wallpaper STATE, not user-facing config (see Config.qml's own
// comment on that distinction) - this changes via the carousel picking a
// new image, not by hand-editing a file, so it lives in its own file
// rather than growing config.json with a key nobody should hand-edit.
//
// niri has no built-in wallpaper mechanism the way KDE Plasma does (this
// port's origin, ~/Projects/cachyos-setup/kuro/theme/config/quickshell/
// kuro-wallpaper, shells out to `plasma-apply-wallpaperimage`) - there is
// no equivalent CLI to call. `currentPath` is instead a plain binding
// ui/WallpaperBackground.qml's Image reads directly: this singleton and
// that surface are the same process, so "applying" a wallpaper is just
// setting a property, no IPC or external command needed at all.
QtObject {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallhaven"
    property string currentPath: ""

    // The path last written to disk - what `revert()` (Esc in the
    // carousel) restores, distinct from `currentPath` so live-previewing
    // during arrow navigation never needs to touch the filesystem.
    property string _persistedPath: ""

    // Called continuously while arrowing through the carousel: changes
    // what's on screen without persisting anything, so cancelling
    // (revert()) has nothing to undo on disk.
    function preview(path) {
        root.currentPath = path
    }

    // Called on Enter: makes the live preview permanent.
    function commit(path) {
        root.currentPath = path
        root._persistedPath = path
        root._file.setText(JSON.stringify({ path: path }))
    }

    // Called on Esc: restores whatever was active before the picker
    // started previewing, whether or not that matches the file on disk
    // (it always does, since only commit() ever writes it).
    function revert() {
        root.currentPath = root._persistedPath
    }

    property FileView _file: FileView {
        path: Quickshell.env("HOME") + "/.config/dynamic-island/wallpaper-state.json"
        blockLoading: true
        printErrors: false
        Component.onCompleted: {
            try {
                const parsed = JSON.parse(text())
                if (typeof parsed.path === "string" && parsed.path.length > 0) {
                    root.currentPath = parsed.path
                    root._persistedPath = parsed.path
                }
            } catch (e) {
                // Missing file or invalid JSON: no wallpaper set yet: the
                // background surface just shows nothing until the first
                // commit() ever runs.
            }
        }
    }
}
