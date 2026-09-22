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
    // FAVORITES row only (ui/AppLauncher.qml sets this alongside
    // tapToLaunch) - drag one favorite card onto another to swap their
    // positions. Off by default so the main results row's cards, sharing
    // this same component, aren't draggable at all.
    property bool reorderable: false
    // The favorites row's ACTUAL rendered id order, set by
    // ui/AppLauncher.qml from the same filtered model the Repeater itself
    // uses - deliberately not read from Favorites.ids directly here. A
    // favorited id whose app got uninstalled is filtered out of the
    // rendered row but stays in Favorites.ids, which would desync
    // "visual slot index" from "index into Favorites.ids" the moment
    // that happens; this keeps the drag-drop slot math against the same
    // list that's actually on screen.
    property var slotIds: []
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

    // Reorder-drag: plain geometry, not Qt's Drag/DropArea protocol.
    // That was tried first (Drag.Internal + DropArea, matching the
    // grabToImage-drag-icon idiom faces/ClipboardFace.qml's chips already
    // proved) and never worked despite four separate targeted fixes -
    // target: card instead of null (needed so the item's bounding box
    // actually moves, since Drag.Internal detects drops via geometric
    // overlap, unlike a real cross-application Drag.Automatic drag where
    // the compositor tracks the cursor independently), Drag.hotSpot set
    // to the card's center instead of the default top-left corner,
    // explicit drag.accept()/drop.accept() in the DropArea, and
    // Qt.callLater-deferring this card's own position reset so it
    // couldn't race the drop check. DropArea.onEntered/onExited fired
    // correctly and consistently right up to release every single time,
    // release position was confirmed (via a live console.log trail)
    // well within the target's bounds every single time, and
    // DropArea.onDropped never fired even once. Whatever's actually
    // wrong sits deeper than any of those four fixes reached - not
    // worth chasing further given the row is only ever up to 4 fixed-
    // width cards in a known layout, which plain arithmetic on card.x
    // (already reliably tracked all along, confirmed in every one of
    // those same logs) solves directly with no protocol involved at all.
    //
    // z bumped while active so the dragged card renders above its
    // siblings as it passes over them (Row doesn't otherwise reorder
    // paint order for a child moved outside its own layout-assigned x/y).
    // Home position captured on drag-start and restored on drag-end -
    // Row only re-lays-out children on structural changes, so it won't
    // "notice" and correct a child's x/y that DragHandler moved on its
    // own; if a swap actually happened, Favorites.ids changing recreates
    // every favorites-row delegate fresh anyway (a plain JS-array model
    // has no persistent per-item identity for Repeater to preserve), so
    // the reset only visibly matters for the "dropped on the same slot,
    // nothing to swap" case.
    property real _homeX: 0
    property real _homeY: 0

    DragHandler {
        id: reorderDrag
        target: card
        enabled: card.reorderable
        onActiveChanged: {
            if (active) {
                card._homeX = card.x
                card._homeY = card.y
                card.z = 1
                return
            }
            // slotWidth matches the favorites Row's own layout exactly
            // (card width 84 + Row's spacing 8, ui/AppLauncher.qml) -
            // nearest whole slot to wherever the card's own x ended up,
            // clamped to a real index. card.slotIds, not Favorites.ids -
            // see that property's own comment for why they can differ.
            const slotWidth = card.width + 8
            const targetIndex = Math.max(0, Math.min(card.slotIds.length - 1, Math.round(card.x / slotWidth)))
            const targetId = card.slotIds[targetIndex]
            // Reset before swap(), not after - Favorites.ids changing
            // destroys this delegate SYNCHRONOUSLY, inside the swap()
            // call itself (a plain JS-array model gives Repeater no
            // persistent identity to preserve across a reorder). Every
            // reference below already resolves off card itself so this
            // ordering is a no-op today, but keeps it that way if a
            // later edit adds anything that isn't.
            card.x = card._homeX
            card.y = card._homeY
            card.z = 0
            if (targetId && targetId !== card.app.id) {
                Favorites.swap(card.app.id, targetId)
            }
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
