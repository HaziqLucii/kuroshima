import QtQuick
import Quickshell.Services.Notifications
import qs.services

// The only file that knows both services and the controller: one
// Connections per service, mapping its signal to Island.show(...). Lives
// in app/, not core/, same reason as Island.qml (needs Quickshell/service
// imports, core/ stays Quickshell-free for tests).
//
// A plain (non-singleton) type: instantiate it once from shell.qml so it
// exists at all. Referencing Audio/Media here (even just as Connections
// targets) is what makes the otherwise-lazy singletons actually start;
// a service nothing references never initializes.
Item {
    Connections {
        target: Audio
        function onChanged() {
            // Any expanded page (MediaExpanded's own CONTROLS section, or
            // pages/SettingsAudioPanel.qml's volume slider) already shows
            // volume live, so popping the OSD transient over it is always
            // redundant, whether the change came from that slider or a
            // hardware volume key pressed while looking at it. Without
            // this guard, the OSD transient's own priority (40, equal to
            // expandedBlockBelow) clears IslandController's expanded gate,
            // which morphs the whole expanded dashboard down to the 320x58
            // OSD pill mid-adjustment - refuter-caught twice now, first for
            // MediaExpanded alone, then again for SettingsExpanded once it
            // existed and this guard hadn't been generalized to it. Plain
            // `Island.isExpanded`, not a specific page name: whatever
            // expanded page comes next inherits the fix for free instead
            // of needing this list remembered and updated again.
            if (Island.isExpanded) {
                return
            }
            Island.show("osd.volume", {
                kind: "volume",
                value: Audio.volume,
                muted: Audio.muted
            }, { key: "osd:volume" })
        }
    }

    // Full Noctalia handoff added niri's hardware brightness keys calling
    // this project's own IPC (shell.qml's "brightness" target) instead of
    // `noctalia msg brightness-up`. That's what makes Brightness stop
    // being effectively dead code: it was only ever referenced from
    // pages/MediaExpanded.qml (an on-demand page), so nothing forced its
    // first ~8s DDC/CI read to happen until the dashboard was opened -
    // meaning the very first hardware key press after every boot would
    // silently no-op for the whole read. This Connections target, same
    // trick as Audio/Media above, forces it to start at shell launch
    // instead. Kinds.table already had an "osd.brightness" entry and
    // OsdPeek.qml already renders it (both since whichever slice added
    // MediaExpanded's brightness slider) - this just finally connects it,
    // giving brightness keys the same OSD feedback volume keys already had.
    Connections {
        target: Brightness
        function onValueChanged() {
            if (Brightness.value < 0) return
            // Same generalization as the volume guard above, same reason.
            if (Island.isExpanded) {
                return
            }
            Island.show("osd.brightness", {
                kind: "brightness",
                value: Brightness.value
            }, { key: "osd:brightness" })
        }
    }

    Connections {
        target: Media
        function onTrackChanged() {
            if (!Media.available) {
                Island.clearKey("media")
                return
            }
            Island.show("media.track", {
                title: Media.title,
                artist: Media.artist,
                artUrl: Media.artUrl,
                isPlaying: Media.isPlaying
            }, { key: "media" })
        }
    }

    // Slice 6. Urgency-specific priority/duration per the plan's Kinds
    // table (critical: priority 60, stays until dismissed; normal/low:
    // priority 50, 5000/3000ms), passed as per-call overrides rather than
    // baked into core/Kinds.qml's generic "notification" entry, since
    // those vary per notification, not per kind. `requeue: true` on that
    // entry already handles a lower-priority current transient getting
    // preempted and re-shown after.
    Connections {
        target: Notifs
        function onReceived(notification) {
            const isCritical = notification.urgency === NotificationUrgency.Critical
            const isLow = notification.urgency === NotificationUrgency.Low
            const key = "notif:" + notification.id

            // Slice 1. History already has this notification (Notifs.qml's
            // onNotification appends before emitting `received`), so
            // suppressing the peek here doesn't lose INBOX. Must expire()
            // immediately on this path: nothing else will. The only other
            // close path is onTransientEnded below, which never runs for a
            // notification that never became a transient - without this,
            // every DND-suppressed notification stays tracked forever and
            // a sender waiting on NotificationClosed (notify-send --wait)
            // hangs, the same class of bug refuter already caught once for
            // queue-evicted notifications.
            if (Notifs.dnd && !isCritical) {
                notification.expire()
                return
            }

            Island.show("notification", { notification: notification }, {
                key: key,
                priority: isCritical ? 60 : 50,
                duration: isCritical ? -1 : (isLow ? 3000 : 5000)
            })

            // Dynamic connection, not a Connections block: notifications
            // arrive and are destroyed at runtime, one at a time, so there's
            // no fixed target to declare a Connections{} against ahead of
            // time. Covers both an external close (the sending app calls
            // CloseNotification, or the user dismisses it some other way)
            // and NotificationPeek.qml's own action-invoke dismiss.
            notification.closed.connect(function () {
                Island.clearKey(key)
            })
        }
    }

    // refuter-caught: setting `tracked = true` above takes on responsibility
    // for eventually closing the notification ourselves - Quickshell's
    // NotificationServer doesn't implement expiry, it just hands the shell
    // `expireTimeout` and expects it to act. Without this, a notification
    // that timed out in our UI (or got queue-cap evicted before ever
    // showing) stayed tracked forever: unbounded growth, and any sender
    // waiting on the D-Bus NotificationClosed signal (e.g. notify-send
    // --wait) hung indefinitely.
    Connections {
        target: Island
        function onTransientEnded(t, reason) {
            if (t.kind !== "notification") return
            const n = t.payload && t.payload.notification
            if (!n) return
            if (reason === "timeout" || reason === "dropped") {
                n.expire()
            } else if (reason === "dismissed") {
                n.dismiss()
            }
            // "preempted": requeue:true on this kind means it's still
            // queued and will show again later - not actually done yet.
            // "cleared": only reachable here because Island.clearKey was
            // already called, which for this kind only ever happens from
            // the notification's own `closed` signal above (or
            // NotificationPeek.qml's dismiss()/invoke() calls, which also
            // route through `closed`) - i.e. it's already closed. Closing
            // it again hits the same "Cannot close destroyed notification"
            // error refuter found on the action-invoke double-dismiss.
        }
    }

    // Slice 7. No payload: pages/WorkspacePeek.qml reads the live
    // services/Workspaces.qml singleton directly, same as the notification
    // page reads its live Notification object.
    Connections {
        target: Workspaces
        function onActiveChanged() {
            Island.show("workspace", {}, {})
        }
    }

    // Slice 8. No payload: pages/PowerPeek.qml reads the live
    // services/Battery.qml singleton directly. This desktop has no
    // battery at all, so this never fires here in practice - only
    // reachable via the demo/IPC path on this machine.
    Connections {
        target: Battery
        function onChargerChanged() {
            Island.show("power", {}, {})
        }
    }

    // No signal to react to here (unlike Audio/Media/Brightness above) -
    // this exists purely to force SystemStats to stop being lazy, same
    // reasoning as Brightness: it was only ever referenced from the
    // on-demand MediaExpanded page, so its poll Timer never started until
    // the dashboard was first opened, compounding CPU%'s own "needs two
    // samples" wait with the poll not even having begun yet. The maintainer:
    // "the cpu stats thing comes in late." Referencing it here starts
    // polling at shell launch instead, so by the time anyone actually
    // opens the dashboard, real numbers are usually already sitting
    // there waiting.
    Connections {
        target: SystemStats
    }
}
