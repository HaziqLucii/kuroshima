import QtQuick
import Quickshell
import qs.theme

// A ryoku.dev showcase widget was the reference: greeting + huge day
// abbreviation + date/time, centered, bracketed by two long, thin hairline
// ticks with real breathing room around them. Kept in this repo's own
// bone-on-black palette rather than the reference's colour accents -
// The maintainer: "widget should be open and up to user of their own creativity",
// but this one's bundled with kuroshima itself, so it follows the same
// house style as everywhere else here.
//
// Two fonts, both confirmed via fc-match before use rather than guessed:
// "Poppins" for the greeting, date, and time - Theme.fontFamily (JetBrains
// Mono Nerd Font) was the original choice for all three, but a monospace
// font's fixed advance width can't reproduce the reference's letter-spaced
// look on the greeting line, so the whole meta-text set moved to Poppins
// for consistency. "Fraunces 144pt" (Black) stays on just the day
// abbreviation - the maintainer wanted something with more character there, not a
// normal grotesk (tried Inter Display first, correctly called out as too
// plain).
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
        if (hour < 5) return "GOOD\nNIGHT"
        if (hour < 12) return "GOOD\nMORNING"
        if (hour < 17) return "GOOD\nAFTERNOON"
        if (hour < 21) return "GOOD\nEVENING"
        return "GOOD\nNIGHT"
    }

    // Two lines always ("GOOD" / mood-word), matching the reference - a
    // single-line "GOOD AFTERNOON" reads noticeably wider than the other
    // three, which the two-line form avoids entirely.
    readonly property string greeting: greetingFor(clock.date.getHours())
    readonly property string dayAbbrev: Qt.formatDateTime(clock.date, "ddd").toUpperCase()
    readonly property string dateLabel: Qt.formatDateTime(clock.date, "d MMMM").toUpperCase()
    readonly property string timeLabel: Qt.formatDateTime(clock.date, "hh:mm")

    // Outer column: just the two ticks and the text block, with real gaps
    // between them. Inner column (below) keeps the text block itself
    // tight - the reference has a clear rhythm difference between
    // "tick to content" spacing and "line to line" spacing, which a
    // single flat Column with one spacing value can't reproduce.
    Column {
        anchors.centerIn: parent
        spacing: Math.max(12, root.height * 0.06)

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(1, root.width * 0.006)
            height: Math.max(18, root.height * 0.16)
            color: Theme.ink
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.max(2, root.height * 0.012)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.greeting
                horizontalAlignment: Text.AlignHCenter
                color: Theme.inkMuted
                font.family: "Poppins"
                font.weight: Font.Medium
                font.pixelSize: Math.max(8, root.height * 0.07)
                font.letterSpacing: 8
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dayAbbrev
                color: Theme.ink
                // "Fraunces 144pt", not plain "Fraunces" - the family is
                // split by optical size (9pt/72pt/144pt, each with Soft/
                // SuperSoft variants), and 144pt is the cut actually drawn
                // for large display text, not just a bigger render of the
                // small-text cut. Confirmed via fc-match before use, not
                // guessed - a plain "Fraunces" family name silently
                // resolved to Noto Sans.
                font.family: "Fraunces 144pt"
                font.weight: Font.Black
                // The big display element - deliberately the tallest
                // single jump in the stack, matching the reference's own
                // emphasis.
                font.pixelSize: Math.max(20, root.height * 0.32)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dateLabel
                color: Theme.inkMuted
                font.family: "Poppins"
                font.pixelSize: Math.max(8, root.height * 0.065)
                font.letterSpacing: 1.5
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.timeLabel
                color: Theme.inkFaint
                font.family: "Poppins"
                font.pixelSize: Math.max(9, root.height * 0.08)
                font.letterSpacing: 1
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(1, root.width * 0.006)
            height: Math.max(18, root.height * 0.16)
            color: Theme.ink
        }
    }
}
