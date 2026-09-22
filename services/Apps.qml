pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Backs ui/AppLauncher.qml. Not polled - refresh() is called once from
// that page's own Component.onCompleted (a real page in ui/Capsule.qml's
// pageMap, not a persistent window with its own _open() - PageHost creates
// a fresh instance every time the launcher opens, so Component.onCompleted
// firing IS the "just opened" signal here), not on a timer: 97 real
// launchable entries on this machine parse in well under that time, so
// "always current after installing something new" beats caching against a
// stale list.
QtObject {
    id: root

    property var list: []

    function refresh() {
        _listProc.running = true
    }

    // Quickshell.shellDir resolves to this repo whether running via -p .
    // (dev) or the installed -c kuroshima symlink, same reasoning the
    // sibling niri-lockscreen project's own suspend-watcher script
    // resolution already relies on.
    property Process _listProc: Process {
        command: ["python3", Quickshell.shellDir + "/scripts/list-apps.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text)
                    root.list = Array.isArray(parsed) ? parsed : []
                } catch (e) {
                    root.list = []
                }
            }
        }
    }
}
