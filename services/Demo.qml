pragma Singleton
import QtQuick

// Fake payload factories so every kind can be previewed (`ipc call island
// demo <kind>`) before the real service producing it exists. Real pages
// for most of these kinds don't exist yet either (slices 4-8); until then
// they render on the shared DummyWide placeholder via `payload.label`.
QtObject {
    function payloadFor(kind) {
        switch (kind) {
        case "osd.volume":
            return { label: "OSD VOLUME", value: 42 }
        case "osd.brightness":
            return { label: "OSD BRIGHTNESS", value: 70 }
        case "power":
            return { label: "POWER", charging: true, percent: 55 }
        case "media.track":
            return { label: "MEDIA TRACK", title: "Song Title", artist: "Some Artist" }
        case "workspace":
            return { label: "WORKSPACE", index: 2, name: "code" }
        case "notification":
            return { label: "NOTIFICATION", summary: "Demo notification", body: "This is a demo body." }
        default:
            return { label: kind }
        }
    }

    // "notification" is the one kind with no static key in Kinds.table
    // (each real notification needs its own id-based key); demo calls
    // need a key too, or IslandController.show() rejects them.
    function overridesFor(kind) {
        if (kind === "notification") {
            return { key: "demo-notif:" + Date.now() }
        }
        return undefined
    }
}
