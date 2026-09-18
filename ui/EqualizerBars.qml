import QtQuick
import qs.theme

// The design's 4-bar EQ glyph (eqA-D), reused in both the compact pill and
// the expanded media section. Each bar scales 0.3->1.0->0.3 on an infinite
// loop, staggered by 120ms per bar (CSS `animation-delay`), only while
// `active`; paused (not just stopped) at the dim 0.3 scale otherwise,
// matching the design's own `opacity: playing ? 0.9 : 0.3`.
//
// Each bar is filled with an ordered (Bayer) dither instead of a flat
// color, per Haziq's standing love of a dithered/halftone texture. A 2x2
// matrix at native pixel resolution: the bar is only 2px wide, too small
// an area for a larger matrix to read as anything but noise. Adjacent bars
// start from an inverted phase (index % 2) so they don't all line up into
// one solid-looking block.
Row {
    id: root

    property bool active: false
    property real barHeight: 11

    spacing: 2

    Repeater {
        model: 4

        Item {
            id: bar
            required property int index

            width: 2
            height: root.barHeight
            opacity: root.active ? 0.9 : 0.3
            transformOrigin: Item.Bottom
            scale: 0.3

            Canvas {
                anchors.fill: parent
                // Static pattern: the Canvas paints once at its fixed
                // pixel size, and the visible "growing/shrinking" comes
                // from the parent Item's `scale` transform stretching that
                // painted content, same as the flat-color version this
                // replaced did with its color fill.
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = Theme.ink
                    const bayer = (bar.index % 2 === 0) ? [[0, 2], [3, 1]] : [[1, 3], [2, 0]]
                    for (let y = 0; y < height; y++) {
                        for (let x = 0; x < width; x++) {
                            if (bayer[y % 2][x % 2] < 2) {
                                ctx.fillRect(x, y, 1, 1)
                            }
                        }
                    }
                }
            }

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
