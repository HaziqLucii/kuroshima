pragma Singleton
import QtQuick

QtObject {
    // Spring physics for the capsule width/height morph. No fixed
    // duration: SpringAnimation is driven by these three. Measured
    // settling around 250-500ms at these values, tune by feel via hot
    // reload from here, but change one field at a time and watch
    // ui/Capsule.qml's clamp (Theme.canvasW/H) is what protects against a
    // bad value; a spring of 300 here once made width diverge to over a
    // million px (confirmed via the quickshell log), which drove a GPU
    // texture allocation the same size and froze the whole desktop. This
    // integrator is only stable for small spring values relative to the
    // frame timestep, "hundreds" from generic spring-UI advice does not
    // apply to it.
    readonly property real morphSpring: 18
    readonly property real morphDamping: 3.5
    readonly property real morphMass: 1.0

    readonly property int fadeOut: 140
    readonly property int fadeIn: 220
    readonly property int fadeInDelay: 60
    readonly property real scaleFrom: 0.96

    readonly property int hoverGrace: 700
    readonly property int debounceOsd: 16
}
