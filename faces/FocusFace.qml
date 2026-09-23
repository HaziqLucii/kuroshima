import QtQuick
import qs.theme
import qs.services

// Face id "focusFace". Slice 2. Desktop echo of the maintainer's own
// ~/Projects/kuro-focus "expedition timer" - same dossier aesthetic, no
// sync between the two apps. Idle state shows preset chips (tap to
// start); running/paused state shows a countdown, a hairline progress
// underline, and pause/reset glyphs.
//
// Was going to pin height to exactly Theme.compactH in both states (the
// plan's own original intent) - tried it, and it genuinely overflowed
// the pill live ("too compact that it overflows in the island"). Same
// "the maintainer wanted dynamic sizing, not another tuned constant"
// resolution faces/MediaFace.qml already reached for the identical
// reason: idle stays exactly Theme.compactH (the chip row fits fine,
// no complaint there), the countdown state grows with real padding
// instead of fighting font metrics for an exact fit.
Item {
    id: root

    property var payload: null

    readonly property bool active: Focus.running || Focus.remaining > 0

    implicitWidth: content.width
    implicitHeight: root.active ? content.height + 24 : Theme.compactH

    Column {
        id: content
        anchors.centerIn: parent
        spacing: 8

        // --- Idle: preset chips ---
        Item {
            visible: !root.active
            width: idleRow.width
            height: Theme.compactH

            Row {
                id: idleRow
                anchors.centerIn: parent
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.inkDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.letterSpacing: 1
                    text: "FOCUS"
                }

                Repeater {
                    model: Focus.presets

                    delegate: Item {
                        id: chip
                        required property int modelData
                        anchors.verticalCenter: parent.verticalCenter
                        width: label.implicitWidth + 14
                        height: Theme.compactH - 8

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.hairline
                        }

                        Text {
                            id: label
                            anchors.centerIn: parent
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            text: chip.modelData
                        }

                        // ReleaseWithinBounds - the documented trap
                        // faces/MediaFace.qml's own transport buttons
                        // already caught: a plain default-policy
                        // TapHandler only takes a passive grab, which
                        // doesn't stop pages/CompactPage.qml's own root
                        // TapHandler (anywhere-on-the-pill ->
                        // requestExpand) from also firing for the same
                        // tap.
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: Focus.start(chip.modelData)
                        }
                    }
                }
            }
        }

        // --- Running or paused: countdown ---
        Column {
            id: activeCol
            visible: root.active
            spacing: 8

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.inkDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        text: Focus.phaseLabel
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        text: {
                            const m = Math.floor(Focus.remaining / 60)
                            const s = Focus.remaining % 60
                            return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
                        }
                    }
                }

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22

                    Text {
                        anchors.centerIn: parent
                        color: Theme.inkMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        // fa-pause / fa-play - same codepoints
                        // faces/MediaFace.qml's own transport button
                        // already verified against this font's cmap.
                        text: String.fromCodePoint(Focus.running ? 0xf04c : 0xf04b)
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: Focus.pause()
                    }
                }

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22

                    Text {
                        anchors.centerIn: parent
                        color: Theme.inkMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        // md-restart, fontTools-verified against this
                        // font's cmap before use.
                        text: String.fromCodePoint(0xf0709)
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: Focus.reset()
                    }
                }
            }

            // Plain display bar, not an interactive ScrubBar - same
            // reasoning faces/MediaFace.qml's own progress bar already
            // documents: a mid-swipe pill isn't a sensible place to
            // start a drag gesture.
            Rectangle {
                width: 140
                anchors.horizontalCenter: parent.horizontalCenter
                height: 2
                radius: 1
                color: Theme.trackBg

                Rectangle {
                    width: Focus.totalSeconds > 0
                        ? parent.width * Math.min(1, (Focus.totalSeconds - Focus.remaining) / Focus.totalSeconds)
                        : 0
                    height: parent.height
                    radius: parent.radius
                    color: Theme.ink
                }
            }
        }
    }
}
