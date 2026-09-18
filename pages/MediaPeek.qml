import QtQuick
import qs.theme

// payload: { title, artist, artUrl, isPlaying } (see app/Bridges.qml)
Item {
    id: root

    property var payload: null
    signal requestExpand(string pageId)
    // No exact design counterpart (the design has no dedicated "media
    // changed" transient: media only ever shows via the idle pill's EQ
    // glyph or inside the full expanded view). Sized/radiused as the
    // closest bucket, the generic "peek" family (state B), since like a
    // hover peek this is the pill grown to show one extra line of info.
    readonly property real cornerRadius: Theme.radius

    readonly property string title: payload ? payload.title : ""
    readonly property string artist: payload ? payload.artist : ""

    implicitWidth: textColumn.implicitWidth + 20 + 32
    implicitHeight: Theme.peekH
    width: implicitWidth
    height: implicitHeight

    Row {
        anchors.centerIn: parent
        spacing: 10

        // No real album art for this slice: a plain placeholder swatch.
        // payload.artUrl loading is Haziq's design-phase work.
        Rectangle {
            width: 20
            height: 20
            radius: 4
            color: Theme.hairline
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            id: textColumn
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 12
                text: root.title
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 220)
            }
            Text {
                color: Theme.inkFaint
                font.family: Theme.fontFamily
                font.pixelSize: 10
                text: root.artist
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 220)
            }
        }
    }

    // The plan's actual rule-8 example: click a peek to expand it.
    TapHandler {
        onTapped: root.requestExpand("MediaExpanded")
    }
}
