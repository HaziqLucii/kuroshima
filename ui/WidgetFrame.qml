import QtQuick
import qs.theme
import qs.services

// Wraps one placed widget instance with edit-mode-only chrome (hairline
// border, delete badge, drag-to-move), same separation of concerns as the
// page contract: a widget file (widgets/*.qml) doesn't know this exists,
// same as a page doesn't know about IslandWindow's morph animation.
Item {
    id: root

    property string widgetId: ""
    property string widgetType: ""
    property bool widgetCustom: false
    property real posX: 0
    property real posY: 0

    x: posX
    y: posY
    implicitWidth: Math.max(loader.implicitWidth, 1)
    implicitHeight: Math.max(loader.implicitHeight, 1)
    width: implicitWidth
    height: implicitHeight

    Loader {
        id: loader
        source: Widgets.urlFor(root.widgetType, root.widgetCustom)
        // A widget failing to load (bad user QML) shouldn't take the
        // whole canvas down with it - just that one instance stays empty.
        onLoaded: {}
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        visible: Widgets.editMode
        color: "transparent"
        border.width: 1
        border.color: Theme.divider
        radius: 2
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        enabled: Widgets.editMode
        cursorShape: Widgets.editMode ? Qt.SizeAllCursor : Qt.ArrowCursor
        drag.target: Widgets.editMode ? root : null
        onReleased: Widgets.moveWidget(root.widgetId, root.x, root.y)
    }

    Rectangle {
        visible: Widgets.editMode
        width: 16
        height: 16
        radius: 2
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -14
        anchors.rightMargin: -14
        color: Theme.bg
        border.width: 1
        border.color: Theme.inkDim

        Text {
            anchors.centerIn: parent
            text: "×"
            color: Theme.inkMuted
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Widgets.removeWidget(root.widgetId)
        }
    }
}
