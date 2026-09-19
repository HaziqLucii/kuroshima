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

    // `Loader { active: Config.notificationServer }` per the plan, but
    // Config.qml doesn't exist yet in this project - hardcoded true for
    // now, revisit once a real config surface lands (see docs/HANDOFF.md).
    // QtObject has no default property (this codebase's standing gotcha,
    // hit 3+ times already): the Loader needs a named property, not a bare
    // unnamed child.
    property Loader _serverLoader: Loader {
        active: true
        sourceComponent: NotificationServer {
            keepOnReload: true
            actionsSupported: true
            imageSupported: true
            bodySupported: true
            onNotification: (notification) => {
                notification.tracked = true
                root.received(notification)
            }
        }
    }
}
