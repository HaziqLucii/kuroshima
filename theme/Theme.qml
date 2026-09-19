pragma Singleton
import QtQuick

// Tokens replicate plans/Claude Design - Dynamic Island/Dynamic Island.dc.html
// 1:1 (colors, type, per-state radius/size). Superseding the earlier Kuro-
// derived palette (bone ink on pure black, Plus Jakarta Sans, single fixed
// radius) per Haziq's explicit "replicate 100%" direction. The one deliberate
// departure: the design's `accent` design-token defaults to (and in every
// swatch renders as) #e8e8e8, i.e. plain ink, so fills/dots/highlights below
// just use `ink` directly rather than adding a separate accent-hue token,
// consistent with Haziq's standing no-accent-hue preference.
QtObject {
    // Ink ramp, exact hex from the design (not opacity-derived: the source
    // hardcodes each shade rather than varying one color's alpha, and the
    // values don't reduce to clean fractions of one another).
    readonly property color ink: "#ededed"
    readonly property color inkMuted: "#8f8f8f"
    readonly property color inkFaint: "#7a7a7a"
    readonly property color inkSubtle: "#6f6f6f"
    readonly property color inkDim: "#5c5c5c"

    readonly property color bg: "#050506"

    readonly property color hairline: Qt.rgba(1, 1, 1, 0.08)
    readonly property color divider: Qt.rgba(1, 1, 1, 0.16)
    readonly property color trackBg: Qt.rgba(1, 1, 1, 0.10)

    // Not the design's literal family names: "JetBrains Mono" and "Noto Sans
    // JP" (the Google Fonts webfont names) aren't installed on this machine
    // and silently fall back to a proportional face, which breaks every
    // content-driven page's sizing (CompactPage/MediaPeek measure implicit
    // width from these fonts) and the design's own "tabular, never reflow"
    // numerals rule. refuter caught this via Qt.fontFamilies(). These are
    // the actually-installed families carrying the same typeface: JetBrains
    // Mono ships here via the Nerd Fonts patcher, and the system JP face is
    // distributed as the Noto CJK superfamily rather than the per-language
    // webfont subset.
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property string fontFamilyJp: "Noto Sans CJK JP"

    // Per-state size/radius, straight from the design's `sizes` table.
    // Only the states with a real page today get a dedicated token; states
    // still on DummyWide (slices 6-8) fall back to `radius`/`compactH`.
    readonly property int radius: 17
    readonly property int compactH: 30
    readonly property int peekH: 34
    readonly property int osdW: 320
    readonly property int osdH: 58
    readonly property int osdRadius: 20
    readonly property int expandedW: 700
    // Bumped from the design's literal 604 once 06 INBOX + the full 07
    // SESSION row landed: live-measured builtSections.implicitHeight hit
    // 616 against a 568 available (content minus margins) budget, a 48px
    // real overflow the capsule's own clip was silently swallowing.
    readonly property int expandedH: 660
    readonly property int expandedRadius: 30
    readonly property int notificationW: 412
    readonly property int notificationH: 100
    readonly property int notificationRadius: 22
    // Battery/charging state: height/radius already match the shared
    // peek-family defaults (peekH/radius), only the width is distinct.
    readonly property int batteryW: 300

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
    // the surface itself never resizes). Must stay >= expandedW/H, with
    // extra headroom beyond that: MultiEffect's shadow paints past the
    // capsule's own bounds (blur bleed + shadowVerticalOffset), and unlike
    // an item-level clip, the actual Wayland surface edge is a hard cutoff
    // with no soft falloff, visible as a straight line slicing the shadow
    // once the capsule gets close enough to it. Expanded (604px) at
    // topInset(5) only left ~11px of bottom margin, well under what even a
    // modest blur needs, hence the cutoff. 60px of slack accounts for it.
    readonly property int canvasW: 800
    readonly property int canvasH: 736

    // Floating-overlay shadow: `0 24px 60px -18px rgba(0,0,0,0.95)` from the
    // design. MultiEffect has no spread parameter, so CSS's -18px spread
    // (which shrinks/softens the shadow well below the box's own size) has
    // no analogue: taking the alpha/offset numbers literally read as a
    // heavy black blob instead of the design's soft recede. Backed off by
    // feel instead of by formula; retune live if it still looks off. The
    // inset top highlight line the design also specifies
    // (`inset 0 1px 0 rgba(255,255,255,0.05)`) is drawn separately in
    // ui/Capsule.qml since MultiEffect can't express an inset shadow.
    readonly property color shadowColor: "#000000"
    readonly property real shadowOpacity: 0.18
    readonly property real shadowBlur: 0.5
    readonly property int shadowVerticalOffset: 5
    readonly property color insetHighlight: Qt.rgba(1, 1, 1, 0.05)
}
