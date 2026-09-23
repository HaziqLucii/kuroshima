import QtQuick
import Quickshell
import qs.theme
import qs.services

// Face id "weatherFace" - Slice 4. Templated on faces/ClockDate.qml's
// clock+divider+secondary-info shape, with a weather readout standing in
// for that face's plain date text. Glyph codepoints below are all
// "weather-*" (Weather Icons, not Codicons) from JetBrains Mono Nerd Font,
// verified against the font's real cmap via fontTools before use, per this
// project's standing icon-glyph discipline.
Item {
    id: root

    property var payload: null

    implicitWidth: content.implicitWidth
    implicitHeight: Theme.compactH

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    function _glyphFor(label) {
        switch (label) {
            case "CLEAR": return 0xe30d  // weather-day_sunny
            case "CLOUDY": return 0xe302 // weather-day_cloudy
            case "FOG": return 0xe313    // weather-fog
            case "RAIN": return 0xe318   // weather-rain
            case "SNOW": return 0xe31a   // weather-snow
            case "STORM": return 0xe31d  // weather-thunderstorm
            default: return 0xe33d       // weather-cloud
        }
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
            width: 1
            height: 11
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.divider
        }

        // Dims (not hides) once fetched data goes stale, so a lingering
        // last-known reading still reads as "old", not silently presented
        // as current - same trust signal faces/StatusFace.qml gives WIFI/BT
        // via Toggles.*Available. Three distinct non-"ok" states, driven by
        // services/Weather.qml's single `status` property rather than
        // re-derived here (refuter-caught: this used to be one `!available`
        // check covering "never configured", "still loading", and
        // "genuinely broken" with the same misleading "SET LOCATION" text
        // for all three):
        // "unset" - the discoverable-fallback precedent (faces/ClipboardFace.qml's
        //   empty state, faces/FocusFace.qml's idle chips) - still
        //   selectable, tells the user what to do.
        // "loading" - first fetch hasn't landed yet (or hasn't failed twice
        //   yet); renders nothing rather than guessing, so a correctly
        //   configured location never flashes a wrong instruction.
        // "unavailable" - configured but never once succeeded (bad
        //   coordinates, curl missing, API down) - a distinct string from
        //   "unset" so a user who already set a location isn't told to do
        //   it again with no explanation. services/Weather.qml also
        //   console.warns on every failed fetch now, so this is
        //   diagnosable from the logs too.
        Row {
            id: weatherRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            opacity: Weather.status !== "ok" ? 0.4 : (Weather.stale ? 0.55 : 1)

            Text {
                visible: Weather.status === "ok"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 13
                text: Weather.status === "ok" ? String.fromCodePoint(root._glyphFor(Weather.label)) : ""
            }

            Text {
                visible: Weather.status === "ok"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                text: Weather.status === "ok" ? Math.round(Weather.tempC) + "°" : ""
            }

            Text {
                visible: Weather.status === "ok"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.inkFaint
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 1
                text: Weather.label
            }

            Text {
                visible: Weather.status === "unset"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.inkDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 1
                text: "WEATHER · SET LOCATION"
            }

            Text {
                visible: Weather.status === "unavailable"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.inkDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 1
                text: "WEATHER · UNAVAILABLE"
            }
        }
    }
}
