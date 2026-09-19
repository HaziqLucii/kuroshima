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
    Component { id: osdPeekComponent; OsdPeek {} }
    Component { id: mediaPeekComponent; MediaPeek {} }
    Component { id: mediaExpandedComponent; MediaExpanded {} }
    Component { id: notificationPeekComponent; NotificationPeek {} }
    Component { id: workspacePeekComponent; WorkspacePeek {} }
    Component { id: powerPeekComponent; PowerPeek {} }

    // The animated value is kept separate from the rendered width/height,
    // and the render size is hard-clamped to the fixed layer-shell canvas.
    // A bad Motion.qml tuning value once made this spring numerically
    // diverge to 1,000,000+ px, and MultiEffect's shadow allocates a GPU
    // texture sized to match the item, uncapped by any parent bounds, so
    // that took the GPU (and the whole desktop sharing it) down with it.
    // This clamp holds even if the animation misbehaves again.
    property real animatedWidth: host.targetWidth
    property real animatedHeight: host.targetHeight
    // Radius has no divergence-safety concern the way width/height do (a
    // rounded-rect radius can't blow up a GPU texture the way MultiEffect's
    // shadow can), but it morphs on the same curve for visual consistency
    // with the design, which ties radius to size per state.
    property real animatedRadius: host.targetRadius
    Behavior on animatedWidth { MorphAnimation {} }
    Behavior on animatedHeight { MorphAnimation {} }
    Behavior on animatedRadius { MorphAnimation {} }

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
        radius: root.animatedRadius
        color: Theme.bg
        border.width: 0

        // `inset 0 1px 0 rgba(255,255,255,0.05)` from the design: a hairline
        // top highlight. MultiEffect only does drop shadows, not CSS-style
        // inset shadows, so it's drawn directly instead.
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.insetHighlight
        }

        PageHost {
            id: host
            anchors.centerIn: parent
            // All real now: OsdPeek (slice 4), MediaPeek/MediaExpanded
            // (slice 5), NotificationPeek (slice 6), WorkspacePeek
            // (slice 7), and PowerPeek (slice 8, though never reachable on
            // this desktop's real hardware - no battery at all).
            pageMap: ({
                "compact": compactComponent,
                "OsdPeek": osdPeekComponent,
                "MediaPeek": mediaPeekComponent,
                "MediaExpanded": mediaExpandedComponent,
                "NotificationPeek": notificationPeekComponent,
                "WorkspacePeek": workspacePeekComponent,
                "PowerPeek": powerPeekComponent
            })

            Component.onCompleted: host.setPage(Island.page, Island.payload)
            Connections {
                target: Island
                function onPageChanged() { host.setPage(Island.page, Island.payload) }
                function onPayloadChanged() { host.setPage(Island.page, Island.payload) }
            }

            // The real click contract (plan rule 8): whatever page is
            // currently shown emits requestExpand(pageId) if it wants to
            // (optional per the page contract; CompactPage/OsdPeek/
            // DummyWide/MediaExpanded declare it unused specifically so
            // this Connections doesn't warn about a missing signal every
            // time one of them is current). Connections.target tracks
            // host.currentItem automatically as pages swap.
            Connections {
                target: host.currentItem
                function onRequestExpand(pageId) {
                    Island.expand(pageId)
                    Island.dismiss()
                }
            }
        }

        // Drives rule 7 (hover-hold): pauses a transient's dismiss timer
        // while the cursor sits on the capsule. The controller side of
        // this was implemented and tested from slice 2, but nothing
        // actually set Island.hovered until now, so it was dead code.
        HoverHandler {
            onHoveredChanged: Island.hovered = hovered
        }
    }

    // Slice 3.5 (inserted, not in the original plan): auto-collapse the
    // expanded page after the cursor's been off it for a grace period.
    // Deliberately separate from rule 7's hover-hold: that pauses a
    // transient's own dismiss timer, this collapses expandedPage, which
    // the controller otherwise only changes on explicit expand/collapse/
    // toggle calls, never on a timer. View-level, not controller-level:
    // like the slice-1.5 click toggle, this is UI convenience layered on
    // top of the state machine, not one of its core rules.
    readonly property bool shouldAutoCollapse: Island.isExpanded && !Island.hovered
    onShouldAutoCollapseChanged: {
        if (shouldAutoCollapse) {
            collapseGraceTimer.restart()
        } else {
            collapseGraceTimer.stop()
        }
    }

    Timer {
        id: collapseGraceTimer
        interval: Motion.autoCollapseDelay
        repeat: false
        onTriggered: Island.collapse()
    }
}
