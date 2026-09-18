pragma Singleton
import QtQuick

QtObject {
    // Spring physics for the capsule width/height morph, tuned for a
    // visible overshoot-and-settle bounce on click. No fixed duration:
    // SpringAnimation is driven by these three, tune by feel via hot reload.
    readonly property real morphSpring: 3.5
    readonly property real morphDamping: 0.4
    readonly property real morphMass: 1.0

    readonly property int fadeOut: 140
    readonly property int fadeIn: 220
    readonly property int fadeInDelay: 60
    readonly property real scaleFrom: 0.96

    readonly property int hoverGrace: 700
    readonly property int debounceOsd: 16
}
