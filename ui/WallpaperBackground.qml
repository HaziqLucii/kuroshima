import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// niri has no built-in desktop-background mechanism (unlike KDE, which is
// what the ported carousel this sits alongside - kuro-wallpaper - relied
// on via `plasma-apply-wallpaperimage`). Something has to actually paint
// the chosen image full-screen; this is that something, always-on for
// the shell's whole lifetime, independent of whether the picker overlay
// is currently open. It only ever reads Wallpaper.currentPath - it has no
// picking logic of its own.
PanelWindow {
    id: root

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    // Not exclusiveZone: a background layer must never reserve space the
    // way the island's own top-anchored bar does (see IslandWindow.qml) -
    // it sits behind everything, full-bleed.
    exclusionMode: ExclusionMode.Ignore
    color: "#000000"

    WlrLayershell.namespace: "kuroshima-wallpaper-bg"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Two stacked Image layers instead of one, so a wallpaper change
    // (from the carousel's commit(), or its own live-preview while
    // arrowing) crossfades instead of popping instantly. Whichever layer
    // is "inactive" gets the new source; once it actually finishes
    // decoding (status: Image.Ready - not just after source is set, so a
    // slow decode never crossfades in a still-blank frame) it becomes
    // active, triggering both layers' state Transition at once: the
    // incoming layer settles from a slight zoom-in to rest while fading
    // in, the outgoing layer zooms out slightly while fading out.
    Item {
        id: canvas
        anchors.fill: parent

        property int activeLayer: 0

        function crossfadeTo(path) {
            const url = path ? "file://" + path : ""
            const nextIndex = canvas.activeLayer === 0 ? 1 : 0
            const next = nextIndex === 1 ? layerB : layerA
            if (next.source.toString() === url) {
                // Re-arrowing back onto whatever this layer already holds
                // (the previous-previous image) - reassigning source to
                // the value it already has is a no-op in QML, no change
                // signal fires, so onStatusChanged's Ready check below
                // would never re-trigger and the crossfade would silently
                // stall on this step, only catching up (skipping straight
                // past this image) once a genuinely different path came
                // in. Already loaded, so just flip immediately.
                canvas.activeLayer = nextIndex
            } else {
                next.source = url
                // onStatusChanged (Ready) below handles the flip once this
                // actually finishes decoding.
            }
        }

        Image {
            id: layerA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            state: canvas.activeLayer === 0 ? "active" : "inactive"
            states: [
                State { name: "active"; PropertyChanges { layerA.opacity: 1; layerA.scale: 1.0 } },
                State { name: "inactive"; PropertyChanges { layerA.opacity: 0; layerA.scale: 1.06 } }
            ]
            transitions: Transition {
                NumberAnimation { properties: "opacity,scale"; duration: 480; easing.type: Easing.OutCubic }
            }
            onStatusChanged: if (status === Image.Ready) canvas.activeLayer = 0
        }

        Image {
            id: layerB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            state: canvas.activeLayer === 1 ? "active" : "inactive"
            states: [
                State { name: "active"; PropertyChanges { layerB.opacity: 1; layerB.scale: 1.0 } },
                State { name: "inactive"; PropertyChanges { layerB.opacity: 0; layerB.scale: 1.06 } }
            ]
            transitions: Transition {
                NumberAnimation { properties: "opacity,scale"; duration: 480; easing.type: Easing.OutCubic }
            }
            onStatusChanged: if (status === Image.Ready) canvas.activeLayer = 1
        }

        Component.onCompleted: canvas.crossfadeTo(Wallpaper.currentPath)
        Connections {
            target: Wallpaper
            function onCurrentPathChanged() { canvas.crossfadeTo(Wallpaper.currentPath) }
        }
    }
}
