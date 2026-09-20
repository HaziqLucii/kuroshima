import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

// Ported from ~/Projects/cachyos-setup/kuro/theme/config/quickshell/
// kuro-wallpaper (the KDE Kuro rice's own wallpaper carousel - keyboard
// nav, live preview, dim overlay). Two real differences from that
// original, both because this shell is a long-running process instead of
// kuro-wallpaper's "launch fresh, quit on choice" model:
//   - apply()/cancel() hide this window (visible = false) rather than
//     Qt.quit()-ing the whole shell.
//   - "restore whatever was active on open" reads Wallpaper.currentPath
//     directly (same process, same singleton) instead of shelling out to
//     grep a KDE config file for the wallpaper currently in force.
// Everything else - the tile scaling/dimming, the debounced live preview,
// the layer-shell exclusive-focus setup - carries over unchanged; see
// that file's own comments for why each piece is shaped the way it is.
PanelWindow {
    id: root

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: false

    // Exclusive keyboard focus only matters while mapped; an invisible
    // layer surface holds no focus at all, so this doesn't fight the
    // island's own WlrKeyboardFocus.None surface while the picker is closed.
    WlrLayershell.namespace: "kuroshima-wallpaper-carousel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property int sel: 0
    // What was on screen the moment this opened - Esc restores exactly
    // this, not necessarily Wallpaper._persistedPath (which is the same
    // value in practice, since only commit() ever changes either, but
    // this local snapshot is what the carousel's own contract is really
    // about: "put back what you saw when you opened this").
    property string _openedWith: ""

    function toggle() {
        if (root.visible) {
            root._cancel()
        } else {
            root._open()
        }
    }

    function _open() {
        root._openedWith = Wallpaper.currentPath
        const base = root._openedWith.split("/").pop()
        for (let i = 0; i < files.count; i++) {
            if (files.get(i, "fileName") === base) {
                root.sel = i
                break
            }
        }
        root.visible = true
        Qt.callLater(() => focusScope.forceActiveFocus())
    }

    function _apply() {
        if (files.count === 0) {
            root.visible = false
            return
        }
        preview.stop()
        Wallpaper.commit(root.dir + "/" + files.get(root.sel, "fileName"))
        root.visible = false
    }

    function _cancel() {
        // Same reason _apply() stops it: without this, a debounced
        // preview from the last arrow press can still land ~220ms after
        // Esc, silently overwriting the just-reverted wallpaper back to
        // whatever tile was last hovered. The KDE original this was
        // ported from never hit this - Qt.quit() killed its process
        // before the timer fired - but this shell stays alive, so the
        // race became reachable. refuter caught it live.
        preview.stop()
        Wallpaper.revert()
        root.visible = false
    }

    readonly property string dir: Wallpaper.dir

    FolderListModel {
        id: files
        folder: "file://" + root.dir
        nameFilters: ["*.png", "*.jpg", "*.jpeg"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    // Selection changes preview live, but debounced: holding an arrow key
    // would otherwise call Wallpaper.preview() once per key-repeat.
    Timer {
        id: preview
        interval: 220
        onTriggered: {
            if (files.count === 0) {
                return
            }
            Wallpaper.preview(root.dir + "/" + files.get(root.sel, "fileName"))
        }
    }
    onSelChanged: if (root.visible) preview.restart()

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.34
    }

    Item {
        id: focusScope
        anchors.fill: parent
        focus: true

        Shortcut { sequence: "Left"; onActivated: root.sel = Math.max(0, root.sel - 1) }
        Shortcut { sequence: "Right"; onActivated: root.sel = Math.min(files.count - 1, root.sel + 1) }
        Shortcut { sequence: "Home"; onActivated: root.sel = 0 }
        Shortcut { sequence: "End"; onActivated: root.sel = files.count - 1 }
        Shortcut { sequences: ["Return", "Enter"]; onActivated: root._apply() }
        Shortcut { sequence: "Esc"; onActivated: root._cancel() }

        // ── header ──────────────────────────────────────────────────
        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: strip.top
            anchors.bottomMargin: 40
            spacing: 6

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 9
                Text {
                    text: "WALLPAPER"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.letterSpacing: 3.2
                }
                Text {
                    text: "壁紙"
                    color: Theme.inkDim
                    font.family: Theme.fontFamilyJp
                    font.pixelSize: 12
                }
            }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                // Layout.preferredWidth/Height, not width/height: this
                // Rectangle is a ColumnLayout child, and qmllint correctly
                // flags plain width/height there as undefined behavior
                // (the layout is what's supposed to own sizing) - a latent
                // issue in the original kuro-wallpaper source this was
                // ported from, worth fixing here even though it evidently
                // never caused a visible problem there.
                Layout.preferredWidth: 190
                Layout.preferredHeight: 1
                color: Theme.hairline
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: files.count === 0 ? "—"
                    : String(root.sel + 1).padStart(2, "0") + " / " + String(files.count).padStart(2, "0")
                color: Theme.inkMuted
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 1.6
            }
        }

        // ── carousel ────────────────────────────────────────────────
        Item {
            id: strip
            anchors.centerIn: parent
            width: parent.width
            height: 150

            readonly property int tileW: 340
            readonly property int tileH: 144
            readonly property int gap: 26

            Row {
                id: row
                spacing: strip.gap
                y: 0
                x: strip.width / 2 - strip.tileW / 2
                   - root.sel * (strip.tileW + strip.gap)
                Behavior on x { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }

                Repeater {
                    model: files
                    delegate: Item {
                        required property int index
                        required property string fileName
                        width: strip.tileW
                        height: strip.tileH

                        readonly property bool current: index === root.sel

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * (parent.current ? 1.0 : 0.84)
                            height: parent.height * (parent.current ? 1.0 : 0.84)
                            color: Theme.bg
                            border.width: 1
                            border.color: parent.current ? Theme.ink : Theme.hairline
                            opacity: parent.current ? 1.0 : 0.42
                            Behavior on width { NumberAnimation { duration: 160 } }
                            Behavior on height { NumberAnimation { duration: 160 } }
                            Behavior on opacity { NumberAnimation { duration: 160 } }

                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                source: "file://" + root.dir + "/" + fileName
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 680
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.bottom
                            anchors.topMargin: 14
                            text: fileName.replace(/\.(png|jpe?g)$/i, "")
                            color: Theme.inkMuted
                            visible: parent.current
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 1.2
                        }
                    }
                }
            }
        }

        // ── statusline ──────────────────────────────────────────────
        RowLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: strip.bottom
            anchors.topMargin: 66
            spacing: 22
            Repeater {
                model: [["←  →", "SELECT"], ["ENTER", "APPLY"], ["ESC", "CANCEL"]]
                delegate: RowLayout {
                    required property var modelData
                    spacing: 7
                    Text {
                        text: modelData[0]
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                    Text {
                        text: modelData[1]
                        color: Theme.inkDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.letterSpacing: 1.4
                    }
                }
            }
        }

        Text {
            visible: files.count === 0
            anchors.centerIn: parent
            text: "NO WALLPAPERS IN " + root.dir
            color: Theme.inkDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }
}
