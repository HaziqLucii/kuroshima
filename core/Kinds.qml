pragma Singleton
import QtQuick

// Data only. Base defaults per kind; a caller (Bridges.qml, slice 6+)
// overrides duration/priority/key per event where the table alone isn't
// enough, e.g. notification urgency (normal/low/critical) or a per-id key.
//
// Durations follow the design's SPEC panel ("TRANSIENT DWELL: 3200ms /
// 900ms ws"): 3200 as the general default, workspace as the one named
// exception. The design's own interactive demo hardcodes slightly
// different per-trigger values (e.g. notification 4200, workspace 1200);
// those read as prototype-convenience numbers for clicking through demo
// buttons quickly, not the documented spec, so the SPEC panel wins here.
QtObject {
    readonly property var table: ({
        "notification": { priority: 50, duration: 3200, page: "NotificationPeek", requeue: true },
        "osd.volume": { priority: 40, duration: 3200, key: "osd:volume", page: "OsdPeek", requeue: false },
        "osd.brightness": { priority: 40, duration: 3200, key: "osd:brightness", page: "OsdPeek", requeue: false },
        "power": { priority: 35, duration: 3200, key: "power", page: "PowerPeek", requeue: false },
        "media.track": { priority: 30, duration: 3200, key: "media", page: "MediaPeek", requeue: false },
        "workspace": { priority: 20, duration: 900, key: "workspace", page: "WorkspacePeek", requeue: false }
    })
}
