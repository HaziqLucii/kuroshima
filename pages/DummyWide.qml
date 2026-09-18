import QtQuick
import qs.theme

// Slice 1 test fixture only: proves the capsule morphs to a page of a very
// different size. Delete once a real wide page (MediaPeek etc.) exists.
Item {
    id: root

    property var payload: null

    implicitWidth: 420
    implicitHeight: 120
    width: implicitWidth
    height: implicitHeight

    Text {
        anchors.centerIn: parent
        color: Theme.ink
        font.family: Theme.fontFamily
        font.pixelSize: 16
        font.letterSpacing: 1
        text: "DUMMY WIDE PAGE"
    }
}
