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
    // 0 means "not resized yet, use the widget's own natural size" - only
    // becomes a real value once the resize handle below is used.
    property real sizeW: 0
    property real sizeH: 0

    x: posX
    y: posY
    implicitWidth: sizeW > 0 ? sizeW : Math.max(loader.implicitWidth, 1)
    implicitHeight: sizeH > 0 ? sizeH : Math.max(loader.implicitHeight, 1)
    width: implicitWidth
    height: implicitHeight

    Loader {
        id: loader
        // Fills the frame rather than sizing the frame to itself - lets a
        // resize actually resize the widget's own content instead of just
        // the frame around it. Widgets declare implicitWidth/Height as a
        // natural-size hint (see the widget contract in CLAUDE.md) but
        // shouldn't bind their own width/height, or this fill can't do
        // anything - same reason pages/*.qml self-size and widgets/*.qml
        // deliberately don't.
        anchors.fill: parent
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

    Rectangle {
        visible: Widgets.editMode
        width: 14
        height: 14
        radius: 2
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -7
        anchors.bottomMargin: -7
        color: Theme.bg
        border.width: 1
        border.color: Theme.inkDim

        MouseArea {
            id: resizeHandle
            anchors.fill: parent
            cursorShape: Qt.SizeFDiagCursor
            property real startW: 0
            property real startH: 0
            property real startMouseX: 0
            property real startMouseY: 0

            onPressed: mouse => {
                startW = root.width
                startH = root.height
                const p = mapToItem(null, mouse.x, mouse.y)
                startMouseX = p.x
                startMouseY = p.y
            }
            onPositionChanged: mouse => {
                if (!pressed) return
                const p = mapToItem(null, mouse.x, mouse.y)
                // 40x30 floor: small enough for a tight widget, large
                // enough that the delete/resize handles never overlap.
                root.sizeW = Math.max(40, startW + (p.x - startMouseX))
                root.sizeH = Math.max(30, startH + (p.y - startMouseY))
            }
            onReleased: Widgets.resizeWidget(root.widgetId, root.sizeW, root.sizeH)
        }
    }
}
