import QtQuick
import qs.theme

// Click-to-set AND drag-to-scrub bar, used for VOL/MIC/media progress.
// Two handlers, not one: DragHandler (target: null, so it reports pointer
// position without trying to move anything, the standard QtQuick idiom for
// a scrub/slider gesture) gives continuous tracking while the pointer
// moves, but a perfectly still click-release (zero pixel movement) may
// never register as a "drag" at all even with dragThreshold near 0; a
// plain TapHandler alongside it covers that exact case, matching the
// click-to-set behavior this already had.
Item {
    id: root

    property real value: 0 // 0..1, the committed/external value
    property real trackHeight: 3
    property real hitHeight: 18
    property color fillColor: Theme.ink
    property bool showPopover: true

    implicitWidth: 100
    implicitHeight: hitHeight

    readonly property bool dragging: dragHandler.active

    // What the pointer is CURRENTLY over while dragging, not the
    // (possibly still catching up) committed `value` - a caller like
    // Audio.setVolume writes through Pipewire and the binding round-trips
    // back, which can lag a live drag by a frame or two. Falls back to
    // `value` when not dragging, so a caller can just bind popoverLabel
    // (and the fill below) to this unconditionally.
    readonly property real previewValue: dragHandler.active
        ? (_pctFromX(dragHandler.centroid.position.x) / 100) : root.value
    property string popoverLabel: Math.round(root.previewValue * 100) + "%"

    // Continuous: fires on every move while dragging, and once on a plain
    // click. Right for a value that should apply live as you drag it (VOL/
    // MIC). Wrong for anything expensive per-call (refuter-caught: media
    // seeking fired one real MPRIS SetPosition D-Bus call per pointer-move,
    // 60-180 calls for a one-second drag) - callers like that should use
    // scrubFinished instead and read the live position from `previewValue`
    // (which the fill below already tracks) for preview only.
    signal scrub(real pct)
    // Once: on release (drag end) or a plain click. `pct` is the final
    // position, safe to treat as the single, real "apply this" value.
    signal scrubFinished(real pct)

    function _pctFromX(x) {
        return Math.max(0, Math.min(100, (x / root.width) * 100))
    }

    Rectangle {
        id: track
        anchors.centerIn: parent
        width: parent.width
        height: root.trackHeight
        radius: root.trackHeight / 2
        color: Theme.trackBg

        // previewValue, not value: tracks the drag live even for a caller
        // that only commits on scrubFinished (media seeking), and for a
        // continuous caller (VOL/MIC) previewValue still equals value
        // whenever not dragging, so this is a strict improvement either way.
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.previewValue))
            height: parent.height
            radius: parent.radius
            color: root.fillColor
        }
    }

    TapHandler {
        onTapped: (eventPoint) => {
            const pct = root._pctFromX(eventPoint.position.x)
            root.scrub(pct)
            root.scrubFinished(pct)
        }
    }

    DragHandler {
        id: dragHandler
        target: null
        dragThreshold: 0
        property real _lastPct: 0

        // Refuter-caught: centroidChanged fires for the very move that
        // *causes* activation before `active` actually flips true, so an
        // `if (active)` guard in onCentroidChanged alone silently drops
        // that first move - a fast flick compressed into press+one
        // move+release then fires zero scrub() calls at all. Firing here
        // too, on activation, using the now-current centroid position,
        // catches exactly that dropped first move without double-firing
        // (onCentroidChanged's own guard already skipped it while active
        // was still false).
        onActiveChanged: {
            if (active) {
                _lastPct = root._pctFromX(centroid.position.x)
                root.scrub(_lastPct)
            } else {
                root.scrubFinished(_lastPct)
            }
        }
        onCentroidChanged: {
            if (active) {
                _lastPct = root._pctFromX(centroid.position.x)
                root.scrub(_lastPct)
            }
        }
    }

    Rectangle {
        id: popover
        visible: root.showPopover && dragHandler.active
        x: Math.max(0, Math.min(root.width - width, dragHandler.centroid.position.x - width / 2))
        y: -height - 6
        width: popoverLabelText.implicitWidth + 12
        height: popoverLabelText.implicitHeight + 6
        radius: 3
        color: Theme.bg
        border.width: 1
        border.color: Theme.hairline

        Text {
            id: popoverLabelText
            anchors.centerIn: parent
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 9
            text: root.popoverLabel
        }
    }
}
