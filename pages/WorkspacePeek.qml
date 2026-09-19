import QtQuick
import qs.theme
import qs.services

// No payload needed: reads straight from the live services/Workspaces.qml
// singleton, same reasoning as pages/NotificationPeek.qml/MediaExpanded.qml
// binding live rather than snapshotting - workspace state is inherently
// singleton-scoped, not a per-event value to carry.
Item {
    id: root

    property var payload: null
    // Declared but unused: present so ui/Capsule.qml's generic
    // Connections to whatever page is current doesn't warn about a
    // missing signal every time this page is shown.
    signal requestExpand(string pageId)
    readonly property real cornerRadius: Theme.radius

    implicitWidth: content.implicitWidth + 32
    implicitHeight: Theme.peekH
    width: implicitWidth
    height: implicitHeight

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 12

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.inkFaint
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.letterSpacing: 2
            text: "WS"
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // model is the COUNT, not the array itself: every handled
            // event in services/Workspaces.qml assigns `list` a brand new
            // array of brand new objects, even when only one workspace's
            // `active` flag actually moved. refuter proved a Repeater
            // whose model IS that array tears down and recreates every
            // delegate on each such change (each new dot gets built
            // already at its final width, since a Behavior can't animate
            // a property's very first binding evaluation on a freshly
            // created object) - the pill never visibly animates, it just
            // snaps. Keying off the length instead means delegates persist
            // across a pure activation change (the count doesn't change),
            // and each one's own `ws` binding re-evaluates in place when
            // `Workspaces.list` changes, which a Behavior CAN animate.
            Repeater {
                model: Workspaces.list.length

                Rectangle {
                    id: dot
                    required property int index
                    readonly property var ws: Workspaces.list[index]

                    anchors.verticalCenter: parent.verticalCenter
                    width: dot.ws && dot.ws.active ? 14 : 5
                    height: 5
                    radius: dot.ws && dot.ws.active ? 3 : 2.5
                    color: dot.ws && dot.ws.active ? Theme.ink : Theme.divider

                    Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 11
            // Only reachable with an empty list via the demo/IPC path
            // (app/Bridges.qml's real trigger only fires once at least one
            // workspace is confirmed active) or on a non-niri host -
            // "0 / 0" reads as broken, so it falls back to a plain dash.
            text: Workspaces.list.length > 0
                ? ((Workspaces.activeIndex + 1) + " / " + Workspaces.list.length)
                : "-"
        }
    }
}
