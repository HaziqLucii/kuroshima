import QtQuick
import qs.theme

// payload: { kind: "volume"|"brightness", value: 0..1, muted?: bool }
// Same page serves both osd.volume and osd.brightness (Kinds.table maps
// both to "OsdPeek"), distinguished by payload.kind.
Item {
    id: root

    property var payload: null
    // Declared but unused: an OSD peek isn't click-to-expand. Present so
    // ui/Capsule.qml's generic Connections to whatever page is current
    // doesn't warn about a missing signal every time this page is shown.
    signal requestExpand(string pageId)

    readonly property string kind: payload ? payload.kind : "volume"
    readonly property real value: payload ? payload.value : 0
    readonly property bool muted: root.kind === "volume" && payload ? !!payload.muted : false

    readonly property real barWidth: 140

    implicitWidth: iconText.implicitWidth + barWidth + 12 + 32
    implicitHeight: Theme.compactH
    width: implicitWidth
    height: implicitHeight

    Row {
        anchors.centerIn: parent
        spacing: 12

        Text {
            id: iconText
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.letterSpacing: 1
            text: root.kind === "brightness" ? "BRI" : (root.muted ? "MUTE" : "VOL")
        }

        Rectangle {
            id: track
            width: root.barWidth
            height: 4
            radius: 2
            color: Theme.hairline
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: track.width * Math.max(0, Math.min(1, root.muted ? 0 : root.value))
                height: parent.height
                radius: parent.radius
                color: Theme.ink
            }
        }
    }
}
