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

    Image {
        anchors.fill: parent
        source: Wallpaper.currentPath ? "file://" + Wallpaper.currentPath : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }
}
