pragma Singleton
import QtQuick

// Fake payload factories so every kind can be previewed (`ipc call island
// demo <kind>`) before the real service producing it exists. Pages that
// exist for real (OsdPeek as of slice 4) get real-shaped payloads; the
// rest still render on the shared DummyWide placeholder via `payload.label`
// until their slice lands.
QtObject {
    function payloadFor(kind) {
        switch (kind) {
        case "osd.volume":
            return { kind: "volume", value: 0.42, muted: false }
        case "osd.brightness":
            return { kind: "brightness", value: 0.70 }
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
