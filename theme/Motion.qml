pragma Singleton
import QtQuick

QtObject {
    // Capsule width/height/radius morph. The design's own
    // `cubic-bezier(.34, 1.5, .5, 1)` overshoot (tried via
    // Easing.BezierSpline) read as too bouncy once actually seen live, for
    // both the expand and collapse directions - Haziq wanted the original,
    // more restrained spring feel back instead, closer to how macOS's
    // actual Dynamic Island moves. Reverted to the pre-redesign
    // SpringAnimation values. Change one field at a time and watch
    // ui/Capsule.qml's clamp (Theme.canvasW/H) is what protects against a
    // bad value: a spring of 300 here once made width diverge to over a
    // million px (confirmed via the quickshell log), which drove a GPU
    // texture allocation the same size and froze the whole desktop. This
    // integrator is only stable for small spring values relative to the
    // frame timestep, "hundreds" from generic spring-UI advice does not
    // apply to it.
    readonly property real morphSpring: 18
    readonly property real morphDamping: 3.5
    readonly property real morphMass: 1.0

    // Content crossfade: "220ms ease-out, +4px rise" in the design, applied
    // symmetrically here (incoming rises in, outgoing drops out) since the
    // design only specifies the enter keyframe.
    readonly property int fadeDuration: 220
    readonly property real fadeRise: 4
    readonly property var fadeBezier: [0.0, 0.0, 0.58, 1.0, 1.0, 1.0]

    // Not in the design: internal stagger so the two-slot crossfade in
    // ui/PageHost.qml doesn't show a fully-transparent gap between the
    // outgoing and incoming page.
    readonly property int fadeInDelay: 60

    readonly property int hoverGrace: 700
    readonly property int debounceOsd: 16

    // Was 1800ms ("AUTO COLLAPSE: 1800ms after exit" in the design) -
    // Haziq felt that lagged too long after moving the mouse off the
    // expanded dashboard. Currently only drives ui/Capsule.qml's
    // expanded-page auto-collapse (slice 3.5); the design also uses it
    // for the not-yet-built hover-peek pill.
    readonly property int autoCollapseDelay: 1000
}
