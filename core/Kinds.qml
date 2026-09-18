pragma Singleton
import QtQuick

// Data only. Base defaults per kind; a caller (Bridges.qml, slice 6+)
// overrides duration/priority/key per event where the table alone isn't
// enough, e.g. notification urgency (normal/low/critical) or a per-id key.
QtObject {
    readonly property var table: ({
        "notification": { priority: 50, duration: 5000, page: "NotificationPeek", requeue: true },
        "osd.volume": { priority: 40, duration: 1500, key: "osd:volume", page: "OsdPeek", requeue: false },
        "osd.brightness": { priority: 40, duration: 1500, key: "osd:brightness", page: "OsdPeek", requeue: false },
        "power": { priority: 35, duration: 3000, key: "power", page: "PowerPeek", requeue: false },
        "media.track": { priority: 30, duration: 3000, key: "media", page: "MediaPeek", requeue: false },
        "workspace": { priority: 20, duration: 1200, key: "workspace", page: "WorkspacePeek", requeue: false }
    })
}
