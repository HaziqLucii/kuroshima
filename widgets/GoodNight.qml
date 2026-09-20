import QtQuick
import Quickshell
import qs.theme

// A ryoku.dev showcase widget was the reference: greeting + huge day
// abbreviation + date/time, centered, bracketed by two short hairline
// ticks. Kept in this repo's own bone-on-black palette rather than the
// reference's colour accents - Haziq: "widget should be open and up to
// user of their own creativity", but this one's bundled with kuroshima
// itself, so it follows the same house style as everywhere else here.
//
// Two fonts, matching this project's own established type system (see
// user CLAUDE.md's aesthetic notes: monospace for labels/meta, a grotesk
// for the big display element): Theme.fontFamily (JetBrainsMono Nerd Font)
// for the greeting/date/time meta text, "Inter Display" (installed on this
// machine, Space Grotesk wasn't) at Font.Black for the day abbreviation -
// a true monospace font can't produce the reference's tight, proportional-
// width geometric look no matter the weight, since every glyph is forced
// to the same advance width.
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
        anchors.centerIn: parent
        width: root.width
        spacing: Math.max(4, root.height * 0.02)

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 1
            height: Math.max(10, root.height * 0.09)
            color: Theme.divider
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.greeting
            color: Theme.inkMuted
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(8, root.height * 0.07)
            font.letterSpacing: 2
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.dayAbbrev
            color: Theme.ink
            font.family: "Inter Display"
            font.weight: Font.Black
            // The big display element - deliberately the tallest single
            // jump in the stack, matching the reference's own emphasis.
            font.pixelSize: Math.max(20, root.height * 0.32)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.dateLabel
            color: Theme.inkMuted
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(8, root.height * 0.065)
            font.letterSpacing: 1.5
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.timeLabel
            color: Theme.inkFaint
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(9, root.height * 0.08)
            font.letterSpacing: 1
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 1
            height: Math.max(10, root.height * 0.09)
            color: Theme.divider
        }
    }
}
