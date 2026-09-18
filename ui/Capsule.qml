import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.theme
import qs.pages

Item {
    id: root

    function setPage(name, payload) {
        host.setPage(name, payload)
    }

    Component.onCompleted: setPage("compact", null)

    Component { id: compactComponent; CompactPage {} }
    Component { id: dummyWideComponent; DummyWide {} }

    width: host.targetWidth
    height: host.targetHeight

    Behavior on width { MorphAnimation {} }
    Behavior on height { MorphAnimation {} }

    // Shadow always-on is fine while the capsule morphs at most a few
    // times a minute; revisit if a future page keeps geometry animating
    // continuously (see Theme.qml / HANDOFF.md for the 200Hz budget note).
    MultiEffect {
        source: background
        anchors.fill: background
        shadowEnabled: true
        shadowColor: Theme.shadowColor
        shadowOpacity: Theme.shadowOpacity
        shadowBlur: Theme.shadowBlur
        shadowVerticalOffset: Theme.shadowVerticalOffset
    }

    ClippingRectangle {
        id: background
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.bg
        border.width: 0

        PageHost {
            id: host
            anchors.centerIn: parent
            pageMap: ({
                "compact": compactComponent,
                "dummyWide": dummyWideComponent
            })
        }
    }
}
