import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme

// payload: { notification }. Binds straight to the live Notification
// object (not a plain snapshot like Audio/Media's payloads) since some
// senders update an existing notification's content in place (same id,
// e.g. a progress notification) - that should reactively update the peek,
// not require a whole new show()/re-render cycle.
Item {
    id: root

    property var payload: null
    // Declared but unused: present so ui/Capsule.qml's generic
    // Connections to whatever page is current doesn't warn about a
    // missing signal every time this page is shown.
    signal requestExpand(string pageId)
    readonly property real cornerRadius: Theme.notificationRadius

    readonly property var n: payload ? payload.notification : null
    readonly property bool hasActions: n && n.actions && n.actions.length > 0

    // Quickshell.iconPath(name, fallbackString) does NOT check the icon
    // actually resolves, it just builds an image://icon/... URL regardless
    // - refuter proved that URL then loads Quickshell's own placeholder
    // image (status stays Image.Ready even for a bogus name, so gating on
    // status is a dead end too). The 3rd-arg-bool overload,
    // iconPath(name, true), DOES check existence and returns "" when it
    // can't resolve, which is what actually lets the plain iconSource===""
    // check below fall back to the monogram correctly.
    readonly property string iconSource: {
        if (!n) return ""
        if (n.image && n.image !== "") return n.image
        if (n.appIcon && n.appIcon !== "") return Quickshell.iconPath(n.appIcon, true)
        return ""
    }

    implicitWidth: Theme.notificationW
    implicitHeight: Theme.notificationH
    width: implicitWidth
    height: implicitHeight

    // A critical notification has no timeout (stays until dismissed, by
    // design), and had no dismiss gesture at all - refuter proved it
    // permanently bricks the island (nothing else can show while it's
    // current) until an IPC `dismiss` call. Tapping the card anywhere
    // outside an action button now closes it directly. This relies on the
    // action buttons' own TapHandlers taking an EXCLUSIVE grab
    // (gesturePolicy: ReleaseWithinBounds, set below) - a plain
    // TapHandler's default policy only grabs passively, which refuter
    // proved does NOT stop this ancestor handler from also firing for the
    // same tap.
    TapHandler {
        onTapped: if (root.n) root.n.dismiss()
    }

    // Per the plan: a notification can be destroyed (expired, removed from
    // the server's tracked list) while this page is still animating its
    // exit crossfade. Locking it here keeps the underlying object alive
    // for exactly this page instance's lifetime; PageHost destroys this
    // Item once the crossfade-out finishes, which destroys this lock as
    // its child, releasing it automatically.
    //
    // Guarded on `n.id !== undefined`, not just `n`: services/Demo.qml's
    // fake notification (Notification itself is isCreatable: false, so a
    // demo payload can't be a real instance) is a plain JS object, and
    // RetainableLock.object is a QObject* property - assigning it a
    // non-QObject value doesn't crash, but logs "Unable to assign QJSValue
    // to QObject*" on every demo trigger. A real Notification always has a
    // genuine `id`; the fake one doesn't define it.
    RetainableLock {
        object: (root.n && root.n.id !== undefined) ? root.n : null
        locked: true
    }

    Row {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 13

        ClippingRectangle {
            id: iconBox
            width: 34
            height: 34
            radius: 4
            color: Theme.hairline
            anchors.verticalCenter: parent.verticalCenter

            IconImage {
                anchors.fill: parent
                anchors.margins: 4
                source: root.iconSource
                visible: root.iconSource !== ""
            }
            Text {
                anchors.centerIn: parent
                visible: root.iconSource === ""
                color: Theme.inkMuted
                font.family: Theme.fontFamily
                font.pixelSize: 12
                text: (root.n && root.n.appName) ? root.n.appName.charAt(0).toUpperCase() : "?"
            }
        }

        Column {
            width: parent.width - iconBox.width - 13
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Item {
                width: parent.width
                height: appNameText.implicitHeight

                Text {
                    id: appNameText
                    anchors.left: parent.left
                    color: Theme.inkSubtle
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.letterSpacing: 2
                    text: (root.n && root.n.appName) ? root.n.appName.toUpperCase() : ""
                }
                Text {
                    anchors.right: parent.right
                    color: Theme.inkSubtle
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.letterSpacing: 2
                    text: "NOW"
                }
            }

            Text {
                width: parent.width
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
                text: root.n ? root.n.summary : ""
            }

            // Actions take priority over body when both would otherwise
            // compete for the one remaining line in this fixed 100px-tall
            // peek: the design's own swatch has no room budgeted for both,
            // and an actionable "OK"/"Dismiss" button is more useful here
            // than descriptive text you can't act on from this compact view.
            Text {
                width: parent.width
                visible: !root.hasActions
                color: Theme.inkFaint
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                maximumLineCount: 1
                text: root.n ? root.n.body : ""
            }

            Row {
                visible: root.hasActions
                spacing: 8

                Repeater {
                    model: root.hasActions ? root.n.actions : []

                    Rectangle {
                        required property var modelData

                        implicitWidth: actionLabel.implicitWidth + 16
                        implicitHeight: 20
                        radius: 2
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.hairline

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.letterSpacing: 1
                            text: modelData.text
                        }

                        TapHandler {
                            // ReleaseWithinBounds, not the default
                            // DragThreshold: the default only takes a
                            // PASSIVE grab, so the root Item's own
                            // dismiss-on-tap TapHandler (above) fired
                            // right alongside this one for the exact same
                            // tap - refuter proved every action tap was
                            // still doing invoke()+dismiss() even after
                            // dropping the explicit dismiss() call below,
                            // just via the OTHER handler instead. An
                            // exclusive grab is what actually suppresses
                            // the ancestor's handler for this point.
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: {
                                // Not also calling dismiss() here:
                                // NotificationAction.invoke() already
                                // closes and destroys the notification
                                // itself (standard desktop-notification
                                // convention), so an explicit dismiss()
                                // right after hit an already-destroyed
                                // object every time ("Cannot close
                                // destroyed notification"). This page's own
                                // `closed` handling (app/Bridges.qml) fires
                                // from invoke()'s own close, same as any
                                // other close path.
                                modelData.invoke()
                            }
                        }
                    }
                }
            }
        }
    }
}
