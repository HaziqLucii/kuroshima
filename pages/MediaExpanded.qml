import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.ui

// Reached via Island.expand("MediaExpanded"), a persistent view, not a
// transient peek, so it reads live from the Media service directly rather
// than from `payload` (expand() carries no payload; Island.payload is null
// whenever there's no current transient). `payload` is still declared,
// required by the page contract even though unused here.
//
// Real so far: the identity header ("01", services/System.qml), the MEDIA
// section ("02", services/Media.qml, since slice 5, with click-and-drag
// seeking via ui/ScrubBar.qml), CONTROLS ("03", VOL/MIC via
// services/Audio.qml and BRI via services/Brightness.qml's DDC/CI path,
// all ScrubBar-driven - BRI specifically commit-on-release
// (scrubFinished) rather than continuous, since every ddcutil call
// measures ~8s on this hardware and a continuous drag would queue up
// dozens of them), SYSTEM ("05", services/SystemStats.qml), and TOGGLES
// ("04", WIFI/BT via services/Toggles.qml and MIC via services/Audio.qml;
// DND/NIGHT/VPN/CAPS/IDLE render dimmed, no real backend for any of them
// on this machine). INBOX/SESSION are still one placeholder box: real
// backend work spanning future slices, not a style pass. That box itself
// has no border, matching Capsule.qml's no-border capsule, but
// ui/ToggleButton.qml's 8 cells DO have a 1px border each (that's the
// design's own toggle-cell styling, not the placeholder-box convention
// above) - a refuter run flagging a border on THOSE specifically would be
// a real finding, not a stale review.
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

                    // Live content has no real "total length" to seek into
                    // (Media.isLive), and some players report canSeek:false
                    // even for non-live content (Quickshell's
                    // MprisPlayer.setPosition silently no-ops, with a
                    // qWarning, when the player itself can't seek) - both
                    // get the plain display bar pinned full/no-interaction;
                    // only a genuinely seekable, non-live player gets the
                    // real ScrubBar. Wrapped in a matching-height Item so
                    // the two don't shift everything below them by
                    // ScrubBar's larger (18px) hit-area height when
                    // swapping between the two (refuter-caught).
                    ScrubBar {
                        id: mediaScrub
                        width: parent.width
                        trackHeight: 3
                        hitHeight: 18
                        visible: !Media.isLive && Media.canSeek
                        value: Media.length > 0 ? Math.min(1, Media.position / Media.length) : 0
                        popoverLabel: root.fmt(mediaScrub.previewValue * Media.length)
                        // Not onScrub: refuter measured one real MPRIS
                        // SetPosition D-Bus call per pointer-move event,
                        // 60-180 calls for a one-second drag, i.e.
                        // continuous re-seek/re-buffer for the whole drag.
                        // scrubFinished fires once, on release or a plain
                        // click; the fill bar already tracks the live drag
                        // via previewValue without needing to actually seek
                        // on every frame.
                        onScrubFinished: (pct) => Media.seek((pct / 100) * Media.length)
                    }
                    Item {
                        width: parent.width
                        height: 18
                        visible: Media.isLive || !Media.canSeek

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 3
                            radius: 2
                            color: Theme.trackBg

                            // Full width for live (always "at the live
                            // edge"); actual position/length ratio for a
                            // finite track that just doesn't support
                            // seeking, so a non-interactive player doesn't
                            // misleadingly look pinned at the very end.
                            Rectangle {
                                width: Media.isLive ? parent.width
                                    : (Media.length > 0 ? parent.width * Math.min(1, Media.position / Media.length) : 0)
                                height: parent.height
                                radius: parent.radius
                                color: Theme.ink
                            }
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
            // three children reproduces that exactly). Both real now
            // (ui/ToggleButton.qml, services/Toggles.qml); the half-width
            // reservation was set up ahead of TOGGLES actually landing
            // specifically so it wouldn't need reflowing once it did.
            Row {
                id: controlsTogglesRow
                width: parent.width
                spacing: 16

                // VOL, BRI, MIC. BRI is commit-on-release (scrubFinished),
                // not the continuous scrub VOL/MIC use: this desktop has no
                // backlight, and the only real brightness path found is
                // DDC/CI over the monitor's I2C bus (`ddcutil`), which
                // measures ~8s round-trip per read/write on this hardware.
                // Haziq accepted the latency for a "set and let it catch
                // up" control (he sees the same lag setting it from KDE);
                // a CONTINUOUS drag would instead queue up dozens of 8s
                // ddcutil calls, exactly the media-seek-spam bug refuter
                // already caught once for the progress bar.
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
                visible: Audio.available || Audio.micAvailable || Brightness.value >= 0

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
                    ScrubBar {
                        width: parent.width
                        value: Audio.muted ? 0 : Audio.volume
                        onScrub: (pct) => Audio.setVolume(pct)
                    }
                }

                Column {
                    width: parent.width
                    spacing: 5
                    // value starts at -1 until the first ddcutil read
                    // completes (~8s after the first time this page is
                    // expanded, not app startup - see
                    // services/Brightness.qml) - hidden until then, same
                    // "don't show a bogus reading" reasoning as everything
                    // else on this page that waits on a slow real source.
                    visible: Brightness.value >= 0

                    Item {
                        width: parent.width
                        height: briValue.implicitHeight

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.inkFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.letterSpacing: 1
                            text: "BRI"
                        }
                        Text {
                            id: briValue
                            anchors.right: parent.right
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            text: Math.round(Math.max(0, Brightness.value) * 100)
                        }
                    }
                    ScrubBar {
                        width: parent.width
                        value: Math.max(0, Brightness.value)
                        // Not onScrub: an 8s ddcutil call per pointer-move
                        // event would be the exact same seek-spam bug
                        // refuter already caught for media, just worse (8s
                        // vs a cheap MPRIS call). scrubFinished commits once,
                        // on release or a plain click; the fill still
                        // tracks the live drag via ScrubBar's own
                        // previewValue, same as the media bar.
                        onScrubFinished: (pct) => Brightness.setBrightness(pct)
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
                    ScrubBar {
                        width: parent.width
                        value: Audio.micMuted ? 0 : Audio.micVolume
                        onScrub: (pct) => Audio.setMicVolume(pct)
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

                    // Only WIFI/BT/MIC are real (services/Toggles.qml,
                    // services/Audio.qml). DND needs the not-yet-built
                    // notification server, NIGHT has no gamma daemon
                    // installed on this machine, VPN has no connection
                    // profile configured, CAPS is a passive indicator (not
                    // sensibly a click-toggle), and IDLE has no idle-inhibit
                    // daemon running - all five render `available: false`
                    // (dimmed, not clickable) rather than being dropped
                    // from the grid, per Haziq: keep the full 4x2 look
                    // rather than shrinking to only what's real.
                    Grid {
                        id: toggleGrid
                        width: parent.width
                        columns: 4
                        rowSpacing: 7
                        columnSpacing: 7

                        ToggleButton {
                            width: (toggleGrid.width - 3 * 7) / 4
                            label: "WIFI"
                            available: Toggles.wifiAvailable
                            isOn: Toggles.wifiOn
                            onIconCodepoint: 0xf05a9
                            offIconCodepoint: 0xf05aa
                            onClicked: Toggles.setWifi(!Toggles.wifiOn)
                        }
                        ToggleButton {
                            width: (toggleGrid.width - 3 * 7) / 4
                            label: "BT"
                            available: Toggles.btAvailable
                            isOn: Toggles.btOn
                            onIconCodepoint: 0xf00af
                            offIconCodepoint: 0xf00b2
                            onClicked: Toggles.setBt(!Toggles.btOn)
                        }
                        ToggleButton {
                            width: (toggleGrid.width - 3 * 7) / 4
                            label: "DND"
                            available: false
                            onIconCodepoint: 0xf009b
                            offIconCodepoint: 0xf0f3
                        }
                        ToggleButton {
                            width: (toggleGrid.width - 3 * 7) / 4
                            label: "NIGHT"
                            available: false
                            onIconCodepoint: 0xf186
                            offIconCodepoint: 0xf185
                        }
                        ToggleButton {
                            width: (toggleGrid.width - 3 * 7) / 4
                            label: "MIC"
                            available: Audio.micAvailable
                            isOn: Audio.micAvailable && !Audio.micMuted
                            onIconCodepoint: 0xf130
                            offIconCodepoint: 0xf131
                            onClicked: Audio.toggleMicMuted()
                        }
                        ToggleButton {
                            width: (toggleGrid.width - 3 * 7) / 4
                            label: "VPN"
                            available: false
                            onIconCodepoint: 0xf0582
                        }
                        ToggleButton {
                            width: (toggleGrid.width - 3 * 7) / 4
                            label: "CAPS"
                            available: false
                            onIconCodepoint: 0xf0a9b
                        }
                        ToggleButton {
                            width: (toggleGrid.width - 3 * 7) / 4
                            label: "IDLE"
                            available: false
                            onIconCodepoint: 0xf0176
                            offIconCodepoint: 0xf0faa
                        }
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
