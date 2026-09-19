pragma Singleton
import QtQuick
import Quickshell.Services.Notifications

// Slice 6. Pure data/signal service, same shape as Audio/Media: this file
// doesn't know about IslandController at all, app/Bridges.qml is what
// turns `received(notification)` into an Island.show(...) call, per the
// established pattern of keeping the controller-aware wiring in one place.
QtObject {
    id: root

    signal received(var notification)

    // Backs the design's "06 INBOX" list. Deliberately NOT
    // `NotificationServer.trackedNotifications`: app/Bridges.qml's
    // Slice-6 cleanup calls `expire()`/`dismiss()` on a notification as
    // soon as its peek transient ends (correctly, per the D-Bus
    // NotificationClosed contract with the sender), which destroys it and
    // drops it out of `trackedNotifications` almost immediately - that
    // list only ever has the ONE currently-showing notification, not a
    // history. This is a separate, plain-data snapshot array the sender-
    // facing lifecycle doesn't touch, capped like the queue elsewhere in
    // this project (core/IslandController.qml's queueCap) so it can't
    // grow unbounded.
    readonly property int historyCap: 20
    property var history: [] // [{id, appName, title, body, time}], newest first

    function clearHistory() {
        root.history = []
    }

    // QtObject has no default property (this codebase's standing gotcha,
    // hit 3+ times already): the Loader needs a named property, not a bare
    // unnamed child. `active` gates on Config.notificationServer (default
    // false, see Config.qml and docs/HANDOFF.md's D-Bus-name-already-owned
    // pitfall) rather than being hardcoded on.
    property Loader _serverLoader: Loader {
        active: Config.notificationServer
        sourceComponent: NotificationServer {
            keepOnReload: true
            actionsSupported: true
            imageSupported: true
            bodySupported: true
            onNotification: (notification) => {
                notification.tracked = true
                root.history = [{
                    id: notification.id,
                    appName: notification.appName || "",
                    title: notification.summary || "",
                    body: notification.body || "",
                    time: Qt.formatDateTime(new Date(), "hh:mm")
                }].concat(root.history).slice(0, root.historyCap)
                root.received(notification)
            }
        }
    }
}
