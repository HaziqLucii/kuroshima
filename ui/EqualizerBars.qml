import QtQuick
import qs.theme

// The design's 4-bar EQ glyph (eqA-D), reused in both the compact pill and
// the expanded media section. Each bar scales 0.3->1.0->0.3 on an infinite
// loop, staggered by 120ms per bar (CSS `animation-delay`), only while
// `active`; paused (not just stopped) at the dim 0.3 scale otherwise,
// matching the design's own `opacity: playing ? 0.9 : 0.3`.
Row {
    id: root

    property bool active: false
    property real barHeight: 11

    spacing: 2

    Repeater {
        model: 4

        Rectangle {
            id: bar
            required property int index

            width: 2
            height: root.barHeight
            radius: 1
            color: Theme.ink
            opacity: root.active ? 0.9 : 0.3
            transformOrigin: Item.Bottom
            scale: 0.3

            // Nested, not one flat looping sequence: a PauseAnimation
            // directly inside a `loops: Infinite` SequentialAnimation would
            // re-insert the stagger delay every single loop, not just
            // before the first one (unlike CSS animation-delay, which only
            // delays the initial iteration). Nesting the infinite loop
            // inside a one-shot outer sequence keeps the delay to a single
            // up-front stagger, so the bars read as one continuous wave
            // rather than periodically going dead together.
            SequentialAnimation {
                running: root.active
                onRunningChanged: if (!running) bar.scale = 0.3

                PauseAnimation { duration: bar.index * 120 }
                SequentialAnimation {
                    loops: Animation.Infinite
                    NumberAnimation { target: bar; property: "scale"; to: 1.0; duration: 450; easing.type: Easing.InOutSine }
                    NumberAnimation { target: bar; property: "scale"; to: 0.3; duration: 450; easing.type: Easing.InOutSine }
                }
            }
        }
    }
}
