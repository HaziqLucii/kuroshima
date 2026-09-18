import QtQuick
import qs.theme

// Shared placeholder for every real peek page that doesn't exist yet
// (NotificationPeek, WorkspacePeek, PowerPeek land in slices 6-8; OsdPeek
// and MediaPeek/MediaExpanded are real as of slices 4-5). Shows
// payload.label so `ipc call island demo <kind>` previews something
// distinguishable for each kind in the meantime. Delete each mapping in
// ui/Capsule.qml's pageMap as its real page lands.
Item {
    id: root

    property var payload: null
    // Declared but unused: present so ui/Capsule.qml's generic
    // Connections to whatever page is current doesn't warn about a
    // missing signal every time this page is shown.
    signal requestExpand(string pageId)
    readonly property real cornerRadius: Theme.radius

    implicitWidth: Math.max(140, labelText.implicitWidth + 48)
    implicitHeight: Math.max(Theme.peekH, labelText.implicitHeight + 24)
    width: implicitWidth
    height: implicitHeight

    Text {
        id: labelText
        anchors.centerIn: parent
        color: Theme.inkMuted
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.letterSpacing: 2
        text: (root.payload && root.payload.label) ? root.payload.label : "DUMMY WIDE PAGE"
    }
}
