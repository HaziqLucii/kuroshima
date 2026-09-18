import QtQuick
import qs.theme
import qs.services

// Reached via Island.expand("MediaExpanded"), a persistent view, not a
// transient peek, so it reads live from the Media service directly
// rather than from `payload` (expand() carries no payload; Island.payload
// is null whenever there's no current transient). `payload` is still
// declared, required by the page contract even though unused here.
Item {
    id: root

    property var payload: null
    // Declared but unused: already the expanded destination, nothing
    // further to expand to. Present so ui/Capsule.qml's generic
    // Connections to whatever page is current doesn't warn about a
    // missing signal every time this page is shown.
    signal requestExpand(string pageId)

    implicitWidth: 320
    implicitHeight: 150
    width: implicitWidth
    height: implicitHeight

    Column {
        anchors.centerIn: parent
        spacing: 10
        width: parent.width - 40

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 15
            text: Media.title
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Theme.ink
            opacity: 0.6
            font.family: Theme.fontFamily
            font.pixelSize: 12
            text: Media.artist
            elide: Text.ElideRight
        }

        Rectangle {
            width: parent.width
            height: 3
            radius: 1.5
            color: Theme.hairline

            Rectangle {
                width: Media.length > 0 ? parent.width * Math.min(1, Media.position / Media.length) : 0
                height: parent.height
                radius: parent.radius
                color: Theme.ink
            }
        }

        // Three matching transport buttons: hairline-bordered, near-sharp
        // corners (2px, matching the capsule's own radius language),
        // bone-ink glyphs on transparent, not filled color blocks. One
        // consistent visual language instead of mixing text labels with
        // an icon button.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            Rectangle {
                width: 32
                height: 32
                radius: 2
                color: "transparent"
                border.width: 1
                border.color: Theme.hairline
                opacity: Media.canGoPrevious ? 1.0 : 0.3

                Canvas {
                    anchors.centerIn: parent
                    width: 14
                    height: 12
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.fillStyle = Theme.ink
                        // Skip-previous: bar, then a left-pointing triangle.
                        ctx.fillRect(0, 0, width * 0.15, height)
                        ctx.beginPath()
                        ctx.moveTo(width, 0)
                        ctx.lineTo(width * 0.3, height / 2)
                        ctx.lineTo(width, height)
                        ctx.closePath()
                        ctx.fill()
                    }
                }

                TapHandler {
                    enabled: Media.canGoPrevious
                    onTapped: Media.previous()
                }
            }

            Rectangle {
                id: playPauseButton
                width: 32
                height: 32
                radius: 2
                color: "transparent"
                border.width: 1
                border.color: Theme.hairline
                opacity: Media.canTogglePlaying ? 1.0 : 0.3

                Canvas {
                    anchors.centerIn: parent
                    width: 12
                    height: 12
                    property bool playing: Media.isPlaying
                    onPlayingChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.fillStyle = Theme.ink
                        if (playing) {
                            ctx.fillRect(0, 0, width * 0.3, height)
                            ctx.fillRect(width * 0.7, 0, width * 0.3, height)
                        } else {
                            ctx.beginPath()
                            ctx.moveTo(0, 0)
                            ctx.lineTo(width, height / 2)
                            ctx.lineTo(0, height)
                            ctx.closePath()
                            ctx.fill()
                        }
                    }
                }

                TapHandler {
                    enabled: Media.canTogglePlaying
                    onTapped: Media.togglePlaying()
                }
            }

            Rectangle {
                width: 32
                height: 32
                radius: 2
                color: "transparent"
                border.width: 1
                border.color: Theme.hairline
                opacity: Media.canGoNext ? 1.0 : 0.3

                Canvas {
                    anchors.centerIn: parent
                    width: 14
                    height: 12
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.fillStyle = Theme.ink
                        // Skip-next: a right-pointing triangle, then a bar.
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.lineTo(width * 0.7, height / 2)
                        ctx.lineTo(0, height)
                        ctx.closePath()
                        ctx.fill()
                        ctx.fillRect(width * 0.85, 0, width * 0.15, height)
                    }
                }

                TapHandler {
                    enabled: Media.canGoNext
                    onTapped: Media.next()
                }
            }
        }
    }
}
