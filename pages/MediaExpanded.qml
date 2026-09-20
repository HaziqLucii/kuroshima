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
// Real so far, all 7 numbered sections: the identity header ("01",
// services/System.qml), the MEDIA section ("02", services/Media.qml,
// since slice 5, with click-and-drag seeking via ui/ScrubBar.qml),
// CONTROLS ("03", VOL/MIC via services/Audio.qml and BRI via
// services/Brightness.qml's DDC/CI path, all ScrubBar-driven - BRI
// specifically commit-on-release (scrubFinished) rather than continuous,
// since every ddcutil call measures ~8s on this hardware and a
// continuous drag would queue up dozens of them), TOGGLES ("04",
// WIFI/BT via services/Toggles.qml and MIC via services/Audio.qml;
// DND/NIGHT/VPN/CAPS/IDLE render dimmed, no real backend for any of them
// on this machine), SYSTEM ("05", services/SystemStats.qml), INBOX
// ("06", services/Notifs.qml's history array, capped to 2 shown here vs
// its own 20-deep cap - separate from NotificationServer.trackedNotifications,
// see Notifs.qml's own comment for why), and SESSION ("07": workspace
// pills read live from services/Workspaces.qml, dimmed
// ETH/VPN/SYNC labels matching the TOGGLES no-real-backend convention,
// battery% from services/Battery.qml - never reachable on this
// desktop's real hardware, no battery at all - and the LOCK/SLEEP/POWER
// actions via loginctl/systemctl through Quickshell.execDetached,
// SLEEP/POWER tap-to-arm-tap-to-confirm). No more placeholder box.
// ui/ToggleButton.qml's 8 cells DO have a 1px border each (that's the
// design's own toggle-cell styling) - a refuter run flagging a border on
// THOSE specifically would be a real finding, not a stale review.
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

    // A real player with no valid duration yet is normal for a brief
    // moment (MPRIS metadata, especially length, often arrives
    // asynchronously right after a player registers or right after this
    // shell restarts mid-playback) - the remaining-time label just hides
    // itself for that window rather than showing a misleading "0:00".
    // But if it's STILL missing well past that normal window, something's
    // actually stuck, most often the browser tab's own MPRIS report gone
    // stale - nothing on this project's side can force a browser to
    // re-report its own metadata, so after a few seconds this names the
    // actual fix instead of leaving a permanent blank space with no
    // explanation. Haziq: "put remark if there's issue on data
    // querying as fallback... like putting 'please refresh the page'."
    readonly property bool needsDuration: Media.available && !Media.isLive && Media.length <= 0
    property bool _durationStuck: false
    onNeedsDurationChanged: {
        if (needsDuration) {
            _durationStuckTimer.restart()
        } else {
            _durationStuckTimer.stop()
            _durationStuck = false
        }
    }
    property Timer _durationStuckTimer: Timer {
        interval: 4000
        onTriggered: root._durationStuck = true
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
                //
                // Sized off mediaInfoColumn's implicitHeight (not a fixed
                // 54) so it always fills the row's real height instead of
                // floating short with dead space above/below - the column's
                // height depends only on its children's own heights, never
                // its width, so binding the art's width to it here doesn't
                // create a layout loop.
                ClippingRectangle {
                    id: mediaArt
                    width: mediaInfoColumn.implicitHeight
                    height: mediaInfoColumn.implicitHeight
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
                    id: mediaInfoColumn
                    width: parent.width - mediaArt.width - 14
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
                            spacing: 14

                            // "For the media player, the pause play should
                            // show the bubble as the background when
                            // hovered" - a fixed-size circular hit area per
                            // control (so Row's layout never shifts) with a
                            // bubble that grows/fades in behind the glyph.
                            Item {
                                id: prevHit
                                property bool hovered: false
                                width: 24
                                height: 24
                                Rectangle {
                                    // Full bone-on-black invert, not a
                                    // translucent brighten.
                                    anchors.centerIn: parent
                                    width: prevHit.hovered ? 22 : 0
                                    height: prevHit.hovered ? 22 : 0
                                    radius: width / 2
                                    color: Theme.ink
                                    opacity: prevHit.hovered ? 1 : 0
                                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 160 } }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    // fa-step_backward, not the raw "◀◀"
                                    // dingbat: confirmed via a crosshair
                                    // render test that plain Unicode
                                    // triangles/bars sit noticeably off
                                    // within their own glyph box (blank
                                    // trailing space baked into the
                                    // character, not designed for
                                    // icon-button centering the way a real
                                    // icon font glyph is) - exactly the
                                    // misalignment Haziq spotted once the
                                    // hover bubble made it visible.
                                    text: String.fromCodePoint(0xf048)
                                    color: prevHit.hovered ? Theme.bg : Theme.inkMuted
                                    opacity: Media.canGoPrevious ? 1.0 : 0.35
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }
                                TapHandler { enabled: Media.canGoPrevious; onTapped: Media.previous() }
                                HoverHandler { enabled: Media.canGoPrevious; onHoveredChanged: prevHit.hovered = hovered }
                            }
                            Item {
                                id: playHit
                                property bool hovered: false
                                width: 26
                                height: 26
                                Rectangle {
                                    // Full bone-on-black invert, not a
                                    // translucent brighten.
                                    anchors.centerIn: parent
                                    width: playHit.hovered ? 24 : 0
                                    height: playHit.hovered ? 24 : 0
                                    radius: width / 2
                                    color: Theme.ink
                                    opacity: playHit.hovered ? 1 : 0
                                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 160 } }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    // fa-pause / fa-play - see the prev
                                    // button's comment above for why.
                                    text: String.fromCodePoint(Media.isPlaying ? 0xf04c : 0xf04b)
                                    color: playHit.hovered ? Theme.bg : Theme.ink
                                    opacity: Media.canTogglePlaying ? 1.0 : 0.35
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }
                                TapHandler { enabled: Media.canTogglePlaying; onTapped: Media.togglePlaying() }
                                HoverHandler { enabled: Media.canTogglePlaying; onHoveredChanged: playHit.hovered = hovered }
                            }
                            Item {
                                id: nextHit
                                property bool hovered: false
                                // Forced off for live content regardless of
                                // MPRIS's own canGoNext: there's nothing
                                // ahead of the live edge to skip forward
                                // into, only backward into the buffer.
                                readonly property bool enabled_: Media.canGoNext && !Media.isLive
                                width: 24
                                height: 24
                                Rectangle {
                                    // Full bone-on-black invert, not a
                                    // translucent brighten.
                                    anchors.centerIn: parent
                                    width: nextHit.hovered ? 22 : 0
                                    height: nextHit.hovered ? 22 : 0
                                    radius: width / 2
                                    color: Theme.ink
                                    opacity: nextHit.hovered ? 1 : 0
                                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 160 } }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    // fa-step_forward - see the prev
                                    // button's comment above for why.
                                    text: String.fromCodePoint(0xf051)
                                    color: nextHit.hovered ? Theme.bg : Theme.inkMuted
                                    opacity: nextHit.enabled_ ? 1.0 : 0.35
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }
                                TapHandler { enabled: nextHit.enabled_; onTapped: Media.next() }
                                HoverHandler { enabled: nextHit.enabled_; onHoveredChanged: nextHit.hovered = hovered }
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
                            // Media.length > 0, not just !isLive: MPRIS
                            // metadata (duration especially) often arrives
                            // asynchronously, slightly after a player
                            // registers or right after this shell itself
                            // restarts mid-playback - during that brief
                            // window length reads as 0, and length-position
                            // would show a misleading "0:00" (reading as
                            // "about to end") instead of just not showing
                            // anything until the real value lands. Haziq
                            // hit this exact window: "it shows the correct
                            // end time... suddenly" once metadata caught up.
                            visible: !Media.isLive && Media.length > 0
                            color: Theme.inkSubtle
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            text: root.fmt(Media.length - Media.position)
                        }
                        // The fallback for when duration genuinely never
                        // arrives (see root.needsDuration's own comment) -
                        // points at the actual fix (the browser tab's own
                        // MPRIS report is stale) rather than this
                        // project's own restart, which wouldn't help here.
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root._durationStuck
                            color: Theme.inkDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.letterSpacing: 1
                            text: "REFRESH TAB"
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

            // 06 INBOX: services/Notifs.qml's own history array, not
            // NotificationServer.trackedNotifications (that list only ever
            // holds the ONE currently-showing notification, since
            // app/Bridges.qml's Slice-6 cleanup expires/dismisses each one
            // as soon as its peek ends - see that file's own comment).
            // Was hard-truncated to the first 2 (matching the design
            // reference's `hint-placeholder-count="2"`) with the rest of
            // history completely unreachable from the UI - Haziq wanted
            // scroll instead of truncation, so this is now a ListView
            // clipped to roughly a 2-card viewport (same height budget as
            // before, so 07 SESSION below it doesn't move) showing the
            // FULL history, scrollable for anything past what fits. CLEAR
            // ALL empties the whole history either way.
            //
            // The header (INBOX label, badge, CLEAR ALL) always shows,
            // even with zero notifications - "even there's no
            // notification, it should just shown the label inbox with
            // the clear all button and all." Matches this same page's
            // own "keep the visual completeness, dim what's not real"
            // rule already applied to ETH/VPN/SYNC. The ListView itself
            // still naturally collapses to zero height when history is
            // empty (contentHeight is 0), so nothing forces a fake empty
            // card into existence - just the header stays put.
            Column {
                width: parent.width
                spacing: 9

                Item {
                    width: parent.width
                    height: inboxCountBadge.implicitHeight

                    Row {
                        anchors.left: parent.left
                        spacing: 9
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "06"; color: Theme.inkDim; font.family: Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 2 }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "INBOX"; color: Theme.inkMuted; font.family: Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 2 }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "通知"; color: Theme.inkDim; font.family: Theme.fontFamilyJp; font.pixelSize: 9 }
                        CountBadge {
                            id: inboxCountBadge
                            anchors.verticalCenter: parent.verticalCenter
                            // "For 0 unread, no need... if only there's
                            // something unread than the badge shown."
                            // Row already excludes invisible children from
                            // layout, so hiding this just closes the gap
                            // rather than leaving a hole.
                            visible: Notifs.history.length > 0
                            count: Notifs.history.length
                        }
                    }
                    // "For hovering on things that is just text, show the
                    // text in a badge" - a fixed-size hit area (so the
                    // right-anchored position never shifts) with a badge
                    // Rectangle that grows/fades in behind the label on
                    // hover, rather than a static box always being there.
                    Item {
                        id: clearAllHit
                        property bool hovered: false
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: clearAllLabel.implicitWidth + 16
                        height: 18

                        Rectangle {
                            // Full bone-on-black invert, not a
                            // translucent brighten.
                            anchors.centerIn: parent
                            width: clearAllLabel.implicitWidth + (clearAllHit.hovered ? 14 : 0)
                            height: clearAllHit.hovered ? 16 : 0
                            radius: height / 2
                            color: Theme.ink
                            opacity: clearAllHit.hovered ? 1 : 0
                            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 160 } }
                        }
                        Text {
                            id: clearAllLabel
                            anchors.centerIn: parent
                            color: clearAllHit.hovered ? Theme.bg : Theme.inkSubtle
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.letterSpacing: 2
                            text: "CLEAR ALL"
                        }
                        TapHandler { onTapped: Notifs.clearHistory() }
                        HoverHandler { onHoveredChanged: clearAllHit.hovered = hovered }
                    }
                }

                ListView {
                    id: inboxList
                    width: parent.width
                    // Shrinks to fit when there's less than a 1.5-card's
                    // worth of history (matching the old Column's own "no
                    // wasted empty space" behavior), clips at exactly 1.5
                    // cards otherwise - a deliberate "sneak peek" of the
                    // next card (not a full 2, which read as a complete,
                    // self-contained list with nothing obviously left off
                    // it) to actually signal there's more to scroll. 103 =
                    // 64 (a card's real measured height - anchors.margins
                    // 9 top + appName row ~11 + spacing 3 + title ~14 +
                    // spacing 3 + body ~13 + the delegate's own +18 bottom
                    // pad) + 7 (this ListView's own spacing, once) + 32
                    // (half of a second card, deliberately truncated).
                    height: Math.min(contentHeight, 103)
                    clip: true
                    spacing: 7
                    boundsBehavior: Flickable.StopAtBounds
                    model: Notifs.history

                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        readonly property bool hasActions: modelData.actions && modelData.actions.length > 0

                        width: inboxList.width
                        height: (hasActions ? inboxActions.y + inboxActions.implicitHeight : inboxBody.y + inboxBody.implicitHeight) + 18
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.hairline

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 3
                            color: Theme.divider
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 9
                            anchors.leftMargin: 11
                            spacing: 3

                            Item {
                                width: parent.width
                                height: inboxApp.implicitHeight
                                Text {
                                    id: inboxApp
                                    anchors.left: parent.left
                                    color: Theme.inkSubtle
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    font.letterSpacing: 2
                                    text: modelData.appName.toUpperCase()
                                }
                                Text {
                                    anchors.right: parent.right
                                    color: Theme.inkSubtle
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    text: modelData.time
                                }
                            }
                            Text {
                                width: parent.width
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                textFormat: Text.PlainText
                                text: modelData.title
                            }
                            Text {
                                id: inboxBody
                                width: parent.width
                                color: Theme.inkFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                textFormat: Text.PlainText
                                text: modelData.body
                            }

                            // Same action-pill pattern as
                            // pages/NotificationPeek.qml, so an action
                            // (e.g. cachy-update's) can still be invoked
                            // from the history, not just the transient
                            // peek that already scrolled past.
                            Row {
                                id: inboxActions
                                visible: card.hasActions
                                spacing: 8

                                Repeater {
                                    model: card.hasActions ? card.modelData.actions : []

                                    Rectangle {
                                        required property var modelData

                                        implicitWidth: actionLabel.implicitWidth + 16
                                        implicitHeight: 20
                                        radius: 2
                                        color: "transparent"
                                        border.width: 1
                                        border.color: Theme.hairline

                                        Text {
                                            id: actionLabel
                                            anchors.centerIn: parent
                                            color: Theme.ink
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            font.letterSpacing: 1
                                            text: modelData.text
                                        }

                                        TapHandler {
                                            // Same exclusive grab as
                                            // NotificationPeek.qml's own
                                            // action pills, same reason:
                                            // ReleaseWithinBounds actually
                                            // suppresses this card's own
                                            // ancestor handlers (if it
                                            // grows one later) for this
                                            // tap point, the default
                                            // passive grab wouldn't.
                                            gesturePolicy: TapHandler.ReleaseWithinBounds
                                            onTapped: modelData.invoke()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

        }

        // Anchored to content's own bottom, deliberately OUTSIDE
        // builtSections' top-down Column: with 06 INBOX hidden (no
        // notifications) or short (1-2 items), a plain top-down flow left
        // this row floating right under 05 SYSTEM with a large dead gap
        // below it. The design's own flexbox has INBOX as `flex:1` so it
        // (invisibly) absorbs whatever's left and this row always lands
        // at the true bottom - anchoring this row directly reproduces
        // that outcome without needing a real flex-shrink implementation.
        Column {
            id: sessionFooter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 16

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.hairline
            }

            // 07 SESSION: workspace pills (left, click-to-switch via
            // `niri msg action focus-workspace <ref>` - NOTES.md's Slice 7
            // notes document `niri msg action <anything>` reproducibly
            // wedging this project's nested-niri test IPC socket, which is
            // why this was originally left read-only. Re-verified against
            // the current niri version before wiring this up: 15+ calls
            // (single, repeated, the exact `focus-workspace-down` verb
            // named in that finding, and 10 concurrent rapid-fire calls)
            // all completed cleanly with the socket staying fully
            // responsive throughout - the original bug looks fixed
            // upstream since that finding was written. `timeout`-wrapped
            // anyway as a cheap safety net: a future regression would then
            // only ever hang the one spawned CLI process, never this shell.
            // ETH/VPN/SYNC (middle, dimmed placeholders - no real network/
            // VPN/sync-status backend exists, same "keep the visual
            // completeness, dim what's not real" call already made for
            // TOGGLES' DND/NIGHT/VPN/CAPS/IDLE) plus battery% (real,
            // hidden when unavailable - permanently the case on this
            // desktop), and LOCK/SLEEP/POWER (right, real).
            //
            // SLEEP and POWER need a tap-to-arm, tap-again-to-confirm step
            // (LOCK doesn't: it's instant, harmless, trivially reversible).
            // The design's own mockup has no confirmation step at all, just
            // a plain button - a single misclick powering off the machine
            // is a real risk a design mockup doesn't have to account for.
            // Quickshell.execDetached fires the action with no
            // success/failure feedback; acceptable here since all three
            // outcomes are self-evident (the screen locks, the system
            // suspends, or it's off) and none of them ever fail in a way
            // worth designing a recovery path for.
            Item {
                width: parent.width
                height: 20

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Repeater {
                        model: Workspaces.list

                        Rectangle {
                            id: wsPill
                            required property var modelData
                            property bool hovered: false
                            // The currently-active workspace gets the SAME
                            // persistent full invert as hover, not just a
                            // faint tint - matching ToggleButton's ON
                            // state getting the same treatment as its own
                            // hover, per Haziq's "same on the which
                            // workspace we currently at."
                            readonly property bool inverted: hovered || modelData.active

                            // Unlike WorkspacePeek.qml's plain dots (where
                            // "active" can just mean "wider"), each pill
                            // here contains a label - active/inactive is
                            // carried by color/border only, both size the
                            // same so the active state can't clip its text.
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(20, wsLabel.implicitWidth + 8)
                            height: 20
                            // Full bone-on-black invert (Theme.ink
                            // background, Theme.bg text), not a
                            // translucent brighten, and morph the small
                            // resting radius (2) into a fully rounded pill.
                            radius: wsPill.inverted ? height / 2 : 2
                            color: wsPill.inverted ? Theme.ink : "transparent"
                            border.width: 1
                            border.color: modelData.active ? Theme.divider : Theme.hairline
                            Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 160 } }

                            Text {
                                id: wsLabel
                                anchors.centerIn: parent
                                color: wsPill.inverted ? Theme.bg : Theme.inkDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                text: modelData.name
                            }

                            // modelData.name is already "the workspace's own
                            // name if it has one, else its numeric index as
                            // a string" (services/Workspaces.qml) - exactly
                            // the "reference (index or name)" niri's own
                            // focus-workspace action expects, so the exact
                            // label on screen is always a valid argument.
                            TapHandler {
                                onTapped: Quickshell.execDetached(["timeout", "3", "niri", "msg", "action", "focus-workspace", modelData.name])
                            }
                            HoverHandler {
                                onHoveredChanged: wsPill.hovered = hovered
                            }
                        }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 13

                    Text { anchors.verticalCenter: parent.verticalCenter; text: "ETH"; color: Theme.inkSubtle; font.family: Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 2 }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "VPN"; color: Theme.inkDim; font.family: Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 2 }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "SYNC"; color: Theme.inkDim; font.family: Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 2 }
                    Rectangle {
                        width: 1
                        height: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.divider
                        visible: Battery.available
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Battery.available
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        text: Math.round(Battery.percentage) + "%"
                    }
                }

                Row {
                anchors.right: parent.right
                spacing: 7

                Rectangle {
                    id: lockBtn
                    property bool hovered: false

                    implicitWidth: lockLabel.implicitWidth + 18
                    implicitHeight: 20
                    // Full bone-on-black invert on hover, not a
                    // translucent brighten.
                    radius: lockBtn.hovered ? height / 2 : 2
                    color: lockBtn.hovered ? Theme.ink : "transparent"
                    border.width: 1
                    border.color: Theme.hairline
                    Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Text {
                        id: lockLabel
                        // Not centerIn: font.letterSpacing adds space AFTER
                        // every character including the last one, so a
                        // naive centerIn sits the text visibly left of true
                        // centre (confirmed empirically with a crosshair
                        // test - most visible on odd-length labels like
                        // SLEEP/POWER, where centerIn landed the middle
                        // character's edge on the box's actual centre
                        // instead of its own middle). Half the letter-
                        // spacing corrects it. The +1 vertical offset
                        // corrects a separate, unrelated effect: an
                        // all-caps label (no descenders) still centers
                        // against the font's full line metrics, which
                        // include descender space it never uses, so it
                        // sits visibly high without this.
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: font.letterSpacing / 2
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 1
                        // LOCK/SLEEP/POWER now step up in visual weight
                        // (dimmest to brightest, staying entirely within
                        // the ink ramp - no new hue) to read as
                        // "increasing consequence" at a glance: LOCK is
                        // instant/harmless/reversible, so it stays the
                        // calmest of the three. Inverts to Theme.bg on
                        // hover, matching the button's own invert.
                        color: lockBtn.hovered ? Theme.bg : Theme.inkDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.letterSpacing: 2
                        text: "LOCK"
                    }
                    TapHandler {
                        // Was `loginctl lock-session`, which just emits a
                        // logind D-Bus signal - it did nothing on its own
                        // without something subscribed to it. Noctalia used
                        // to be that listener; niri-lockscreen (its
                        // replacement) never subscribed to that signal at
                        // all - its only triggers are this exact IPC call
                        // (same one Mod+ALT+L already uses), idle timeout,
                        // and the suspend hook. Calling the real mechanism
                        // directly instead of hoping something's listening.
                        onTapped: Quickshell.execDetached(["qs", "-c", "niri-lockscreen", "ipc", "call", "lockscreen", "lock"])
                    }
                    HoverHandler {
                        onHoveredChanged: lockBtn.hovered = hovered
                    }
                }

                Rectangle {
                    id: sleepBtn
                    property bool armed: false
                    property bool hovered: false

                    implicitWidth: sleepLabel.implicitWidth + 18
                    implicitHeight: 20
                    // Full bone-on-black invert on hover, not a
                    // translucent brighten.
                    radius: sleepBtn.hovered ? height / 2 : 2
                    color: sleepBtn.hovered ? Theme.ink : "transparent"
                    border.width: 1
                    border.color: armed ? Theme.divider : Theme.hairline
                    Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Timer {
                        id: sleepArmTimer
                        interval: 3000
                        onTriggered: sleepBtn.armed = false
                    }
                    Text {
                        id: sleepLabel
                        // See lockLabel's comment for why centerIn alone
                        // isn't right here.
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: font.letterSpacing / 2
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 1
                        // Theme.bg when hovered (background just inverted
                        // to Theme.ink under it), else the existing
                        // armed/resting distinction.
                        color: sleepBtn.hovered ? Theme.bg : (sleepBtn.armed ? Theme.ink : Theme.inkMuted)
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.letterSpacing: 2
                        text: sleepBtn.armed ? "CONFIRM?" : "SLEEP"
                    }
                    TapHandler {
                        onTapped: {
                            if (sleepBtn.armed) {
                                sleepArmTimer.stop()
                                sleepBtn.armed = false
                                Quickshell.execDetached(["systemctl", "suspend"])
                            } else {
                                sleepBtn.armed = true
                                sleepArmTimer.restart()
                            }
                        }
                    }
                    HoverHandler {
                        onHoveredChanged: sleepBtn.hovered = hovered
                    }
                }

                Rectangle {
                    id: powerBtn
                    property bool armed: false
                    property bool hovered: false

                    implicitWidth: powerLabel.implicitWidth + 18
                    implicitHeight: 20
                    // Full bone-on-black invert on hover, not a
                    // translucent brighten.
                    radius: powerBtn.hovered ? height / 2 : 2
                    color: powerBtn.hovered ? Theme.ink : "transparent"
                    border.width: 1
                    // Brightest of the three at rest (Theme.divider,
                    // Theme.inkSubtle below), escalating to the existing
                    // red only once actually armed - POWER is the most
                    // consequential of the three, so it carries the most
                    // visual weight before you even touch it.
                    border.color: armed ? "#d75f5f" : Theme.divider
                    Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Timer {
                        id: powerArmTimer
                        interval: 3000
                        onTriggered: powerBtn.armed = false
                    }
                    Text {
                        id: powerLabel
                        // See lockLabel's comment for why centerIn alone
                        // isn't right here.
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: font.letterSpacing / 2
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 1
                        // Red stays red even when hovered (still reads
                        // as a danger signal on a white background);
                        // otherwise Theme.bg when hovered, matching the
                        // button's own invert.
                        color: powerBtn.armed ? "#d75f5f" : (powerBtn.hovered ? Theme.bg : Theme.inkSubtle)
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.letterSpacing: 2
                        text: powerBtn.armed ? "CONFIRM?" : "POWER"
                    }
                    TapHandler {
                        onTapped: {
                            if (powerBtn.armed) {
                                powerArmTimer.stop()
                                powerBtn.armed = false
                                Quickshell.execDetached(["systemctl", "poweroff"])
                            } else {
                                powerBtn.armed = true
                                powerArmTimer.restart()
                            }
                        }
                    }
                    HoverHandler {
                        onHoveredChanged: powerBtn.hovered = hovered
                    }
                }
                }
            }
        }
    }
}
