import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.ui

// Face id "media". Used to be just title/artist text at a fixed compactH -
// the maintainer wanted it to actually look like a media player once
// something's playing: art thumbnail left, title/artist/progress/transport
// on the right, EqualizerBars (this project's own dithered EQ glyph,
// already proven in faces/ClockEq.qml - no new dithering code, reusing
// the existing one) at the end of the header row. implicitHeight is
// content-derived, not fixed, same "the maintainer wanted dynamic sizing,
// not another tuned constant" reasoning already applied throughout this
// project (NotificationPeek, MediaExpanded) - pages/CompactPage.qml's own
// implicitHeight now tracks whichever face is active, so this face being
// taller than compactH grows the whole pill via ui/Capsule.qml's existing
// continuous width/height Behavior (see pages/CompactPage.qml's own
// comment), no new animation code.
//
// Falls back to the original compact single-line text when nothing's
// playing - the rich player layout only makes sense with real content,
// and a swipe landing on a big mostly-empty player would look wasteful.
Item {
    id: root

    // Unused - see faces/ClockEq.qml's own comment on why this is here
    // despite the face contract otherwise not needing one.
    property var payload: null

    implicitWidth: content.width
    // Only the playing state gets vertical breathing room - the maintainer
    // caught the player content sitting flush against the pill's rounded
    // top/bottom edges ("the top is near the edge"). The idle fallback
    // stays exactly Theme.compactH with no padding added, so "nothing
    // playing" still matches the original compact pill's size exactly.
    // content.centerIn below then splits this evenly, top and bottom.
    implicitHeight: Media.available ? content.height + 24 : content.height

    Column {
        id: content
        anchors.centerIn: parent

        // --- Nothing playing: the original compact text fallback ---
        // Explicit Theme.compactH, not just the text's own implicit
        // height - the maintainer caught this collapsing shorter than the
        // original pill once root's height stopped being a fixed
        // Theme.compactH: "nothing playing better off stick with the
        // compact size original." Only the playing state should ever grow
        // past it.
        Item {
            visible: !Media.available
            width: idleTitle.implicitWidth
            height: Theme.compactH
            Text {
                id: idleTitle
                anchors.centerIn: parent
                color: Theme.inkDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                elide: Text.ElideRight
                maximumLineCount: 1
                text: "NOTHING PLAYING"
            }
        }

        // --- Playing: the richer player layout ---
        Column {
            id: player
            visible: Media.available
            width: 260
            spacing: 10

            Row {
                id: header
                width: parent.width
                spacing: 10

                // Squircle art thumbnail, same clipped-rounded-rect
                // treatment pages/MediaExpanded.qml already uses for the
                // same Media.artUrl source - a fixed size now (the
                // maintainer flagged the whole layout reading too small when
                // this tracked infoCol's own compact 2-line height).
                ClippingRectangle {
                    id: art
                    width: 44
                    height: 44
                    radius: 10
                    color: Theme.hairline

                    Image {
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: Media.artUrl !== ""
                    }
                }

                Column {
                    id: infoCol
                    anchors.verticalCenter: art.verticalCenter
                    width: header.width - art.width - eq.width - 20
                    spacing: 3

                    Text {
                        width: parent.width
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        text: Media.title
                    }
                    Text {
                        width: parent.width
                        color: Theme.inkFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.letterSpacing: 0.5
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        text: Media.artist
                    }
                }

                EqualizerBars {
                    id: eq
                    anchors.verticalCenter: art.verticalCenter
                    active: Media.isPlaying
                    barHeight: 16
                }
            }

            // Plain display bar, not an interactive ScrubBar - a compact
            // pill mid-swipe isn't a sensible place to start a drag
            // gesture (it would fight the face-swipe DragHandler in
            // pages/CompactPage.qml). Seeking is still one tap away via
            // MediaExpanded's own real ScrubBar.
            Rectangle {
                width: parent.width
                height: 3
                radius: 1
                color: Theme.trackBg

                Rectangle {
                    width: Media.isLive ? parent.width
                        : (Media.length > 0 ? parent.width * Math.min(1, Media.position / Media.length) : 0)
                    height: parent.height
                    radius: parent.radius
                    color: Theme.ink
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                // Fixed-size hit areas, not just the bare glyph's own tiny
                // ~10x20px text bounds (refuter measured that against
                // MediaExpanded's own 24x24/26x26 wrapper Items for the
                // same three buttons and called it out as fiddly to tap).
                // gesturePolicy: ReleaseWithinBounds on each TapHandler
                // below is the actual correctness fix, not this - refuter
                // caught a real bug here: a plain default-policy
                // TapHandler only takes a PASSIVE grab, which does NOT
                // stop pages/CompactPage.qml's own root TapHandler
                // (anywhere-on-the-pill -> requestExpand("MediaExpanded"))
                // from ALSO firing for the same tap, so pressing pause was
                // also expanding the whole dashboard. This exact trap is
                // already documented in pages/NotificationPeek.qml's own
                // action buttons for the identical reason - missed here
                // because this page's root tap handler lives one file
                // away (CompactPage.qml, not this one), not obviously in
                // view while writing this face.
                Item {
                    width: 22
                    height: 22
                    Text {
                        anchors.centerIn: parent
                        color: Theme.inkMuted
                        opacity: Media.canGoPrevious ? 1.0 : 0.35
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        // fa-step_backward - same codepoint MediaExpanded.qml
                        // already verified against this font's cmap.
                        text: String.fromCodePoint(0xf048)
                    }
                    TapHandler {
                        enabled: Media.canGoPrevious
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: Media.previous()
                    }
                }
                Item {
                    width: 24
                    height: 24
                    Text {
                        anchors.centerIn: parent
                        color: Theme.ink
                        opacity: Media.canTogglePlaying ? 1.0 : 0.35
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        // fa-pause / fa-play - same codepoints MediaExpanded.qml
                        // already verified against this font's cmap.
                        text: String.fromCodePoint(Media.isPlaying ? 0xf04c : 0xf04b)
                    }
                    TapHandler {
                        enabled: Media.canTogglePlaying
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: Media.togglePlaying()
                    }
                }
                Item {
                    width: 22
                    height: 22
                    Text {
                        anchors.centerIn: parent
                        color: Theme.inkMuted
                        opacity: (Media.canGoNext && !Media.isLive) ? 1.0 : 0.35
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        // fa-step_forward - same codepoint MediaExpanded.qml
                        // already verified against this font's cmap.
                        text: String.fromCodePoint(0xf051)
                    }
                    TapHandler {
                        enabled: Media.canGoNext && !Media.isLive
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: Media.next()
                    }
                }
            }
        }
    }
}
