import QtQuick
import qs.theme
import qs.services
import qs.ui
import qs.faces
import qs.app

// Island Faces: the compact pill hosts a small, self-contained PageHost of
// its own (facesHost below) instead of one fixed layout. Reuses
// ui/PageHost.qml exactly as-is - it's already fully generic (a pageMap plus
// setPage(name, payload, direction)), and ui/Capsule.qml already proved the
// pushRight/popLeft mechanics work for a real page pair (MediaExpanded <->
// SettingsExpanded), so a second, independent instance here gets a real
// spring-eased slide transition between faces for free, no new animation
// code. The notification-bell indicator stays outside facesHost, shared
// across every face rather than duplicated per-face - see faces/*.qml.
Item {
    id: root

    // Page contract (docs/NOTES.md): implicitWidth/Height + payload.
    property var payload: null
    signal requestExpand(string pageId)
    // Page contract addition: per-state radius (design's IDLE state, r15).
    readonly property real cornerRadius: 15

    implicitWidth: content.implicitWidth + 28
    // Was a fixed Theme.compactH - every face stayed pill-sized regardless
    // of content. Now tracks content's own implicitHeight (a Row, so this
    // is just the tallest child's height), which itself tracks whichever
    // face facesHost currently hosts (ui/PageHost.qml's own targetHeight
    // binding already does this reactively - nothing new needed there).
    // The richer "media" face (faces/MediaFace.qml) is the first face
    // that's ever taller than compactH. refuter corrected this comment:
    // it's not a discrete page-swap morph that "picks up" the change -
    // ui/Capsule.qml's own animatedWidth/animatedHeight are continuously
    // bound to host.targetWidth/targetHeight behind a Behavior, so ANY
    // change here (a face swipe, or Media.available flipping mid-face)
    // animates automatically, already proven for MediaExpanded<->
    // SettingsExpanded. That continuity is also what makes a live
    // Media.available flip (nothing playing -> a track starts, without
    // ever swiping faces) resize smoothly instead of leaving a stale
    // capsule size behind.
    implicitHeight: content.implicitHeight
    // Plain Item doesn't self-size from implicitWidth/Height the way a
    // Control does; the page contract relies on width/height tracking it
    // so a host can anchor/center against this item directly.
    width: implicitWidth
    height: implicitHeight

    // Fixed order for now, not user-configurable - a natural fit for the
    // Settings island screen later, not built yet. Clamped at both ends
    // when swiping (matches ui/WallpaperCarousel.qml's own Left/Right
    // precedent), not wrapping.
    readonly property var faceOrder: ["clockEq", "clockDate", "statusFace", "systemFace", "focusFace", "media", "clipboard"]

    function _goToFace(id, direction) {
        facesHost.setPage(id, null, direction)
        Island.setCompactFace(id)
    }

    // refuter-caught: Island.compactFace can end up holding a value that
    // isn't in faceOrder at all (a typo'd `ipc call island setCompactFace`,
    // or a face id renamed out from under a value that survived a hot
    // reload via PersistentProperties) - facesHost.setPage() itself already
    // rejects an unknown id safely (a console.warn, no crash), but that
    // alone leaves Island.compactFace permanently desynced from what's
    // actually showing, and faceOrder.indexOf() then returns -1 forever,
    // silently killing every future swipe in BOTH directions until a full
    // process restart. Self-heals back to the default instead of just
    // failing safe once: reassigning Island.compactFace here re-triggers
    // this same function via the Connections below, this time with a valid
    // id, so it settles in one extra round-trip rather than staying broken.
    function _syncFaceHost() {
        if (root.faceOrder.indexOf(Island.compactFace) === -1) {
            Island.setCompactFace(root.faceOrder[0])
            return
        }
        facesHost.setPage(Island.compactFace, null)
    }

    Component { id: clockEqComponent; ClockEq {} }
    Component { id: clockDateComponent; ClockDate {} }
    Component { id: statusFaceComponent; StatusFace {} }
    Component { id: systemFaceComponent; SystemFace {} }
    Component { id: focusFaceComponent; FocusFace {} }
    Component { id: mediaComponent; MediaFace {} }
    Component { id: clipboardComponent; ClipboardFace {} }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 11

        PageHost {
            id: facesHost
            anchors.verticalCenter: parent.verticalCenter
            pageMap: ({
                "clockEq": clockEqComponent,
                "clockDate": clockDateComponent,
                "statusFace": statusFaceComponent,
                "systemFace": systemFaceComponent,
                "focusFace": focusFaceComponent,
                "media": mediaComponent,
                "clipboard": clipboardComponent
            })

            Component.onCompleted: root._syncFaceHost()
            Connections {
                target: Island
                // Not just Component.onCompleted above - PersistentProperties'
                // own restoration (app/Island.qml) happens on loaded/reloaded,
                // which can land after this page is already created, same
                // race that file's own comments already document for
                // expandedPage. This keeps facesHost correct regardless of
                // which one actually wins. setPage's own same-name guard
                // makes calling it twice for the same face a harmless no-op,
                // not a double crossfade.
                function onCompactFaceChanged() { root._syncFaceHost() }
            }
        }

        Rectangle {
            width: 1
            height: 11
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.divider
            // || Notifs.dnd - refuter caught this live: without it, DND
            // being on has literally no visual confirmation anywhere in
            // the collapsed pill the moment INBOX is empty (a very
            // reachable state, e.g. right after CLEAR ALL), directly
            // contradicting this same slice's own claim that the bell
            // shows "muted" at a glance regardless of which face is
            // showing.
            visible: Notifs.history.length > 0 || Notifs.dnd
        }

        // Same "gone when there's genuinely nothing to show" pattern used
        // throughout this project. "Unread" here just means "history isn't
        // empty" - there's no separate read/unread tracking anywhere else,
        // and CLEAR ALL in the expanded INBOX (Notifs.clearHistory()) is the
        // only thing that empties it, so that's also what makes this
        // disappear (except while DND is on - see the divider above). A
        // single icon, not a separate bell+counter-bubble pair: cod-bell_dot
        // already draws the "unread" indicator as a dot on the bell's own
        // top-right corner - codepoint verified against this font's actual
        // cmap via fontTools before use.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifs.history.length > 0 || Notifs.dnd
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 13
            // Slice 1. Swaps to the slashed glyph while DND is on, so the
            // pill shows "muted" at a glance regardless of which face is
            // showing - codepoint verified against this font's actual
            // cmap via fontTools before use, same as cod-bell_dot was.
            text: String.fromCodePoint(Notifs.dnd ? 0xec08 : 0xeb9a)
        }
    }

    // MediaExpanded stopped being just the media view once CONTROLS,
    // TOGGLES, SYSTEM, INBOX and SESSION landed - it's the whole dashboard
    // now, useful with or without anything playing. Gating this on
    // Media.available (an early-slice leftover from when it really was
    // media-only) made the compact pill silently unclickable whenever no
    // player was active, which is most of the time.
    TapHandler {
        onTapped: root.requestExpand("MediaExpanded")
    }

    // target: null, same idiom as ui/ScrubBar.qml's own DragHandler - reports
    // pointer position without trying to move anything. Paired with the
    // TapHandler above as siblings (not parent/child), no exclusive-grab
    // gesturePolicy needed BETWEEN THESE TWO SPECIFICALLY: Qt's own
    // drag-threshold disambiguation already lets a still tap fall through
    // to it untouched, same as ScrubBar's own tap-or-drag pairing. This
    // does NOT generalize to descendant tap targets, though - refuter
    // caught faces/MediaFace.qml's transport buttons (nested inside
    // facesHost, below this TapHandler) needing their own
    // ReleaseWithinBounds grab, since a plain passive-grab TapHandler
    // does not stop THIS ancestor handler from also firing for the same
    // tap (the exact trap pages/NotificationPeek.qml's own action
    // buttons already document, for the same reason). Direction-only, no
    // live-follow drag preview for v1 - purely a swipe-direction detector,
    // same role WallpaperCarousel.qml's Left/Right keys play, just via
    // touch/mouse.
    //
    // dragThreshold explicitly set to the same constant the release-time
    // delta check already used, not left at Qt's small platform default
    // (~startDragDistance(), a handful of px) - without it, this handler
    // was claiming the exclusive grab on ANY tiny movement anywhere on the
    // pill, including directly on top of faces/ClipboardFace.qml's own
    // chips, before that chip's own (default-threshold) drag-out
    // DragHandler ever got a chance to react at all - confirmed live via a
    // temporary console.log on the chip's handler that never once fired
    // while this bug was live. Now this handler doesn't even start
    // tracking until genuine 40px movement, so a chip's own smaller-
    // threshold drag-out handler wins any short gesture first. A real
    // swipe now needs slightly LESS total movement than before this fix,
    // not literally identical (refuter measured the minimum effective
    // distance: ~49px pre-fix, ~41px post-fix - the old unset-threshold
    // handler could already be mid-gesture, tracking from a small
    // platform-default distance, by the time the release-time 40px check
    // ran, effectively stacking a bit past 40; dragThreshold now gates
    // activation on exactly 40px instead). Close enough not to be felt,
    // but worth naming accurately rather than claiming "identical."
    // centroid.pressPosition, not a hand-tracked _startX captured in
    // onActiveChanged - with a real
    // dragThreshold, active only flips true AFTER the threshold is already
    // exceeded, so capturing "start" position at that point would measure
    // from partway through the gesture, not the true press origin.
    DragHandler {
        id: swipeHandler
        target: null
        dragThreshold: Motion.compactFaceSwipeThreshold

        onActiveChanged: {
            if (active) return

            const delta = swipeHandler.centroid.position.x - swipeHandler.centroid.pressPosition.x
            if (Math.abs(delta) < Motion.compactFaceSwipeThreshold) return

            const idx = root.faceOrder.indexOf(Island.compactFace)
            if (idx === -1) return

            if (delta < 0 && idx < root.faceOrder.length - 1) {
                // Dragged left: next face slides in from the right.
                root._goToFace(root.faceOrder[idx + 1], "pushRight")
            } else if (delta > 0 && idx > 0) {
                // Dragged right: previous face slides in from the left.
                root._goToFace(root.faceOrder[idx - 1], "popLeft")
            }
        }
    }
}
