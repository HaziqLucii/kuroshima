import QtQuick
import qs.theme

// Drop into `Behavior on width/height/radius { MorphAnimation {} }` on the
// capsule. A fixed-duration bezier, not a spring: Easing.BezierSpline with
// Motion.morphBezier reproduces the design's `cubic-bezier(.34, 1.5, .5, 1)`
// overshoot exactly (control points, y > 1 allowed) and, unlike the spring
// this replaced, can't numerically diverge since it always runs for
// Motion.morphDuration to a known target.
NumberAnimation {
    duration: Motion.morphDuration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.morphBezier
}
