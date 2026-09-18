import Quickshell
import Quickshell.Wayland
import qs.theme

// Reserves layout space for the compact pill (tiled windows don't render
// directly under it), separate from IslandWindow, which does the actual
// rendering and stays a floating, non-reserving overlay.
//
// This has to be its own surface: a single PanelWindow can't both be
// centered (anchored top only, so the compositor decides its horizontal
// position) and reserve a nonzero exclusiveZone. That combination hung
// niri's whole layer-shell configure handshake outright, reproduced in
// an isolated test outside this project (confirmed: anchoring top+left+
// right, i.e. full width, loads instantly with the same exclusiveZone
// value; centered top-only never completes). See docs/HANDOFF.md
// ("exclusiveZone hangs niri") for the full incident. A full-width
// invisible spacer sidesteps the ambiguity entirely: its position is
// never in question, so there's nothing for the reservation to be
// circular with.
PanelWindow {
    anchors.top: true
    anchors.left: true
    anchors.right: true
    // topInset above the pill, bottomInset below it (IslandWindow's
    // capsule sits at y: Theme.topInset from this surface's top edge):
    // tuned independently, not symmetric, see Theme.qml.
    exclusiveZone: Theme.compactH + Theme.topInset + Theme.bottomInset
    implicitHeight: Theme.compactH + Theme.topInset + Theme.bottomInset
    color: "transparent"

    WlrLayershell.namespace: "dynamic-island-reserved-space"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Purely a layout reservation: never visible, never interactive.
    mask: Region {}
}
