import QtQuick
import qs.theme

// payload: { kind: "volume"|"brightness", value: 0..1, muted?: bool }
// Same page serves both osd.volume and osd.brightness (Kinds.table maps
// both to "OsdPeek"), distinguished by payload.kind. Layout/size/radius are
// the design's OSD state (C) verbatim: fixed 320x58, r20, a label+value row
// over a full-width thin bar, not content-driven like the other pages.
Item {
    id: root

    property var payload: null
    // Declared but unused: an OSD peek isn't click-to-expand. Present so
    // ui/Capsule.qml's generic Connections to whatever page is current
    // doesn't warn about a missing signal every time this page is shown.
    signal requestExpand(string pageId)
    readonly property real cornerRadius: Theme.osdRadius

    readonly property string kind: payload ? payload.kind : "volume"
    readonly property real value: payload ? payload.value : 0
    readonly property bool muted: root.kind === "volume" && payload ? !!payload.muted : false

    readonly property string label: root.kind === "brightness" ? "BRI" : (root.muted ? "MUTE" : "VOL")
    readonly property string jp: root.kind === "brightness" ? "輝度" : "音量"
    readonly property int displayValue: Math.round((root.muted ? 0 : root.value) * 100)

    implicitWidth: Theme.osdW
    implicitHeight: Theme.osdH
    width: implicitWidth
    height: implicitHeight

    Column {
        anchors.fill: parent
        anchors.margins: 0
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 11
        anchors.bottomMargin: 11
        spacing: 9

        Item {
            width: parent.width
            height: valueText.implicitHeight

            Row {
                anchors.left: parent.left
                // Not anchors.baseline: Row's own baselineOffset is always
                // 0, so anchoring a Row to another item's baseline aligns
                // the Row's TOP (not its text) to that baseline, dropping
                // this whole row ~17px too low and overrunning into the bar
                // below (refuter-caught, verified on a standalone replica).
                anchors.verticalCenter: valueText.verticalCenter
                spacing: 8

                Text {
                    color: Theme.inkMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 2
                    text: root.label
                }
                Text {
                    color: Theme.inkDim
                    font.family: Theme.fontFamilyJp
                    font.pixelSize: 10
                    text: root.jp
                }
            }

            Text {
                id: valueText
                anchors.right: parent.right
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.Medium
                text: root.displayValue
            }
        }

        Rectangle {
            width: parent.width
            height: 3
            radius: 2
            color: Theme.trackBg

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.muted ? 0 : root.value))
                height: parent.height
                radius: parent.radius
                color: Theme.ink

                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
            }
        }
    }
}
