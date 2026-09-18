import QtQuick
import qs.services

// The only file that knows both services and the controller: one
// Connections per service, mapping its signal to Island.show(...). Lives
// in app/, not core/, same reason as Island.qml (needs Quickshell/service
// imports, core/ stays Quickshell-free for tests).
//
// A plain (non-singleton) type: instantiate it once from shell.qml so it
// exists at all. Referencing Audio here (even just as a Connections
// target) is what makes the otherwise-lazy Audio singleton actually start;
// a service nothing references never initializes.
Item {
    Connections {
        target: Audio
        function onChanged() {
            Island.show("osd.volume", {
                kind: "volume",
                value: Audio.volume,
                muted: Audio.muted
            }, { key: "osd:volume" })
        }
    }
}
