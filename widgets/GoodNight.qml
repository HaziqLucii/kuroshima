import QtQuick
import Quickshell
import qs.theme

// A ryoku.dev showcase widget was the reference for this one: greeting +
// huge day abbreviation + date/time, bracketed by a pair of short hairline
// ticks. Kept in this repo's own bone-on-black palette rather than the
// reference's colour accents - Haziq: "widget should be open and up to
// user of their own creativity", but this one's bundled with kuroshima
// itself, so it follows the same house style as everywhere else here.
// Same font as the rest of the project (Theme.fontFamily, JetBrainsMono
// Nerd Font) - matching that is what actually sells the look, not the
// exact layout.
Item {
    id: root

    // Fixed natural size, not derived from the labels below - same
    // no-binding-loop reasoning as widgets/Clock.qml's font.pixelSize.
    implicitWidth: 220
    implicitHeight: 170

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function greetingFor(hour) {
        if (hour < 5) return "GOOD NIGHT"
        if (hour < 12) return "GOOD MORNING"
        if (hour < 17) return "GOOD AFTERNOON"
        if (hour < 21) return "GOOD EVENING"
        return "GOOD NIGHT"
    }

    readonly property string greeting: greetingFor(clock.date.getHours())
    readonly property string dayAbbrev: Qt.formatDateTime(clock.date, "ddd").toUpperCase()
    readonly property string dateLabel: Qt.formatDateTime(clock.date, "d MMMM").toUpperCase()
    readonly property string timeLabel: Qt.formatDateTime(clock.date, "hh:mm")

    Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.width * 0.08
        spacing: Math.max(4, root.height * 0.02)

        Rectangle {
            width: 1
            height: Math.max(10, root.height * 0.09)
            color: Theme.divider
        }

        Text {
            text: root.greeting
            color: Theme.inkMuted
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(8, root.height * 0.07)
            font.letterSpacing: 2
        }

        Text {
            text: root.dayAbbrev
            color: Theme.ink
            font.family: Theme.fontFamily
            font.weight: Font.Black
            // The big display element - deliberately the tallest single
            // jump in the stack, matching the reference's own emphasis.
            font.pixelSize: Math.max(20, root.height * 0.32)
            font.letterSpacing: -1
        }

        Text {
            text: root.dateLabel
            color: Theme.inkMuted
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(8, root.height * 0.065)
            font.letterSpacing: 1.5
        }

        Text {
            text: root.timeLabel
            color: Theme.inkFaint
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(9, root.height * 0.08)
            font.letterSpacing: 1
        }

        Rectangle {
            width: 1
            height: Math.max(10, root.height * 0.09)
            color: Theme.divider
        }
    }
}
