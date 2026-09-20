import QtQuick
import qs.theme
import qs.services

// Face id "media" - the actual title/artist, not just the EQ glyph
// faces/ClockEq.qml shows. The highest-value new face from the original
// idea list. Elided, not wrapped: a compact pill has no room to grow
// vertically for a long title. Dimmed placeholder when nothing's playing,
// matching this project's established "gone/dimmed when absent" convention
// (TOGGLES, SYSTEM) rather than skipping this face outright when swiped to.
Item {
    id: root

    // Unused - see faces/ClockEq.qml's own comment on why this is here
    // despite the face contract otherwise not needing one.
    property var payload: null

    // content.width, not content.implicitWidth - the Column's own explicit
    // width binding already clamps at 200 (the actual rendered size), but
    // implicitWidth on a Column still reflects its children's natural,
    // unclamped size regardless of that override.
    implicitWidth: content.width
    implicitHeight: Theme.compactH

    Column {
        id: content
        anchors.centerIn: parent
        width: Math.min(200, Math.max(titleText.implicitWidth, artistText.implicitWidth))
        spacing: 1

        Text {
            id: titleText
            width: parent.width
            color: Media.available ? Theme.ink : Theme.inkDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.Medium
            elide: Text.ElideRight
            maximumLineCount: 1
            text: Media.available ? Media.title : "NOTHING PLAYING"
        }

        Text {
            id: artistText
            width: parent.width
            visible: Media.available
            color: Theme.inkFaint
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.letterSpacing: 0.5
            elide: Text.ElideRight
            maximumLineCount: 1
            text: Media.artist
        }
    }
}
