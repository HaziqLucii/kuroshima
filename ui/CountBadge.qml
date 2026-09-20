import QtQuick
import qs.theme

// Long light-background pill reading "N UNREAD" (services/Notifs.qml's
// history count) - Haziq's correction after a first version rendered
// just the bare numeral in a small circle: "i said badge. a long badge,
// so it should read 4 unread in the badge. not 4 in the bubble." Mono-
// uppercase with letterSpacing, matching every other label in this UI
// (INBOX, CLEAR ALL, VOL, BRI, ...). Theme.ink/Theme.bg, not literal
// "white"/"black": stays inside the established ink-token system while
// reading as a plain light badge with dark text.
Rectangle {
    id: root

    property int count: 0
    readonly property string countText: (count > 99 ? "99+" : String(count)) + " UNREAD"

    implicitWidth: label.implicitWidth + 16
    implicitHeight: 15
    radius: implicitHeight / 2
    color: Theme.ink

    Text {
        id: label
        anchors.centerIn: parent
        color: Theme.bg
        font.family: Theme.fontFamily
        font.pixelSize: 8
        font.weight: Font.Bold
        font.letterSpacing: 1
        text: root.countText
    }
}
