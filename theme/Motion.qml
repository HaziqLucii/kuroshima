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
    // damping/(2*sqrt(spring*mass)) was ~0.41 (underdamped enough to
    // visibly oscillate before settling) - Haziq wanted the morph
    // smoother. Raised damping only, not spring: the file's own warning
    // above is specifically about spring diverging, damping is the
    // stabilizing term and raising it can't cause that failure mode.
    // Landed at a ratio of ~0.76 (still a hair underdamped, so it keeps
    // some spring character rather than reading as a mechanical snap).
    readonly property real morphSpring: 18
    readonly property real morphDamping: 6.5
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

    // pushRight/popLeft page transitions (ui/PageHost.qml). A full-width
    // Android/iOS-style push (opaque, no fade, page-width travel distance)
    // was tried first and dropped - Haziq: "looks ugly... do you have any
    // animation idea that matches our theme kuro" - it read as a foreign
    // phone-UI import next to how restrained every other transition here
    // already is (fadeRise above is just 4px). This is the same small-
    // nudge treatment, just with an X component: fixed pixels, not a
    // fraction of the page's own width, and spring-eased
    // (morphSpring/damping/mass above) rather than the fade's bezier
    // curve, so it settles rather than glides - the same object language
    // as the capsule's own width/height/radius morph.
    readonly property real pushSlideDistance: 32

    readonly property int hoverGrace: 700
    readonly property int debounceOsd: 16

    // Was 1800ms ("AUTO COLLAPSE: 1800ms after exit" in the design) -
    // Haziq felt that lagged too long after moving the mouse off the
    // expanded dashboard. Currently only drives ui/Capsule.qml's
    // expanded-page auto-collapse (slice 3.5); the design also uses it
    // for the not-yet-built hover-peek pill.
    readonly property int autoCollapseDelay: 1000
}
