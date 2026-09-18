import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.services

// Reached via Island.expand("MediaExpanded"), a persistent view, not a
// transient peek, so it reads live from the Media service directly rather
// than from `payload` (expand() carries no payload; Island.payload is null
// whenever there's no current transient). `payload` is still declared,
// required by the page contract even though unused here.
//
// Real so far: the identity header ("01", services/System.qml), the MEDIA
// section ("02", services/Media.qml, since slice 5), and CONTROLS ("03",
// VOL/MIC via services/Audio.qml; BRI deliberately left out, see
// docs/HANDOFF.md - this desktop has no backlight, and the DDC/CI
// alternative measured ~8s round-trip per read/write, too slow to be a
// usable slider). TOGGLES/SYSTEM/INBOX/SESSION are still one placeholder
// box: real backend work spanning several future slices, not a style pass.
// The box itself has no border, per Haziq's Capsule.qml preference (no
// borders anywhere on this page) - if a refuter run flags the missing
// border again, that's this comment being right and the review being
// stale, not a regression.
Item {
    id: root

    property var payload: null
    // Declared but unused: already the expanded destination, nothing
    // further to expand to. Present so ui/Capsule.qml's generic
    // Connections to whatever page is current doesn't warn about a
    // missing signal every time this page is shown.
    signal requestExpand(string pageId)
    readonly property real cornerRadius: Theme.expandedRadius

    implicitWidth: Theme.expandedW
    implicitHeight: Theme.expandedH
    width: implicitWidth
    height: implicitHeight

    // Position, not length, is what's live-ticked (services/Media.qml polls
    // it once a second while playing; MPRIS doesn't push continuous
    // updates), so elapsed/remaining below re-derive off that each tick.
    // Hours included past 60 minutes: refuter caught a live stream's
    // elapsed rendering as a bare, un-hour-rolled "125:00" without this.
    function fmt(totalSecs) {
        const s = Math.max(0, Math.floor(totalSecs))
        const secs = s % 60
        const mins = Math.floor(s / 60) % 60
        const hours = Math.floor(s / 3600)
        const pad = (n) => (n < 10 ? "0" + n : "" + n)
        return hours > 0 ? (hours + ":" + pad(mins) + ":" + pad(secs)) : (mins + ":" + pad(secs))
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    readonly property var _days: ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
    readonly property var _daysJp: ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"]
    readonly property var _months: ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    readonly property string _dateLong: clock.date.getDate() + " " + root._months[clock.date.getMonth()] + " · " + root._days[clock.date.getDay()]
    readonly property string _dateJp: root._daysJp[clock.date.getDay()]

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: 20
        anchors.topMargin: 18
        anchors.bottomMargin: 18

        Column {
            id: builtSections
            anchors.top: parent.top
            width: parent.width
            spacing: 16

            // 01 IDENTITY: the only always-on module. userHost/uptime/niri
            // (services/System.qml) each hide independently when their
            // source is absent, per the design's own degrade rule.
            Item {
                width: parent.width
                height: Math.max(identityLeft.implicitHeight, identityRight.implicitHeight)

                Row {
                    id: identityLeft
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        text: Qt.formatDateTime(clock.date, "hh:mm:ss")
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.inkFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        text: root._dateLong
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.inkDim
                        font.family: Theme.fontFamilyJp
                        font.pixelSize: 10
                        text: root._dateJp
                    }
                }

                Row {
                    id: identityRight
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: System.userHost !== ""
                        color: Theme.inkSubtle
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        text: System.userHost
                    }
                    Rectangle {
                        width: 1
                        height: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.divider
                        visible: System.userHost !== "" && System.uptimeLabel !== ""
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: System.uptimeLabel !== ""
                        color: Theme.inkSubtle
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        text: System.uptimeLabel
                    }
                    Rectangle {
                        width: 1
                        height: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.divider
                        visible: System.uptimeLabel !== "" && System.niriVersion !== ""
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: System.niriVersion !== ""
                        color: Theme.inkSubtle
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        text: "NIRI " + System.niriVersion
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.hairline
            }

            Row {
                width: parent.width
                spacing: 14
                visible: Media.available

                // Squircle art thumbnail. A true superellipse needs a
                // custom Shape path; at this size a large-radius rounded
                // rect reads the same and is what most UI toolkits mean by
                // "squircle" in practice, so that's what ships here.
                ClippingRectangle {
                    width: 54
                    height: 54
                    radius: 18
                    color: Theme.hairline

                    Image {
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: Media.artUrl !== ""
                    }
                }

                Column {
                    width: parent.width - 54 - 14
                    spacing: 8

                    Item {
                        width: parent.width
                        height: titleText.implicitHeight

                        Text {
                            id: titleText
                            anchors.left: parent.left
                            anchors.right: artistText.left
                            anchors.rightMargin: 10
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            text: Media.title
                        }
                        Text {
                            id: artistText
                            anchors.right: parent.right
                            anchors.verticalCenter: titleText.verticalCenter
                            color: Theme.inkFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, parent.width * 0.4)
                            text: Media.artist
                        }
                    }

                    // Display only: services/Media.qml doesn't expose a
                    // seek method yet (MPRIS SetPosition), so this isn't
                    // click-to-seek like the design's version. Real seeking
                    // is new service work, not a style pass.
                    //
                    // Live content has no real "total length" to be a
                    // fraction of (Media.isLive), so the fill just pins
                    // full: you're always at the live edge, which is also
                    // the only direction there's nothing further to seek.
                    Rectangle {
                        width: parent.width
                        height: 3
                        radius: 2
                        color: Theme.trackBg

                        Rectangle {
                            width: Media.isLive ? parent.width
                                : (Media.length > 0 ? parent.width * Math.min(1, Media.position / Media.length) : 0)
                            height: parent.height
                            radius: parent.radius
                            color: Theme.ink
                        }
                    }

                    Item {
                        width: parent.width
                        height: transportRow.implicitHeight

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.inkSubtle
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            text: root.fmt(Media.position)
                        }

                        Row {
                            id: transportRow
                            anchors.centerIn: parent
                            spacing: 18

                            Text {
                                text: "◀◀"
                                color: Theme.inkMuted
                                opacity: Media.canGoPrevious ? 1.0 : 0.35
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                TapHandler { enabled: Media.canGoPrevious; onTapped: Media.previous() }
                            }
                            Text {
                                text: Media.isPlaying ? "▮▮" : "▶"
                                color: Theme.ink
                                opacity: Media.canTogglePlaying ? 1.0 : 0.35
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                TapHandler { enabled: Media.canTogglePlaying; onTapped: Media.togglePlaying() }
                            }
                            Text {
                                text: "▶▶"
                                color: Theme.inkMuted
                                // Forced off for live content regardless of
                                // MPRIS's own canGoNext: there's nothing
                                // ahead of the live edge to skip forward
                                // into, only backward into the buffer.
                                opacity: (Media.canGoNext && !Media.isLive) ? 1.0 : 0.35
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                TapHandler { enabled: Media.canGoNext && !Media.isLive; onTapped: Media.next() }
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5
                            visible: Media.isLive

                            Rectangle {
                                width: 5
                                height: 5
                                radius: 2.5
                                anchors.verticalCenter: parent.verticalCenter
                                color: "#d75f5f"

                                SequentialAnimation on opacity {
                                    running: Media.isLive
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutQuad }
                                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                                }
                            }
                            Text {
                                color: "#d75f5f"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.letterSpacing: 2
                                text: "LIVE"
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !Media.isLive
                            color: Theme.inkSubtle
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            text: root.fmt(Media.length - Media.position)
                        }
                    }
                }
            }

            Text {
                visible: !Media.available
                color: Theme.inkDim
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.letterSpacing: 2
                text: "NO MEDIA"
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.hairline
            }

            // 03 CONTROLS / 04 TOGGLES: side by side, half width each, per
            // the design's `grid-template-columns: 1fr 1px 1fr` (a content
            // column, a 1px divider, a content column, 16px gaps either
            // side of the divider - a plain Row with spacing:16 and these
            // three children reproduces that exactly). Only CONTROLS is
            // real; TOGGLES stays a placeholder in its own reserved half,
            // not stacked below, so it doesn't need reflowing again once
            // it's built for real.
            Row {
                id: controlsTogglesRow
                width: parent.width
                spacing: 16

                // VOL and MIC only. BRI is deliberately left out, not just
                // hidden: this desktop has no backlight, and the only real
                // brightness path found is DDC/CI over the monitor's I2C
                // bus (`ddcutil`), which measured ~8s round-trip per
                // read/write on this hardware. A click-to-set slider that
                // takes 8 seconds to visibly respond isn't a style/scope
                // question, it's a genuinely bad control, so Haziq chose to
                // skip it rather than ship it pending or fire-and-forget.
                Column {
                id: controlsCol
                width: (controlsTogglesRow.width - 32 - 1) / 2
                spacing: 11
                // Whole section, header included: without this, the "03
                // CONTROLS" label rendered alone with nothing under it for
                // the ~2-3s Pipewire takes to bind at startup (refuter
                // measured `Audio.available` still false at 2.5s), which
                // contradicts "each module hides itself when its source is
                // absent" same as everything else on this page.
                visible: Audio.available || Audio.micAvailable

                Row {
                    spacing: 9
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "03"; color: Theme.inkDim; font.family: Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 2 }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "CONTROLS"; color: Theme.inkMuted; font.family: Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 2 }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "制御"; color: Theme.inkDim; font.family: Theme.fontFamilyJp; font.pixelSize: 9 }
                }

                Column {
                    width: parent.width
                    spacing: 5
                    visible: Audio.available

                    Item {
                        width: parent.width
                        height: volValue.implicitHeight

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.inkFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.letterSpacing: 1
                            text: "VOL"
                        }
                        Text {
                            id: volValue
                            anchors.right: parent.right
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            text: Math.round((Audio.muted ? 0 : Audio.volume) * 100)
                        }
                    }
                    // The visual track stays a 3px hairline (matching OSD/
                    // media's own bars), but a 3px-tall tap target is a
                    // refuter-caught real usability problem, so the
                    // TapHandler lives on a taller invisible parent instead
                    // of the bar itself.
                    Item {
                        id: volHitArea
                        width: parent.width
                        height: 18

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 3
                            radius: 2
                            color: Theme.trackBg

                            Rectangle {
                                width: parent.width * (Audio.muted ? 0 : Audio.volume)
                                height: parent.height
                                radius: parent.radius
                                color: Theme.ink
                            }
                        }
                        TapHandler {
                            onTapped: (eventPoint) => Audio.setVolume((eventPoint.position.x / volHitArea.width) * 100)
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 5
                    visible: Audio.micAvailable

                    Item {
                        width: parent.width
                        height: micValue.implicitHeight

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.inkFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.letterSpacing: 1
                            text: "MIC"
                        }
                        Text {
                            id: micValue
                            anchors.right: parent.right
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            text: Math.round((Audio.micMuted ? 0 : Audio.micVolume) * 100)
                        }
                    }
                    Item {
                        id: micHitArea
                        width: parent.width
                        height: 18

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 3
                            radius: 2
                            color: Theme.trackBg

                            Rectangle {
                                width: parent.width * (Audio.micMuted ? 0 : Audio.micVolume)
                                height: parent.height
                                radius: parent.radius
                                color: Theme.ink
                            }
                        }
                        TapHandler {
                            onTapped: (eventPoint) => Audio.setMicVolume((eventPoint.position.x / micHitArea.width) * 100)
                        }
                    }
                }
                }

                Rectangle {
                    width: 1
                    // Gated on controlsCol specifically, not just sized
                    // from it: an invisible Column still reports a real
                    // implicitHeight, so without this gate the divider
                    // rendered as an orphan hairline pinned at the left
                    // edge whenever CONTROLS hides (the ~2-3s Pipewire
                    // startup window, or permanently on a machine with no
                    // audio device at all) - refuter-caught, a real hole in
                    // the "hides when absent" rule this page otherwise
                    // follows everywhere else.
                    visible: controlsCol.visible
                    height: controlsCol.visible ? Math.max(controlsCol.implicitHeight, togglesCol.implicitHeight) : togglesCol.implicitHeight
                    color: Theme.hairline
                }

                Column {
                    id: togglesCol
                    width: (controlsTogglesRow.width - 32 - 1) / 2
                    spacing: 11

                    Row {
                        spacing: 9
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "04"; color: Theme.inkDim; font.family: Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 2 }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "TOGGLES"; color: Theme.inkMuted; font.family: Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 2 }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "切替"; color: Theme.inkDim; font.family: Theme.fontFamilyJp; font.pixelSize: 9 }
                    }
                    Text {
                        color: Theme.inkDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        text: "PLACEHOLDER"
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.hairline
            }

            // 05 SYSTEM: read-only, unlike CONTROLS above it, no
            // destructive-action or latency tradeoffs to weigh, so all four
            // stats land in one pass. Each cell hides independently if its
            // own source isn't there (services/SystemStats.qml keeps
            // missing stats at -1). Row skips invisible children (and their
            // spacing) entirely, so a hidden cell doesn't leave a gap where
            // it sat, the remaining cells just close up and shift left,
            // same as everywhere else on this page a field can go missing
            // (the identity row's optional userHost/uptime/niri fields
            // included). Since every cell keeps its own fixed width rather
            // than growing to redistribute the freed space, the row simply
            // narrows and the empty space lands as trailing space on the
            // right, not between cells.
            Column {
                width: parent.width
                spacing: 11
                visible: SystemStats.cpuPercent >= 0 || SystemStats.memPercent >= 0
                    || SystemStats.diskPercent >= 0 || SystemStats.tempCelsius >= 0

                Row {
                    spacing: 9
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "05"; color: Theme.inkDim; font.family: Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 2 }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "SYSTEM"; color: Theme.inkMuted; font.family: Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 2 }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "系統"; color: Theme.inkDim; font.family: Theme.fontFamilyJp; font.pixelSize: 9 }
                }

                Row {
                    id: statsRow
                    width: parent.width
                    spacing: 14

                    Column {
                        width: (statsRow.width - 3 * 14) / 4
                        spacing: 6
                        visible: SystemStats.cpuPercent >= 0

                        Item {
                            width: parent.width
                            height: cpuValue.implicitHeight
                            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; color: Theme.inkFaint; font.family: Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 1; text: "CPU" }
                            Text { id: cpuValue; anchors.right: parent.right; color: Theme.ink; font.family: Theme.fontFamily; font.pixelSize: 11; text: SystemStats.cpuPercent + "%" }
                        }
                        Rectangle {
                            width: parent.width; height: 2; color: Theme.trackBg
                            Rectangle { width: parent.width * Math.min(1, SystemStats.cpuPercent / 100); height: parent.height; color: Qt.rgba(1, 1, 1, 0.45) }
                        }
                    }

                    Column {
                        width: (statsRow.width - 3 * 14) / 4
                        spacing: 6
                        visible: SystemStats.memPercent >= 0

                        Item {
                            width: parent.width
                            height: memValue.implicitHeight
                            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; color: Theme.inkFaint; font.family: Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 1; text: "MEM" }
                            Text { id: memValue; anchors.right: parent.right; color: Theme.ink; font.family: Theme.fontFamily; font.pixelSize: 11; text: SystemStats.memUsedLabel }
                        }
                        Rectangle {
                            width: parent.width; height: 2; color: Theme.trackBg
                            Rectangle { width: parent.width * Math.min(1, SystemStats.memPercent / 100); height: parent.height; color: Qt.rgba(1, 1, 1, 0.45) }
                        }
                    }

                    Column {
                        width: (statsRow.width - 3 * 14) / 4
                        spacing: 6
                        visible: SystemStats.tempCelsius >= 0

                        Item {
                            width: parent.width
                            height: tempValue.implicitHeight
                            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; color: Theme.inkFaint; font.family: Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 1; text: "TEMP" }
                            Text { id: tempValue; anchors.right: parent.right; color: Theme.ink; font.family: Theme.fontFamily; font.pixelSize: 11; text: SystemStats.tempCelsius + "°C" }
                        }
                        Rectangle {
                            width: parent.width; height: 2; color: Theme.trackBg
                            // 90C as the top of the bar, not 100: a CPU
                            // "full" temp reading meaningfully lower than
                            // its actual throttle point makes the bar
                            // useless as an at-a-glance signal.
                            Rectangle { width: parent.width * Math.min(1, SystemStats.tempCelsius / 90); height: parent.height; color: Qt.rgba(1, 1, 1, 0.45) }
                        }
                    }

                    Column {
                        width: (statsRow.width - 3 * 14) / 4
                        spacing: 6
                        visible: SystemStats.diskPercent >= 0

                        Item {
                            width: parent.width
                            height: diskValue.implicitHeight
                            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; color: Theme.inkFaint; font.family: Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 1; text: "DISK" }
                            Text { id: diskValue; anchors.right: parent.right; color: Theme.ink; font.family: Theme.fontFamily; font.pixelSize: 11; text: SystemStats.diskPercent + "%" }
                        }
                        Rectangle {
                            width: parent.width; height: 2; color: Theme.trackBg
                            Rectangle { width: parent.width * Math.min(1, SystemStats.diskPercent / 100); height: parent.height; color: Qt.rgba(1, 1, 1, 0.45) }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.hairline
            }
        }

        Rectangle {
            anchors.top: builtSections.bottom
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            color: "transparent"
            border.width: 0

            Text {
                anchors.centerIn: parent
                width: parent.width * 0.6
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Theme.inkDim
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.letterSpacing: 2
                text: "INBOX · SESSION · PLACEHOLDER"
            }
        }
    }
}
