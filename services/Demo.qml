pragma Singleton
import QtQuick

// Fake payload factories so every kind can be previewed (`ipc call island
// demo <kind>`) before the real service producing it exists. Pages that
// exist for real (OsdPeek since slice 4, MediaPeek since slice 5) get
// real-shaped payloads; the rest still render on the shared DummyWide
// placeholder via `payload.label` until their slice lands.
QtObject {
    function payloadFor(kind) {
        switch (kind) {
        case "osd.volume":
            return { kind: "volume", value: 0.42, muted: false }
        case "osd.brightness":
            return { kind: "brightness", value: 0.70 }
        case "power":
            // Unused by the real page: pages/PowerPeek.qml reads the live
            // services/Battery.qml singleton directly. This desktop has no
            // battery at all, so demoing this kind shows Battery.available
            // === false's rendering (0%, "BATTERY" label), not a fake
            // charging state - there's no live source to fake it against
            // meaningfully.
            return {}
        case "media.track":
            return { title: "Song Title", artist: "Some Artist", artUrl: "", isPlaying: true }
        case "workspace":
            // Unused by the real page: pages/WorkspacePeek.qml reads the
            // live services/Workspaces.qml singleton directly, same as
            // notifications read a live object rather than a snapshot.
            // Demoing this kind just shows whatever niri's real current
            // workspace state actually is, not a fake one.
            return {}
        case "notification":
            // Not the same shape as a real one (services/Notifs.qml wraps
            // a live Quickshell Notification object, isCreatable: false so
            // there's no way to fake a real instance): a plain JS object
            // matching what pages/NotificationPeek.qml itself reads, plus
            // expire()/dismiss() no-ops. Those two ARE needed even on this
            // bypassed-Bridges.qml.onReceived demo path: app/Bridges.qml's
            // onTransientEnded handler reacts to Island.transientEnded for
            // ANY "notification" kind transient, demo or real, and calls
            // whichever of the two matches how it ended (this demo one
            // will genuinely time out and hit expire() on its own) -
            // omitting either here throws "Property 'X' ... is not a
            // function" the first time this demo transient ends.
            // `closed`/`tracked` genuinely aren't needed: those are read
            // only by onReceived, which this demo path never goes through
            // (the IPC handler calls Island.show() directly).
            return {
                notification: {
                    appName: "Demo",
                    summary: "Demo notification",
                    body: "This is a demo body.",
                    appIcon: "",
                    image: "",
                    actions: [],
                    expire: function () {},
                    dismiss: function () {}
                }
            }
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
