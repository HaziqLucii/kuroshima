import QtQuick
import qs.theme
import qs.services
import qs.faces

// Loaded by pages/SettingsExpanded.qml's Loader for the "faces" category.
// One card per bundled Island Face: a live preview (the real face
// Component, not a hand-built mockup - most are small self-contained
// Items, cheap to instantiate twice; faces/ClipboardFace.qml is the one
// real outlier at ~320 lines, still just an Item with no Process/Timer
// side effects of its own), an enable/disable toggle, and up/down reorder
// arrows. User drop-in faces aren't listed here - see services/Faces.qml's
// own comment on why that half of the original plan was dropped.
//
// Cards, not the original single-line row (live feedback, first version):
// the compact pill's own real width varies a lot face to face (a bare
// clock vs. StatusFace's several glyphs vs. MediaFace's transport row),
// and a fixed ~96px clipped preview window cut most of them off
// mid-content - not a "preview" at all for anything wider than a plain
// clock. Second version gave the preview the panel's full width but still
// forced every face into one shared fixed-height strip, scaling
// ClipboardFace's ~97px-tall idle state down to barely-legible text - and
// the maintainer separately asked for the preview to look like "a dummy
// dynamic island" rather than a plain bordered box. Both fixed the same
// way: each preview is a real, undersized replica of the actual floating
// capsule (ui/Capsule.qml's own radius/background chrome), sized to the
// loaded face's own real implicit size, not a shared box - see the
// preview block's own comment below for the sizing math. `clip: true`
// stays on the replica as a defensive backstop only; correct scale math
// should already guarantee nothing crosses that edge.
//
// This file owns its own local id -> Component map for previews, separate
// from pages/CompactPage.qml's own (identical) map for the real swipeable
// pill. Not deduplicated into services/Faces.qml: a QtObject singleton
// would need `import qs.faces` to hold real Component children, which
// creates a services -> faces -> services module cycle for a purely
// cosmetic dedup - not worth it for a mapping that already has to be
// touched in two other places (services/Faces.qml's `bundled` list,
// pages/CompactPage.qml's own Component list) every time a bundled face
// is added.
Item {
    id: root
    anchors.fill: parent

    Component { id: clockEqComponent; ClockEq {} }
    Component { id: clockDateComponent; ClockDate {} }
    Component { id: statusFaceComponent; StatusFace {} }
    Component { id: systemFaceComponent; SystemFace {} }
    Component { id: weatherFaceComponent; WeatherFace {} }
    Component { id: focusFaceComponent; FocusFace {} }
    Component { id: mediaComponent; MediaFace {} }
    Component { id: clipboardComponent; ClipboardFace {} }

    // Shared with the column legend above the card list and each card's
    // own controlsRow below, so the legend labels land directly over the
    // icons they describe instead of just approximately near them.
    readonly property int _reorderGroupWidth: 34
    readonly property int _toggleWidth: 30

    readonly property var _previewMap: ({
        "clockEq": clockEqComponent,
        "clockDate": clockDateComponent,
        "statusFace": statusFaceComponent,
        "systemFace": systemFaceComponent,
        "weatherFace": weatherFaceComponent,
        "focusFace": focusFaceComponent,
        "media": mediaComponent,
        "clipboard": clipboardComponent
    })

    // Enabled faces first, in their real swipe order, then disabled ones
    // in services/Faces.qml's own declared (bundled) order - stable and
    // predictable, and re-sorts live as the user toggles/reorders, so the
    // list always reads top-to-bottom as "this is the swipe order".
    readonly property var _rows: root._sortedRows()
    function _sortedRows() {
        return Faces.bundled.map(f => ({
            id: f.id,
            label: f.label,
            enabled: Faces.order.indexOf(f.id) !== -1
        })).sort((a, b) => {
            const ai = Faces.order.indexOf(a.id)
            const bi = Faces.order.indexOf(b.id)
            if (ai === -1 && bi === -1) return 0
            if (ai === -1) return 1
            if (bi === -1) return -1
            return ai - bi
        })
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: parent.width
            spacing: 10

            Text {
                color: Theme.inkMuted
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.letterSpacing: 2
                text: "ISLAND FACES"
            }

            // Column legend for the per-card controls below - live
            // feedback: the toggle switch and two bare chevrons read as
            // decoration, not controls, without something naming what they
            // do. One legend row here rather than repeating labels on all
            // 8 cards (noisy) - same "section header above the controls it
            // describes" convention this panel's sibling,
            // pages/SettingsAudioPanel.qml's OUTPUT/INPUT headers, already
            // uses. Column widths (34/30) and the 10px gap between them
            // match _reorderGroupWidth/_toggleWidth below exactly, so
            // these sit directly over the icons they describe.
            Item {
                width: parent.width
                height: legendRow.implicitHeight

                Row {
                    id: legendRow
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        width: root._reorderGroupWidth
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.inkDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.letterSpacing: 1
                        text: "ORDER"
                    }
                    Text {
                        width: root._toggleWidth
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.inkDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.letterSpacing: 1
                        text: "SHOW"
                    }
                }
            }

            Repeater {
                model: root._rows
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    readonly property int _index: Faces.order.indexOf(card.modelData.id)
                    readonly property bool _isFirst: card._index === 0
                    readonly property bool _isLast: card._index === Faces.order.length - 1

                    width: parent.width
                    implicitHeight: cardCol.implicitHeight + 24
                    radius: 6
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.hairline
                    opacity: card.modelData.enabled ? 1 : 0.55

                    Column {
                        id: cardCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 10

                        // refuter-caught: this was a `Row` with children
                        // anchored to its own left/right edges - a `Row`
                        // positions children itself and explicitly refuses
                        // anchor-based positioning on them (a runtime-only
                        // warning, "Row will not function", invisible to
                        // both the lint sweep and the headless boot check
                        // since this panel only loads once Settings > FACES
                        // is actually opened). It happened to look right
                        // because the positioner gave up and the anchors
                        // won by default - fired 8x per toggle/reorder
                        // click (one per card, `_rows` rebuilding fresh
                        // every time). Plain `Item`, which imposes no
                        // positioning of its own, is what left/right
                        // anchors are actually meant to be used inside.
                        Item {
                            width: parent.width
                            height: Math.max(labelText.implicitHeight, controlsRow.implicitHeight)

                            Text {
                                id: labelText
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                color: card.modelData.enabled ? Theme.ink : Theme.inkFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.letterSpacing: 1
                                text: card.modelData.label
                            }

                            Row {
                                id: controlsRow
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                // Reorder arrows: only meaningful (and only
                                // shown) for an enabled card - a disabled
                                // face has no position in the swipe order
                                // to move. Grouped under one fixed-width
                                // Row (root._reorderGroupWidth) so the
                                // "ORDER" legend above lines up with both
                                // arrows together, not just one of them.
                                Row {
                                    width: root._reorderGroupWidth
                                    spacing: 4

                                    Text {
                                        visible: card.modelData.enabled
                                        opacity: card._isFirst ? 0.3 : 1
                                        color: Theme.ink
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        // cod-chevron_up, verified against
                                        // the font's real cmap via
                                        // fontTools before use.
                                        text: String.fromCodePoint(0xeab7)
                                        TapHandler {
                                            enabled: !card._isFirst
                                            onTapped: Faces.moveUp(card.modelData.id)
                                        }
                                    }
                                    Text {
                                        visible: card.modelData.enabled
                                        opacity: card._isLast ? 0.3 : 1
                                        color: Theme.ink
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        // cod-chevron_down, verified
                                        // against the font's real cmap via
                                        // fontTools before use.
                                        text: String.fromCodePoint(0xeab4)
                                        TapHandler {
                                            enabled: !card._isLast
                                            onTapped: Faces.moveDown(card.modelData.id)
                                        }
                                    }
                                }

                                // Enable/disable. Live feedback: the
                                // original filled/outline circle glyph
                                // (same language services/Favorites.qml's
                                // star toggle uses) read as decoration, not
                                // a control, without a caption to explain
                                // it - a real switch (track + sliding
                                // thumb) is a shape people already
                                // recognize as on/off with no label needed.
                                // Same full-invert-on-active language
                                // ui/ToggleButton.qml already established
                                // for this app's TOGGLES grid: Theme.ink
                                // track + Theme.bg thumb when on, not just
                                // a tint. setEnabled() itself refuses to
                                // disable the last remaining face, so this
                                // can't ever silently go to zero.
                                //
                                // refuter-caught: the Behaviors below don't
                                // actually animate in practice. `root._rows`
                                // (this delegate's model) is a fresh JS
                                // array built by `_sortedRows()` on every
                                // Faces.order change, so the Repeater tears
                                // down and recreates every card on every
                                // single toggle/reorder tap - each new
                                // delegate is born already at its final
                                // value, nothing to animate FROM. Fixing
                                // that would mean giving delegates a stable
                                // identity (a ListModel updated with
                                // move()/setProperty() instead of a
                                // reassigned array), real churn for a purely
                                // cosmetic snap-vs-slide difference the user
                                // already confirmed looks "perfect" as-is -
                                // left alone rather than gold-plated.
                                // Everything else about the rebuild is
                                // cheap: each face creates at most one
                                // lightweight SystemClock of its own, every
                                // shared singleton (Focus/Media/Weather/
                                // Clipboard) survives it untouched, and a
                                // synchronous Loader already has `item` set
                                // before the first frame, so there's no
                                // visible flash of the 40x30 fallback size.
                                Rectangle {
                                    id: toggleTrack
                                    width: root._toggleWidth
                                    height: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: 8
                                    color: card.modelData.enabled ? Theme.ink : "transparent"
                                    border.width: 1
                                    border.color: card.modelData.enabled ? Theme.ink : Theme.hairline
                                    Behavior on color { ColorAnimation { duration: 160 } }

                                    Rectangle {
                                        width: 12
                                        height: 12
                                        radius: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: card.modelData.enabled ? parent.width - width - 2 : 2
                                        color: card.modelData.enabled ? Theme.bg : Theme.inkDim
                                        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                    }

                                    TapHandler {
                                        onTapped: Faces.setEnabled(card.modelData.id, !card.modelData.enabled)
                                    }
                                }
                            }
                        }

                        // Preview: an actual dummy replica of the real
                        // floating island capsule (ui/Capsule.qml's own
                        // chrome - radius 15, Theme.bg, no border on the
                        // real one), not a fixed-size clipped window. Live
                        // feedback after an earlier version: "shouldnt we
                        // spawn a dummy dynamic island so we can see the
                        // full replica of the island itself" - and forcing
                        // every face into one shared small strip was also
                        // WHY faces/ClipboardFace.qml's idle state (~97px
                        // tall, the tallest common case - a title label
                        // plus a padded drop zone) rendered as
                        // barely-legible tiny text: it was being scaled
                        // down to fit a 56px-tall box built for the common
                        // ~30px-tall faces. Sized to the loaded face's own
                        // real implicit size instead (same +28px horizontal
                        // padding formula pages/CompactPage.qml's own root
                        // uses for the real pill), so every bundled face
                        // renders at its true native size - `_fitScale`
                        // below is a safety net for anything oversized
                        // enough to need it, not the primary mechanism.
                        Item {
                            width: parent.width
                            height: capsuleReplica.height + 16

                            Rectangle {
                                id: capsuleReplica
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                radius: 15
                                color: Theme.bg
                                // The real capsule has no border - it reads
                                // as a shape against the desktop wallpaper
                                // behind it. This one sits on the settings
                                // panel's own matching Theme.bg background,
                                // so it needs a hairline edge to read as a
                                // shape at all.
                                border.width: 1
                                border.color: Theme.hairline
                                clip: true
                                width: previewLoader.item ? (previewLoader.item.implicitWidth + 28) * previewLoader._fitScale : 40
                                height: previewLoader.item ? previewLoader.item.implicitHeight * previewLoader._fitScale : 30

                                Loader {
                                    id: previewLoader
                                    anchors.centerIn: parent
                                    // refuter-caught: these are the REAL
                                    // face Components, complete with their
                                    // own real TapHandlers/DragHandlers/
                                    // DropArea - without this, tapping a
                                    // preview would actually pause/skip
                                    // real media, start a real focus
                                    // session, or accept a real file drag.
                                    // `enabled: false` disables input
                                    // delivery for the whole loaded subtree
                                    // while leaving it painting normally -
                                    // a look, not a control.
                                    enabled: false
                                    sourceComponent: root._previewMap[card.modelData.id]
                                    // Fixed bounds, not capsuleReplica's own
                                    // size - capsuleReplica's size is
                                    // ITSELF derived from this scale value
                                    // above, so binding the scale calc back
                                    // to it would be circular. 500x140 is
                                    // comfortably under this panel's real
                                    // content width (~550-600px). refuter
                                    // checked every bundled face against it
                                    // (even MediaFace playing, ~260x115):
                                    // none currently need it, this is a
                                    // pure safety net for whatever gets
                                    // added next, not something any face
                                    // relies on today.
                                    readonly property real _fitScale: {
                                        if (!item || item.implicitWidth <= 0 || item.implicitHeight <= 0) return 1
                                        return Math.min(1, 500 / item.implicitWidth, 140 / item.implicitHeight)
                                    }
                                    scale: previewLoader._fitScale
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
