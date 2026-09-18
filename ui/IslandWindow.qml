import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.ui

PanelWindow {
    id: root

    anchors.top: true
    exclusiveZone: 0
    color: "transparent"

    implicitWidth: Theme.canvasW
    implicitHeight: Theme.canvasH

    WlrLayershell.namespace: "dynamic-island"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Tracks the capsule's live geometry automatically, so clicks outside
    // it always pass through to the window underneath.
    mask: Region {
        item: capsule
    }

    Capsule {
        id: capsule
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.topInset
    }
}
