import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.services

// Face id "clipboard". Drag files onto the file zone from one workspace,
// they stay staged as removable chips, then drag them back out to another
// app in another workspace - real Wayland drag-and-drop on this project's
// own wlr-layer-shell surface, proven working both directions via a
// standalone feasibility spike before any of this was built.
//
// A text-clipboard history section (backed by cliphist) was built and
// tried here too, but dropped: its rows never received clicks/taps no
// matter what was tried, while everything above it (drag-in, drag-out,
// the remove badge) worked correctly throughout - narrowed down to
// something about that section specifically, not chased further since the
// file half stands on its own. See services/Clipboard.qml for the
// surviving piece; there's no ClipboardHistory service anymore.
//
// Tried a dashed-line border around the drop zone first (Haziq's own
// request, to read as "a clipboard tray" at a glance) - dropped it once it
// visibly mismatched the actual chip content's bounds once files were
// staged, plus a real bug it surfaced: chips were a horizontally-scrolling
// ListView, and scrolling past the first ~4 competed with
// pages/CompactPage.qml's own face-swipe DragHandler for the same
// horizontal drag gesture, making chips beyond the visible width
// unreachable. Chips wrap onto a new row instead now (Flow, not ListView) -
// no scrolling needed at all, so that gesture conflict can't happen.
Item {
    id: root

    property var payload: null

    readonly property bool hasFiles: Clipboard.files.length > 0

    implicitWidth: content.width
    implicitHeight: content.height + 32

    Column {
        id: content
        anchors.centerIn: parent
        spacing: 12

        // Persistent header, outside the file drop zone entirely - a
        // single anchor override on one Column child is fine here (Column
        // still drives the overall layout, this just recenters this one
        // short label against fileZone).
        Text {
            id: titleLabel
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.weight: Font.Medium
            font.letterSpacing: 2
            text: "CLIPBOARD"
        }

        // The file drop zone. width/height bound directly to fileContent
        // (the inner Column) rather than using anchors.fill on a
        // positioner, which would be a circular size binding.
        Item {
            id: fileZone
            width: fileContent.width
            height: fileContent.height

            // Plain hover tint, not a border - a dashed outline here
            // visibly stopped matching the actual chip content's bounds
            // once files were staged (see the top-of-file comment).
            Rectangle {
                anchors.fill: parent
                radius: 6
                color: dropZone.containsDrag ? Theme.hairline : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            DropArea {
                id: dropZone
                anchors.fill: parent
                onDropped: drop => {
                    if (drop.hasUrls) {
                        Clipboard.addFiles(drop.urls)
                        drop.accept()
                    }
                }
            }

            Column {
                id: fileContent
                anchors.centerIn: parent
                spacing: 0

                // --- Empty: nothing staged ---
                Item {
                    visible: !root.hasFiles
                    // Real padding around the text, not just the bare text
                    // bounds - the dashed box was hugging the letters with
                    // zero padding, reading as a tight outline instead of a
                    // container.
                    width: idleText.implicitWidth + 40
                    height: Theme.compactH + 10
                    Text {
                        id: idleText
                        anchors.centerIn: parent
                        color: dropZone.containsDrag ? Theme.ink : Theme.inkDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        font.letterSpacing: 1
                        // Stronger prompt while something's actually being
                        // dragged over it, same idle-vs-hover copy swap the
                        // feasibility spike's own toy test already used
                        // ("Drag a file..." vs "DROP HERE").
                        text: dropZone.containsDrag ? "DROP HERE" : "DRAG & DROP HERE"
                    }
                }

                // --- Staged: file chips ---
                // Flow, not a horizontally-scrolling ListView - wraps onto
                // a new row once chips exceed the width instead of hiding
                // extras behind a scroll gesture that turned out to
                // conflict with CompactPage.qml's own face-swipe
                // DragHandler (same top-of-file comment). Flow self-sizes
                // like Column/Row (no explicit height needed, unlike
                // ListView/Flickable), and the whole face already grows
                // smoothly via ui/Capsule.qml's morph however tall this
                // gets.
                Flow {
                    id: chipRow
                    visible: root.hasFiles
                    width: 260
                    spacing: 10

                    Repeater {
                        model: Clipboard.files

                        // Delegate is taller than the chip square itself
                        // (64 vs 56) - the remove badge floats above the
                        // square's own top-right corner via negative anchor
                        // margins, and a plain positioner's implicit-size
                        // math only ever sums each child's own declared
                        // size, blind to a grandchild rendered outside
                        // those bounds. Since this ends up feeding the
                        // whole Capsule's auto-sizing (unlike
                        // ui/WidgetFrame.qml's own badge, which floats
                        // inside a fixed-size WidgetCanvas that never
                        // derives its size this way), an under-measured
                        // delegate meant the capsule rendered shorter than
                        // what was actually painted, and the badge visibly
                        // poked out past the pill's own rounded top edge.
                        // Reserving real headroom here (square anchored to
                        // the delegate's bottom, badge living in the empty
                        // strip above it) fixes that at the source.
                        delegate: Item {
                            id: chip
                            required property int index
                            required property var modelData
                            width: 56
                            height: 64

                            Item {
                                id: square
                                anchors.bottom: parent.bottom
                                width: 56
                                height: 56

                                // Grabbed once the fallback/thumbnail
                                // visual actually settles, used as the
                                // drag-out cursor icon below instead of the
                                // raw source file - Drag.imageSource
                                // pointing straight at chip.modelData.url
                                // rendered the file at its own full native
                                // resolution under the cursor (huge for any
                                // real photo). Grabbing square itself
                                // captures exactly what's already on
                                // screen, correctly sized, and with
                                // transparent (so visually rounded) corners
                                // for free, since square has no background
                                // fill of its own - only its already-
                                // radius-clipped children paint anything.
                                property url dragImageUrl: ""

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: Theme.hairline
                                    border.width: 1
                                    border.color: Theme.divider
                                    visible: art.status !== Image.Ready

                                    Text {
                                        anchors.centerIn: parent
                                        text: chip.modelData.ext
                                        color: Theme.inkMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        font.letterSpacing: 0.5
                                    }
                                }

                                ClippingRectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: "transparent"
                                    visible: art.status === Image.Ready

                                    Image {
                                        id: art
                                        anchors.fill: parent
                                        source: chip.modelData.url
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        // Without this, a dropped photo
                                        // decodes and uploads at its own
                                        // full native resolution just to
                                        // fill a 56x56 square - refuter
                                        // measured +106MB RSS for four
                                        // staged 6000x4000 JPEGs in this
                                        // shell process, which lives for
                                        // the whole session. 2x the
                                        // display size for headroom on
                                        // HiDPI, same precedent as
                                        // ui/WallpaperCarousel.qml's own
                                        // sourceSize cap.
                                        sourceSize: Qt.size(112, 112)
                                        // Ready or Error - both are
                                        // terminal outcomes, and by the
                                        // time either lands the fallback
                                        // Rectangle's own visible binding
                                        // has already settled too, so this
                                        // grabs whichever of the two is
                                        // actually on screen. A non-image
                                        // file (Error) still gets a correct
                                        // drag icon this way - the
                                        // extension-text fallback square,
                                        // not no icon at all.
                                        onStatusChanged: {
                                            if (status === Image.Ready || status === Image.Error)
                                                square.grabToImage(result => { square.dragImageUrl = result.url })
                                        }
                                    }
                                }

                                // target: null - same idiom
                                // pages/CompactPage.qml's own swipeHandler
                                // already uses, for the same reason: an
                                // unset target defaults to moving square
                                // itself, so every drag attempt (even one
                                // that doesn't end in a real OS drop)
                                // permanently nudged the chip's own
                                // position by however far the cursor moved
                                // - this is what was reported as the chip
                                // drifting left/right across repeated drag
                                // attempts. The native OS drag session
                                // itself only cares about Drag.active, not
                                // about the handler visually moving
                                // anything.
                                DragHandler { id: dragOut; target: null }
                                Drag.active: dragOut.active
                                Drag.mimeData: ({ "text/uri-list": chip.modelData.url })
                                Drag.dragType: Drag.Automatic
                                // Real cursor-follow icon for the OS-level
                                // drag - Drag.Automatic only auto-renders a
                                // preview for in-app QML-to-QML drags, a
                                // cross-application Wayland drag needs an
                                // explicit image source. The grabbed
                                // square (see above), not the raw file url
                                // - pointing this straight at
                                // chip.modelData.url rendered the source
                                // file at its own full native resolution
                                // under the cursor.
                                Drag.imageSource: square.dragImageUrl
                            }

                            // Corner remove badge - a sibling of square,
                            // not nested inside it, so square.grabToImage()
                            // (above) doesn't pick up part of the badge
                            // bleeding into the drag-out cursor icon (it
                            // used to, since the badge's negative anchor
                            // margins put part of it back inside square's
                            // own 56x56 grab bounds). Same shape as
                            // ui/WidgetFrame.qml's delete badge otherwise -
                            // splices the staging list only, never touches
                            // the real file. anchors reference square
                            // directly (a sibling, not parent) to keep
                            // sitting at its top-right corner, in the
                            // delegate's own reserved top headroom (see the
                            // delegate-level comment above).
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 3
                                anchors.top: square.top
                                anchors.right: square.right
                                anchors.topMargin: -8
                                anchors.rightMargin: -8
                                color: Theme.bg
                                border.width: 1
                                border.color: Theme.inkDim

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: Theme.inkMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Clipboard.removeFile(chip.index)
                                }
                            }
                        }
                    }
                } // chipRow Flow
            } // fileContent Column
        } // fileZone Item
    }
}
