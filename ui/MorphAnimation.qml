import QtQuick
import qs.theme

// Drop into `Behavior on width/height/radius { MorphAnimation {} }` on the
// capsule so every geometry morph uses the same duration/easing.
NumberAnimation {
    duration: Motion.morph
    easing.type: Motion.morphEasing
}
