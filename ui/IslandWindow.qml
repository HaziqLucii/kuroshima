import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.ui

PanelWindow {
    id: root

    anchors.top: true
    // -1, not 0: per wlr-layer-shell semantics, 0 means "I don't reserve
    // space myself, but I still respect other surfaces' reservations",
    // which pushed this window below ui/ReservedSpaceWindow.qml's strip
    // instead of overlaying inside it (the actual bug behind the pill
    // rendering below the reserved gap instead of inside it). -1 means
    // "ignore other surfaces' exclusive zones, anchor to the true edge
    // regardless", which is what a floating overlay actually needs once
    // a sibling surface is reserving space. A nonzero *positive* value
    // here (tried: Theme.compactH + Theme.topInset) hung niri's
    // layer-shell configure handshake outright; see docs/HANDOFF.md
    // ("exclusiveZone hangs niri") before ever trying that again, on
    // this window specifically.
    exclusiveZone: -1
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
