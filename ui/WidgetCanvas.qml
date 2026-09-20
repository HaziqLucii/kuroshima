import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

// Desktop widget canvas: same background-layer shape as
// WallpaperBackground.qml, sitting above it (instantiated after it in
// shell.qml). No `mask` needed the way IslandWindow.qml uses one - that
// trick exists because IslandWindow sits on WlrLayer.Top, ABOVE normal
// windows, so an unmasked transparent surface would steal clicks meant
// for whatever's underneath. This surface is on WlrLayer.Background,
// BELOW normal windows, so a real window at any given spot already wins
// input by ordinary stacking - each MouseArea below just gates its own
// `enabled` on edit mode, which is simpler and equally correct here.
PanelWindow {
    id: root

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "kuroshima-widgets"
    // One layer above WallpaperBackground's WlrLayer.Background - same-layer
    // stacking order between two surfaces isn't guaranteed by creation order
    // (confirmed live: instantiating this after WallpaperBackground in
    // shell.qml did NOT reliably render above it). Bottom is still below
    // Top/Overlay, where real application windows live, so normal windows
    // still win over widgets exactly like before.
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Subtle full-screen tint while editing, so it's unambiguous the
    // desktop is in a different mode - not meant to be loud.
    Rectangle {
        anchors.fill: parent
        visible: Widgets.editMode
        color: Qt.rgba(0, 0, 0, 0.25)
    }

    Repeater {
        model: Widgets.placed
        delegate: WidgetFrame {
            widgetId: modelData.id
            widgetType: modelData.type
            widgetCustom: !!modelData.custom
            posX: modelData.x
            posY: modelData.y
        }
    }

    // Add-widget affordance: bottom-right pill + a plain list of available
    // types, bundled and custom together. Edit-mode-only, same as the
    // per-widget chrome in WidgetFrame.qml.
    Column {
        id: addUi
        visible: Widgets.editMode
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 8

        Rectangle {
            id: pickerList
            visible: pickerOpen.checked
            anchors.right: parent.right
            width: 180
            height: typeColumn.implicitHeight + 16
            color: Theme.bg
            border.width: 1
            border.color: Theme.divider
            radius: 2

            Column {
                id: typeColumn
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                Repeater {
                    model: Widgets.bundledTypes.map(t => ({ type: t, custom: false }))
                        .concat(Widgets.customTypes.map(t => ({ type: t, custom: true })))
                    delegate: Rectangle {
                        width: typeColumn.width
                        height: 26
                        color: entryMouse.containsMouse ? Theme.hairline : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.type + (modelData.custom ? " (custom)" : "")
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: entryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                Widgets.addWidget(modelData.type, modelData.custom)
                                pickerOpen.checked = false
                            }
                        }
                    }
                }

                Text {
                    visible: Widgets.bundledTypes.length === 0 && Widgets.customTypes.length === 0
                    text: "no widgets available"
                    color: Theme.inkDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }

        Rectangle {
            width: pill.implicitWidth + 24
            height: 32
            radius: 16
            color: pickerOpen.checked ? Theme.ink : Theme.bg
            border.width: 1
            border.color: Theme.divider

            Text {
                id: pill
                anchors.centerIn: parent
                text: pickerOpen.checked ? "CLOSE" : "+ ADD WIDGET"
                color: pickerOpen.checked ? Theme.bg : Theme.inkMuted
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 1
            }

            MouseArea {
                id: pickerOpen
                property bool checked: false
                anchors.fill: parent
                onClicked: checked = !checked
            }
        }
    }
}
