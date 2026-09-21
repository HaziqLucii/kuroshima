import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.ui

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
    readonly property string artUrl: payload ? payload.artUrl : ""
    readonly property bool isPlaying: payload ? payload.isPlaying : false

    implicitWidth: contentRow.implicitWidth + 32
    implicitHeight: Theme.peekH
    width: implicitWidth
    height: implicitHeight

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 10

        // Real album art - was always a flat placeholder swatch
        // regardless of whether real art existed (payload.artUrl was
        // already being passed in from app/Bridges.qml, just never
        // actually used here - the maintainer caught it: "the thumbnail
        // isnt shown, it is just grey squircle"). Same squircle treatment
        // pages/MediaExpanded.qml and faces/MediaFace.qml already use for
        // the same Media.artUrl source.
        ClippingRectangle {
            width: 20
            height: 20
            radius: 4
            color: Theme.hairline
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: root.artUrl !== ""
            }
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

        // At the trailing edge, matching faces/MediaFace.qml's own
        // layout - reusing the existing dithered EQ glyph, not new code.
        EqualizerBars {
            anchors.verticalCenter: parent.verticalCenter
            active: root.isPlaying
            barHeight: 12
        }
    }

    // The plan's actual rule-8 example: click a peek to expand it.
    TapHandler {
        onTapped: root.requestExpand("MediaExpanded")
    }
}
