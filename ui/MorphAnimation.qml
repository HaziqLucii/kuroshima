import QtQuick
import qs.theme

// Drop into `Behavior on width/height { MorphAnimation {} }` on the capsule.
// Spring, not eased: the capsule should visibly overshoot and settle on a
// click-triggered morph, not glide smoothly to the target.
SpringAnimation {
    spring: Motion.morphSpring
    damping: Motion.morphDamping
    mass: Motion.morphMass
}
