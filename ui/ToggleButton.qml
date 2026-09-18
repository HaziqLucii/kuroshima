import QtQuick
import qs.theme

// One cell of the design's "04 TOGGLES" grid. Real icon glyphs, not text
// abbreviations, per Haziq: pulled from JetBrainsMono Nerd Font (already
// the project's font, so no image assets needed) - codepoints verified
// against this font's actual cmap via fontTools rather than guessed from
// memory, since a wrong Nerd Font codepoint silently renders as a blank
// box with no error. `offIconCodepoint` is optional: toggles with only one
// meaningful glyph (VPN, CAPS) leave it 0 and always show `onIconCodepoint`,
// relying on color/border alone to carry the on/off state.
Rectangle {
    id: root

    property string label: ""
    property bool available: true
    property bool isOn: false
    property int onIconCodepoint: 0
    property int offIconCodepoint: 0
    signal clicked()

    readonly property string iconChar: String.fromCodePoint(
        (!isOn && offIconCodepoint !== 0) ? offIconCodepoint : onIconCodepoint)
    readonly property color contentColor: !available ? Theme.inkDim : (isOn ? Theme.ink : Theme.inkSubtle)

    implicitHeight: content.implicitHeight + 16
    border.width: 1
    border.color: !available ? Theme.hairline : (isOn ? Theme.divider : Theme.hairline)
    color: (available && isOn) ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

    Column {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: Theme.fontFamily
            font.pixelSize: 13
            color: root.contentColor
            text: root.iconChar
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: Theme.fontFamily
            font.pixelSize: 8
            font.letterSpacing: 1
            color: root.contentColor
            text: root.label
        }
    }

    TapHandler {
        enabled: root.available
        onTapped: root.clicked()
    }
}
