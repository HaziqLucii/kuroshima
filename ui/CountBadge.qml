import QtQuick
import qs.theme

// Small light-background numeric badge (unread notification count, etc).
// Theme.ink/Theme.bg, not literal "white"/"black": stays inside the
// established ink-token system so it still tracks Theme if those values
// ever change, while reading as a plain white badge with dark digits.
Rectangle {
    id: root

    property int count: 0
    readonly property string countText: count > 99 ? "99+" : String(count)

    implicitWidth: Math.max(implicitHeight, label.implicitWidth + 8)
    implicitHeight: 13
    radius: implicitHeight / 2
    color: Theme.ink

    Text {
        id: label
        anchors.centerIn: parent
        color: Theme.bg
        font.family: Theme.fontFamily
        font.pixelSize: 8
        font.weight: Font.Bold
        text: root.countText
    }
}
