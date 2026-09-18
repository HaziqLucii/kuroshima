pragma Singleton
import QtQuick

QtObject {
    // Ink stays from the Kuro palette; background goes pure black per
    // Haziq's ask (the capsule floats, it isn't a Kuro panel surface).
    readonly property color ink: "#cdc4ba"
    readonly property color bg: "#000000"
    readonly property color hairline: Qt.rgba(0.804, 0.769, 0.729, 0.2)

    // Project-specific override: not the usual monospace-forward Kuro type,
    // Haziq asked for Plus Jakarta Sans here specifically.
    readonly property string fontFamily: "Plus Jakarta Sans"

    readonly property int radius: 18
    readonly property int compactH: 36
    readonly property int topInset: 5
    // 0, not a positive value: niri's own `gaps` setting (currently 12px,
    // ~/.config/niri/cfg/layout.kdl) already adds spacing "between windows
    // and to screen edges", which stacks on top of whatever we reserve
    // here for the bottom (nothing analogous exists for the top, there's
    // no window above it to trigger that gap), which is the entire reason
    // a mathematically symmetric reserved strip looked visually
    // bottom-heavy. Letting niri's own gap be the full bottom spacing.
    readonly property int bottomInset: 0

    // Fixed layer-shell canvas size (slice 1 morphs the capsule inside it,
    // the surface itself never resizes).
    readonly property int canvasW: 800
    readonly property int canvasH: 420

    // Floating-overlay shadow, since the island has no border to separate
    // it from whatever window content sits underneath.
    readonly property color shadowColor: "#000000"
    readonly property real shadowOpacity: 0.38
    readonly property real shadowBlur: 0.85
    readonly property int shadowVerticalOffset: 5
}
