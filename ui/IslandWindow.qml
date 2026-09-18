import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.ui

// One surface, not two: an earlier version split rendering (this file)
// from space reservation (a second, separate PanelWindow) specifically to
// dodge a hang (see docs/HANDOFF.md, "exclusiveZone hangs niri"), but that
// left two surfaces measuring "the top" independently, which breaks the
// instant a third-party top-anchored bar with its own exclusive zone is
// in the picture (e.g. Haziq's noctalia bar on the real session, absent
// from the nested-niri test sandbox this was built against): the two
// surfaces would disagree about where "the top" actually is. Fixed by
// refuter's review: a single surface anchored top+left+right does both
// jobs from one shared reference point. exclusiveZone is a distance from
// the anchored edge, independent of the surface's own height, so a tall
// (Theme.canvasH) surface reserving only the compact row's height is
// protocol-legal. For history (this window is full-width now, not
// top-only): refuter confirmed in the wlr-layer-shell spec that top-only
// anchoring was ALSO always the canonical valid case for a positive
// exclusive zone, contradicting an earlier "centered anchor can't
// resolve a positive zone" theory tried on the old version of this file.
// That theory was wrong: the niri hang encountered while building this
// is very likely a genuine niri bug on a spec-legal request, not
// something that wasn't spec-legal in the first place.
PanelWindow {
    id: root

    anchors.top: true
    anchors.left: true
    anchors.right: true
    exclusiveZone: Theme.compactH + Theme.topInset + Theme.bottomInset
    color: "transparent"

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
