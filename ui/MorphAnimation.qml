import QtQuick
import qs.theme

// Drop into `Behavior on width/height/radius { MorphAnimation {} }` on the
// capsule. Spring, not eased: the capsule should visibly (but gently)
// settle on a click-triggered morph, not glide smoothly or overshoot
// noticeably. A CSS-style bezier-overshoot curve was tried here (matching
// the Claude Design reference exactly) and read as too bouncy once seen
// live in both directions, so this reverted to the original tuned spring.
SpringAnimation {
    spring: Motion.morphSpring
    damping: Motion.morphDamping
    mass: Motion.morphMass
}
