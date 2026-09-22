import QtQuick
import Quickshell
import qs.theme
import qs.services

// Extracted from ui/AppLauncher.qml's own results delegate (was inline)
// once the FAVORITES section needed the identical card shape a second
// time - same convention this project already follows for reusable UI
// pieces (ui/EqualizerBars.qml, ui/WidgetFrame.qml, ui/CountBadge.qml).
//
// tapToLaunch splits the two rows' interaction on purpose: the main
// results row is select-then-launch (tap picks, double-tap or Return
// launches, so arrow-key nav and a stray tap don't fight), while the
// favorites row (tapToLaunch: true) launches on a single tap - the whole
// point of favoriting is fastest possible access, and there's no
// keyboard-nav state to protect there since favorites aren't part of the
// Left/Right/Home/End index at all (ui/AppLauncher.qml).
Item {
    id: card

    required property var app
    property bool current: false
    property bool tapToLaunch: false
    signal launch()
    signal selected()

    readonly property bool favorited: Favorites.ids.includes(app.id)

    width: 84
    height: 84

    TapHandler {
        onTapped: card.tapToLaunch ? card.launch() : card.selected()
        onDoubleTapped: {
            if (!card.tapToLaunch) card.launch()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: card.current ? Theme.hairline : "transparent"
        border.width: 1
        border.color: card.current ? Theme.divider : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Column {
        anchors.centerIn: parent
        spacing: 6

        Item {
            id: iconBox
            anchors.horizontalCenter: parent.horizontalCenter
            width: 40
            height: 40

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: Theme.hairline
                visible: iconImg.status !== Image.Ready
            }
            Image {
                id: iconImg
                anchors.fill: parent
                source: Quickshell.iconPath(card.app.icon, true)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            // Star toggle - a plain glyph, not a ui/WidgetFrame.qml-style
            // badge Rectangle: this whole card is 84x84 with only a 40x40
            // icon, badge chrome would crowd it. Fixed-size hit area
            // wrapping the bare glyph, not just its own tiny ~10px text
            // bounds - same fix faces/MediaFace.qml's transport buttons
            // already needed for the identical reason. Own TapHandler with
            // ReleaseWithinBounds, same established fix this project
            // already applies everywhere a small interactive element sits
            // inside a larger tap target (faces/MediaFace.qml's transport
            // buttons, pages/NotificationPeek.qml's action buttons) - so
            // starring doesn't also select/launch the whole card.
            Item {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: -6
                anchors.rightMargin: -6
                width: 18
                height: 18

                Text {
                    anchors.centerIn: parent
                    // cod-star_full (favorited) / cod-star_empty (not),
                    // fontTools-verified against Theme.fontFamily before
                    // use, same discipline every other icon glyph in this
                    // project follows - 0xeb58 was tried first and turned
                    // out to be cod-squirrel, not a star at all; re-checked
                    // the font's own cmap directly rather than guessing a
                    // neighboring codepoint a second time.
                    text: card.favorited ? String.fromCodePoint(0xeb59) : String.fromCodePoint(0xea6a)
                    color: card.favorited ? Theme.ink : Theme.inkDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: Favorites.toggle(card.app.id)
                }
            }
        }

        Text {
            width: 80
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            text: card.app.name
            color: card.current ? Theme.ink : Theme.inkFaint
            font.family: Theme.fontFamily
            font.pixelSize: 9
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
