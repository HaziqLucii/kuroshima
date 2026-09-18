import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.theme
import qs.app
import qs.pages

Item {
    id: root

    Component { id: compactComponent; CompactPage {} }
    Component { id: dummyWideComponent; DummyWide {} }

    // The animated value is kept separate from the rendered width/height,
    // and the render size is hard-clamped to the fixed layer-shell canvas.
    // A bad Motion.qml tuning value once made this spring numerically
    // diverge to 1,000,000+ px, and MultiEffect's shadow allocates a GPU
    // texture sized to match the item, uncapped by any parent bounds, so
    // that took the GPU (and the whole desktop sharing it) down with it.
    // This clamp holds even if the animation misbehaves again.
    property real animatedWidth: host.targetWidth
    property real animatedHeight: host.targetHeight
    Behavior on animatedWidth { MorphAnimation {} }
    Behavior on animatedHeight { MorphAnimation {} }

    width: Math.max(0, Math.min(animatedWidth, Theme.canvasW))
    height: Math.max(0, Math.min(animatedHeight, Theme.canvasH))

    // Shadow always-on is fine while the capsule morphs at most a few
    // times a minute; revisit if a future page keeps geometry animating
    // continuously (see Theme.qml / HANDOFF.md for the 200Hz budget note).
    MultiEffect {
        source: background
        anchors.fill: background
        shadowEnabled: true
        shadowColor: Theme.shadowColor
        shadowOpacity: Theme.shadowOpacity
        shadowBlur: Theme.shadowBlur
        shadowVerticalOffset: Theme.shadowVerticalOffset
    }

    ClippingRectangle {
        id: background
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.bg
        border.width: 0

        PageHost {
            id: host
            anchors.centerIn: parent
            // Real peek pages land in slices 4-8; until each one exists,
            // its Kinds.table page name maps to the shared placeholder.
            pageMap: ({
                "compact": compactComponent,
                "dummyExpanded": dummyWideComponent,
                "OsdPeek": dummyWideComponent,
                "MediaPeek": dummyWideComponent,
                "MediaExpanded": dummyWideComponent,
                "NotificationPeek": dummyWideComponent,
                "WorkspacePeek": dummyWideComponent,
                "PowerPeek": dummyWideComponent
            })

            Component.onCompleted: host.setPage(Island.page, Island.payload)
            Connections {
                target: Island
                function onPageChanged() { host.setPage(Island.page, Island.payload) }
                function onPayloadChanged() { host.setPage(Island.page, Island.payload) }
            }
        }

        // Real click contract (plan rule 8) needs a page to emit
        // requestExpand(pageId) for the view to route through
        // Island.expand()/dismiss(); no page does that yet (only
        // CompactPage and the DummyWide placeholder exist), so this
        // toggles a stand-in "dummyExpanded" page directly for now.
        TapHandler {
            onTapped: Island.toggle("dummyExpanded")
        }
    }
}
