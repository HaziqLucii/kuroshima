import QtQuick
import qs.theme
import qs.services
import qs.ui

// Loaded by pages/SettingsExpanded.qml's Loader for the "audio" category -
// not itself a top-level page (no page-contract signals needed), just
// fills whatever box the Loader gives it. Template for whatever category
// gets added next (Display, Network, ...): same "list + ScrubBar" shape,
// reading live from services/Audio.qml the same way MediaExpanded's own
// CONTROLS section already does for VOL/MIC.
Item {
    id: root
    anchors.fill: parent

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: parent.width
            spacing: 20

            // ── Output ──────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 8
                visible: Audio.sinks.length > 0

                Text {
                    color: Theme.inkMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.letterSpacing: 2
                    text: "OUTPUT"
                }

                Repeater {
                    model: Audio.sinks
                    delegate: Rectangle {
                        id: sinkRow
                        required property var modelData
                        readonly property bool isDefault: Audio.sink && modelData.id === Audio.sink.id
                        property bool hovered: false

                        width: parent.width
                        implicitHeight: 32
                        radius: 4
                        color: sinkRow.hovered ? Theme.hairline : "transparent"
                        border.width: 1
                        border.color: sinkRow.isDefault ? Theme.ink : Theme.hairline

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 10
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            color: sinkRow.isDefault ? Theme.ink : Theme.inkFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            text: sinkRow.modelData.description || sinkRow.modelData.name
                        }

                        TapHandler { onTapped: Audio.setDefaultSink(sinkRow.modelData) }
                        HoverHandler { onHoveredChanged: sinkRow.hovered = hovered }
                    }
                }

                Item {
                    width: parent.width
                    height: outVolValue.implicitHeight
                    visible: Audio.available

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.inkFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        text: "VOLUME"
                    }
                    Text {
                        id: outVolValue
                        anchors.right: parent.right
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        text: Math.round((Audio.muted ? 0 : Audio.volume) * 100)
                    }
                }
                ScrubBar {
                    width: parent.width
                    visible: Audio.available
                    value: Audio.muted ? 0 : Audio.volume
                    onScrub: (pct) => Audio.setVolume(pct)
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.hairline; visible: Audio.sources.length > 0 }

            // ── Input ───────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 8
                visible: Audio.sources.length > 0

                Text {
                    color: Theme.inkMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.letterSpacing: 2
                    text: "INPUT"
                }

                Repeater {
                    model: Audio.sources
                    delegate: Rectangle {
                        id: sourceRow
                        required property var modelData
                        readonly property bool isDefault: Audio.source && modelData.id === Audio.source.id
                        property bool hovered: false

                        width: parent.width
                        implicitHeight: 32
                        radius: 4
                        color: sourceRow.hovered ? Theme.hairline : "transparent"
                        border.width: 1
                        border.color: sourceRow.isDefault ? Theme.ink : Theme.hairline

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 10
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            color: sourceRow.isDefault ? Theme.ink : Theme.inkFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            text: sourceRow.modelData.description || sourceRow.modelData.name
                        }

                        TapHandler { onTapped: Audio.setDefaultSource(sourceRow.modelData) }
                        HoverHandler { onHoveredChanged: sourceRow.hovered = hovered }
                    }
                }

                Item {
                    width: parent.width
                    height: inVolValue.implicitHeight
                    visible: Audio.micAvailable

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.inkFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        text: "VOLUME"
                    }
                    Text {
                        id: inVolValue
                        anchors.right: parent.right
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        text: Math.round((Audio.micMuted ? 0 : Audio.micVolume) * 100)
                    }
                }
                ScrubBar {
                    width: parent.width
                    visible: Audio.micAvailable
                    value: Audio.micMuted ? 0 : Audio.micVolume
                    onScrub: (pct) => Audio.setMicVolume(pct)
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.hairline; visible: Audio.appStreams.length > 0 }

            // ── Applications ────────────────────────────────────
            // No app-icon resolution exists anywhere in this codebase or in
            // Quickshell.Services.Pipewire itself (no desktop-entry lookup)
            // - text-only labels, explicitly scoped out rather than
            // half-built. The `.audio` guards below aren't about it being
            // null (PwNode.audio is `isPropertyConstant: true`, it never
            // transitions null -> non-null after a node's created) - they
            // stay as a cheap defensive check against a genuinely
            // non-audio node ever slipping through the filters in
            // services/Audio.qml. What services/Audio.qml's PwObjectTracker
            // actually exists for is `.audio.volume`/`.audio.muted`
            // themselves: those two ARE notifiable (volumesChanged/
            // mutedChanged) and silently read stale/zero without tracking.
            Column {
                width: parent.width
                spacing: 12
                visible: Audio.appStreams.length > 0

                Text {
                    color: Theme.inkMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.letterSpacing: 2
                    text: "APPLICATIONS"
                }

                Repeater {
                    model: Audio.appStreams
                    delegate: Column {
                        id: appRow
                        required property var modelData
                        width: parent.width
                        spacing: 5

                        readonly property string appLabel: (
                            (appRow.modelData.properties && appRow.modelData.properties["application.name"])
                            || appRow.modelData.description
                            || appRow.modelData.name
                            || "UNKNOWN"
                        ).toUpperCase()
                        readonly property real appVolume: appRow.modelData.audio ? appRow.modelData.audio.volume : 0
                        readonly property bool appMuted: appRow.modelData.audio ? appRow.modelData.audio.muted : false

                        Item {
                            width: parent.width
                            height: appValue.implicitHeight

                            Text {
                                id: appLabelText
                                anchors.left: parent.left
                                anchors.right: appValue.left
                                anchors.rightMargin: 10
                                elide: Text.ElideRight
                                color: Theme.inkFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.letterSpacing: 1
                                text: appRow.appLabel
                            }
                            Text {
                                id: appValue
                                anchors.right: parent.right
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                text: Math.round((appRow.appMuted ? 0 : appRow.appVolume) * 100)
                            }
                        }
                        ScrubBar {
                            width: parent.width
                            value: appRow.appMuted ? 0 : appRow.appVolume
                            onScrub: (pct) => {
                                if (appRow.modelData.audio) {
                                    appRow.modelData.audio.volume = pct / 100
                                }
                            }
                        }
                    }
                }
            }

            Text {
                visible: Audio.sinks.length === 0 && Audio.sources.length === 0
                color: Theme.inkDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
                text: "NO AUDIO DEVICES"
            }
        }
    }
}
