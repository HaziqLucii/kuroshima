import QtQuick
import Quickshell
import qs.theme
import qs.services

// Face id "statusFace". Slice 1. Clock plus a glyph row that only shows
// what's true (WIFI, BT, MIC-MUTED, IDLE) - nothing shown when a state is
// off, so the face collapses to just the clock in the machine's default
// state, same "gone when there's genuinely nothing to show" rule used
// throughout this project (pages/CompactPage.qml's own bell,
// MediaExpanded's dimmed toggles). Read-only, no handlers - glyphs reuse
// the exact codepoints already verified for the TOGGLES grid
// (ui/ToggleButton.qml call sites in pages/MediaExpanded.qml). No DND
// glyph here specifically - CompactPage.qml's own shared bell indicator
// already covers it, visible on every face, not just this one; showing it
// a second time here was a plain duplicate (caught live).
Item {
    id: root

    // Unused - see faces/ClockEq.qml's own comment on why this is here
    // despite the face contract otherwise not needing one.
    property var payload: null

    readonly property bool wifiShown: Toggles.wifiAvailable && Toggles.wifiOn
    readonly property bool btShown: Toggles.btAvailable && Toggles.btOn
    readonly property bool micMutedShown: Audio.micAvailable && Audio.micMuted
    readonly property bool idleShown: Toggles.idleInhibit
    // No dndShown here - the maintainer caught it live: pages/CompactPage.qml's
    // own shared bell indicator already swaps to this exact slashed glyph
    // and is visible on every face (not just this one) whenever there's
    // history and DND is on, so showing it a second time here was a plain
    // duplicate, unlike WIFI/BT/MIC/IDLE which have no other indicator
    // anywhere in the pill.
    readonly property bool anyStatus: wifiShown || btShown || micMutedShown || idleShown

    implicitWidth: content.implicitWidth
    implicitHeight: Theme.compactH

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 11

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            font.letterSpacing: 1
            text: Qt.formatDateTime(clock.date, "hh:mm:ss")
        }

        Rectangle {
            visible: root.anyStatus
            width: 1
            height: 11
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.divider
        }

        Row {
            visible: root.anyStatus
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                visible: root.wifiShown
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 12
                text: String.fromCodePoint(0xf05a9) // md-wifi
            }
            Text {
                visible: root.btShown
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 12
                text: String.fromCodePoint(0xf00af) // md-bluetooth
            }
            Text {
                visible: root.micMutedShown
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 12
                text: String.fromCodePoint(0xf131) // fa-microphone_slash
            }
            Text {
                visible: root.idleShown
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 12
                text: String.fromCodePoint(0xf0176) // md-coffee (idle inhibit, matches IDLE toggle's onIconCodepoint)
            }
        }
    }
}
