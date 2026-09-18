pragma Singleton
import QtQuick

QtObject {
    readonly property int morph: 420
    readonly property int morphEasing: Easing.OutQuint

    readonly property int fadeOut: 140
    readonly property int fadeIn: 220
    readonly property int fadeInDelay: 60
    readonly property real scaleFrom: 0.96

    readonly property int hoverGrace: 700
    readonly property int debounceOsd: 16
}
