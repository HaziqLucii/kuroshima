import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.ui

PanelWindow {
    id: root

    anchors.top: true
    // Floating overlay: reserves no space, tiled windows can render
    // directly under it. A nonzero value here (tried: Theme.compactH +
    // Theme.topInset, to reserve just the compact pill's row) hung the
    // whole niri session's layer-shell configure handshake, reproducibly,
    // likely because this surface is centered (anchored top only, not
    // also left+right) and exclusiveZone may need a horizontally-fixed
    // surface to resolve. See docs/HANDOFF.md ("exclusiveZone hangs
    // niri") before trying this again: the fix is a separate,
    // full-width, invisible spacer surface doing the reservation, not
    // this window.
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
