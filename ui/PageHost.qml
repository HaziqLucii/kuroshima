import QtQuick
import qs.theme

// Two-slot synchronous Loader crossfade. No StackView: its transitions
// assume the container owns the size, which breaks the "morph the capsule
// to the incoming page's size" behavior this needs.
Item {
    id: root

    // name -> Component, set by the consumer (Capsule.qml).
    property var pageMap: ({})
    property string pageName: ""
    property var pendingPayload: null
    // "fade" (default, every existing call site): plain crossfade, riseX
    // never leaves 0, behavior unchanged. "pushRight"/"popLeft": a real
    // horizontal slide on top of the same fade, for a page pushed onto
    // (and popped back off of) the normal dashboard - see
    // pages/SettingsExpanded.qml.
    property string pendingDirection: "fade"

    property bool aActive: true
    property Loader pendingIncoming: null

    // Loader.item's actual declared type is QObject (Loader can host
    // non-visual components too), so typing this as Item is a static
    // mismatch qmllint flags even though every page here always is one.
    // Typing it QtObject instead "fixes" that but breaks the
    // implicitWidth/implicitHeight access below instead (missing-property
    // on QObject) since those aren't members of the generic type either:
    // there's no way to satisfy qmllint here without a runtime cast QML
    // doesn't have. Keeping Item: one warning beats two, and it's correct
    // at runtime.
    readonly property Item currentItem: (aActive ? slotA : slotB).item
    readonly property real targetWidth: currentItem ? currentItem.implicitWidth : 0
    readonly property real targetHeight: currentItem ? currentItem.implicitHeight : 0
    // Per-state radius (page contract, alongside implicitWidth/Height):
    // each page declares its own design-spec radius since the design ties
    // radius to state, not one fixed value. Falls back to Theme.radius for
    // a page that hasn't declared cornerRadius (shouldn't happen once every
    // page in pageMap does, but a missing property read would otherwise be
    // a hard QML error rather than a graceful default).
    readonly property real targetRadius: currentItem && currentItem.cornerRadius !== undefined ? currentItem.cornerRadius : Theme.radius

    implicitWidth: targetWidth
    implicitHeight: targetHeight

    function setPage(name, payload, direction = "fade") {
        if (name === pageName) {
            // Same-page payload update (e.g. a coalesced volume OSD):
            // update in place, no reload, no crossfade.
            if (currentItem) {
                currentItem.payload = payload
            }
            return
        }

        const component = pageMap[name]
        if (!component) {
            console.warn("PageHost: unknown page", name)
            return
        }

        pageName = name
        pendingPayload = payload
        pendingDirection = direction

        const incoming = aActive ? slotB : slotA
        pendingIncoming = incoming
        // Force a fresh instance even if this slot already holds the exact
        // same Component reference (most page names share the DummyWide
        // placeholder right now, and will keep sharing Components even
        // once real pages land, e.g. two different notifications both
        // mapping to NotificationPeek). Loader.sourceComponent is a
        // silent no-op when assigned the same value, which would mean
        // `loaded` never fires, `pendingIncoming`/`pageName` desync from
        // what's actually on screen, and the incoming page never appears.
        incoming.sourceComponent = null
        incoming.sourceComponent = component
    }

    function handleLoaded(loader) {
        if (loader !== pendingIncoming) {
            return
        }
        pendingIncoming = null

        if (loader.item) {
            loader.item.payload = pendingPayload
        }
        pendingPayload = null

        const direction = pendingDirection
        pendingDirection = "fade"

        const maxW = Theme.canvasW - 2 * Theme.topInset
        const maxH = Theme.canvasH - 2 * Theme.topInset
        if (loader.item && (loader.item.implicitWidth > maxW || loader.item.implicitHeight > maxH)) {
            console.warn("PageHost: page", pageName, "exceeds canvas bounds")
        }

        const outgoing = aActive ? slotA : slotB

        // Slide distance is each item's own implicitWidth, not a fixed
        // theme constant - correct regardless of how wide the incoming/
        // outgoing page actually is.
        const incomingW = loader.item ? loader.item.implicitWidth : 0
        const outgoingW = outgoing.item ? outgoing.item.implicitWidth : 0

        loader.opacity = 0
        loader.riseY = Motion.fadeRise
        loader.riseX = direction === "pushRight" ? incomingW : direction === "popLeft" ? -incomingW : 0
        loader.visible = true
        // Re-enable explicitly: this slot may have been the *outgoing*
        // side of an earlier crossfade and left disabled below.
        loader.enabled = true

        // Disabled, not just faded: refuter found that when
        // ui/Capsule.qml's Connections re-points its `target` from
        // *inside* onPageChanged (which this exact call chain triggers),
        // Qt updates the target but never tears down the old connection,
        // so the outgoing page keeps receiving signals and stays
        // hit-testable for the whole ~140-280ms crossfade even though
        // it's fading out. Harmless while pages have no controls near
        // center, a real misfire once one does (slice 6's notification
        // actions will).
        outgoing.enabled = false

        crossfade.outgoing = outgoing
        crossfade.incoming = loader
        crossfade.outgoingTargetX = direction === "pushRight" ? -outgoingW : direction === "popLeft" ? outgoingW : 0

        // Flip now, not after the animation: targetWidth/Height must jump
        // to the incoming page's size in the same frame the crossfade
        // starts, so the morph and the fade run together.
        aActive = !aActive

        crossfade.restart()
    }

    // riseY backs the design's fadeUp keyframe (translateY(4px) -> 0), via
    // a Translate transform: Loader has no "y offset independent of anchors"
    // property of its own, and this slot is anchors.centerIn'd. riseX is
    // the same idea for the pushRight/popLeft slide - 0 for a plain fade,
    // never independently touched otherwise.
    Loader {
        id: slotA
        asynchronous: false
        anchors.centerIn: parent
        layer.enabled: opacity < 1
        property real riseY: 0
        property real riseX: 0
        transform: Translate { x: slotA.riseX; y: slotA.riseY }
        onLoaded: root.handleLoaded(slotA)
    }
    Loader {
        id: slotB
        asynchronous: false
        anchors.centerIn: parent
        layer.enabled: opacity < 1
        property real riseY: 0
        property real riseX: 0
        transform: Translate { x: slotB.riseX; y: slotB.riseY }
        onLoaded: root.handleLoaded(slotB)
    }

    ParallelAnimation {
        id: crossfade
        property Loader outgoing: null
        property Loader incoming: null
        // 0 for a plain fade (outgoing.riseX just animates 0 -> 0, a
        // no-op) - only pushRight/popLeft ever set this to something else.
        property real outgoingTargetX: 0

        // The design only specifies the enter keyframe (fadeUp); the exit
        // here mirrors it (fade + drop by fadeRise) for a symmetric feel.
        ParallelAnimation {
            NumberAnimation {
                target: crossfade.outgoing; property: "opacity"; to: 0
                duration: Motion.fadeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.fadeBezier
            }
            NumberAnimation {
                target: crossfade.outgoing; property: "riseY"; to: Motion.fadeRise
                duration: Motion.fadeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.fadeBezier
            }
            NumberAnimation {
                target: crossfade.outgoing; property: "riseX"; to: crossfade.outgoingTargetX
                duration: Motion.fadeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.fadeBezier
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: Motion.fadeInDelay }
            ParallelAnimation {
                NumberAnimation {
                    target: crossfade.incoming; property: "opacity"; to: 1
                    duration: Motion.fadeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.fadeBezier
                }
                NumberAnimation {
                    target: crossfade.incoming; property: "riseY"; to: 0
                    duration: Motion.fadeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.fadeBezier
                }
                NumberAnimation {
                    target: crossfade.incoming; property: "riseX"; to: 0
                    duration: Motion.fadeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.fadeBezier
                }
            }
        }

        onFinished: {
            if (crossfade.outgoing) {
                crossfade.outgoing.sourceComponent = null
                crossfade.outgoing.visible = false
            }
        }
    }
}
