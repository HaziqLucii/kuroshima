pragma Singleton
import QtQuick

QtObject {
    // Capsule width/height/radius morph. The design specifies a CSS
    // overshoot curve (`cubic-bezier(.34, 1.5, .5, 1)`), not a physical
    // spring, and Qt's Easing.BezierSpline reproduces a CSS cubic-bezier
    // exactly (control points cp1, cp2, endpoint; y can exceed 1 for the
    // overshoot, unlike x). This replaces the old SpringAnimation-based
    // morph, which is also a deliberate safety win: a spring can diverge
    // numerically (a bad Motion.qml value once sent width past a million
    // px and froze the GPU via MultiEffect's shadow texture, see
    // docs/HANDOFF.md); a fixed-duration bezier animation to a known
    // target cannot.
    readonly property int morphDuration: 520
    readonly property var morphBezier: [0.34, 1.5, 0.5, 1.0, 1.0, 1.0]

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

    // "AUTO COLLAPSE: 1800ms after exit" in the design. Currently only
    // drives ui/Capsule.qml's expanded-page auto-collapse (slice 3.5); the
    // design also uses it for the not-yet-built hover-peek pill.
    readonly property int autoCollapseDelay: 1800
}
