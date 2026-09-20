import QtQuick
import qs.theme

// Reached via Island.expand("SettingsExpanded"), pushed onto the normal
// dashboard (ui/Capsule.qml's directionFor() picks "pushRight" for this
// page specifically, "popLeft" on the way back) rather than the plain
// crossfade every other page transition uses - Haziq wanted a real
// Android-style slide + back button. Same footprint as MediaExpanded
// (Theme.expandedW/H) so the transition reads as a pure horizontal push,
// not a simultaneous width/height morph.
//
// Left sidebar of category "bubbles" - just Audio today
// (pages/SettingsAudioPanel.qml), but built as a real model/Loader pair
// specifically because Haziq wants more categories added later without
// restructuring this file: adding one is a `categories` entry plus a
// content file, not a rewrite.
Item {
    id: root

    property var payload: null
    signal requestExpand(string pageId)
    readonly property real cornerRadius: Theme.expandedRadius

    implicitWidth: Theme.expandedW
    implicitHeight: Theme.expandedH
    width: implicitWidth
    height: implicitHeight

    readonly property var categories: [
        { id: "audio", icon: 0xf057e, label: "AUDIO", component: audioPanelComponent }
    ]
    property string activeCategory: "audio"
    readonly property var _activeEntry: root.categories.find(c => c.id === root.activeCategory)

    Component {
        id: audioPanelComponent
        SettingsAudioPanel {}
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: 20
        anchors.topMargin: 18
        anchors.bottomMargin: 18

        Row {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            spacing: 10

            Rectangle {
                id: backBtn
                property bool hovered: false
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 26
                implicitHeight: 26
                radius: backBtn.hovered ? height / 2 : 4
                color: backBtn.hovered ? Theme.ink : "transparent"
                border.width: 1
                border.color: Theme.hairline
                Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 160 } }

                Text {
                    anchors.centerIn: parent
                    color: backBtn.hovered ? Theme.bg : Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    // md-arrow-left, verified against the actual font's cmap
                    // (fontTools) before use, same discipline as every other
                    // icon glyph in this project.
                    text: String.fromCodePoint(0xf004d)
                }
                TapHandler { onTapped: root.requestExpand("MediaExpanded") }
                HoverHandler { onHoveredChanged: backBtn.hovered = hovered }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.letterSpacing: 2
                text: "SETTINGS"
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.inkDim
                font.family: Theme.fontFamilyJp
                font.pixelSize: 13
                text: "設定"
            }
        }

        Rectangle {
            id: headerRule
            anchors.top: header.bottom
            anchors.topMargin: 14
            width: parent.width
            height: 1
            color: Theme.hairline
        }

        Item {
            id: body
            anchors.top: headerRule.bottom
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            Column {
                id: sidebar
                anchors.left: parent.left
                anchors.top: parent.top
                width: 44
                spacing: 10

                Repeater {
                    model: root.categories
                    delegate: Rectangle {
                        id: bubble
                        required property var modelData
                        readonly property bool active: modelData.id === root.activeCategory
                        property bool hovered: false

                        width: 44
                        height: 44
                        radius: width / 2
                        color: bubble.active ? Theme.ink : (bubble.hovered ? Theme.hairline : "transparent")
                        border.width: 1
                        border.color: bubble.active ? Theme.ink : Theme.hairline
                        Behavior on color { ColorAnimation { duration: 160 } }

                        Text {
                            anchors.centerIn: parent
                            color: bubble.active ? Theme.bg : Theme.inkMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            text: String.fromCodePoint(bubble.modelData.icon)
                        }

                        TapHandler { onTapped: root.activeCategory = bubble.modelData.id }
                        HoverHandler { onHoveredChanged: bubble.hovered = hovered }
                    }
                }
            }

            Rectangle {
                anchors.left: sidebar.right
                anchors.leftMargin: 10
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: Theme.hairline
            }

            Loader {
                id: panelLoader
                anchors.left: sidebar.right
                anchors.leftMargin: 21
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                sourceComponent: root._activeEntry ? root._activeEntry.component : null
            }
        }
    }
}
