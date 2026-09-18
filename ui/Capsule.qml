import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.theme
import qs.pages

Item {
    id: root

    width: page.implicitWidth
    height: page.implicitHeight

    // Slice 0: static size, no morph yet (that's slice 1). The shadow is
    // safe to leave always-on here because nothing changes geometry every
    // frame; revisit if morphing later makes this a per-frame cost.
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

        CompactPage {
            id: page
            anchors.centerIn: parent
        }
    }
}
