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

    // Slice 1. Not persisted, and unlike compactFace (app/Island.qml),
    // doesn't survive a hot reload either: this file is a bare QtObject
    // singleton, and app/Island.qml's own comment on why IT is Singleton-
    // rooted instead already spells out the reason - a bare QtObject
    // singleton is never registered by Quickshell's SingletonRegistry and
    // is unreachable by reload propagation, PersistentProperties or not.
    // Resets to false on every `scripts/dev.sh` hot reload and every real
    // restart, same as every other services/*.qml boolean in this
    // codebase (wifiOn, btOn, editMode, ...) - v1 scope, real persistence
    // is Slice 5's job once Faces.qml's config file exists to hold it.
    property bool dnd: false

    function clearHistory() {
        root.history = []
    }

    // QtObject has no default property (this codebase's standing gotcha,
    // hit 3+ times already): the Loader needs a named property, not a bare
    // unnamed child. `active` gates on Config.notificationServer (default
    // false, see Config.qml and docs/NOTES.md's D-Bus-name-already-owned
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
                    // Deliberately NOT keeping a live `actions` reference
                    // here (tried once, reverted - see docs/NOTES.md): this
                    // handler's own `tracked = true` only stops Quickshell's
                    // OWN auto-expiry, it doesn't stop app/Bridges.qml's
                    // explicit expire()/dismiss() calls once this
                    // notification's transient peek ends, which happens for
                    // essentially every notification within seconds. Those
                    // calls destroy the underlying object (and its actions
                    // with it) - a history entry holding onto one past that
                    // point is a dangling QObject pointer, not "still
                    // invokable later", and touching it segfaulted the whole
                    // shell.
                }].concat(root.history).slice(0, root.historyCap)
                root.received(notification)
            }
        }
    }
}
