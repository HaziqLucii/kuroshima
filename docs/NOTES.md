# Handoff

Read this first when resuming (new session, or after `/compact`).

## Status: Slice 5 done (Media)

Built: `services/Media.qml` (active player chosen reactively from `Mpris.players.values`,
preferring `isPlaying` else the first known player; `trackChanged()` gated the same way
`Audio.changed()` is, debounced + suppressed until 500ms after start; `position` is a
plain property refreshed by a 1s `Timer` while playing, not a live binding, since MPRIS
doesn't push continuous position updates so a binding to `player.position` would just
sit frozen), `pages/MediaPeek.qml` (art placeholder + title/artist, the first page to
actually emit `requestExpand`), `pages/MediaExpanded.qml` (art placeholder, title/artist,
progress bar, transport controls, reads live from `Media` directly rather than
`payload`, since `expand()` carries no payload). `CompactPage.qml` now shows a
now-playing marquee next to the clock when `Media.available` (elided/clamped, no real
scrolling marquee, that's design-phase polish). `app/Bridges.qml` wires
`Media.trackChanged` the same pattern as `Audio.changed`, plus clears the `"media"` key
via `Island.clearKey` when `!Media.available`. **Correction, `refuter` caught this
prose was wrong even though the code is right**: `available` means the *player object
exists*, not "is playing" or "has content" — pausing a track with the app still open
leaves `available` true indefinitely, the key is only cleared once the last MPRIS
client actually quits, not "when playback stops".

**This is also where the slice-3 deferred item finally landed**: `ui/Capsule.qml`'s
click handling no longer hardcodes `Island.toggle("dummyExpanded")`. It now generically
connects to `host.currentItem`'s `requestExpand(pageId)` signal (`Connections.target`
tracks `currentItem` automatically as pages swap) and routes through
`Island.expand(pageId); Island.dismiss()`, the plan's actual rule-8 example. Every
existing page (`CompactPage`, `OsdPeek`, `DummyWide`, `MediaExpanded`) now declares
`signal requestExpand(string pageId)` even where unused, specifically so this generic
`Connections` doesn't warn about a missing signal every time one of them is current.

**Real UX gap found live by the maintainer, fixed same session**: clicking only worked during
`MediaPeek`'s brief ~3s transient window right when a track changes. The now-playing
marquee that's actually visible most of the time lives on `CompactPage`, which had no
click handling at all. Added a `TapHandler` there too (`enabled: Media.available`,
`requestExpand("MediaExpanded")`), so clicking the persistent compact view works, not
just the narrow peek window.

**Transport controls redesigned live, twice, per the maintainer's aesthetic direction**: v1 was
plain text labels (PREV/PLAY/NEXT). v2 was a solid white filled circle with a black
play/pause glyph, the maintainer's own suggestion, but a filled circle plus solid white breaks
his established palette (bone-on-black, hairline rules instead of color blocks,
near-sharp 2px corners not soft circles). Final ("go all out"): all three controls are
matching hairline-bordered near-square buttons (`radius: 2`), bone-`Theme.ink` glyphs on
transparent, drawn on `Canvas` rather than Unicode play/pause/skip characters (font
glyph coverage for those isn't guaranteed). Play/pause repaints on `Media.isPlaying`
via an explicit `onPlayingChanged: requestPaint()`, not automatic: `Canvas.onPaint`
does not itself establish a reactive binding to properties it merely reads.

Verified live against a real MPRIS player (Chromium/YouTube, not simulated): now-playing
marquee, click-to-expand from both `MediaPeek` and `CompactPage`, play/pause/next/prev
all functional, transport glyphs render correctly.

## Slice 5 refuter fixes: 2 real Media.qml bugs, plus a PageHost input leak

1. **`trackKey` was keyed on `player.trackTitle`, which can't detect a genuinely new
   track when the title doesn't change** (a looped track, or two different tracks that
   happen to share a title). Consequence: no `trackChanged()`, no fresh `MediaPeek`, and
   `position` never resets for the new track, it just keeps counting up from the
   previous one until the next 1s tick. Fixed: keyed on `player.uniqueId` instead,
   confirmed via Quickshell's own doc comment on that property, "an opaque identifier
   for the current track... NOT `mpris:trackid`, as that is sometimes missing or
   nonunique in some players", i.e. built specifically to solve this.
2. **The debounce that fires `trackChanged()` had no content guard**, unlike its sibling
   `Audio.qml`'s debounce (which the slice-4 refuter pass already gated on `available`
   for exactly this class of bug). A player can register its MPRIS object before its
   metadata arrives (Chromium routinely does this); anything past the 500ms startup
   gate would fire `trackChanged()` with `title === ""`, briefly showing an empty
   `MediaPeek` until the real metadata coalesced in a moment later. Fixed: the debounce
   now only actually emits when `!available || title !== ""` (the `!available` branch
   has to stay reachable, that's what lets `app/Bridges.qml`'s `clearKey("media")` path
   fire). Also introduced a separate `debounceKey` (trackKey + title + artist combined)
   to restart the debounce, since metadata arriving *after* the player registers doesn't
   change `trackKey` by itself and would otherwise never get a second chance to fire.
   **Repeated the exact underscore-property-handler-naming mistake from earlier in this
   same file while writing this fix** (`_debounceKey`/`on_DebounceKeyChanged`, which is
   invalid/ambiguous QML): caught before committing, renamed to a public `debounceKey`.

**Also fixed, found in the same pass, currently harmless but a real problem waiting to
happen**: when `ui/Capsule.qml`'s `Connections { target: host.currentItem }` re-points
its own `target` from *inside* the very `onPageChanged` handler that triggers a page
swap (which is exactly what happens here), Qt updates `target` to the new page but never
disconnects from the old one. The outgoing page in `ui/PageHost.qml`'s crossfade stays
`visible: true` and hit-testable for the whole ~140-280ms fade even though it's fading
out, and paints above the incoming page on half of all transitions (slot declaration
order). Harmless today (nothing sits within ~18px of a page's vertical center that would
catch a stray click), but slice 6's notification action buttons will. Fixed:
`PageHost.handleLoaded` now explicitly sets `outgoing.enabled = false` when a crossfade
starts (closes both the input-leak and the paint-order overlap, since a disabled Item
also stops rendering interactively) and `loader.enabled = true` on the incoming side
(guards against a slot that was previously the *outgoing* half of an earlier cycle
still being disabled from that).

Also corrected inaccurate prose (not code) from the slice 5 commit/HANDOFF entry above:
`Island.clearKey("media")` fires on `!Media.available` (the player object is gone
entirely), not "when playback stops"; pausing a track with the app still open leaves
`available` true indefinitely.

## Slice 4 refuter fixes: 2 real Audio.qml bugs, plus scripts/lint.sh was a no-op

A `refuter` pass on the slice 4 commit found two real bugs in `services/Audio.qml`, both
fixed, plus a meta-finding that undermines trust in every prior "lint clean" claim:

1. **`scripts/lint.sh` called bare `qmllint`, which on this system is qt5-declarative's
   binary**: syntax-only, silently exits 0 on real errors (missing properties,
   unqualified access) it can't detect. The exact same PATH-shadowing trap
   `scripts/test.sh` already documents and works around for `qmltestrunner`, just never
   applied to this script. Fixed: now calls `/usr/lib/qt6/bin/qmllint` directly. Also
   corrected a misdiagnosis in the old script's comment: it excluded `shell.qml`
   believing qmllint crashed on typed function parameters; the real qt6 binary handles
   `shell.qml` fine (verified directly), the exclusion was masking nothing.
   Re-running the real linter across the whole repo surfaced ~90 warnings, verified
   individually: all but one are the already-known `qs.*`-unresolvable-import cascade
   (`[import]`/`[unqualified]`, plus secondary cascades like `[unresolved-alias]` on
   `app/Island.qml` since `IslandController`'s type never resolves without `qs.core`).
   The one independent finding, `ui/PageHost.qml`'s `currentItem` (`Loader.item` is
   declared `QObject`, typing it `Item` is a static mismatch): tried "fixing" it by
   typing it `QtObject` instead, which only moved the warning (breaks
   `.implicitWidth`/`.implicitHeight` access instead, `missing-property` on `QObject`).
   Reverted, `Item` is correct at runtime and one warning beats two.
2. **`Audio.volume`/`Audio.muted` synthesize `0`/`false` when `available` is false**
   (sink null, or a newly-tracked node not yet `ready`), and that synthetic value fed
   straight into the emission path: losing the audio sink (unplugged, or switched to a
   device still binding) fired a real "volume changed to 0%" OSD that never actually
   happened. Fixed: `_debounce`'s `changed()` emission now also checks `root.available`.
3. **`_pastStartupBurst` was set once and never reset**, so the 500ms startup-burst
   suppression only worked on the very first Pipewire connection. A real
   pipewire/wireplumber restart mid-session (`Pipewire.ready` false -> true) re-arms the
   500ms timer correctly, but the flag was already `true` throughout that window, so the
   reconnect's own re-enumeration burst leaked straight through as a stream of real OSD
   pops. Fixed: a `Connections` on `Pipewire.readyChanged` resets the flag to `false`
   whenever `Pipewire.ready` goes false.

Both fixes verified live (real PipeWire, real `wpctl`): OSD still pops correctly for a
genuine volume change.

## Slice 4.5 done: reserved space, one surface, not two

The maintainer asked for the compact pill's height to be reserved space (tiled windows shouldn't
render directly under the clock), matching how other Dynamic Island implementations
behave, and matching what the original plan itself anticipated
(`exclusiveZone: Config.reserveSpace ? Theme.compactH + Theme.topInset : 0`).

**The naive one-line version genuinely hangs niri, this is real, confirmed
reproducibly**: setting `ui/IslandWindow.qml`'s `exclusiveZone` directly to
`Theme.compactH + Theme.topInset` (a positive value) on the centered (`anchors.top`
only) window hung the whole nested niri session's layer-shell configure handshake
(toggling the value back and forth reproduced it every time; `qs` sits at 0% CPU,
`Configuration Loaded` never prints). niri recovered on its own within a few seconds of
the client dying each time (`niri msg` IPC came back), so not a permanent deadlock, but
it visibly froze the session while stuck.

**Correction, found by a `refuter` pass, do not repeat the earlier wrong claim**: an
earlier version of this note theorized that a centered (top-only-anchored) surface
"can't resolve" a positive exclusive zone per the wlr-layer-shell protocol. Checked
directly against the protocol XML (`wlr-layer-shell-unstable-v1.xml`, "A positive value
is only meaningful if the surface is anchored to one edge or an edge and both
perpendicular edges"): **top-only anchoring is the canonical valid case for a positive
exclusive zone**, not an unresolvable one. This means the hang is very likely a genuine
**niri bug** on a spec-legal client request, not a client-side mistake. Not filed
upstream yet (the maintainer's call); if revisited, this is the accurate framing to file it with.

**First fix attempt, since superseded**: two separate layer-shell surfaces, an
invisible full-width spacer (`ui/ReservedSpaceWindow.qml`, anchored `top`+`left`+`right`,
doing only the `exclusiveZone` reservation) plus the existing centered `IslandWindow.qml`
(unchanged, rendering the capsule). This sidestepped the hang (confirmed working,
screenshotted), but a second `refuter` pass caught a real regression it introduced,
invisible in the nested-niri sandbox because nothing else there has a top-anchored bar:
The maintainer's real session runs `noctalia` with a floating top bar and its own exclusion zone
(`~/.config/noctalia/settings.json`, `enableExclusionZoneInset: true`). The spacer
surface (a normal, non-ignoring exclusive zone) would correctly get pushed below
noctalia's bar, but `IslandWindow.qml` had been set to `exclusiveZone: -1`
("ignore every other surface's exclusive zone, anchor to the true output edge
regardless") specifically to stop it rendering below its *own* spacer sibling. On the
real session that same `-1` would make the pill ignore noctalia's bar too, rendering at
the absolute screen top, overlapping/under noctalia, while the spacer surface (still
correctly respecting noctalia) reserved space in a different, lower position: the two
surfaces would disagree about where "the top" is the moment a third surface enters the
picture. Two independently-positioned surfaces measuring the same edge was the root
design flaw, not fixable by tuning either one's exclusiveZone value alone.

**The actual fix**: one surface, not two. `ui/ReservedSpaceWindow.qml` deleted.
`ui/IslandWindow.qml` itself is now anchored `top`+`left`+`right` (full width, the
combination already proven not to hang) with a normal positive
`exclusiveZone: Theme.compactH + Theme.topInset + Theme.bottomInset` (no `-1`, no
"ignore" mode: a normal exclusive zone correctly queues behind noctalia's own, restoring
proper coexistence). `implicitHeight` stays `Theme.canvasH` (the full morph range):
exclusive zone is a distance from the anchored edge, independent of the surface's own
height, so a tall surface reserving only the compact row is protocol-legal. The capsule
content is unaffected, still centered via `anchors.horizontalCenter` inside whatever
width the compositor stretches the window to, still masked via
`mask: Region { item: capsule }` so clicks outside it pass through. One surface, one
shared reference point, nothing left to disagree.

Verified live at each step with a bounded `timeout` wrapper on the launch (given the
hang history): isolated full-width+positive-zone test loaded instantly outside this
repo; the real consolidated window then loaded cleanly in the actual project; niri
stayed responsive (`niri msg` instant) throughout. Visually confirmed by the maintainer: pill
renders, positions, and morphs exactly as before. A third `refuter` pass on this exact
fix came back clean (no must-fix items); worth knowing for later, not a defect: stacking
order between same-layer positive-zone surfaces (this window vs. noctalia's bar) is
determined by which one mapped first, not any priority, so restarting one while the
other is running can flip which one renders visually on top of the other (they still
never overlap in *position*, exclusive zones guarantee that; only paint order can
change). If "the pill moved relative to noctalia's bar" ever gets reported, that's why.

**Vertical spacing tuned live, non-obvious finding along the way**: `Theme.topInset`
settled at `5` (tried `14` first per an ambiguous "a little lower" request that turned
out to mean "less gap", then `5` per "looks more minimalist"). The *bottom* gap (pill's
bottom edge to where tiled windows start) turned out not to just be `topInset` again:
a mathematically symmetric formula (`compactH + 2*topInset`) looked visibly
*bottom-heavy* despite the equal math. Cause, found by the maintainer: **niri's own `gaps`
setting** (`~/.config/niri/cfg/layout.kdl`, currently `12`) adds spacing "between
windows and to screen edges", which stacks on top of whatever's reserved for the
bottom, since the reserved strip's lower boundary is effectively a screen edge from
niri's layout perspective. Nothing analogous exists for the *top* gap, there's no
window above it to trigger niri's own gap logic, so top and bottom were never going to
match from one symmetric formula. Fixed: a separate `Theme.bottomInset` (distinct from
`topInset`, tuned independently, not derived from it), set to `0` so niri's own `12px`
gap is the entire bottom spacing. **If `~/.config/niri/cfg/layout.kdl`'s `gaps` value
ever changes, re-check this balance, it's tuned against `12` specifically, not derived
from it.** Also worth knowing: `ui/PageHost.qml`'s oversize-page warning bound
(`Theme.canvasW/H - 2*Theme.topInset`) reuses `topInset` for canvas padding too, so
retuning the visual gap silently shifts that warning threshold as a side effect.

Verified live throughout, safely, with a bounded `timeout` wrapper on every test launch
specifically because of the hang risk: isolated minimal repro confirmed the anchor
theory (A: full width, loaded; B: centered, hung) before touching the real project; the
two-surface version then loaded cleanly; the `exclusiveZone: -1` follow-up also loaded
cleanly; screenshots at each step confirmed tiled windows starting below the pill's row,
then the pill itself sitting correctly inside that reserved gap.

**Incidental discovery while debugging this**: some of the session's earlier "stale
instance" / hot-reload flakiness was likely two concurrent `qs` processes (one launched
by Claude via a scripting shell, one the maintainer had separately running in his own terminal)
both watching and reloading on the same file edits at once, not a Quickshell bug. Keep
to one running instance at a time when both are actively iterating on this repo.

## Status: Slice 4 done (Audio OSD)

Built: `services/Audio.qml` (`Pipewire.defaultAudioSink` bound through a `PwObjectTracker`,
which is required for its properties to actually populate; `volume`/`muted`/`available`;
a `changed()` signal gated two ways: `Motion.debounceOsd` (16ms) debounce, and suppressed
entirely until 500ms after `Pipewire.ready` to swallow the startup enumeration burst),
`app/Bridges.qml` (first real service -> `Island.show()` wiring, lives in `app/` not
`core/`, same reasoning as `Island.qml`), `pages/OsdPeek.qml` (the first *real* peek page,
icon text + bar, payload `{kind: "volume"|"brightness", value, muted?}`, since
`Kinds.table` maps both `osd.volume` and `osd.brightness` to the same `"OsdPeek"` page
name). `ui/Capsule.qml`'s `pageMap["OsdPeek"]` now points at the real page instead of
`DummyWide`. `services/Demo.qml`'s osd payloads updated to the real shape.

**Where "coalesces into one bar" actually happens, worth not re-deriving**: it is NOT
`Audio.qml`'s job to suppress rapid user-paced volume changes (`debounceOsd` is only
16ms, purely for collapsing PipeWire's own redundant same-instant signals, e.g. a single
logical change firing both a volume and a channels update). Rapid `wpctl` presses each
legitimately call `Island.show("osd.volume", ..., {key:"osd:volume"})`; the actual
coalescing is `IslandController`'s rule 1 (same key as current updates payload in place,
restarts the timer, no re-animation), already built and tested in slice 2. Verified live:
5 rapid `wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+` calls produced one continuously-
updating bar, not five flickering peeks; no OSD fired during the startup window.

**Another `QtObject`-has-no-default-property hit, same class of bug as `app/Island.qml`'s
`PersistentProperties` in slice 3**: a debug `Connections {}` added directly as an
unnamed child of `Audio.qml`'s root `QtObject` failed the same way
(`Cannot assign to non-existent default property`). Same fix pattern: a named property
(`property Connections _x: Connections {...}`). Worth remembering as a standing rule for
this codebase: **any QtObject-rooted singleton needs named properties for its children,
never bare unnamed ones**, only `Item`-rooted types (and Quickshell's own `Singleton`/
`ReloadPropagator`) have a default property to receive them.

Deliberately left minimal, confirmed with the maintainer: `OsdPeek` shows an icon label + bar, no
percentage readout. Visual polish is explicitly his design-phase work after slice 9, this
slice's job was proving the real PipeWire data path end to end, which it now does.

## Status: Slice 3.5 done (auto-collapse on cursor-away, inserted by the maintainer)

Not in the original plan; the maintainer asked whether hovering *off* the island for a while
auto-collapses it (symmetric to the earlier hover-to-expand question, also not planned).
Added `theme/Motion.qml`'s `expandCollapseGrace` (1500ms, longer than `hoverGrace` since
an expanded page is something the user is likely reading, not a transient peek) and
`ui/Capsule.qml`'s `shouldAutoCollapse` (`Island.isExpanded && !Island.hovered`) driving
a one-shot `Timer` that calls `Island.collapse()`. View-level, not controller-level, same
reasoning as the slice-1.5 click toggle: this is UI convenience layered on the state
machine, not one of its 8 core rules, so it doesn't belong in `IslandController.qml`.

Verified live: `expand("dummyExpanded")` via IPC with the cursor elsewhere, capsule
auto-collapsed to the compact clock after ~1.5s. Confirmed by the maintainer: "very nice, i like it."

## Status: Slice 3 done (Wire), including a second refuter pass that found 3 more real bugs

A second `refuter` pass on the slice 3 commit (static review, no live testing given the
GPU incident, then verified live afterward once fixes landed) returned FAIL with three
must-fix findings, all real, all fixed and live-verified:

1. **`ui/PageHost.qml`'s `Loader.sourceComponent = component` is a silent no-op when the
   slot already holds that exact Component reference.** Since 6 of 8 `pageMap` entries
   share `dummyWideComponent`, and `IslandController`'s preempt path transitions
   `OsdPeek -> compact -> NotificationPeek` in one synchronous call (the intermediate
   `compact` step is real and expected, but it consumes a slot), the follow-up
   `NotificationPeek` assignment could hit a slot that still held `dummyWideComponent`
   from before: `loaded` never fires, `pendingIncoming`/`pageName` desync from what's
   actually rendered, and the notification never appears at all, the pill just sits on
   the clock until the transient times out. This isn't a placeholder-only bug either:
   two different real notifications will both map to the same `NotificationPeek`
   Component once that page exists. Fixed: `setPage()` now does
   `incoming.sourceComponent = null` immediately before reassigning, forcing a fresh
   instance regardless of whether the Component reference changed. Verified live: traced
   `page -> OsdPeek -> compact -> NotificationPeek` in the log, then visually confirmed
   "NOTIFICATION" actually rendered and held for its real duration.
   **Known remaining cosmetic issue, not re-broken by the fix, pre-existing**: that
   `compact` intermediate is now visibly reachable when nothing else masks it, so a
   rapid preempt can flash the clock for a frame before the real content field lands.
   Revisit if it's visible enough in practice to matter once real (non-placeholder)
   pages make transitions more frequent.
2. **`app/Island.qml`'s `PersistentProperties` never actually survived a hot reload**,
   contrary to what the file's own comment and slice 3's commit message claimed.
   Verified against Quickshell's own C++ source (`singleton.hpp`, `reload.cpp`,
   `persistentprops.cpp`): reload registration requires the singleton's *root type* to
   be `Quickshell.Singleton` (a `ReloadPropagator`/`Reloadable`), not a bare
   `QtObject`-based type like the previous `IslandController`-rooted version; the
   restored child must be reachable via the default `children` property
   (`ReloadPropagator::onReload` only walks `mChildren`), so a *named* property
   assignment (`property PersistentProperties _persisted: ...`, what the previous
   version used) is invisible to it; and restoration fires on `reloaded()`, emitted
   after the whole tree rebuilds, not `Component.onCompleted`, which runs before that
   point on every generation. Fixed: `Island.qml`'s root is now `Singleton`, with
   `IslandController` as a named child (`controller`, forwarded via property
   aliases/one-line function delegates so `Island.show()`/`Island.page` etc. keep
   working directly) and `PersistentProperties` as a genuine unnamed default-property
   child, restoring via its own `onLoaded`/`onReloaded` handlers. Verified live:
   `expand("dummyExpanded")`, triggered two hot reloads via trivial file edits, capsule
   still showed the expanded page after both.
3. **Nothing in the view ever set `Island.hovered`.** Rule 7 (hover-hold: pausing a
   transient's dismiss timer while the cursor sits on the capsule) was fully implemented
   and covered by 3 passing unit tests at the controller level, entirely dead code in
   the running app because no `HoverHandler` existed anywhere. Fixed: added one to
   `ui/Capsule.qml`, `onHoveredChanged: Island.hovered = hovered`.

Built: `app/Island.qml` (the singleton `IslandController` instance the real app uses,
`PersistentProperties` for `expandedPage` surviving hot reload), `services/Demo.qml`
(fake payload factories per kind), full `IpcHandler` surface in `shell.qml`
(`page`/`demo`/`expand`/`collapse`/`toggle`/`dismiss`), `ui/Capsule.qml` now reacts to
`Island.page`/`Island.payload` instead of being poked directly, click routes through
`Island.toggle("dummyExpanded")` instead of the slice-1.5 raw toggle. `DummyWide`
(the temporary placeholder every not-yet-built peek page maps to) now renders
`payload.label` and sizes itself to it, both width AND height, so it doubles as a
crude preview for every kind in `Kinds.table`.

**Deviation from the plan's file layout, load-bearing, not cosmetic**: `Island.qml`
moved from `core/` to a new `app/` directory. The plan lists it under `core/`, but a
qmldir `singleton` declaration is resolved eagerly, and `Island.qml` needs Quickshell
(`PersistentProperties`, `qs.theme`) which plain `qmltestrunner` doesn't have. Adding it
to `core/qmldir` broke `import "../core"` under the test runner entirely (collateral
failure, not just Island itself failing to resolve) even though no test ever references
`Island`. `core/` stays exactly what its own file comments already promised:
Quickshell-free. `core/qmldir` now also explicitly lists `IslandController` as a plain
type: a manual qmldir disables Quickshell's automatic per-directory type synthesis
entirely, so once one singleton was declared there, the *other* file in the directory
needed an explicit entry too, or it stops being visible to any importer including tests.

**Also found a second unrelated QtObject gotcha while wiring Island**: `QtObject` (what
`IslandController` extends) has no default property, so nesting `PersistentProperties {}`
as an unnamed child inside `IslandController { ... }` fails ("Cannot assign to
non-existent default property"). Fixed the same way `IslandController.qml` itself
already handles its internal `Timer`: a named property (`property PersistentProperties
_persisted: PersistentProperties {...}`), not an unnamed child.

### A real incident: a bad spring value froze the desktop

While chasing a "the morph feels sluggish" complaint, `Motion.morphSpring` was set to
`300` on the (wrong) assumption that UI springs generally want stiffness in the
hundreds. For this specific `SpringAnimation` integrator that is numerically unstable:
the capsule's bound `width` diverged past 1,000,000px within one animation cycle
(confirmed in the quickshell log: `455 -> -1274 -> 5296 -> -19671 -> 75207 -> -285332 ->
1084718`), and the `MultiEffect` shadow tried to allocate a GPU texture the same size,
logged as `QSGRhiLayer: Unsupported size requested: [1084783, 411997]. Maximum texture
size: 65536`. This happened live, on the maintainer's actual desktop GPU (the nested-niri sandbox
shares hardware with the real session), and caused real, repeated system freezing until
the process crashed on its own.

Fixed two ways: `Motion.morphSpring`/`morphDamping` retuned to `18`/`3.5` (measured
settling in 250-500ms, verified stable via a temporary instrumented log, since removed);
and, independent of tuning correctness, `ui/Capsule.qml` now hard-clamps its rendered
`width`/`height` to `Theme.canvasW`/`Theme.canvasH` (the fixed layer-shell canvas size),
via a separate `animatedWidth`/`animatedHeight` pair that the spring actually animates,
clamped down into the real `width`/`height`. That clamp is the load-bearing fix: it holds
even if a future Motion.qml value is wrong again, whereas "use a good spring value" only
holds until the next tuning mistake.

**Process lesson**: don't tune animation feel by guessing and asking "does this look
better", verify with an instrumented measurement (timestamped width log) before showing
a change, especially before applying an untested extreme parameter value to a live
process on real hardware.

### Environment flakiness fighting this slice (not a code bug, but cost real time)

- `qs -n` (`--no-duplicate`) leaves a stale "already running" lock after a process is
  killed abnormally (crash, `kill -9`); `qs list --all` can *also* claim "No running
  instances" while stale entries are shown as "Dead instances" even though the current
  process is genuinely alive and healthy. When this happens, don't fight it: kill
  whatever's running, relaunch without `-n`, or accept the churn and relaunch clean.
- A `qs` instance that has survived many hot-reloads across large structural changes
  (directories added/moved, `qmldir` changes) can end up in a state where `qs ipc call`
  succeeds (exit 0) against it but the shell is actually unresponsive/stale. Confirmed
  twice this slice (once as the root cause of a "payload always renders as the fallback
  text" false alarm). If behavior doesn't match a source change after a save, restart
  the process fully before debugging the QML.
- A bare `qs -p .` launched from a shell whose `WAYLAND_DISPLAY` is set but
  `QT_QPA_PLATFORM` isn't can silently fall back to the `xcb` platform (logs a WARN, easy
  to miss), producing a real running instance that responds to IPC but isn't visible in
  the intended Wayland session at all. Always pass `QT_QPA_PLATFORM=wayland` explicitly
  when scripting a launch.

## Status: Slice 2 done (Controller), including a refuter pass that found real bugs

Built: `core/IslandController.qml` (pure `QtObject`, imports only `QtQuick`), `core/Kinds.qml`
(data table) + `core/qmldir` (`singleton Kinds 1.0 Kinds.qml`, needed for the singleton to
resolve without pulling in Quickshell's `qs.*` machinery), `tests/tst_controller.qml`
(22 test functions, 24 total entries counting qtest's `init`/`cleanupTestCase`, all
passing), `scripts/test.sh`. No UI change this slice, as specified.

Implements all 8 rules from the plan: coalesce (current + queued), expanded gate, empty,
preempt (+ conditional requeue), enqueue with cap 6, timeout/dismiss/clearKey ending +
queue advance, hover-hold (pause/resume with `max(remaining, hoverGrace)`), and
`expand`/`collapse`/`toggle` for `expandedPage`.

**Real bugs found only by writing the tests, not by reasoning about the code:**

1. **QML `readonly property` genuinely cannot be reassigned from the type's own internal
   JS**, even from functions in the same file. (Some QML lore says otherwise; it's wrong,
   at least on Qt 6.11.) Fixed with the standard workaround: private writable backing
   properties `_current`/`_queue`, exposed as `readonly property alias current: _current`
   / `queue: _queue`. **Correction to an earlier version of this note**: this is a naming
   convention, not real enforcement, external code that knows the underscore names can
   still write `_current`/`_queue` directly (the refuter pass proved this empirically).
   Only the alias name is genuinely read-only. Don't write the underscore properties from
   outside `core/IslandController.qml`; nothing stops you, but nothing should.
2. **`Array.prototype.sort` is not stable in this Qt6 JS engine** for equal-priority
   comparator results, verified empirically (traced actual output, saw insertion order
   scrambled). "FIFO within priority" cannot rely on sort stability. Fixed with an
   explicit monotonic `_seqCounter` stamped onto every transient as `seq`, used as an
   explicit tiebreaker: `(b.priority - a.priority) || (a.seq - b.seq)`.

**A `refuter` pass (Opus) after the above found 4 more real bugs, all fixed, tests added
for each**:

3. **A `duration: null`/`-1` ("until dismissed") peek died on one hover-and-unhover.**
   `_restartTimer` treated `undefined`/`null`/`<0` as "infinite", but `_updateHold`'s
   resume guard checked `duration >= 0`, and `null >= 0` is `true` in JS, so unhovering
   armed a timer using a **stale `_remaining` left over from a previous transient**.
   Fixed with a shared `_isInfiniteDuration()` helper used consistently in both places.
   This is exactly slice 6's "critical notification stays until dismissed" case.
4. **`_advanceQueue` never re-applied the expanded gate (rule 2), and rule 8's own click
   contract (`expand()` then `dismiss()`) triggers it.** A queued low-priority item would
   pop over a page you just expanded. Fixed: `_advanceQueue` now re-checks the gate
   against the queue head (safe to check only the head: the queue is priority-sorted, so
   if the head is gated everything behind it is too) and leaves it queued rather than
   dropping it; `collapse()` now retries the queue afterward.
5. **`core/Kinds.qml`'s `notification` row has no static `key`** (by design, it needs a
   per-notification-id key), and `show()` had no guard against that, so a call without
   `overrides.key` silently coalesced every notification into one slot under key
   `undefined`. Fixed: `show()` now rejects (warns + no-ops) a kind resolving to an
   undefined key, forcing the caller to supply one instead of failing silently.
6. **A `transientEnded` handler calling `show()` re-entrantly (e.g. "notification closed,
   show the next thing") had its result immediately overwritten** by the queue-advance
   that runs right after `_end()`'s signal emission. Fixed: `_advanceQueue` now checks
   `if (root._current) return` first, since a re-entrant call means something already
   claimed `current` before it got there.

**Also fixed, lower severity but cheap and real**: same-key coalesce (current or queued)
now carries `priority`/`page` through, not just `payload`/`duration` (an escalating
same-key event needs its new priority to actually apply); queue-cap-dropped items and
`clearKey`'d *queued* (never-shown) items now emit `transientEnded` with reasons
`"dropped"`/`"cleared"` respectively, extending the plan's original four reasons, so a
future `RetainableLock` on a notification has something to release even if it never
became current; the preempt-requeue front-push now goes through the same normalize
(sort+cap) path as a normal enqueue, so the queue can no longer transiently exceed
`queueCap`.

**Tooling gotcha, cost real time**: `/usr/bin/qmltestrunner` on this system is
**qt5-declarative's** binary (Qt 5.15, wants versioned imports like `import QtQuick 2.15`,
logs to journald not stdout by default so failures look like silent zero-output hangs).
The right one, matching qt6-declarative and this project's unversioned Qt6-style imports,
is `/usr/lib/qt6/bin/qmltestrunner`. `scripts/test.sh` hardcodes that path and sets
`QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1`. If test output ever goes silent
again with a bare nonzero exit code, check `journalctl --user -n 50` before assuming the
test file itself is broken.

## Status: Slice 1.5 done (click-to-morph + spring bounce, inserted by the maintainer)

Not in the original plan's slice list; the maintainer asked for it directly after seeing slice 1's
smooth morph, wanted to feel a spring/bounce motion and trigger it by clicking the capsule
rather than only via IPC. Two changes:

- `theme/Motion.qml`'s `morph`/`morphEasing` (duration+easing tokens) replaced with
  `morphSpring`/`morphDamping`/`morphMass`. `ui/MorphAnimation.qml` now wraps
  `SpringAnimation`, not `NumberAnimation`: springs have no fixed duration, they
  overshoot and settle based on the three physics params, tuned live with the maintainer
  (`spring: 3.5, damping: 0.4, mass: 1.0`).
- `ui/Capsule.qml` has a `TapHandler` that toggles `expanded` and calls
  `setPage("dummyWide"/"compact")` directly. **This is temporary**: slice 3's real click
  contract is a page emitting `requestExpand()`, which the view routes through
  `IslandController.expand()`. Replace this direct toggle when slice 3 wires the
  controller into `Capsule`/`IslandWindow`, don't leave both mechanisms in place.

Confirmed by the maintainer: "looks very cool."

## Status: Slice 1 done (Morph)

Built: `theme/Motion.qml` (morph/fade/scale tokens), `ui/MorphAnimation.qml`
(reusable `Behavior` animation), `ui/PageHost.qml` (two-slot `Loader`
crossfade, `pageMap: name -> Component`, same-key payload update without
reload), `pages/DummyWide.qml` (throwaway test fixture, delete once a real
wide page exists), `IpcHandler { target: "island" }` in `shell.qml` with
`page(name: string)`. `Capsule.qml` now sizes itself from
`host.targetWidth/Height` with `Behavior on width/height { MorphAnimation {} }`.

Verified live in nested niri: `qs -p ~/Projects/dynamic-island ipc call island
page dummyWide` / `page compact` morphs the capsule width/height smoothly with
a fade+scale crossfade, confirmed by the maintainer ("morphs really nice"). No corner
clipping artifacts observed mid-morph.

**Deviation from the plan**: no per-page `targetRadius` yet, radius stays
`Theme.radius` fixed. The plan's `Capsule.qml` spec has radius as a bound,
morphable value; skipped because no page so far wants a different radius,
and an unwired `Behavior on radius` binding to a constant is dead code. Add
it when a real page actually needs a different corner radius, not before.

**Non-obvious tool gap found this slice**: `qmllint` (qt6-declarative 6.11)
crashes outright (exit 255, no output) on typed function parameters
(`function f(x: string): void`), which `IpcHandler` requires by contract.
`shell.qml` is excluded from `scripts/lint.sh` for this reason, not because
it's unchecked, it's exercised at runtime every dev session instead.

**IPC gotcha for the maintainer specifically**: Quickshell's `ipc call` instance
registry is scoped to the current `$WAYLAND_DISPLAY`. Sending IPC from the
host Plasma terminal (`wayland-0`) can't see an instance running in the
nested niri sandbox (`wayland-1`); `export WAYLAND_DISPLAY=wayland-1` in
that one terminal first. Check `ls /run/user/1000/wayland-*` if the nested
display number changes between launches.

## Status: Slice 0 done (Baseline and skeleton)

Built:

- `theme/Theme.qml`: ink `#cdc4ba`, bg pure black `#000000` (deliberately not the Kuro
  panel bg `#0b0a09`, this floats and needed to read as its own surface), font
  `Plus Jakarta Sans` (project-specific override of the usual Kuro monospace type,
  already installed at `~/.local/share/fonts/PlusJakartaSans/`), radius/canvas/shadow
  tokens.
- `ui/IslandWindow.qml`: `PanelWindow`, fixed canvas (`Theme.canvasW/H`), anchored top
  only (layer-shell centers it), `exclusiveZone: 0` (floating overlay, confirmed with
  the maintainer: real Dynamic Island doesn't reserve bar space either), `WlrLayershell`
  namespace/layer/keyboardFocus set, `mask: Region { item: capsule }` so clicks outside
  the capsule always pass through regardless of capsule size.
- `ui/Capsule.qml`: `ClippingRectangle` (Quickshell.Widgets), black, no border, static
  size for now (sized to `CompactPage`'s implicit size). `MultiEffect` drop shadow
  behind it, tuned live with the maintainer: `shadowOpacity: 0.38`, `shadowBlur: 0.85`,
  `shadowVerticalOffset: 5`.
- `pages/CompactPage.qml`: clock only (`SystemClock`, not a manual `Timer`), per the
  page contract in `CLAUDE.md`.
- `shell.qml`, `scripts/dev.sh`, `scripts/lint.sh`, root `CLAUDE.md`.
- `~/dev-niri.kdl` `Mod+I` rebound to `scripts/dev.sh`.

Verified: pill renders top-center in nested niri; `qs.theme`/`qs.ui`/`qs.pages`
root-relative imports resolve fine in Quickshell 0.3.1 (no fallback to relative imports
needed); hot reload confirmed live (shadow tuning applied without relaunching);
`scripts/lint.sh` clean.

**Non-obvious bug fixed this slice**: `MultiEffect.blurMax` is the shared max pixel
radius for *both* the content blur and the shadow blur, not just the content blur. It
was set to `0` on a mistaken assumption it only gated `blurEnabled`'s effect, which made
`shadowBlur` render as a perfectly hard-edged silhouette instead of a soft shadow.
Removed; `blurMax` is left at its default (32) and `shadowBlur` (0..1, a fraction of it)
does the actual softness tuning.

**Deviation from the plan's aspirational Kuro tokens**: bg and font are the maintainer's explicit
per-project asks (pure black, Plus Jakarta Sans), not the plan's original Kuro-default
`#0b0a09` / `Inter`. Theme.qml comments record this so it isn't "fixed" back later by
accident.

## Not built yet (slice 0 explicitly excludes)

No morph (capsule is static size), no `IslandController`, no services, no other pages,
no IPC. Window-focus-title and MPRIS now-playing (both working in the pre-plan raw
prototype) are intentionally dropped for now; now-playing comes back in slice 5 as part
of `CompactPage`, per the plan. There is currently no page showing anything but a clock.

## Claude Design reference swap (theme/motion token pass)

Per the maintainer's explicit "replicate 100%" direction, `plans/Claude Design - Dynamic Island/Dynamic Island.dc.html`
now supersedes the earlier Kuro-derived `theme/Theme.qml` (bone ink, pure black,
Plus Jakarta Sans, one fixed radius) and the spring-based `theme/Motion.qml`/
`ui/MorphAnimation.qml`. New tokens: ink ramp `#ededed`/`#8f8f8f`/`#7a7a7a`/`#6f6f6f`/
`#5c5c5c`, surface `#050506`, JetBrains Mono + Noto Sans JP, per-state size/radius
constants (`compactH`/`peekH`/`osdW`/`osdH`/`osdRadius`/`expandedW`/`expandedH`/
`expandedRadius`). The design's `accent` token defaults to (and every swatch renders
as) plain `#e8e8e8`, so fills/dots/highlights just use `ink` directly rather than
adding a real accent-hue system, consistent with the maintainer's standing no-accent-hue
preference.

Motion: replaced `SpringAnimation` (spring/damping/mass tuned by feel, the same
mechanism that once diverged to 1,000,000+ px and froze the GPU) with a fixed-duration
`NumberAnimation` using `Easing.BezierSpline` and an explicit control-point array,
reproducing the design's `cubic-bezier(.34, 1.5, .5, 1)` overshoot exactly (control
points can exceed y=1, unlike x). This is a real safety improvement, not just fidelity:
a bezier animation to a fixed target over a fixed duration can't diverge the way a
spring's integrator can. `Motion.expandCollapseGrace` renamed `autoCollapseDelay`
(1500 -> 1800ms per the design's SPEC panel). Content crossfade switched from a
scale-based transition to translateY (`Motion.fadeRise`, 4px) via a `transform:
Translate` on each `ui/PageHost.qml` Loader slot, per the design's `fadeUp` keyframe;
both fade directions now share one `Motion.fadeDuration` (220ms) instead of the old
asymmetric fadeIn/fadeOut split.

**Page contract addition**: every page now declares `readonly property real
cornerRadius`, alongside the existing `implicitWidth`/`implicitHeight`/`payload`/
`requestExpand`. `ui/PageHost.qml` exposes it as `targetRadius` (falls back to
`Theme.radius` if a page doesn't declare it), and `ui/Capsule.qml` morphs
`ClippingRectangle.radius` against it the same way width/height already morph.
`OsdPeek` and `MediaExpanded` (placeholder) use the design's exact per-state
radius/size; `CompactPage` uses the design's IDLE radius (15); `MediaPeek`/`DummyWide`
have no exact design counterpart (the design has no "media track changed" or
"not-yet-built kind" transient at all) so they use the generic peek-family radius (17)
as the closest reasoned bucket.

`core/Kinds.qml` transient durations updated to the design's SPEC panel ("TRANSIENT
DWELL: 3200ms / 900ms ws"): osd/notification/power/media.track all 3200, workspace 900
(was 1200). The design's own interactive demo buttons hardcode slightly different
per-trigger numbers (e.g. notification 4200); treated those as prototype-convenience
values, not the documented spec, and went with the SPEC panel as authoritative.

`pages/MediaExpanded.qml` was deliberately gutted to an empty bordered placeholder box
(700x604, r30, sized/radiused to the design's EXPANDED state) per the maintainer: "for the
expanded part you can just put an empty box with border as placeholder, so next slices
will replace that placeholder." The real dashboard (identity/media/controls/toggles/
system/inbox/session, see the design's ANATOMY panel) is real backend work spanning
several future slices, not a style pass.

**Known, deliberate divergences from the literal design values** (the maintainer tuned these
live after seeing them rendered; don't "fix" them back to the design's numbers):
- **Capsule border removed entirely.** The design specifies
  `border: 1px solid rgba(255,255,255,0.08)` on every state; the maintainer tried it live and
  preferred the capsule with no border at all. `ui/Capsule.qml`'s `ClippingRectangle`
  is `border.width: 0`.
- **Shadow backed off hard from the literal CSS values.** The design's
  `0 24px 60px -18px rgba(0,0,0,0.95)` taken literally into `MultiEffect` (which has no
  spread parameter to soften/shrink the shadow the way CSS's `-18px` does) rendered as
  a heavy black blob, not a soft recede. Tuned down live to
  `shadowOpacity: 0.18, shadowBlur: 0.5, shadowVerticalOffset: 5` ("just enough to be
  seen"). These are feel-tuned, not derived from the CSS numbers by any formula;
  expect further live retuning as more states get built.
- **`Theme.canvasH` bumped 620 -> 680.** Real bug, not a taste call: the shadow's blur
  bleed extends past the capsule's own bounds, and unlike an item-level `clip: true`
  (soft nothing, just stops being drawn), the actual Wayland surface edge is a hard
  cutoff with no falloff, visible as a straight line slicing through the shadow. At
  680px, `expandedH(604) + topInset(5)` leaves 71px of margin below the capsule, plenty
  for blur bleed even at higher `shadowBlur` values. Keep this margin in mind if
  `expandedH` ever grows once the real dashboard replaces the placeholder.

## Claude Design swap, refuter round 1 fixes

refuter caught four real bugs in the token/motion swap above, all fixed:

- **Font tokens didn't resolve.** `"JetBrains Mono"`/`"Noto Sans JP"` (the Google Fonts
  webfont names from the design's `<link>` tag) aren't installed on this machine and
  silently fell back to a proportional face, which breaks every content-driven page's
  sizing math (`CompactPage`/`MediaPeek` measure `implicitWidth` from these fonts) and
  the design's own "tabular, never reflow" numerals rule. Fixed to the actually-
  installed families carrying the same typefaces: `"JetBrainsMono Nerd Font"` (JetBrains
  Mono via the Nerd Fonts patcher) and `"Noto Sans CJK JP"` (the Noto CJK superfamily,
  not the per-language webfont subset). Verify with `Qt.fontFamilies()` if this machine's
  font set ever changes.
- **Morph overshoot vs. the canvas clamp.** `Motion.morphBezier`'s
  `cubic-bezier(.34, 1.5, .5, 1)` peaks around y=1.08, so a 30->604 height morph
  transiently overshoots to ~650px. `Theme.canvasH` was already bumped to 680 for the
  shadow-bleed fix above, which happens to clear this too (650 < 680) — confirmed, not
  re-fixed. If `Theme.expandedH` ever grows, recheck this headroom accounts for both the
  shadow bleed AND the morph overshoot, not just one.
- **`pages/OsdPeek.qml`'s label row was baseline-anchored to a `Row`.** `Row.baselineOffset`
  is always 0, so `anchors.baseline: valueText.baseline` aligned the Row's *top* (not its
  text) to that baseline, dropping the whole label ~17px too low and overrunning into the
  bar below. Fixed to `anchors.verticalCenter`.
- **OSD fill lost its rounded ends.** The fill `Rectangle` had no `radius`, and the
  attempted `clip: true` on its rounded parent doesn't help either: Qt Quick's
  `Rectangle.clip` clips to a rectangular bounds regardless of `radius`. Added
  `radius: parent.radius` back to the fill directly (the pattern the pre-swap
  OsdPeek/MediaExpanded already used), removed the now-pointless `clip: true`.

**Reviewed and accepted, not fixed**: the same overshoot bezier also means shrinking to
a small enough target transiently computes a *negative* height, clamped to 0 for part
of the animation. Refuter round 2 measured this precisely: any target below ~44.8px
zeroes out, so it's not just the 604->30 (expanded->compact) collapse, expanded->peek
(604->34) blinks too, invisible for roughly 130ms in the middle of the 520ms animation.
During that window the capsule (and its `Region`-based click mask) is fully invisible
and fully click-through at once, which is internally consistent, not a surprise to
click on nothing that isn't there. The design's own CSS transition has the identical
artifact (browsers clamp computed height at 0 the same way). Not chasing this: fixing it
would mean deviating from the design's specified curve for a genuinely cosmetic
mid-animation blink.

**Superseded**: the bezier-overshoot morph described in this whole section (and the
canvas-headroom/collapse-blink consequences above) was reverted back to the original
`SpringAnimation` in a later pass, see "Revert capsule morph to the original spring
feel" further down. `Theme.canvasW/H`'s headroom is still correct (the spring doesn't
overshoot at all, confirmed by refuter round 5 by driving it numerically under the real
runtime), and the collapse-blink artifact this section describes no longer happens.
Left this section as-is rather than rewritten: it's an accurate record of what was
found and fixed at the time, just no longer describing current behavior.

**`pages/MediaExpanded.qml`'s placeholder was too broad.** the maintainer caught that the "empty
box" instruction had swallowed real, working functionality (title/artist/progress/
transport, backed by `services/Media.qml` since slice 5), not just the design's new,
not-yet-built sections. Restored the MEDIA section for real (title/artist, tabular
elapsed/remaining, prev/play-pause/next as plain glyph text per the design, not the old
bordered Canvas buttons), plus a squircle-clipped album art thumbnail (`ClippingRectangle`
+ `Image { source: Media.artUrl }`, falling back to a flat hairline swatch when there's no
art) per the maintainer's ask. The squircle is a large-radius rounded rect, not a true
superellipse: at 54px a custom `Shape` path would be indistinguishable by eye and isn't
worth the extra surface area. The remaining design sections (identity header, controls,
toggles, system, inbox, session) are still the one placeholder box, now anchored below
the real media section instead of replacing it. Seeking-by-click on the progress bar is
NOT implemented: `services/Media.qml` has no `seek()`/`SetPosition` method yet, adding one
is real MPRIS service work, not a style pass.

## Claude Design swap, refuter round 2 fixes + identity header + live-stream handling

refuter round 2 PASSed the round-1 fixes and the MediaExpanded media-section rebuild
(all four round-1 items independently re-verified as genuinely fixed, not just claimed),
with two small misses fixed since: an em-dash in the placeholder label text (violates
the standing no-em-dash rule) swapped for the same middot already used elsewhere in that
string, and the media progress track was missing `radius: 2` that `OsdPeek`'s equivalent
bar already has (cosmetic consistency, not a functional bug). refuter also flagged the
placeholder box's `border.width: 0` as a miss against the file's own header comment and
this doc's "empty bordered placeholder box" wording — that's not a bug, the maintainer asked for
the border removed live *after* refuter's round-1 snapshot; both the file comment and
this doc's earlier wording are now corrected instead.

**Real bug caught live, not by refuter**: `services/Media.qml`'s player selection
(`isPlaying ? that : players[0]`) picked whichever player reported `isPlaying` first,
which on a real desktop is not always the richest source. Confirmed via `playerctl -l`
while watching a YouTube livestream in Chrome: `chromium.instanceNNNN` (raw browser
MPRIS, generic per-session icon as its `artUrl`, i.e. literally a Chrome logo) and
`plasma-browser-integration` (KDE's extension, real per-tab artwork/artist/title) were
BOTH reporting `isPlaying: true` for the same tab. Fixed: among playing players, prefer
one whose `dbusName` contains `"plasma-browser-integration"` when present.

**Live-stream handling, new.** MPRIS has no explicit "this is live" flag, and the two
players disagree on how they signal an unknown/live duration: raw Chromium uses the
documented sentinel (int64 max microseconds), `plasma-browser-integration` instead
reports some arbitrary large placeholder (confirmed live: 13 hours, for an actual
livestream). `Media.isLive` (`services/Media.qml`) treats any `length` over 4 hours as
"not a real duration" rather than trying to match every player's own sentinel
convention: no legitimate track/video runs that long. `pages/MediaExpanded.qml` uses it
to replace the remaining-time countdown with a pulsing "● LIVE" badge, pin the progress
fill full (you're always at the live edge), and force the skip-forward glyph off
regardless of what MPRIS's own `canGoNext` claims (the maintainer: "for live video you cant go
forward, only backwards, since it is well, live" - there's nothing ahead of live to skip
into).

**New: `services/System.qml`**, backing the design's "01 IDENTITY" header row that
The maintainer flagged as missing ("dont forget the things above the media player"). Exposes
`userHost` (`$USER`/`$LOGNAME` via `Quickshell.env()`, `+`/etc/hostname`), `uptimeLabel`
(one blocking read of `/proc/uptime` at startup plus a live wall-clock offset, not
re-read on a timer) and `niriVersion` (`niri msg --json version` via a `Process`,
`stdout` parsed as JSON). Each field hides independently when absent, same rule as
every other module: on Hyprland (the maintainer's other target compositor) `niri msg` simply
doesn't exist, the `Process` errors, `niriVersion` stays `""`, and that one field in the
header disappears rather than showing garbage. Added to `pages/MediaExpanded.qml` as the
first section, above the (now real) media section. `services/qmldir` needed the new
`singleton System 1.0 System.qml` line (manual `qmldir` files disable auto-synthesis for
the whole directory, same gotcha as `core/qmldir`).

## CONTROLS section (VOL/MIC), brightness deliberately skipped

Extended `services/Audio.qml` with a write path (`setVolume(pct)`, writes
`sink.audio.volume`) and mic support (`Pipewire.defaultAudioSource`, mirroring the sink:
`micAvailable`/`micVolume`/`micMuted`/`setMicVolume(pct)`; both sink and source now need
to be in `PwObjectTracker.objects` for their `.audio` sub-object to populate, mic was
silently reading zero forever without that). `pages/MediaExpanded.qml` "03 CONTROLS"
section: VOL/MIC as click-to-set bars (`TapHandler.onTapped`'s `eventPoint.position.x`
against the bar's own width), each independently hidden when its source isn't available.

**BRI was initially skipped, then built anyway once the maintainer reconsidered the latency
tradeoff.** This desktop has no `/sys/class/backlight` (confirmed earlier in this doc).
Investigated the only real alternative, DDC/CI over the monitor's I2C bus (`ddcutil`):
it actually works, found the real monitor (`ddcutil detect` -> Acer XZ306C X on
`/dev/i2c-7`, no root needed, a udev ACL already grants the seat user access) and both
`getvcp 10`/`setvcp 10 <n>` round-trip correctly. But every single call measured
**~8 seconds** on this hardware (confirmed 3x, consistent to the tenth of a second,
reads like a fixed retry/backoff policy on `ddcutil`'s side more than raw I2C latency).
Asked the maintainer how to handle it (skip / show a pending state / fire-and-forget with drift);
he chose skip at the time.

**Later reversed**: the maintainer decided the ~8s delay is fine for a "set and let it catch up"
control (he sees the same lag setting brightness from KDE itself), as long as it's
commit-on-release, not a live drag. New `services/Brightness.qml` (a `Process`-driven
service, not a live property binding like `Audio.qml` - confirmed this doesn't transfer
directly, DDC calls need `Quickshell.Io.Process`, closer in shape to
`services/System.qml`'s niri-version `Process` than the audio/mic sliders next to it):
`setBrightness(pct)` optimistically updates `value` immediately then fires
`ddcutil setvcp 10 <n>` via a reused `Process`; one separate one-shot `ddcutil getvcp 10`
read at first use (not app startup - Quickshell singletons are lazy, and nothing in the
always-loaded tree references `Brightness`, only `pages/MediaExpanded.qml` does, which
is only instantiated on demand). Deliberately NOT re-confirmed via a fresh read after
every set: a set-then-verify round trip would double every adjustment to ~16s, and a
silently-failed `setvcp` is rare enough on a working DDC/CI link to accept the risk.
`pages/MediaExpanded.qml`'s CONTROLS section gained a BRI slider between VOL and MIC
(matching the design's order), using `ui/ScrubBar.qml`'s `scrubFinished` signal
(commits once, on release) instead of the continuous `scrub` VOL/MIC use - continuous
firing would queue up dozens of 8-second `ddcutil` calls per drag, the same class of
bug already caught and fixed for media seeking. refuter verified the real end-to-end
path (a real `setvcp` genuinely moves the physical monitor's brightness, confirmed via
a separate manual `getvcp` after) and confirmed the established Process-reuse
coalescing behavior holds here too: two rapid successive commits correctly settle on
the LATEST value, not a stale intermediate one, verified both synthetically and through
the real ddcutil path.

The "04 TOGGLES · 05 SYSTEM · 06 INBOX · 07 SESSION" placeholder box shrank accordingly
(it used to also say "CONTROLS", now that section is real).

## Refuter round 3: CONTROLS section fixes

refuter round 3's brief predated the CONTROLS section (dispatched right before it was
built), but it reviewed the moving tree anyway and caught a real architectural bug in it:

**Tapping the VOL slider inside the expanded dashboard collapsed the dashboard around
it.** `Audio.setVolume()` -> `Audio.volume` changes -> `Audio.changed()` ->
`app/Bridges.qml` -> `Island.show("osd.volume", ...)`. `osd.volume`'s priority (40)
equals `IslandController.expandedBlockBelow` (40), and the gate is a strict `<`
(`t.priority < expandedBlockBelow`), so `40 < 40` is false and the OSD is NOT blocked,
by original design (the gate's own comment: "OSD/notifications ... still show over an
expanded page"). That's correct for a volume change from OUTSIDE the dashboard (a
hardware key while looking at something else); it's wrong here because
`pages/MediaExpanded.qml`'s CONTROLS section shows the same volume value live, in place,
so popping a whole separate OSD transient over it just morphs the 700x604 dashboard down
to the 320x58 OSD pill mid-adjustment, hiding the slider you just touched, for the
dwell's full 3200ms (this diff also raised that dwell from 1500ms, making it worse).
Fixed in `app/Bridges.qml`: the `Audio.changed` handler now skips `Island.show(...)`
whenever `Island.expandedPage === "MediaExpanded"`, regardless of whether the change
came from the dashboard's own slider or a hardware key. `core/IslandController.qml`'s
gate logic itself is untouched: the fix is at the integration point that decides whether
to ask for an OSD in the first place, not at the priority-comparison rule.

Also fixed, all flagged by the same round: the file's own header comment still listed
"controls" among the not-yet-real sections (same class of drift rounds 1-2 already
caught, now three for three); the VOL/MIC tap targets were the visual 3px track itself,
too thin to comfortably hit, moved onto a taller (18px) invisible parent Item instead;
the "03 CONTROLS" header row was missing `anchors.verticalCenter` on its children (same
bug class as round 1's OsdPeek catch, ~1.27px here vs ~17px there, still fixed for
consistency); the whole CONTROLS `Column` had no visibility gate of its own, only its
two inner VOL/MIC sub-columns did, so the "03 CONTROLS" label rendered alone for the
2-3s Pipewire takes to bind at startup; and `fmt()` had no hours field, so a live
stream's elapsed or a long film's remaining rendered as a bare un-rolled-over
"125:00" past 60 minutes.

`./scripts/lint.sh` picked up a new category from the `Island.isExpanded`/
`Island.expandedPage` property reads added to `app/Bridges.qml`: 2 `unresolved-type`
warnings, same root cause as the existing `unqualified`/`incompatible-type` baseline
(qmllint can't resolve Quickshell's directory-as-singleton convention outside the
Quickshell runtime), just a different warning code because this is a property read on
the unresolved reference rather than a bare reference or method call. Confirmed real at
runtime (`Island.isExpanded`/`expandedPage` both genuinely exist, `app/Island.qml`), not
a new baseline count to chase down.

## Revert capsule morph to the original spring feel

The bezier-overshoot morph (previous sections) read as too bouncy once actually seen
live, in both the expand and collapse directions. Reverted `theme/Motion.qml` +
`ui/MorphAnimation.qml` to the original pre-redesign `SpringAnimation`
(spring:18, damping:3.5, mass:1.0), closer to how macOS's actual Dynamic Island moves.
`ui/Capsule.qml` needed no change (it already delegates to `ui/MorphAnimation.qml` via
`Behavior`). Refuter round 5 drove the reverted spring numerically under the real
runtime across all four state-pair transitions: it never overshoots the target at all
(peak == target exactly in every direction), so the canvas headroom (`Theme.canvasW/H`)
is still more than enough and the bezier-era collapse-blink artifact is gone entirely,
not just reduced.

## Real compact/idle pill: animated EQ bars, not title/artist text

The maintainer caught that `pages/CompactPage.qml`'s title/artist marquee wasn't what the actual
design does in its collapsed/idle pill: that state is clock + an animated 4-bar EQ
glyph reflecting play state; title/artist only ever appears in the expanded view. New
`ui/EqualizerBars.qml` reproduces the design's staggered scale-oscillation keyframes:
each bar loops scale 0.3->1.0->0.3 forever while `active`, staggered 120ms apart. The
stagger is a ONE-SHOT `PauseAnimation` outside the looping `SequentialAnimation`, not
inside it - putting it inside would re-insert the delay every single loop instead of
just before the first, breaking the "continuous wave" look. Made reusable since the
design reuses the same glyph in the expanded media section too (not yet wired there).

## 04 TOGGLES: WIFI/BT/MIC real, five others deliberately dimmed

New `services/Toggles.qml` (WIFI via `nmcli radio wifi`, BT via `bluetoothctl power` /
`bluetoothctl show`, both polled every 5s plus an immediate re-poll after this page's
own toggle actions) and new `ui/ToggleButton.qml`. MIC reuses `services/Audio.qml`
directly (`toggleMicMuted()`, new this round). DND (needs the not-yet-built
notification server), NIGHT (no gamma daemon installed on this machine), VPN (no
connection profile configured at all), CAPS (a passive indicator, not sensibly a
click-toggle), and IDLE (no idle-inhibit daemon running - the "idle_inject" kernel
threads found while checking are CPU power management, unrelated) all render
`available: false` (dimmed, not clickable) rather than being dropped from the grid, per
The maintainer: keep the full 4x2 look rather than shrinking to only what's real (the opposite
call from the earlier BRI decision, which just left VOL/MIC as two rows with no BRI
slot at all - context-dependent, not a rule either way).

**Real icons, not text abbreviations**, per the maintainer. All 8 use JetBrainsMono Nerd Font
glyphs (`String.fromCodePoint(codepoint)`; several are above the BMP and need this, not
a `\uXXXX` literal). Codepoints were verified against this exact installed font's cmap
via a Python fontTools script before shipping, not guessed from memory or copied from a
generic Nerd Font cheatsheet (patch versions can differ in exactly which glyphs/
codepoints they bundle). Refuter round 5 independently re-verified all 14 codepoints
(some toggles have separate on/off glyphs, e.g. wifi vs wifi_off) against
`fc-match "JetBrainsMono Nerd Font"`'s actual resolved file and confirmed live rendering
(each rasterizes real ink, unlike a genuinely-missing codepoint which renders zero
width) - both independently correct.

refuter round 5 found no bugs in the polling/action logic itself; the optimistic-set
race (a click's optimistic value getting clobbered by an in-flight poll from before the
click, then corrected ~15-25ms later by the action's own re-poll) measured at roughly
0.2% of clicks and is sub-perceptual, not worth a suppression flag.

## Click-and-drag scrub bars with a live popover, plus real media seeking

The maintainer: "make it like a slider behaviour too... when i drag, it can show popover it is
currently on what percent volume." New `ui/ScrubBar.qml` replaces the click-to-set-only
bars for VOL, MIC, and the (non-live) media progress bar. Two handlers layered on the
same track: a `TapHandler` (a plain click with zero pointer movement might never
register as a "drag" even with `dragThreshold: 0`) and a `DragHandler` with
`target: null` (the standard QtQuick idiom for tracking pointer position without
actually moving anything) for continuous tracking while dragging. Exposes
`previewValue` (what the pointer is CURRENTLY over during a drag, not the possibly-
lagging committed `value` - a caller like `Audio.setVolume` writes through Pipewire and
the property binding round-trips back, which can lag a live drag by a frame) and a
`popoverLabel` shown above the drag point while active, overridable per call site (the
media bar formats it as a time string via the page's own `fmt()`, not a percentage).

New `services/Media.qml` function `seek(seconds)`, writing through Quickshell's
`MprisPlayer.position` setter (confirmed by refuter round 6 to perform a real MPRIS
seek, not just change the local QML property - verify again if this session's setup
ever changes). Guarded on `!isLive`: live content has no real "total length" to seek
into, so its progress bar stays the plain non-interactive display `Rectangle` pinned
full from earlier rounds, with the ScrubBar swapped in only for `!Media.isLive`.

Synthetic-input tools (`ydotool`) exist on this machine but operate at the global
uinput level regardless of which window has focus, so this session could not safely
simulate a real drag gesture to verify the interaction end-to-end; refuter round 6
verified what it could statically/via scratch harnesses (grabToImage rendering,
numeric driving of the handlers, live MPRIS position checks) and the user confirmed the
actual drag feel live themselves.

## Refuter round 6 fixes, plus a real isLive bug caught live by the maintainer

refuter round 6 reviewed `ui/ScrubBar.qml`/`services/Media.qml`/the ScrubBar call sites
and found two real bugs, both fixed:

- **A fast flick could silently do nothing.** `DragHandler.centroidChanged` fires for
  the very pointer move that *causes* activation, before `active` actually flips true,
  so `onCentroidChanged`'s `if (active)` guard discarded that first move; if Qt
  compressed a quick flick into press + one move + release, neither handler ever called
  `scrub()`. Fixed by also firing on `onActiveChanged` using the now-current centroid
  position, which catches exactly the move `onCentroidChanged` had to skip (no double-
  fire: that guard only skips it while `active` is still false).
- **Dragging the media progress bar fired a real MPRIS `SetPosition` D-Bus call per
  pointer-move event** - 60-180 calls for a one-second drag, i.e. continuous re-seek/
  re-buffer for the whole gesture, confirmed live by refuter via `dbus-monitor` against
  a throwaway MPRIS player. `ui/ScrubBar.qml` gained a second signal, `scrubFinished`
  (fires once, on release or a plain click), and the media call site switched to it for
  the actual `Media.seek()` call; VOL/MIC keep using the continuous `scrub` signal since
  applying volume live while dragging is desired there. The fill bar itself now tracks
  `previewValue` instead of `value` so it still visually follows the drag in real time
  even though the actual seek only commits on release (this also benefits VOL/MIC,
  whose fill no longer waits on Pipewire's write-then-bind-round-trip during a drag).
- Also added `Media.canSeek` (from `player.canSeek`) since Quickshell's
  `MprisPlayer.setPosition` silently no-ops (with a `qWarning`) on a player that reports
  it can't seek; `pages/MediaExpanded.qml`'s media bar now shows the real interactive
  `ScrubBar` only when `!Media.isLive && Media.canSeek`, and a plain display bar
  otherwise (full-pinned for live, actual position/length ratio for a seek-incapable
  finite track, so it doesn't misleadingly look parked at the end). The two variants are
  wrapped to the same height so switching between them doesn't shift the rest of the
  section by ScrubBar's larger hit-area height.

**Separately, a real bug the maintainer caught live, not by refuter**: opening a second YouTube
livestream didn't show the LIVE badge at all. `Media.isLive`'s original heuristic
checked only the *selected* player's own `length` against a fixed threshold (4 hours),
picked from the first livestream's numbers. Diagnosed via `playerctl`: on the second
stream, `plasma-browser-integration` (preferred for its richer metadata) reported a
placeholder length of only ~2.35 hours, under that threshold - so plasma-browser-
integration's "unknown duration" guess isn't a fixed convention, it's apparently
arbitrary per stream. What IS consistent across both streams: Chromium's own raw MPRIS
handle reports the literal documented "unknown length" sentinel (int64 max
microseconds, ~292471 years) both times. Fixed `isLive` to check every currently-
*playing* MPRIS player (not just the one selected for display) for an outright absurd
length (over ~31 years, chosen to sit far below any real sentinel and far above even a
very long finite recording, so plasma-browser-integration's noisy few-hour guesses
never trip it), rather than trusting any one player's own number.

## Idea for a future slice: swipeable compact-mode pages (not started)

The maintainer, 2026-09-19: the compact/idle pill currently shows exactly one fixed layout
(clock, plus the EQ glyph when media is playing). Idea: let it become swipeable, so
swiping the compact pill cycles through several different "compact faces," each
showing a different combination of already-built info, and the user picks which one is
currently active.

His proposed faces:
1. Clock + equalizer
2. Clock + date
3. Clock + date + equalizer
4. Media player (title/artist, not just the EQ glyph - closer to what `CompactPage.qml`
   showed before it was changed to match the design's real idle pill; that content
   still exists in git history if useful as a starting point)
5. Open to more ideas

Additional faces worth considering, since the backend already exists for each (nothing
new to build to support them, unlike the ones above that still need real data):
- Clock + WIFI/BT status glyph (`services/Toggles.qml`, already has `wifiOn`/`btOn`)
- Clock + mic-mute indicator (`services/Audio.qml`'s `micMuted`, useful as an at-a-glance
  "am I muted" check, e.g. mid-call, without opening the full dashboard)
- Clock + one system stat (CPU or TEMP, `services/SystemStats.qml`) as a minimal system
  monitor face
- Clock + workspace indicator, once Slice 7 (Workspaces) lands

Open questions to resolve when this actually gets picked up, not decided yet:
- Swipe mechanism: a `SwipeView`/`PathView`-driven page cycle, or a `DragHandler`
  directly on the compact pill re-using the click-to-morph precedent from slice 1.5?
- Does the currently-selected face persist across reloads/restarts? `app/Island.qml`'s
  `PersistentProperties` pattern for `expandedPage` is the precedent to follow if so.
- Fixed, hardcoded order vs. user-configurable (enable/disable/reorder faces)? The
  latter needs a real settings/config surface that doesn't exist yet anywhere in this
  project.
- Should swiping skip a face whose data source isn't currently available (e.g. the
  media face when nothing's playing), or land on it anyway showing an empty/dim state?

## Slice 6 done (Notifications)

`services/Notifs.qml`: `NotificationServer` inside `Loader { active: true }` (the plan says
`Loader { active: Config.notificationServer } `, but `Config.qml` doesn't exist in this
project yet - hardcoded true, revisit when a real config surface lands).
`keepOnReload: true`, `actionsSupported`/`imageSupported`/`bodySupported: true`. On arrival,
sets `notification.tracked = true` and re-emits via a plain `received(var notification)`
signal; doesn't know about `Island` at all, same shape as Audio/Media.

`app/Bridges.qml` computes urgency-specific priority/duration as per-call overrides
(critical: 60 / -1 "stays until dismissed"; normal: 50 / 5000; low: 50 / 3000 - these vary
per notification, not per kind, so `core/Kinds.qml`'s generic `"notification"` entry doesn't
encode them), calls `Island.show("notification", { notification }, {...})`, and does a
DYNAMIC `notification.closed.connect(...)` (not a declarative `Connections{}`, since
notifications arrive/die one at a time at runtime with no fixed target to declare ahead of
time) to call `Island.clearKey(key)` on close, whatever closed it.

`pages/NotificationPeek.qml`: payload is `{ notification }`, and the page binds straight to
the LIVE object's properties (not a snapshot like Audio/Media use), so a sender updating an
existing notification in place (same id) reactively updates the peek. Fixed 412x100, r22
(new `Theme.notificationW/H/notificationRadius`). Icon: `notification.image` first, else
`Quickshell.iconPath(notification.appIcon, true)`, else a letter-monogram fallback. Shows
appName/NOW header, summary, then EITHER body OR an actions row (not both - the fixed 100px
height has no room budgeted for both, and an actionable button beats uninteractable text at
this size). `RetainableLock` guards against the notification being destroyed while this page
is still crossfading out, per the plan.

This is the first kind with a real per-instance key (`notif:<id>`, no static key in
`Kinds.table`, `show()` already rejects a missing key since slice 2's refuter fixes).
`services/Demo.qml`'s old `"notification"` fake payload (`{label, summary, body}`, matching
the pre-slice-6 `DummyWide` placeholder) was updated to the real shape:
`{ notification: {appName, summary, body, appIcon, image, actions, expire(), dismiss()} }` -
a plain JS object, not a real instance (`Notification` itself is `isCreatable: false`), shaped
to satisfy only what the page and (see below) `Bridges.qml`'s cleanup handler read.

**Three refuter rounds on this slice, all real bugs, all fixed:**

- **Round 1, action tap double-closed the notification.** `NotificationAction.invoke()`
  already closes/destroys it (standard desktop-notification convention); the action
  button's tap handler also called `root.n.dismiss()` right after, hitting "Cannot close
  destroyed notification" on every action tap. Fixed: dropped the extra `dismiss()` call.
- **Round 1, a critical notification permanently bricked the island.** `duration: -1` +
  no dismiss gesture on the peek + nothing else ever closing it = unrecoverable from the
  UI (refuter proved this with byte-identical screenshots over 20s while other transients
  queued and never showed). Fixed: added a `TapHandler` on the whole card that calls
  `root.n.dismiss()`.
- **Round 1, tracked notifications never released.** Quickshell's `NotificationServer`
  doesn't implement expiry itself - it hands the shell `expireTimeout` and expects it to
  act. Setting `tracked = true` on arrival took on that responsibility, and nothing ever
  called `expire()`/`dismiss()` afterward: unbounded `trackedNotifications` growth, and any
  sender waiting on the D-Bus `NotificationClosed` signal (`notify-send --wait`) hung
  forever. Fixed: `app/Bridges.qml` now listens to `Island.transientEnded` and closes the
  notification on reason `timeout`/`dropped` (`expire()`) or `dismissed` (`dismiss()`) -
  deliberately NOT on `preempted` (this kind has `requeue: true`, so it's still queued and
  will show again) or `cleared` (only reachable here because the notification was already
  closed by something else first - the dynamic `closed.connect` above, or this page's own
  dismiss()/invoke() calls, both of which route through `closed`; closing it again would
  double-close it, same bug class as the action-tap one). refuter verified this reasoning
  is airtight (only two `clearKey` callers in the whole codebase, disjoint key namespaces)
  and verified all four reasons live via real D-Bus round-trips.
- **Round 1, broken-image checkerboard on an unresolvable icon.**
  `Quickshell.iconPath(name, fallbackString)` doesn't check the icon actually resolves, so
  a bad name still produced a loadable-looking URL that failed at render time; the
  monogram fallback was only gated on an empty `iconSource`, never true for a bad name.
  First attempted fix (gate on `IconImage.status === Image.Ready`) was itself proven a
  no-op in round 2: Quickshell's `image://icon/` provider hands back a placeholder image
  for an unresolvable name rather than failing, so `status` stays `Image.Ready` regardless.
  Real fix: `Quickshell.iconPath(name, true)` - the 3-arg-bool overload - genuinely checks
  existence and returns `""` when it can't resolve, which is what actually lets the plain
  `iconSource === ""` gate work.
- **Round 2, the round-1 critical-notification fix reintroduced the round-1 action-tap
  bug.** The new card-level dismiss `TapHandler` was assumed to not fire for action-button
  taps because "child handlers grab first" - refuter proved this assumption wrong: a plain
  `TapHandler`'s default `gesturePolicy` (`DragThreshold`) only takes a *passive* grab, so
  both the action button's handler and the card's ancestor handler fired for the same tap,
  reintroducing invoke()+dismiss() on every action tap via a different path than round 1's
  original bug. Fixed: the action button's `TapHandler` now sets
  `gesturePolicy: TapHandler.ReleaseWithinBounds`, an exclusive grab that actually
  suppresses the ancestor's handler (refuter verified this via a full gesturePolicy matrix
  live, not just theory: only the CHILD's policy matters, and `WithinBounds`/
  `ReleaseWithinBounds`/`DragWithinBounds` all correctly suppress it while `DragThreshold`
  never does).

**Reviewed and accepted, not fixed (round 2)**: one unreproducible "Cannot close destroyed
notification" appeared in 1 of 3 full live refuter runs, not reproduced in a byte-identical
rerun or a targeted 5-case race matrix (0/8). Plausible mechanism: `onTransientEnded` calls
`expire()`/`dismiss()` unconditionally with no guard against the notification having already
been closed by a racing external `CloseNotification` landing in the same tick. Left
unguarded: the failure mode is a benign log warning, not a crash, and it didn't reproduce
under deliberate stress. Worth a defensive guard (e.g. a small "already closing" id set
shared between the `closed.connect` handler and `onTransientEnded`) if it's ever seen again
in real use.

**Standing reminder for every future slice** (found 3 times now: `PersistentProperties`
in `app/Island.qml`, a debug `Connections` in `services/Audio.qml`, and the `_timer` in
`core/IslandController.qml` got it right from the start): a `QtObject`-rooted
singleton/service has no default property, so any child object needs a named property
(`property Foo _x: Foo {...}`), never an unnamed one, or it fails to load with "Cannot
assign to non-existent default property". Only `Item`-rooted types and Quickshell's own
`Singleton`/`ReloadPropagator` accept bare unnamed children.

**Standing reminder for every future slice** (found 3 times now: `PersistentProperties`
in `app/Island.qml`, a debug `Connections` in `services/Audio.qml`, and the `_timer` in
`core/IslandController.qml` got it right from the start): a `QtObject`-rooted
singleton/service has no default property, so any child object needs a named property
(`property Foo _x: Foo {...}`), never an unnamed one, or it fails to load with "Cannot
assign to non-existent default property". Only `Item`-rooted types and Quickshell's own
`Singleton`/`ReloadPropagator` accept bare unnamed children.

## Slice 7 done (Workspaces)

Tried `Quickshell.WindowManager.windowsets` first; on this test setup it only ever
reflected a single windowset. Inconclusive at the time (the sandbox genuinely only had
one real workspace, confirmed against `niri msg --json workspaces`), and refuter later
proved a differently-configured niri instance reports `windowsets` fine - so this is not
a real WindowManager/niri incompatibility, just an untested case. Went with niri's own
event-stream regardless, per the plan's documented fallback for exactly this
uncertainty: new `services/Workspaces.qml` spawns `niri msg --json event-stream` as a
long-running `Process` with a `SplitParser` (not the raw `NIRI_SOCKET` wire protocol the
plan describes - the CLI already implements that handshake correctly, no need to
reimplement it blind). Confirmed live (by refuter, with 4 real workspaces, not the
1-workspace sandbox): the startup burst of 6 events arrives as 6 separate `onRead`
calls within 2ms, never a partial or merged line, and `Workspaces.list` matches a
simultaneous `niri msg --json workspaces` query exactly, sorted by niri's own per-output
`idx`.

New `pages/WorkspacePeek.qml`: no payload, reads the live singleton directly (same
pattern as `NotificationPeek`/`MediaExpanded`). 190x34, r17 (already exactly
`Theme.peekH`/`Theme.radius`'s existing peek-family defaults, no new tokens needed).

**Two refuter-caught bugs, both fixed:**

- **A phantom WORKSPACE peek fired on every shell startup.** The event stream's first
  line is always a full `WorkspacesChanged` snapshot; `_lastActiveId` starting at -1
  meant that snapshot always looked like a "change" and fired `activeChanged()` ~25ms
  after launch, popping a peek nobody triggered. Fixed: a `_seeded` flag suppresses
  exactly the first check (establishing the starting state isn't a switch), regardless
  of which event type arrives first.
- **The active-workspace dot never actually animated, just snapped.** Every handled
  event assigns `Workspaces.list` a brand new array of brand new objects, even when only
  one workspace's `active` flag moved. A `Repeater` whose `model` IS that array tears
  down and rebuilds every delegate on each such change (refuter instrumented this: each
  new dot is constructed already at its final width, and a `Behavior` can't animate a
  freshly-created object's very first binding evaluation - there are no intermediate
  frames to animate through). Fixed by keying the `Repeater` off `Workspaces.list.length`
  (an int, stable across a pure activation switch since the workspace count doesn't
  change) instead of the array itself, with each delegate reading `Workspaces.list[index]`
  via its own live binding - delegates now persist across an activation change, so the
  `Behavior on width` has an actual in-place property change to animate.

Also fixed on the same pass, both cheap: `_checkActiveChanged()` now ignores an
`activeIndex < 0` result (no workspace currently flagged active - reachable via an
ordering race between the two handled event types, which is exactly what a real bug
would look like, not a made-up edge case: refuter reproduced it with a
`WorkspaceActivated` for an id not yet in `list`) rather than firing a peek for a
broken-looking state; and the "N / total" text falls back to a plain dash instead of
"0 / 0" when the list is empty (only reachable via the demo/IPC path or a non-niri host,
since `app/Bridges.qml`'s real trigger can no longer fire before at least one workspace
is confirmed active).

**Known, accepted simplifications** (single-monitor machine, per system-spec.md):
`_normalize` sorts by `idx` globally, which niri scopes per-output, so a second monitor
would interleave both outputs' workspaces into one list; `WorkspaceActivated`'s patch
sets `active` across the whole list by id, which would clobber the OTHER output's own
active workspace on a multi-monitor setup (niri tracks one `is_active` per output, plus
a separate global `is_focused` this code doesn't use). Also unhandled: niri's
`WorkspaceUrgencyChanged` event, so `urgent` goes stale after the first snapshot -
harmless only because the page doesn't render it yet.

**Standing reminder, reconfirmed this slice**: `niri msg action <anything>` (e.g.
`focus-workspace-down`) reproducibly wedged this project's nested-niri test instance's
entire IPC socket during manual testing - not just the one client; killing the stray
client did NOT recover it, `niri msg --json version` kept timing out with zero
niri-msg processes running, and only a full niri restart fixed it. refuter separately
stress-tested the actual `Process`/`SplitParser` design this slice ships with (6
connect/SIGKILL churn cycles, 4 simultaneous long-lived event-stream clients) and
exonerated it - niri stayed responsive throughout all of that. The hang is specifically
tied to the `action` subcommand, not to querying or streaming. Avoid `niri msg action`
against this test environment; read-only query commands (`workspaces`, `version`,
`outputs`, `event-stream`) are the ones confirmed safe.

## Slice 8 done (Power/Brightness), the "power" half

Brightness landed separately (see "BRI slider in CONTROLS..." above). This covers the
rest: `services/Battery.qml` (UPower's `displayDevice`, `available: isPresent` -
permanently false on this desktop, no battery hardware at all, confirmed via
`upower -i`; built for correctness/portability per the plan's own expectation),
`pages/PowerPeek.qml` (battery/charging transient, 300x34 r17, new `Theme.batteryW`),
and a LOCK/SLEEP/POWER actions row added to `pages/MediaExpanded.qml`'s "07 SESSION"
(partial - workspace pills/network-VPN-sync tray status/battery% still placeholder,
those need real backend work this pass didn't cover).

**Destructive-action safety, taken seriously given the stakes**: `systemctl suspend`/
`systemctl poweroff` (via `Quickshell.execDetached`) affect the REAL host system with no
sandboxing regardless of which test niri/qs instance triggers them - unlike every other
piece of hardware interaction this project has tested live (ddcutil brightness, real
notifications, real workspace switches), these were never actually executed during
development or either refuter pass, not even `loginctl lock-session` (least severe, but
still an unrequested action against the live session). Verified instead by: careful
manual code read-through of the arm/confirm/timeout state machine before ever
dispatching refuter, then a refuter pass explicitly instructed to verify ONLY via a
scratch copy with the three `execDetached` calls stubbed out - confirmed clean
afterward (`grep` for remaining `execDetached` calls in the scratch copy found only
the two in comments). LOCK is a single instant tap (harmless, trivially reversible via
password). SLEEP and POWER need tap-to-arm, tap-again-within-3s-to-confirm (POWER shows
red once armed, matching the design's own hover-red convention for it); refuter's
scratch-copy state-machine suite specifically covered the timing edge case that
mattered most here - a tap landing at 2.9s into the window still confirms, one at 3.1s
does NOT execute, it just re-arms (no Timer/input race where a late tap could be
mistaken for a still-valid confirmation).

**Two real bugs in `services/Battery.qml`, caught by refuter, both fixed** (neither
reproducible on this hardware - `available` is false either way here, so both silently
had no visible effect on this desktop, but would have been wrong on any machine with a
real battery):

- **`percentage` was 0..100 but Quickshell actually normalizes UPower's `Percentage` to
  0..1** (`device.hpp`: "equivalent to energy / energyCapacity"). Read backwards from
  Quickshell's own source, not verified against it originally. Would have rendered a
  92%-charged battery as "1%" and left the battery-bar fill permanently near-empty.
  Fixed: `percentage: available ? device.percentage * 100 : 0`.
- **`charging` checked only `state === Charging`, missing real UPower transitions that
  never pass through that exact enum value**: charge completing while still plugged in
  goes `Charging -> FullyCharged` (still charging, but the check would say no); some
  hardware with a charge-limit threshold goes `Discharging -> PendingCharge` on plug-in,
  skipping `Charging` entirely; and `FullyCharged -> Discharging` on unplug is a direct
  transition that never re-enters `Charging` either, meaning a charged laptop being
  unplugged would show NO state change and NO peek for the actual unplug event. Fixed:
  derived from `UPower.onBattery` instead ("is the system currently running on battery
  power, or discharging" - the semantically correct "is a charger connected" signal,
  correct across all three transitions) rather than enumerating charging-adjacent state
  values by hand.

Also tightened the startup-burst guard (same class of bug as `services/Audio.qml`'s
`_pastStartupBurst`/`services/Workspaces.qml`'s `_seeded`, applied here preemptively
since it can't be reproduced on battery-less hardware): the original 500ms fixed-`Timer`
heuristic risked leaking a real startup burst through if UPower resolved slower than
that on a busy boot. Replaced with `device.ready`, Quickshell's own deterministic
"this device's properties have actually finished populating" signal - no arbitrary
window to get wrong.

## 06 INBOX + the rest of 07 SESSION landed, all 7 numbered sections now real

Closed out the two placeholders left over from Slice 8: `pages/MediaExpanded.qml`'s "06
INBOX" (notification history) and the rest of "07 SESSION" (workspace pills,
ETH/VPN/SYNC + battery%; LOCK/SLEEP/POWER were already real from Slice 8 and untouched
here beyond being re-parented). The whole dashboard has no placeholder box left.

`services/Notifs.qml` gained `history`/`historyCap`(20)/`clearHistory()`. Deliberately
separate from `NotificationServer.trackedNotifications`: `app/Bridges.qml`'s Slice-6
cleanup calls `expire()`/`dismiss()` on a notification the moment its peek ends, which
destroys it and drops it out of `trackedNotifications` almost immediately - that list
only ever holds the ONE currently-showing notification, never a history. `history` is a
plain-data snapshot array the sender-facing notification lifecycle never touches.

INBOX shows up to 2 cards (`Notifs.history.slice(0, 2)`), matching the design
reference's own `hint-placeholder-count="2"` for this list, not an arbitrary choice.
CLEAR ALL empties the whole history, not just what's visible.

**Two real bugs found live (by literally watching the panel in the nested niri
instance) and one more from refuter, all fixed before commit:**

- **Layout overflow, silently clipped by the capsule's own rounded-rect mask.** Adding
  06+07 pushed `builtSections.implicitHeight` to 616px against a 568px budget (604 -
  36px margins) - the excess wasn't visible as an error, 07 SESSION just failed to
  render at all (clipped entirely below the visible frame), which is a much easier bug
  to miss than a compile error. Caught by a temporary debug `Text` bound to
  `builtSections.implicitHeight`/`content.height`, screenshotted via `grim` against the
  nested niri output. Fixed by bumping `Theme.expandedH` 604->660 and `Theme.canvasH`
  680->736 (same +56 delta, preserving the ~76px shadow-bleed slack the original 680
  value was tuned for - see that token's own comment).
- **SESSION row floated under SYSTEM with a dead gap below it whenever INBOX was short
  or empty**, instead of sitting at the panel's true bottom edge. The design's own CSS
  has INBOX as `flex:1` inside a fixed-height flex column, so it (invisibly) absorbs
  whatever space is left and 07 always lands at the bottom - a plain top-down QML
  `Column` can't reproduce that without a real flex-shrink implementation, so instead
  `sessionFooter` was pulled out of `builtSections` into its own `Column`, anchored
  `anchors.bottom: parent.bottom` on the shared `content` Item, independent of how much
  `builtSections` above it actually fills. Confirmed via live screenshots with 0, and 2
  populated inbox items: SESSION pins to the bottom in both cases, no dead gap, no
  overlap.
- **refuter caught what the live check above didn't: inbox card height was
  content-driven with no line cap**, so a real multi-line body (or one with embedded
  `<b>`/`<br>` parsed as rich text under the default `Text.AutoText`) grows the card
  height without bound - refuter measured a 4-line body producing 60px of overlap into
  `sessionFooter`, i.e. the exact clipping bug above, reintroduced through content
  rather than through section count. Fixed: `textFormat: Text.PlainText` +
  `maximumLineCount: 1` on both the title and body `Text`s (elide still truncates
  single-line overflow correctly). Also fixed a smaller bug in the same area the same
  pass surfaced: the per-card `implicitHeight` formula only added 9px of bottom
  padding instead of 18px (forgot the inner `Column`'s own `anchors.margins: 9`), which
  had been silently donating slack toward the overflow bug above - now `+ 18`.
  Re-verified live with the same adversarial multi-line/long-single-line bodies refuter
  used: both cards now truncate to one line each, no overlap.

Also fixed on the same pass: the SESSION-row workspace-pill `Repeater` had a leftover
`visible: !modelData.active || true` (always-true, clearly a stray edit artifact - just
deleted) and a width formula that made the ACTIVE pill narrower (14px) than inactive
ones sized to fit their label - backwards for a pill that contains visible label text
(unlike `WorkspacePeek.qml`'s plain unlabeled dots, where "active = wider" is fine).
Both states now size uniformly via `Math.max(20, wsLabel.implicitWidth + 8)`, matching
the design reference's own uniform numbered-square session-row pills (only
color/border differ by active state there, not size).

**refuter also flagged two non-blocking items, deliberately left as-is for now:**

- The workspace-pill Row (left) and the centered ETH/VPN/SYNC Row can collide once
  there are enough workspaces that the left row's width exceeds the center row's start
  x - measured at 12 numeric workspaces on the current 20px-floor pill width (this
  desktop's niri config declares no named workspaces, so pills stay at the floor;
  named workspaces would trigger it around 5). The session row has no width
  arbitration between its three independently-anchored Rows at all. Not touched this
  pass since it needs actual workspaces to reproduce and isn't hit on this machine
  today; worth a real fix (e.g. clamping the center Row's position, or giving the left
  Row a max width) before this ships anywhere with more than a handful of workspaces.
- `services/Notifs.qml` has no dedupe on notifications that replace an existing one via
  `replaces_id` (progress bars, volume/brightness OSD daemons, some media players re-
  sending on every tick) - each resend adds a new history entry, so the 20-deep cap can
  fill with repeats of the same logical notification and push real ones out. Left as a
  deliberate simplicity call; revisit if it turns out to matter in practice.

Verification: `./scripts/lint.sh` (no new warning categories beyond the established
`qs.*` import-resolution baseline present in every page file), `./scripts/test.sh` (24
passed), a dedicated refuter pass (built an offscreen `qmltestrunner` harness with
stubbed `qs.services`/`Quickshell` modules to measure actual computed heights rather
than trust screenshots - this is how the multi-line overflow bug above was actually
caught and precisely measured), and live checks via `grim` screenshots against the
existing nested niri instance (never spun up an extra one; `niri msg action` was never
used, per the standing rule above).

## Slice 9 done (Ship). Foundation frozen.

With all 7 numbered dashboard sections real, the plan's own milestone is reached:
"after slice 9 the foundation is frozen and the maintainer's design work starts." Shipped:
`services/Config.qml`, `config.example.json`, `scripts/install.sh`, `README.md`. Verified
via `./scripts/lint.sh` (clean, no new warning categories), `./scripts/test.sh` (24
passed), a refuter pass, and live checks against both the nested niri instance and, for
`install.sh` specifically, this machine's real `$HOME` (low-risk, reversible: it only
ever creates a new symlink and a new config file, never touches niri's or Noctalia's own
config - those stay print-only per the plan's own wording).

`services/Config.qml` reads `~/.config/dynamic-island/config.json` (falls back to
defaults on a missing file or bad JSON, read once at startup, no live-reload) and
exposes exactly one key, `notificationServer` (default `false`), even though the plan's
"JSON config (under 8 keys)" scoped room for more (`screen`, `reserveSpace`, `offsetX`,
`osdEnabled`, `workspacesEnabled`, `debug` were all on the table). Deliberate: those
other keys have no corresponding real toggle in the codebase yet (e.g.
`ui/IslandWindow.qml`'s `exclusiveZone` is still hardcoded, not
`Config.reserveSpace`-gated) - shipping a config key with nothing behind it is a fake
feature, not a config surface. `notificationServer` is the one key `Notifs.qml` actually
consumes (gates the real `NotificationServer`'s `Loader.active`, replacing a hardcoded
`true`). Add more keys only once there's a real toggle for them to drive.

`Notifs.qml` references the sibling `Config` singleton with no explicit `import
qs.services` - relies on QML's same-directory implicit visibility for qmldir-registered
singletons. Confirmed sound, not a fluke, by refuter via a standalone `qml` runtime
harness: resolves with no import, resolves identically through the `qs -c
dynamic-island` symlink path, returns the SAME singleton instance either way (no
duplicate-Config hazard), and a negative control (removing the `qmldir` line) correctly
makes it `undefined` rather than silently succeeding. Both defaults happen to coincide
if that qmldir line is ever lost by accident (`Config.notificationServer` ->
`undefined` -> `active: false`, same as the intended off-by-default), so a future
accidental breakage there would fail silently rather than loudly - noted here rather
than "fixed" with a speculative `import` for a maintenance mistake that hasn't happened
and isn't expected to.

**One real bug caught by refuter, fixed before commit**: `scripts/install.sh` used
`REPO_DIR="$(pwd)"` (logical path) after `cd`-ing into the repo. Running the script a
*second* time from its own already-installed location
(`~/.config/quickshell/dynamic-island/scripts/install.sh` - exactly the path a user
re-runs it from) resolved `REPO_DIR` to that same symlinked path, so `ln -sfn` linked it
to itself: exits 0, prints `linked X -> X`, looks like success, and silently destroys a
working install (`qs -c dynamic-island` then fails with "Too many levels of symbolic
links"). Fixed with `pwd -P` (physical path, symlinks resolved) plus an explicit
same-path guard that skips relinking entirely. Verified idempotent afterward (including
this exact self-referential re-run case) via refuter running the script twice against a
scratch `$HOME`, never the real one.

Also live-verified (30-second check, not just inferred from the read pattern) that
flipping `notificationServer` to `true` in the real `~/.config/dynamic-island/config.json`
genuinely re-triggers the "Could not register notification server" warning on this
machine (something else already owns `org.freedesktop.Notifications` on this session
bus) - confirming the config value actually reaches the `Loader`, not just that the
default happens to look right. Restored to the shipped `false` default afterward.

## Post-freeze: full Noctalia handoff, then a long real-use bug/polish pass

Everything below happened after Slice 9's freeze, across ~18 commits, without a
matching HANDOFF entry at the time - commit messages carry full detail per change;
this is the summary that should have landed alongside them.

**Wallpaper carousel + background painter** (`services/Wallpaper.qml`,
`ui/WallpaperBackground.qml`, `ui/WallpaperCarousel.qml`): ported from the KDE Kuro
rice's own `kuro-wallpaper` tool. niri has no built-in wallpaper mechanism the way KDE
does, so this needed two new pieces the original didn't: an always-on background-
painting layer surface, and applying a choice as a direct property update instead of
shelling out to `plasma-apply-wallpaperimage`. Folded into this shell's own process
(not a separate sibling project) as a standalone overlay window, outside the capsule/
peek state machine entirely. refuter found `cancel()` didn't stop the pending 220ms
preview debounce timer, letting a stale preview silently overwrite a just-reverted
wallpaper - fixed to match `apply()`'s existing `preview.stop()`.

**Audio/media/brightness exposed over IPC** (`app/Bridges.qml`, `services/Audio.qml`,
`shell.qml`): niri's hardware media/brightness keys called `noctalia msg <command>`,
which actually performed the PipeWire/DDC-CI change - this project's own OSD only ever
observed the result. New `IpcHandler` targets (`audio`, `media`, `brightness`) wrap the
existing services. Also connects `Brightness` into `Bridges.qml` (it was only ever
referenced from the on-demand `MediaExpanded` page, so its first ~8s DDC-CI read never
even started until the dashboard was opened) and finally wires up `Kinds.qml`'s
already-existing but never-fired `osd.brightness` entry.

**Compact pill**: divider + EQ now gate on `Media.isPlaying`, not `Media.available` - a
paused-but-loaded player (a backgrounded YouTube tab, most commonly) used to leave them
stuck on screen indefinitely instead of collapsing back to clock-only.

**Capsule's inset top highlight removed** (`ui/Capsule.qml`): the 1px
`rgba(255,255,255,0.05)` hairline read as an unwanted faint grey line once live on a
real desktop instead of just test screenshots.

**Three real bugs found clicking through the expanded dashboard for real** (see
`ac96cff`'s own commit message for full detail on each):
1. Workspace pills (07 SESSION) were read-only - `niri msg action` had a documented
   history of wedging this project's test IPC socket. Re-verified against the current
   niri version (15+ calls, including the exact verb that wedged it before, all clean)
   before wiring click-to-switch back up, `timeout`-wrapped regardless.
2. The LOCK button called `loginctl lock-session`, which just emits a D-Bus signal -
   niri-lockscreen (Noctalia's replacement) never subscribed to it. Now calls the same
   IPC path `Mod+ALT+L` already uses.
3. 06 INBOX hard-truncated to 2 notifications with the rest of history completely
   unreachable - replaced with a `ListView`, scrollable for the rest.

Also added `ui/CountBadge.qml` and a notification bell to the compact pill - refined
twice after visual feedback: the bell went from a separate icon+numeral-bubble pair to
a single `cod-bell_dot` glyph (the "unread" dot is drawn into the glyph itself), and
the INBOX header's badge went from a bare numeral in a small circle to a long "N
UNREAD" pill. Both glyph and layout choices confirmed via direct rendering tests
(fontTools cmap lookups, crosshair-guide screenshots), not guessed.

**Hover feedback, then corrected to a full invert**: every interactive control in the
expanded dashboard (TOGGLES, workspace pills, LOCK/SLEEP/POWER, CLEAR ALL, media
transport) first got a translucent-brighten hover treatment, then was corrected to a
full bone-on-black invert (`Theme.ink` background, `Theme.bg` content) after the maintainer
pointed at ryoku.dev as the reference - "shouldn't our theme be bone on black?" The ON
state of a toggle and the currently-active workspace pill also get the SAME persistent
invert, not just hover. POWER's armed (danger) red text stays red even inverted, since
losing the color would weaken the signal exactly when it matters most.

That same pass surfaced a real misalignment bug once the hover bubble gave LOCK/SLEEP/
POWER and the media transport buttons a visible box to line up against: LOCK/SLEEP/
POWER's labels used `centerIn` with `font.letterSpacing` set, which adds space AFTER
the last character with no matching leading gap - confirmed via a crosshair render test
that this visibly shifts centered text left, worse on odd-length labels. Fixed with an
`anchors.horizontalCenterOffset: font.letterSpacing / 2` correction (plus an unrelated
`+1` vertical offset for all-caps text centering against full line-metrics including
unused descender space). The media transport buttons were using raw Unicode dingbats
("◀◀"/"▶"/"▮▮"/"▶▶") instead of real icon glyphs - confirmed via the same crosshair test
that plain Unicode symbols carry their own baked-in asymmetric blank space, not
designed for icon-button centering - replaced with `fa-step_backward`/`fa-play`/
`fa-pause`/`fa-step_forward`.

**Auto-collapse delay** (`theme/Motion.qml`): 1800ms → 1000ms, felt laggy after moving
the mouse off the expanded dashboard.

**06 INBOX layout, three rounds of real bugs, each caught by the maintainer actually looking at
it** (`pages/MediaExpanded.qml`, `theme/Theme.qml`):
1. The `ListView`'s clip height (145) was an unmeasured guess 10px too generous,
   letting a sliver of a third card's top edge peek past the clip line before being cut
   off. Measured a real card's actual height (64px) and fixed to the exact value (135
   for 2 full cards).
2. That fix addressed the wrong overflow - 07 SESSION is independently anchored to
   this page's own bottom (not part of 06 INBOX's top-down Column), so nothing actually
   guaranteed a gap between them. Live-measured with temporary debug logging (removed
   after): `builtSections` landed at height 593, `sessionFooter` started at y=587, a
   genuine 6px overlap. Bumped `expandedH`/`canvasH` (+22 each, preserving the shadow-
   bleed slack ratio) to restore a proper ~16px gap.
3. Once fixed, the maintainer asked for less height back - a full 2-card view didn't obviously
   signal there was more to scroll. Shrank the `ListView` to a deliberate 1.5-card
   "sneak peek" (103, not 135), which freed 32px INBOX no longer needed - pulled
   `expandedH`/`canvasH` back down correspondingly (682→650, 758→726) rather than
   leaving a now-oversized ~48px dead gap.
4. Separately: the whole 06 INBOX header (label, badge, CLEAR ALL) was gated on
   `Notifs.history.length > 0`, hiding everything the instant history emptied - now
   only the badge itself hides at zero, matching this page's own "keep visual
   completeness, dim what's not real" rule already applied elsewhere (ETH/VPN/SYNC).

Every one of these was re-verified live with real `notify-send` test notifications and
screenshots after each fix, not just reasoned about.

**Morph animation smoothing** (`theme/Motion.qml`): the capsule's `SpringAnimation`
(spring=18, damping=3.5) had a damping ratio of ~0.41 - underdamped enough to visibly
oscillate before settling. Raised damping only, to 6.5 (~0.76 ratio) - deliberately not
touching `spring`, since this same file already documents a spring value of 300 once
making width diverge to 1M+ px and freeze the desktop via a runaway GPU texture
allocation. Damping is the stabilizing term; raising it can't cause that failure mode.
Verified with 4 rapid expand/collapse cycles via IPC: process survived cleanly, memory
stayed normal, capsule rendered at its correct size afterward.

**Brightness and CPU stats "comes in late" on every restart** - two separate, real
causes (`services/Brightness.qml`, `services/SystemStats.qml`, `app/Bridges.qml`):
1. Brightness's ~8s-per-`ddcutil`-call latency turned out to be pure auto-detection
   overhead, not real DDC-CI protocol latency - measured `ddcutil detect --brief`
   alone at ~8.1s, and `ddcutil getvcp --bus N` (skipping detection, once the bus is
   known) at ~0.05s. `--sleep-multiplier`/dynamic-sleep flags made zero difference,
   ruling out DDC retry timing as the cause. The bus is now discovered once and
   persisted to `~/.config/dynamic-island/brightness-bus.json`, with a fallback back to
   rediscovery if a cached bus ever stops returning a valid read (monitor moved to a
   different port, etc.) - only the very first run ever pays the ~8s cost now. Verified
   live: the BRI OSD fired within ~1.3s of restart across three separate restarts,
   versus never that fast before.
2. `SystemStats` had the exact same lazy-singleton problem `Brightness` itself had
   before its own earlier fix - only ever referenced from the on-demand dashboard page,
   so its poll `Timer` never started until first opened. Referenced from `Bridges.qml`
   now. Separately, CPU% specifically needs two `/proc/stat` samples to compute a
   delta, so it stayed hidden for one full `pollInterval` (3000ms) after the first
   sample - added a one-off 250ms follow-up poll instead of waiting the full 3s.

**Media position/duration display, investigated carefully before touching anything**:
The maintainer reported the elapsed/remaining time "looks off" on a normal (non-live) 2:50:27
YouTube video. The obvious suspect - the `isLive` length-threshold heuristic - turned
out NOT to be the bug: `Media.length` is confirmed in seconds (10227, matching reality)
and the live-detection threshold (~31 years) is nowhere close to triggering for any
real video regardless of length, confirmed via an isolated debug harness reading the
real live values. Real cause: the remaining-time label (`Media.length - Media.position`)
had no guard against `Media.length` itself not having arrived yet - MPRIS metadata,
duration especially, often arrives asynchronously slightly after a player registers or
right after this shell restarts mid-playback, during which it showed a misleading
"0:00" (reads as "about to end") instead of nothing. Fixed to hide until
`Media.length > 0`, plus added a "REFRESH TAB" fallback (a derived `needsDuration` bool
+ a one-shot 4s `Timer`) if that normal gap doesn't resolve - pointing at the actual
fix (a stale browser-tab MPRIS report) since restarting this shell wouldn't help a
browser-side problem. State machine verified correct in an isolated test before
landing: a case resolving in 1.5s never trips the fallback, a case that never resolves
fires it at exactly 4s.

**Bundled fuzzel theme** (`fuzzel/fuzzel.ini`, wired into `scripts/install.sh`): same
tokens as `theme/Theme.qml`, sharp corners (`radius=0`), and the selected entry gets
the same full bone-on-black invert as the dashboard's own hover/active treatment.
`//kuro.` lives in the `prompt` slot (fuzzel can't pin arbitrary text to a window
corner - it's a plain list launcher, not a custom canvas). Icons kept, not disabled -
confirmed with the maintainer first, since losing at-a-glance app recognition for a strict
monochrome palette was a real tradeoff, not an obvious win. `install.sh` links it with
the same not-a-symlink-already caution as its own `QS_TARGET`, since this is a real
user config file fuzzel itself also reads.

## Renamed dynamic-island to kuroshima

"dynamic-island" was always the working title, not a real product name - generic,
hard to search for, and not distinct from Apple's own feature. The maintainer wanted a real
name to put on a public repo. Landed on `kuroshima` (黒島, "black island"): keeps the
literal island metaphor, extends the existing Kuro brand (the Obsidian theme, the
`//kuro.` fuzzel prompt) instead of starting a new identity, and reads fine as a repo
name, a `qs -c` scope, and a directory name.

Full rename, not just the repo name, since the old name was load-bearing on a live
desktop: local project directory (`~/Projects/dynamic-island` -> `~/Projects/kuroshima`),
`WlrLayershell.namespace` on the main window and both wallpaper surfaces
(`dynamic-island[-wallpaper-bg|-wallpaper-carousel]` -> `kuroshima[-wallpaper-bg|
-wallpaper-carousel]`), the config directory (`~/.config/dynamic-island/` ->
`~/.config/kuroshima/`, existing `config.json`/`brightness-bus.json`/
`wallpaper-state.json` migrated in place, not regenerated), the `~/.config/quickshell/`
symlink, and every live niri config that invokes it by name (`autostart.kdl`,
`keybinds.kdl`'s 11 `qs -c dynamic-island ...` IPC calls, `rules.kdl`'s wallpaper-bg
namespace match). Verified live: killed the old process, re-ran `install.sh` from the
renamed directory, launched `qs -c kuroshima`, confirmed the compact pill still
rendered and `qs -c kuroshima ipc call island demo audio` round-tripped correctly.

Deliberately did NOT rewrite: this file's own history above (a decision log, not
meant to be edited to match later renames), `plans/2026-09-18-foundation-plan.md`
(a dated point-in-time planning doc, same reasoning), the `plans/Claude Design -
Dynamic Island/` reference asset (a historical design capture, its name documents
what it was called when captured), `theme/Theme.qml`'s comment pointing at that same
asset path, `theme/Motion.qml`'s comment about macOS's actual Dynamic Island feature
(a different product, not ours), and the already-tagged `v0.1.0` CHANGELOG entry
(tags are frozen; the rename is its own `Unreleased` entry instead).

## Media thumbnail height fix (MediaExpanded)

The maintainer flagged the MEDIA section's art thumbnail as visually floating: it was a fixed
54x54 `ClippingRectangle`, while the row's actual content column (title/artist, scrub
bar, transport row) is naturally taller, leaving dead space above/below the art.

Fix: gave the info `Column` an id (`mediaInfoColumn`) and bound the art's `width`/
`height` to `mediaInfoColumn.implicitHeight` instead of the literal `54`, then narrowed
the column's own width by the art's new (larger) width instead of the old constant.
No binding loop: the column's implicit height only depends on its children's heights,
never its own width, so the art can safely depend on it. Kept the width/height fix
entirely inside the MEDIA row itself, no `Theme.qml` canvas-size changes needed.

Verified: `scripts/lint.sh` unchanged at 1917 warning lines before and after (same
known noise, no new categories). Restarted the live `qs -c kuroshima` process cleanly
(no new errors in the log), expanded to `MediaExpanded` via
`qs -c kuroshima ipc call island expand MediaExpanded` with a real YouTube track
playing, and screenshotted it: the art now reads as a proper square flush with the
full row height instead of a smaller box floating inside it.

## Bundled foot, fastfetch, yazi (same treatment as the earlier fuzzel bundle)

The maintainer made yazi his default file manager and asked for the same "bundle it so
installing the island gets it too" treatment already applied to fuzzel, plus a
matching bone-on-black theme for it, foot, and fastfetch.

Added `foot/foot.ini`, `fastfetch/foot.jsonc`, `fish/functions/{fastfetch,y}.fish`,
`yazi/{theme.toml,init.lua,keymap.toml,package.toml}`, all linked by `install.sh`
with the same not-a-symlink-already caution as the existing `fuzzel/fuzzel.ini`
block. Converted the real, already-in-place versions of each on this machine into
actual symlinks by running `install.sh` for real (removed the standalone files
first, then let the script link them from the repo), the same way fuzzel was
dogfooded earlier.

Two real bugs surfaced and got fixed as part of this, not just theming:

- **Yazi's `<Enter>` crashed on every directory** with `process exited with status
  code: 127`. Root cause: stock yazi's `[open] rules` maps `folder/*` to try the
  `edit` opener FIRST (`${EDITOR:-vi} %s`) before anything else - `<Enter>` on a
  directory does not natively `cd`, it tries to open it in `$EDITOR`. This system
  has neither `$EDITOR` set nor a `vi` binary (only `nvim`/`vim`/`micro`/`nano`), so
  the fallback resolved to a literal `vi` that doesn't exist. Confirmed via
  `yazi-actor/src/mgr/open_do.rs` (fetched from upstream, no native is-directory
  branch at all - directories go through the same mime-matched opener path as
  files) and `yazi-config/preset/yazi-default.toml`'s `[open] rules` (`{ mime =
  "folder/*", use = ["edit", "open", "reveal"] }`). Reproduced deterministically
  with `ydotoold` + `ydotool key` sending real keypresses into a live yazi window
  (confirmed via `niri msg focused-window` first) rather than guessing, and
  confirmed it affected every directory, not just the one the maintainer happened to report
  (`~/Desktop`) - `l` (bound to yazi's separate native `enter` action) navigated
  fine, only `<Enter>` (bound to `open`) broke.
  Fixed two ways: installed the official `smart-enter.yazi` plugin (`ya pkg add
  yazi-rs/plugins:smart-enter`) and bound `<Enter>`/`l` to it in `keymap.toml`, so
  Enter does the expected thing (navigate dirs, open files) instead of hitting the
  opener path at all; and set `EDITOR`/`VISUAL` to `nvim` in niri's `misc.kdl`
  `environment{}` block (fixes actually opening files too, not just the directory
  case) - that block only applies at niri's own startup though, not on live config
  reload, so it needs a niri restart/relogin to take effect, unlike everything else
  in this pass. Added the same two lines to `config.fish` for immediate effect from
  an interactive shell.
- **Foot's fastfetch greeting broke**: `config.jsonc`'s dithered PNG logo uses the
  kitty graphics protocol, which foot doesn't support (Sixel only). New
  `fastfetch/foot.jsonc` (flat hairline key/value rows, no image) plus a
  `~/.config/fish/functions/fastfetch.fish` wrapper that injects `-c
  .../foot.jsonc` whenever `$TERM` is `foot` - covers both the shell greeting and
  a manually-typed `fastfetch`, and this needed to be a wrapper around the actual
  command, not just a `fish_greeting` override, since the first fix attempt only
  caught the greeting and left manual invocations still crashing on the PNG logo.

Yazi's theme (`yazi/theme.toml`) was built from yazi's actual upstream
`theme-dark.toml` and `yazi-default.toml` (fetched from `sxyazi/yazi` on GitHub via
`gh api`), not guessed - confirmed the real `[mgr]`/`[status]`/`[filetype]`/`[icon]`
schema and field names against the installed binary's own embedded defaults
(`strings /usr/bin/yazi`) before writing anything. Kept every icon glyph from the
stock `[icon]` tables (700+ file-type entries) but stripped their per-language `fg`
hex colors via a regex pass, same "keep icons, drop hue" call as fuzzel. Directories
and the four marker states (`copied`/`cut`/`marked`/`selected`) are told apart by
ink-tier brightness instead of hue; the three modes (`normal`/`select`/`unset`) by
bold/underline/italic, since the status bar still needs to say which one is active
at a glance without color to lean on.

## Switched default terminal from foot to kitty, dropped foot entirely

The maintainer wanted yazi's drag-and-drop working, which surfaced that foot doesn't
implement the Drag and Drop protocol at all (only kitty 0.47.1+, iTerm2 3.7.0
beta10+, and eventually Ghostty do). Considered Ghostty first since it's the more
fashionable pick, but its DnD support is only "accepted" upstream, not shipped -
kitty was the only option that actually solved the reported problem. Once decided,
The maintainer asked to drop foot outright rather than keep both.

Removed from this repo: `foot/`, `fastfetch/foot.jsonc`, and
`fish/functions/fastfetch.fish` (the $TERM-routing wrapper - no longer needed since
there's only one terminal to route for, and kitty renders the default
`~/.config/fastfetch/config.jsonc`'s image logo natively anyway). Reverted
`config.fish`'s `fish_greeting` override to nothing, since with the wrapper gone it
was doing exactly what `cachyos-config.fish`'s own default greeting already does
(plain `fastfetch`) - redundant, not a functional change.

`kitty/kitty.conf` needed two settings that aren't just preference, both would
otherwise silently break things:
- `shell fish` - niri's own environment has `SHELL=/usr/bin/zsh` (confirmed via
  `/proc/<qs-pid>/environ`, not guessed - the account's real login shell per
  `getent passwd` is fish), and kitty's default `shell .` inherits whatever `$SHELL`
  says. Without this override every kitty window would launch zsh, silently
  dropping `y` and fastfetch's greeting. First test spawn (from this session's own
  shell, itself zsh-flavored) hid this - only caught it by checking niri's actual
  process environment directly rather than trusting the first successful-looking
  screenshot.
- `confirm_os_window_close 0` - the maintainer reported this as "are you sure you want to
  close" firing every time he exited yazi via `Mod+E`. Default asks whenever a
  foreground process is still running in the window; yazi (or anything else) always
  counts.

`kitty --version` confirmed 0.48.2, comfortably past the 0.47.1 DnD minimum, so no
upgrade was needed - just the config and keybind changes (`Mod+T`/`Mod+E` in
`keybinds.kdl`, `kitty`/`kitty yazi` instead of `foot`/`foot -e yazi`).

**Real mistake caught mid-task, worth recording**: `~/.config/foot` and
`~/.config/fastfetch` turned out to be whole-directory symlinks into a separate,
pre-existing dotfiles project (`~/Projects/minimalist`, its own git repo, last
commit "Add a lock screen"), not standalone config. Every foot/fastfetch edit
earlier in this session had actually been landing inside that repo, invisibly -
a directory-level symlink makes files inside it look like ordinary files, so the
`[ ! -L "$FOOT_TARGET" ]` safety check in `install.sh` (checking the FILE path)
never caught it. Then "uninstall foot" led to `rm`-ing minimalist's tracked
`config/foot/foot.ini` directly. Caught it via `ls -la` on the parent directories
(showing them as symlinks) before going further, restored the deleted file with
`git checkout` in that repo, and asked the maintainer directly rather than guessing what to
do about the second project - he confirmed minimalist is retired, kuroshima is now
the one canonical repo. Migrated the one thing worth keeping from it: a
hand-tuned fastfetch config with a dithered logo, now `fastfetch/config.jsonc` +
image here, source path repointed from `~/Pictures/...` (this machine only) to
`~/.config/fastfetch/...` (works for anyone installing this repo). Left
minimalist's own `config/fastfetch/config.jsonc` local diff alone - dated August
25, predates this session, not mine to touch.

Then went through several rounds trying to replace that migrated logo with a
dithered "クロシマ" (kuroshima in katakana) image wordmark, ultimately abandoning
the image approach entirely:
1. Black text on a white card, square 308x308 to match the disc's own pixel
   dimensions so `width: 25` would reproduce the same rendered height with no
   further tuning. Wrong on both counts - looked like a sticker, not the
   halftone accent it was meant to be, and still ran taller than the spec box
   despite matching the disc's pixel dimensions exactly. Matching pixel
   dimensions does not mean matching *rendered terminal rows* - cell aspect
   ratio still applies, and fixing it required dropping `width` by trial (25 to
   19), not computation.
2. White ink dithered to transparency instead (dithered BLACK pixels mapped to
   alpha 0 instead of opaque black), for "no card, just dithered text," plus a
   `//kuroshima` header above the katakana stack.
3. Two more rounds chasing a bottom-clipping bug: the last katakana glyph kept
   getting cut off in the maintainer's own screenshots despite looking fine in mine.
   Added padding, still clipped. Added *more* padding (up to 22% of height),
   still clipped, and each attempt visibly shrank the glyph within the frame
   without fixing anything - the maintainer correctly called this out as chasing a bug
   with cosmetic patches instead of finding the cause. Real cause never fully
   confirmed (suspected: fastfetch's column-based image width doesn't map onto
   a whole number of terminal rows, and the fractional remainder gets clipped
   by whatever prints next, independent of the image's own internal margins).
4. Dropped the image entirely on the maintainer's suggestion: `//kuroshima クロシマ` as
   one plain text line (both scripts, horizontal) above the spec box, single
   column, `"logo": {"type": "none"}`. Sidesteps the whole bug class instead of
   curing it. One gotcha on the way: a `custom` module with `key: ""` plus a
   `format` prints the module's type name ("Custom") as a fallback label -
   fixed by putting the whole line in `key` with no `format`, matching how the
   box's own border-line modules already did it.

## Desktop widget canvas: edit mode, `services/Widgets.qml`

The maintainer wants desktop widgets, inspired by a ryoku.dev showcase and Noctalia's own
widget-edit-mode, but explicitly scoped this pass to the *framework*, not any
specific widget: an edit mode to add/move/remove widgets, open enough that he
(or anyone) can drop in custom QML without touching this repo. Explicit: widget
*content* is not held to this repo's bone-on-black rule - "up to user of their
own creativity." The "good night" greeting widget itself is a deliberate
follow-up once this landed, not part of this pass.

New: `services/Widgets.qml` (editMode + placed[] + FileView persistence, same
shape as `services/Wallpaper.qml`), `ui/WidgetCanvas.qml` (the background
surface), `ui/WidgetFrame.qml` (per-instance edit-mode chrome: border, drag,
delete badge), `widgets/Clock.qml` (one bundled placeholder, proves the
mechanics, not the point). `Mod+Shift+W` toggles edit mode via a new
`toggleWidgetEdit` function on `shell.qml`'s existing `island` IpcHandler,
same pattern as `wallpaperToggle`.

Three real bugs found and fixed while building this, all confirmed via direct
log evidence rather than guessing from screenshots (see below for why):

1. **`Widgets` singleton wasn't resolvable at all** (`ReferenceError: Widgets is
   not defined`) despite `pragma Singleton` and `import qs.services` - missed
   that `services/qmldir` explicitly lists every singleton by name
   (`singleton Wallpaper 1.0 Wallpaper.qml`, etc.); a new singleton needs an
   entry there too, plain `import` alone isn't enough for Quickshell's
   directory-as-module convention. Non-singleton types (`ui/WidgetCanvas.qml`,
   `widgets/Clock.qml`) don't need this - confirmed no `ui/qmldir` exists
   either.
2. **`WidgetCanvas` never rendered above the wallpaper**, even though it's
   instantiated after `WallpaperBackground` in `shell.qml` - same-layer
   (`WlrLayer.Background`) stacking order is NOT guaranteed by creation order,
   confirmed live (widget data was correct, Loader status was Ready, nothing
   ever appeared on screen). Fixed by moving it up one real wlr-layer-shell
   layer (`WlrLayer.Bottom`) instead of relying on ordering within the same
   layer - Bottom is still below Top/Overlay, where real windows effectively
   sit, so normal windows still win over widgets exactly as before.
3. **`required property` on `WidgetFrame` intermittently stuck at empty
   string** when set via a Repeater delegate's model-row bindings
   (`widgetType: modelData.type`), causing `Widgets.urlFor("", false)` to
   resolve to a nonexistent `widgets/.qml` and the Loader to fail silently.
   `modelData` itself was always correct (confirmed via
   `console.log(JSON.stringify(modelData))` directly in the delegate) - the
   break was specifically between the model row and the `required` property
   receiving it. Switched to plain `property string widgetType: ""` (not
   required) and it started working reliably; never fully root-caused why
   `required` specifically behaved this way with an external-file delegate
   type, but the practical fix is confirmed solid across multiple hot-reloads.

**On verification for this one being lighter than usual**: the real desktop was
extremely active this session (browser tabs, Spotify, other real windows
constantly opening/moving), and repeated attempts to visually confirm the
widget canvas via screenshots kept landing on unrelated real personal content
by coincidence of window layout - handled per this project's own established
rule (never analyze or keep screenshots of content that isn't what was being
tested), but it meant abandoning the visual-click-through verification
(add/drag/delete via actual mouse input) that every other feature this session
got. What IS verified: qmllint clean, headless `qs -n -p .` launches with zero
warnings, `console.log`-confirmed correct data flow end-to-end (JSON ->
`Widgets.placed` -> `modelData` -> `WidgetFrame.widgetType` -> `Loader` ->
`Loader.status` never `Error`), and the IPC toggle (`toggleWidgetEdit`)
round-trips cleanly on the real live process. The maintainer should confirm the actual
visual/drag/drop experience himself via `Mod+Shift+W` - he has full context of
his own screen and won't hit the same "which window is this" confusion.

**Resize, added right after**: the maintainer immediately flagged that a widget editor
without resize is missing something obvious - correct, and it was explicitly
called out as deferred in the plan, not forgotten. Added a bottom-right drag
handle (`WidgetFrame.qml`, mirrors the existing delete badge's positioning
convention) plus `Widgets.resizeWidget(id, w, h)`, persisting `w`/`h` alongside
`x`/`y`.

This forced a real contract change, not just an additive one: `ui/WidgetFrame.qml`'s
`Loader` now uses `anchors.fill: parent` instead of sizing itself to the loaded
item, so a resize actually resizes the widget's rendered content, not just an
empty frame around it. That only works if the widget itself does NOT bind its own
`width`/`height` (only `implicitWidth`/`implicitHeight` as a natural-size hint) -
the opposite of the page contract, which explicitly requires pages to self-size
that way. Updated `widgets/Clock.qml` to drop its `width`/`height` bindings and
documented the distinction explicitly in `CLAUDE.md`'s widget contract section,
since getting this backwards (copying the page contract's self-sizing rule) would
silently make every widget resize-proof in a way that's easy to not notice until
someone actually drags the handle.

**Click-to-focus, right after**: the maintainer wanted a real edit interaction model, not
every widget's border/handles showing at once for the whole time edit mode is
open. Added `Widgets.focusedWidgetId` - a widget's border/resize-handle/delete
badge now only show when it's the focused one (click to focus), while dragging
to move stays available on any widget without needing focus first. `<Enter>`
clears focus (stays in edit mode, matching his description: "the box will
disappear, means the widget is done already... can click the widget to focus
again"); `<Escape>` exits edit mode entirely, per his explicit ask.

Needed real keyboard input for the first time on this surface, which meant
`WlrLayershell.keyboardFocus` couldn't stay a fixed `WlrKeyboardFocus.None`
anymore - made it conditional on `Widgets.editMode` instead (`Exclusive` while
editing, `None` otherwise). `WallpaperCarousel.qml` already does something
similar but gets away with a FIXED `Exclusive` because it's also `visible:
false` when closed - its own comment notes "an invisible layer surface holds no
focus at all" - which doesn't apply here since this surface is always visible
for the widgets themselves, hence the actual conditional rather than relying on
visibility. `forceActiveFocus()` on entering edit mode follows the same
`Qt.callLater` pattern `WallpaperCarousel._open()` already uses.

Also added a diagonal resize-direction glyph to the resize handle per the maintainer's
suggestion ("↘", U+2198) - confirmed present in JetBrainsMono Nerd Font via
`fontTools` first, this project's own established rule for icon glyphs, not
guessed from memory.

## First real bundled widget: `widgets/GoodNight.qml`

The actual feature request from the start of this whole widget-system thread -
a ryoku.dev showcase widget the maintainer wanted (greeting + huge day abbreviation +
date/time, bracketed by short hairline ticks), now that the framework exists
to hold it. Registered in `Widgets.bundledTypes` alongside `Clock`.

Kept in this repo's own bone-on-black palette rather than the reference's
colour accents (teal glow, red day-label, coloured dock icons) - the maintainer's own
words on widget content were "up to user of their own creativity," but this
one ships WITH kuroshima, so it follows the same house style as every other
bundled surface. He specifically flagged that the font matters for the look
working at all - used `Theme.fontFamily` throughout (same JetBrainsMono Nerd
Font everything else in this repo already uses), `Font.Black` weight for the
day abbreviation specifically, matching how the fastfetch wordmark logo
earlier in this session also went straight for the Black weight for its own
big display element.

Deliberately left out of scope, both clearly separate design elements in the
reference rather than part of the greeting card itself: the vertical icon
dock (WiFi/BT/mic/volume/battery - reads as Noctalia's own always-on sidebar,
not something this one widget should absorb) and the diagonal audio-
visualizer streak. Also dropped the reference's redundant second date label
(bottom-left "Saturday · August 22", repeating the same date already shown
in the main block) - sensible on a huge wallpaper-covering canvas with empty
space to fill, not on a compact resizable widget.

Font sizes scale with `root.width`/`root.height` the same way
`widgets/Clock.qml` already does (fixed `implicitWidth`/`implicitHeight`
constants, never derived from the child labels, to avoid the exact binding
loop documented in that file's own comment) - resizing this one changes
every line's size together, not just the day abbreviation. Greeting is
genuinely time-of-day aware (`GOOD MORNING`/`AFTERNOON`/`EVENING`/`NIGHT`
via `clock.date.getHours()`), not hardcoded to match whatever the reference
screenshot happened to show.

**Two real fixes right after, from the maintainer's own side-by-side comparison
screenshots**: (1) everything was left-aligned; the reference is centered.
`anchors.left: parent.left` on the Column -> `anchors.centerIn: parent`,
plus each child needs its own `anchors.horizontalCenter: parent.horizontalCenter`
against the Column (a `Column` only manages children's *y*, not *x* -
without this, text still stacks flush-left inside a centered Column,
since items of different natural widths don't self-center just because
their container does). (2) the day abbreviation used `Theme.fontFamily`
(JetBrainsMono Nerd Font) at `Font.Black` and still looked nothing like
the reference - because a monospace font structurally can't produce the
reference's tight, proportional-width geometric look, no weight fixes
that. This project's own user-level aesthetic notes already call for a
grotesk display font for exactly this role ("interface / H2"); Space
Grotesk itself isn't installed on this machine, but `fc-list` turned up
"Inter Display" with a real Black cut, confirmed via `fc-match` before
using it (same "verify before use" rule this project already applies to
icon glyphs) - not a guess, and not silently falling back to a default
face.

**Inter Display swapped for Fraunces, right after**: the maintainer correctly called
Inter Display "kind of normal" - it's a clean grotesk, exactly what it's for,
but not what "quirky/unique" means for a display element like this. This
project's own aesthetic notes already name Fraunces specifically for that
role (a display-serif wordmark), so that's what got installed -
`ttf-fraunces` from the AUR (`aur/ttf-fraunces`, `aur/otf-fraunces`, and a
variable cut all exist; picked the static one). First AUR install attempt
hit a transient TLS error cloning from `aur.archlinux.org` - not a real
problem, just retried and it built fine.

Real gotcha once installed: the family name isn't plain "Fraunces" at all -
`fc-match "Fraunces"` silently resolved to Noto Sans, no error, nothing
in the log to suggest anything was wrong. Fraunces ships as three separate
optical-size families (`Fraunces 9pt`, `Fraunces 72pt`, `Fraunces 144pt`,
each also with Soft/SuperSoft variants), and only the specific family name
matches. `144pt` is the cut actually drawn for large display text, not
just the small-text cut rendered bigger, so it's also just the correct
choice for a day-abbreviation this size, not only the name that happens to
resolve. Confirmed via `fc-match "Fraunces 144pt:weight=black"` before
touching the widget - the exact same "verify before use" step that caught
Inter Display's own correct name earlier in this same file, now caught a
subtler version of the same failure mode (a family name that LOOKS
plausible and doesn't error, just silently substitutes).

Also made the top/bottom hairline ticks thicker and switched them from
`Theme.divider` to `Theme.ink` (a hairline-weight rgba tint reads as
barely-there at 2px+ - it needs to be a solid tone to still look
intentional once it's not a literal 1px hairline) - both straightforward,
no gotchas.

**Went too far the other direction on the ticks, plus a layout gap the maintainer
caught from the reference directly**: made them thicker in the previous
pass when he'd actually meant them thicker than the original 1px but still
thin overall - overcorrected. Also, "GOOD AFTERNOON" as one line reads
visibly wider than "GOOD NIGHT"/"GOOD MORNING"/"GOOD EVENING", which the
reference avoids entirely by always splitting into two lines ("GOOD" /
mood-word) - simplest fix was making `greetingFor()` return `"GOOD\n" +
word` directly and letting `Text`'s native `\n` + `horizontalAlignment:
Text.AlignHCenter` handle the two-line render, no wrap-mode measuring
needed.

The real structural fix was spacing, not just tick dimensions: a single
flat `Column` with one `spacing` value can't have a big gap around the
ticks AND a tight gap between the greeting/day/date/time lines at the
same time - they're the same property. Split into a nested `Column`: the
outer one holds just [tick, inner-column, tick] with a large spacing
value, the inner one holds the four text lines with a small spacing
value. Matches the reference's actual rhythm (loose around the ticks,
tight within the text block) instead of one compromise value applied
everywhere.

## `GoodNight` greeting line: Poppins, wider letter-spacing

The maintainer's next reference-image comparison round: the greeting line
("GOOD"/mood-word) needed more letter-spacing to match the original, and
"I think Poppins is better" than `Theme.fontFamily` (JetBrainsMono Nerd
Font) for that line specifically. A monospace font's fixed advance width
can't reproduce the reference's letter-spaced caps look at any spacing
value - every glyph already occupies the same width regardless of the
letter itself, so widening the gaps between them still reads as
mechanical rather than the reference's more organic tracking.

Installed `ttf-poppins` from the AUR, confirmed the real family name via
`fc-match "Poppins"` before use (unlike Fraunces, Poppins isn't split by
optical size - plain `"Poppins"` resolves correctly, weights come from
`font.weight`). Used `Font.Medium`. README's Widgets section now lists
`ttf-poppins` alongside `ttf-fraunces` as a `GoodNight` dependency.

`letterSpacing` went `2` -> `4` -> `8`: the first two bumps looked
identical to the maintainer because the running `qs -c kuroshima` process was
never restarted after either edit - editing a bundled widget's `.qml`
file on disk does nothing to an already-running instance, there's no
file-watch/hot-reload wired into the installed (non-dev) shell. Only
`scripts/dev.sh`'s sandbox picks up changes live. Killed and relaunched
the real process (`pkill -f "qs -c kuroshima"` then `qs -c kuroshima &`)
before the `8` value was visible - worth remembering before assuming a
QML edit "didn't work."

## Wallpaper carousel: darker scrim, catching up on missing docs

The maintainer's feedback on the `Mod+P` carousel: the header/footer text (WALLPAPER
label, selection counter, keyboard hints) was hard to read over the dim
scrim behind it. `ui/WallpaperCarousel.qml`'s background `Rectangle`
(`color: "#000000"`) went `opacity: 0.34` -> `0.62`.

Also caught while touching this: the wallpaper carousel (`Mod+P`,
`ui/WallpaperCarousel.qml`, `services/Wallpaper.qml`) was fully built,
committed, and even manually wired into the live `keybinds.kdl` on this
machine, but was never added to `scripts/install.sh`'s printed niri-keybind
steps or given a README section - the only bundled feature in this state.
Fixed: `install.sh` step 7 now prints the `Mod+P` keybind (old step 7,
"restart niri", renumbered to 8), README's Install section mirrors it, and
a new "## Wallpaper carousel" section documents the directory it reads
(`~/Pictures/Wallhaven`, hardcoded, no config key yet), live-preview vs.
commit/revert (`services/Wallpaper.qml`), and the no-thumbnail-generation
tradeoff.

## Wallpaper background crossfade, and its carousel: accordion + diagonal mask

The maintainer asked for "some animation when changing the wallpaper (the entry
animation), like honeycomb animation and such" - offered a choice between a
real hexagonal-tile shader reveal (needs GLSL + Qt's `qsb` compile step, a
real build-tooling addition) and a pure-QML crossfade+zoom. He picked the
crossfade. `ui/WallpaperBackground.qml` now runs two stacked `Image` layers:
whichever is "inactive" gets the new source, and once it actually finishes
decoding (`Image.Ready`, not just source-assigned) the layers swap active
state via a declarative `State`/`Transition` pair - incoming settles from a
slight zoom-in while fading in, outgoing zooms out slightly while fading
out, ~480ms.

Real bug in that first version, caught by the maintainer stepping backward through
the carousel: "when i go backward one time, the animation didnt triggered
and wallpaper didnt changed, had to go back 2 times then it triggers."
Root cause: the layer swap was gated purely on `Image.onStatusChanged`
firing to `Ready`. Reassigning a QML `Image.source` to a URL it already
holds is a no-op - no property-change signal fires, so `onStatusChanged`
never re-triggers. Stepping back onto whatever the currently-inactive layer
already held (the previous-previous wallpaper, from two steps before) hit
exactly this: the swap silently stalled on that step, only catching up
(and visibly skipping straight past the missed image) once a genuinely
different path came in next. Fixed by comparing the target layer's current
`source` against the requested URL before assigning - if it already matches,
flip the active layer immediately instead of waiting on a signal that will
never fire.

Separately, the carousel's own visual design (`ui/WallpaperCarousel.qml`)
went through two real iterations from the maintainer's feedback, both on the same
comparison-screenshot pattern used throughout this project:
- v1: full-width filmstrip of uniform wide rectangles - "full width of
  horizontal rectangles" - too plain, and too much of the library visible
  at once for a minimalist feel.
- v2: fixed 3-tile clipped viewport, each tile sheared into a parallelogram
  via a `Matrix4x4` transform on the whole tile (image included),
  alternating shear direction per index for a zigzag. Wrong on three counts
  per the maintainer's follow-up: he wanted *vertical* (portrait) tiles, not
  horizontal; *all* tiles leaning the *same* direction, not alternating;
  and critically, shearing the `Matrix4x4` transform on the tile as a whole
  visibly distorted the photo itself, which he explicitly didn't want -
  "you dont have to make the image distorted to the diagonal too. its fine
  for it to be cut off. just showing a glimpse of the wallpaper is enough."
- v3: an accordion of narrow vertical panels, all leaning the same
  diagonal direction. The current (selected) panel's own `width` grows to
  `currentTileW` while every other panel stays `baseTileW` - a real `Row`
  layout reflow (not just an inner-Rectangle visual scale the way v1/v2
  did it), so neighbors genuinely shift to make room, per the maintainer's "the
  irregular rectangle will expand in width... so user can see it better."
  First attempt at keeping the photo undistorted used
  `Qt5Compat.GraphicalEffects`' `OpacityMask`, cropping an ordinary Image
  through a separate sheared `Rectangle` (plain white fill, `visible:
  false`) used purely as an alpha stencil, plus a matching-transform
  bordered `Rectangle` drawn on top tracing the same outline.
- v3 turned out broken, not just imperfect: the maintainer's screenshot showed the
  photo rendering as a plain, uncropped rectangle - `OpacityMask` wasn't
  actually cropping anything - with a mismatched diagonal border floating
  over it, reading as a stray bright line across one corner. Disabling the
  mask shape's `antialiasing` (the standard fix for OpacityMask's classic
  color-fringe-at-the-edge issue) didn't help, because that wasn't the
  actual failure here.
- v4: dropped `OpacityMask`/`Qt5Compat.GraphicalEffects` entirely, no
  shader-based masking at all. The photo stayed a plain, fully undistorted
  `Image`, and the diagonal look instead came from two solid `Theme.bg`
  triangles (`QtQuick.Shapes` `Shape`/`ShapePath`) drawn on top at the two
  corners - a real vector fill/stroke, not an alpha-multiply composite, so
  no edge-blend case to get wrong there. Top-left triangle tapered from
  `shearPx` wide at the top down to a point at the bottom-left corner,
  bottom-right the mirror at the opposite corner; a third `Shape` traced
  that same boundary as a 1px stroke for the border.
- v4 fixed the actual cropping (the photo genuinely followed the diagonal
  this time), but introduced a new problem: "the edge of diagonal looks
  ugly. the line is pixelated instead of smooth diagonal line." Root
  cause: `Shape`'s default renderer (`GeometryRenderer`) triangulates
  paths and relies on multisampling for smooth edges - a raw layer-shell
  `PanelWindow` surface doesn't have MSAA the way a normal windowed
  surface might. `Shape.preferredRendererType: Shape.CurveRenderer` (a
  renderer that antialiases without needing MSAA) would have been the
  fix, but never got applied - the maintainer called a stop on the whole diagonal
  approach at this point instead of chasing a fourth iteration:
  "nevermind, rather than making this hard, can you just do this" with a
  reference image.
- v5 (current): the reference showed something much simpler than any of
  v2-v4 had been reaching for - a plain accordion of thin, straight,
  un-sheared vertical strips (no diagonal cut anywhere), the current one
  widening into a clean bordered rectangle. Matches that directly:
  `baseTileW: 30` (thin sliver) up to `currentTileW: 320` (wide, full
  image visible) on selection, `gap: 6` (tight, strips nearly touching),
  ordinary `Image` + a plain bordered `Rectangle`, nothing sheared or
  masked. `strip.width` fixed at `1500` (not a formula tied to a specific
  visible tile count) so however many thin strips fit at once is however
  many show, sliding as the selection moves - matches the reference's
  wide fan rather than the earlier "exactly 3 tiles" framing. Net result:
  three real implementation attempts (`Matrix4x4` shear, `OpacityMask`,
  `Shape` corner covers) all had genuine bugs before landing on something
  with no masking/shearing machinery at all - worth remembering next time
  a "diagonal cut" visual comes up as a request, since the plain-strips
  reference here turned out to be what was actually wanted regardless.
- The three-tile viewport centering math (kept through v3-v5): since only
  the current tile's width varies and every other tile is uniformly
  `baseTileW`, the offset to the selected tile simplifies to `root.sel *
  (baseTileW + gap) + currentTileW/2` rather than needing per-tile width
  lookups.
- Two small follow-ups after v5 landed: the header (WALLPAPER label/
  counter) and statusline (keyboard hints) text sat directly on the main
  0.62-opacity scrim with nothing behind them - fine against a dark
  wallpaper, unreadable against a bright one. Both now sit on their own
  `Theme.bg`-backed, bordered panel (`opacity: 0.75`), sized off the
  wrapped `ColumnLayout`/`RowLayout`'s own `implicitWidth`/`implicitHeight`
  rather than a hand-picked fixed size. Also dropped the per-tile filename
  caption under the current tile entirely - the maintainer: "hide the filename too
  below the wallpaper."

## INBOX history dropped notification actions entirely

The maintainer: a `cachy-update` notification had an action he should be able to
interact with, but couldn't click it in the expanded dashboard's INBOX.
Root cause, not a rendering bug: `services/Notifs.qml`'s `onNotification`
handler builds each history entry from a fixed subset of fields (`id,
appName, title, body, time`) and never kept the notification's `actions`
at all - the INBOX delegate (`pages/MediaExpanded.qml`) had nothing to
render a button for even if it wanted to. `pages/NotificationPeek.qml`
(the transient popup) already had the real pattern for this - a `Row` of
bordered pill `Rectangle`s over `Repeater { model: n.actions }`, each with
a `TapHandler` calling `modelData.invoke()` - it just never got carried
over to the persisted history view.

Fixed by keeping `actions: notification.actions || []` as a LIVE
reference on the history entry (not copied primitives the way the other
fields are) - `notification.tracked = true`, already set on the line
above for an unrelated reason (keeping the object alive at all so the
history snapshot doesn't reference something already destroyed), is
exactly what also keeps these actions invokable long after the peek
transient that first showed them is gone. Mirrored
`NotificationPeek.qml`'s action-pill UI and its
`TapHandler.ReleaseWithinBounds` gesture policy (an exclusive grab,
needed so an action tap doesn't also fire some ancestor's dismiss
handler - see that file's own comment) into the INBOX delegate.

Real, unavoidable tradeoff surfaced by this fix: `Notifs.history` is
plain in-memory state, `property var history: []`, no `FileView`
persistence the way `widgets.json`/`wallpaper-state.json` have - a shell
restart (needed to load ANY code change here, same as everywhere else in
this project) wipes the whole history, not just this fix's new field.
Confirmed with the maintainer before restarting rather than silently losing his
actual pending `cachy-update` notification.

## Settings island screen: sidebar of category bubbles, Audio first

The maintainer wants a way to reach OS-style audio settings from the expanded
dashboard - his own term for it going forward, "the island screen." Not a
one-off Audio Settings page: a general **Settings** island screen reached
by a new gear button, with a **left sidebar of icon bubbles** (Android-
style, more categories later), Audio being the first (and only, for now).
Opens with a real slide-right + back button, not the plain crossfade
every other page transition in this app uses. Planned via `EnterPlanMode`
given the real architectural surface (a genuinely new transition
capability, not just reuse) - full plan at the time:
`/home/deprecated/.claude/plans/wondrous-nibbling-eagle.md`.

Almost everything needed already existed, just unused:
- Page navigation is already fully generic (`signal requestExpand(string
  pageId)`, `ui/Capsule.qml`'s `Connections` handling whichever page is
  current) - a new page is 2 lines of `pageMap` registration plus a
  button calling `root.requestExpand("SettingsExpanded")`.
- `Quickshell.Services.Pipewire`'s `Pipewire.nodes` already exposes every
  device AND per-app stream (`.type` bitflags tell them apart),
  `Pipewire.preferredDefaultAudioSink`/`Source` are **writable** (the
  actual device switcher), and `services/Audio.qml` already had the real
  gotcha documented (`PwObjectTracker` needed before `.audio` populates).

The one genuinely new piece: `ui/PageHost.qml`'s two-slot crossfade was
the ONLY transition, hardcoded identical for every page switch (opacity +
a 4px vertical rise). Added a `direction` param to `setPage()` (default
`"fade"`, every existing call site unchanged), a `riseX` alongside the
existing `riseY` on both Loader slots, and `"pushRight"`/`"popLeft"`
variants that slide by each item's own `implicitWidth` (not a fixed theme
constant, so it's correct regardless of how wide Settings ends up vs.
MediaExpanded). Direction logic itself lives in `ui/Capsule.qml` (the
actual page registry), not inside `PageHost` - a `directionFor(next,
prev)` helper, so `PageHost` stays a fully generic slide/fade host that
doesn't know any page's name.

### Three real bugs, all refuter-caught, none of which showed up in lint,
### headless launch, or exercising both page transitions via IPC

1. **`services/Audio.qml`'s node filters were structurally wrong, not
   just imprecise.** Written as `(n.type & PwNodeType.AudioSink) !== 0`
   ("any bit overlaps") instead of mask-equality. `PwNodeType` composites
   share bits - every audio node has the `Audio` bit set, so `!== 0`
   matched almost everything against almost every mask. Refuter verified
   the real enum values live (`Audio=1, Stream=4, Sink=16, Source=8,
   AudioSink=17, AudioSource=9, AudioOutStream=21, AudioInStream=13`) and
   confirmed `sinks` was literally "every audio node" - the OUTPUT list
   would have shown microphones and app streams alongside real output
   devices, and tapping one would call `Audio.setDefaultSink()` on
   whatever got clicked, including a microphone. Fixed with `(n.type & X)
   === X` (all bits of X present) plus a `Stream`-bit exclusion for
   sinks/sources specifically. This is exactly why "the page loads and
   renders without a QML runtime error" is necessary but not sufficient
   verification - a filter matching the wrong objects doesn't throw
   anything, it just quietly returns the wrong list.
2. **`app/Bridges.qml`'s OSD-suppression guard wasn't extended to the new
   page, reintroducing a bug its own comment already documents being
   caught once before.** `if (Island.isExpanded && Island.expandedPage
   === "MediaExpanded") return` - narrowly matched only MediaExpanded, so
   adjusting the new Audio panel's volume slider fired a real OSD
   transient anyway, whose priority-40 clear of the expanded gate morphs
   the whole dashboard down to the 320x58 OSD pill mid-drag, the slider
   vanishing from under the cursor - verbatim the original bug, just
   reachable from a second page now. Fixed by generalizing to plain
   `Island.isExpanded` (both the volume and brightness copies) instead of
   enumerating page names one at a time - whatever expanded page comes
   next inherits the fix for free.
3. **`ui/Capsule.qml`'s `directionFor()` only tested one side of the
   transition pair**, so `prev === "SettingsExpanded"` matched ANY
   departure from Settings, not just the return to MediaExpanded - the
   auto-collapse-to-pill timer, or a transient popping over an open
   Settings screen, both got a spurious slide instead of the correct
   fade. Fixed by requiring both `next`/`prev` match the exact
   MediaExpanded<->SettingsExpanded pair before returning a slide
   direction, `"fade"` for everything else.

Also worth remembering: `PwNode.audio` is `isPropertyConstant: true` (no
notify signal, never transitions null -> non-null after creation) -
a defensive `if (node.audio)` guard in `SettingsAudioPanel.qml` is about a
genuinely non-audio node slipping through a bad filter (see bug 1 above),
not about timing. What actually needs `PwObjectTracker` is `.audio.volume`/
`.audio.muted` themselves (`volumesChanged`/`mutedChanged` ARE notifiable)
- got this backwards in the panel's own comment initially, refuter caught it.

## Settings push/pop: from "crossfade with sideways motion" to a real stack push

The maintainer, after seeing the first version: "is it possible to make the
animation going to the settings island screen, like android/ios stack
screen animation when opening new app or something?" The pushRight/
popLeft transition (`ui/PageHost.qml`) had genuinely been a crossfade
with `riseX` bolted on - both pages still faded through partial opacity,
the incoming page's motion still started `Motion.fadeInDelay` (60ms)
after the outgoing page's, and the outgoing page traveled the exact same
full-width distance as the incoming one. None of that is how a real OS
stack push looks: it's solid front to back (nothing ever partially
transparent), both pages start moving in the same instant, and the page
being covered only shifts a fraction of its own width underneath the one
covering it (iOS's own UINavigationController push convention is close to
30%) rather than moving in lockstep.

Fixed by branching the four crossfade parameters (`outgoingTargetOpacity`,
`outgoingTargetY`, `outgoingTargetX`, `incomingDelay` - all now bindable
per-transition instead of hardcoded) on `isSlide = direction ===
"pushRight" || direction === "popLeft"`: opacity stays pinned at 1
throughout for a slide (no animation at all, not even 1->1 - the incoming
loader's `opacity` is set to `1` directly before the crossfade starts,
same for the outgoing target), `riseY` stays 0 (purely horizontal, no
vertical fadeUp nudge), `incomingDelay` drops to 0 (both pages'
`ParallelAnimation`s start together - the delay only ever existed to hide
a fade's transparent gap, and nothing here is ever transparent), and the
outgoing page's `riseX` target is scaled by a new `Motion.pushParallax`
(0.3) instead of traveling the full `outgoingW`. The plain "fade" case
(every other page transition in the app) is untouched - all four
properties default to their original hardcoded values.

## Settings push/pop, take 3: dropped the "real stack push" for a small spring nudge

The previous entry's "real OS stack push" (solid, no fade, full-width
travel, 0.3 parallax on the outgoing page) got a direct verdict once
The maintainer actually saw it live: "hm the animation isnt, looks ugly. do you
have any animation idea that matches our theme kuro though?" Asked him to
choose a direction (restrained slide / hairline wipe reveal / plain fade,
no slide) rather than guessing again - every visual iteration this
session that shipped without checking first needed at least one more
round anyway. He picked restrained slide.

Landed on something much closer to the original crossfade than to a
phone-UI push: opacity fade and the existing 4px vertical `riseY` both
came back exactly as they were before pushRight/popLeft ever existed (no
more `isSlide` branching on them at all), and the only thing that still
distinguishes a push/pop from a plain fade is a small **fixed-pixel**
`riseX` nudge (`Motion.pushSlideDistance: 32`, not a fraction of the
page's own ~700px width the way the previous two attempts computed it) -
the same fadeRise-scale magnitude philosophy applied to a second axis.
`riseX` specifically uses `SpringAnimation` (`Motion.morphSpring`/
`morphDamping`/`morphMass` - the exact same three values
`theme/MorphAnimation.qml` already applies to the capsule's own width/
height/radius `Behavior`) instead of the fade's `NumberAnimation`+bezier
curve, so the one thing that IS still direction-dependent settles rather
than glides, reading as the same object language as the rest of the app
instead of an imported one.

Real uncertainty worth flagging for later: `SpringAnimation` had only
ever been used in this codebase as a `Behavior` (continuous, implicit,
triggered by a property changing) before this - here it's a one-shot
animation element living inside `ParallelAnimation`/`SequentialAnimation`
alongside ordinary `NumberAnimation`s, participating in the SAME group's
`onFinished` (which is what actually clears the outgoing slot's
`sourceComponent`). This is documented/supported QtQuick behavior, not
guessed, but hadn't been exercised in this specific way here before.
Stress-tested 3 rapid push/pop cycles via IPC against the live process
with no errors and no leaked/stuck slot, which is reasonable confidence
but not the same as watching it settle live - if a future push/pop ever
looks like it "hangs" mid-animation or the outgoing page never actually
disappears, this coordination is the first place to look.

## Fuzzel prompt renamed, corner placement ruled out

The maintainer wanted the fuzzel prompt moved to a bottom-right corner "like a
trademark" and renamed from `//kuro.` to `//kuroshima`. Checked fuzzel
1.15.0's own `fuzzel.ini` man page rather than trusting the earlier
"can't pin text to a corner" note at face value - still true: `prompt`/
`placeholder`/`message` are the only text slots fuzzel has, all tied to
the input line, no canvas/watermark feature exists. Renamed in place
(the only real option); corner placement stays out of reach without
switching off fuzzel entirely, which wasn't asked for.

## Real crash: INBOX action pills held dangling QObject pointers, reverted

The earlier "INBOX notifications dropping actions" fix (services/Notifs.qml
keeping a live `actions: notification.actions || []` reference per history
entry) crashed the whole shell - a real segfault, not a QML warning.
Reported live: "i saw a bug, when the notification bell shown in the
compact, and when i opened, it shows quickshell crashed prompt." Confirmed
via `/home/deprecated/.cache/quickshell/crashes/` - 3 separate crash
reports, all `Signal: Segmentation fault (11)`, all on this shell config,
stack rooted in `QV4::VariantAssociationPrototype::fromQVariantMap` /
`QQmlVMEMetaObject::writeKnownVarProperty` during a `TapHandler`-triggered
`QQuickLoader`/`QQmlComponent::create` chain - i.e. a property being
initialized during component creation from a value the QML engine
couldn't safely handle. `pages/CompactPage.qml`'s bell icon
(`Notifs.history.length > 0`) taps into `requestExpand("MediaExpanded")`
like the rest of the pill; MediaExpanded's INBOX `ListView` is what
actually creates the delegate that crashed.

Root cause: the earlier fix's own reasoning was wrong. `notification.
tracked = true` only stops Quickshell's OWN automatic expiry - it does
nothing to `app/Bridges.qml`'s explicit `n.expire()`/`n.dismiss()` calls,
which fire for essentially every notification within seconds of its peek
ending (`Island.onTransientEnded`, by design - see that file's own
comment on why: an untracked notification would otherwise never close,
hanging any sender waiting on `NotificationClosed`, e.g. `notify-send
--wait`). Those calls destroy the underlying `Notification` C++ object,
and its `.actions` (`NotificationAction` objects) get destroyed with it.
A `history` entry holding onto one of those past that point is a
dangling pointer, not "still invokable later" - accessing it (reading
`.text`, binding a `Repeater` delegate to it) is undefined behavior, and
in this Qt 6.11.2 build that meant a segfault, not a graceful null.

This isn't a timing edge case to guard against - it's the *normal* case.
By the time anyone would realistically open the INBOX to look at past
notifications, the notification that prompted opening it has almost
certainly already been destroyed; the only window where its actions are
genuinely safe to invoke is the transient peek itself
(`pages/NotificationPeek.qml`, which already has real action-pill
rendering and was never broken - it only ever touches a notification
while it's still the one actively showing). Reverted `services/
Notifs.qml` and the INBOX delegate in `pages/MediaExpanded.qml` back to
their original display-only shape rather than trying to track
liveness/guard against the dangling pointer - the feature this was
supposed to enable ("act on a notification from history, after its
peek already scrolled past") isn't reliably achievable given this app's
own notification lifecycle, matching how most desktop notification
systems already treat history as read-only.

Verified the fix by actually reproducing the crash scenario twice, not
just re-running lint/headless (which had passed both times *before* the
crash too - the bug never showed up in that class of check at all,
matching the crash trace exactly: a segfault deep in the QML engine
during real component creation isn't the kind of thing a
syntax/type-level lint pass or a clean headless boot log would ever
catch): sent a real D-Bus notification with an action via `notify-send`,
waited for its 5s peek to time out and get destroyed by `Bridges.qml`,
then opened the INBOX via IPC. Before the fix this crashed the live
process 3 times; after, confirmed clean across two full round-trips with
zero new entries in `~/.cache/quickshell/crashes/`.

## NotificationPeek showed "Activate" instead of the actual message

Reported live: "whatsapp web from firefox showing activate button
instead of the message." Root cause: `pages/NotificationPeek.qml`'s
`hasActions` was just `n.actions.length > 0`, and whenever true it hid
the body text entirely in favor of rendering every action as a button.
Per the freedesktop Desktop Notifications spec, an action with
`identifier === "default"` is reserved to mean "invoke this when the
notification body itself is clicked" - it's conventionally never
rendered as its own visible button. Firefox relays a web page's
notification click handler (WhatsApp Web included) as exactly one
action with that identifier, so this page treated it as a real,
nameable action, showed its label ("Activate") as the only visible
content, and hid the actual message underneath it - for every single-
default-action notification, not just WhatsApp's.

Fixed by splitting `n.actions` into `_realActions` (identifier !==
"default", what actually renders as buttons and drives `hasActions`)
and `_defaultAction` (the one, if present, invoked when the body itself
is tapped instead of just calling `dismiss()`) - matching the spec's
actual click-to-activate convention rather than just hiding it. `Notification
Action.identifier` confirmed via Quickshell's own `.qmltypes` before
use, not guessed.

Verified via `notify-send --action="default=Activate"` (reproducing
Firefox's exact pattern) against the live process - no crash, no lint/
headless regressions - but couldn't visually confirm the peek now shows
the real message text instead of the button, since this session has no
way to see the rendered screen; needs a live look to fully close out.

## NotificationPeek: fixed height -> content-driven

Haziq: "also the notification i feel like you hardcoded the height isnt?
shouldnt it dynamic height? because i want it to be as compact as it can."
Correct - `implicitHeight: Theme.notificationH` was a flat 100px
regardless of actual content, and since the icon/text column were only
`anchors.verticalCenter`'d within that fixed-height Row (not what was
sizing it), most notifications sat inside real dead space above and
below their own content.

Changed to `Math.max(iconBox.height, contentCol.implicitHeight) + 28`
(the 28 being the Row's own `anchors.margins: 14` top+bottom) - the peek
is only ever as tall as its icon or its text column actually needs, plus
that margin, nothing fixed. `Theme.notificationH` removed from
`theme/Theme.qml` entirely now that nothing reads it. Verified with both
an action-less and an action-having notification live (different content
heights) - no crash, no lint/headless regressions either way; couldn't
visually confirm the sizing itself reads as "compact" rather than just
"not fixed" since this session has no way to see the rendered screen.

## MediaExpanded: fixed page height -> content-derived, same class of fix as NotificationPeek

Haziq, from a screenshot showing a large dead gap between 06 INBOX (only
2 short notifications) and the 07 SESSION footer row: "nice but now the
inbox section in expanded height is like bigger now that it is more
than the content height." Same underlying pattern as NotificationPeek's
fixed-100px fix just before this - `implicitHeight: Theme.expandedH`
was a flat 650px regardless of actual content, and NOTES.md's own
earlier history shows this exact constant already got hand-retuned 3
times (604 -> 660 -> 682 -> 650) chasing content shape changes rather
than ever just being derived.

Real wrinkle here `sessionFooter` (07 SESSION) was deliberately anchored
to the PAGE's bottom, independent of `builtSections`' own top-down
Column, specifically because a short/hidden INBOX previously left it
floating right under 05 SYSTEM with a dead gap *below* it instead - a
real problem that fix solved, just by relocating where the dead space
showed up (between INBOX and SESSION) rather than removing it. Once
root's `implicitHeight` is computed from content instead of fixed
(`18 + builtSections.height + 16 + sessionFooter.height + 18`), that
leftover space doesn't exist in the first place - `sessionFooter` just
went back to being anchored directly below `builtSections.bottom` (a
plain 16px gap, same rhythm as gaps between sections inside
`builtSections` itself), no space left over for it to be dislocated
into.

Side effect, noted in `pages/SettingsExpanded.qml`'s own comment:
`Theme.expandedH` still exists (kept, other pages read it, e.g.
`SettingsExpanded` for its own fixed footprint) but MediaExpanded no
longer always equals it - an unusually short or tall MediaExpanded
state can now make the push/pop slide's height not match Settings'
height exactly, adding a small vertical morph alongside the horizontal
slide. Not worth chasing - width (the dominant axis for how a
horizontal push reads) still always matches.

Verified via IPC round-trips (expand MediaExpanded, expand
SettingsExpanded, collapse) against the live process - no errors, no
lint/headless regressions - but same caveat as the NotificationPeek fix:
couldn't visually confirm the gap is actually gone, only that nothing
broke computing the new height. Needs a live look.

## Island Faces: swipeable compact-pill content, first build

Idea first noted 2026-09-19 (compact/idle pill showing several swipeable
"faces" instead of one fixed layout), picked up 2026-09-20. Naming going
forward: **Island Faces** = content inside the *compact* pill,
**Island Screen** = content inside the *expanded* dashboard (MediaExpanded,
SettingsExpanded).

Architecture reused almost everything: `ui/PageHost.qml` (the same generic
two-slot crossfade/slide host `ui/Capsule.qml` already uses for real pages)
gets a SECOND, independent instance nested inside `pages/CompactPage.qml`
for faces, with its own tiny `pageMap` of 3 starter faces
(`faces/ClockEq.qml` - today's original default content, byte-for-byte;
`faces/ClockDate.qml`; `faces/MediaFace.qml` - real title/artist, the
highest-value new face from the original idea list). Zero new animation
code - the existing `pushRight`/`popLeft` spring-nudge mechanics apply
directly. `app/Island.qml` gets a new `compactFace` property plus a second
`PersistentProperties` block, mirroring the existing `expandedPage` pattern
exactly. A new `DragHandler` (`target: null`, matching `ui/ScrubBar.qml`'s
own idiom) detects swipe direction only - no live-follow drag preview for
v1, purely a direction detector like `ui/WallpaperCarousel.qml`'s own
Left/Right keys.

### Two real bugs caught before it ever ran, by lint/headless alone

Neither showed up until an actual headless boot, both fixed same pass:
- Missing `import qs.app` in `pages/CompactPage.qml` - referencing `Island`
  without importing its module threw `ReferenceError: Island is not
  defined` at runtime, not a lint-time error.
- `ui/PageHost.qml` unconditionally assigns `.payload` on whatever it
  loads (matching the page contract it was actually built for) - the
  faces originally had no `payload` property at all (matching the WIDGET
  contract's shape instead, which was the original design intent), and
  PageHost threw `Error: Cannot assign to non-existent property "payload"`
  the moment it tried to load one. Fixed by giving each face an unused
  `property var payload: null` purely to satisfy the host mechanically -
  same "declared but unused" precedent `pages/MediaExpanded.qml` already
  sets for a page that doesn't need one either. Updated `CLAUDE.md`'s own
  Face contract section to say so honestly rather than leave the
  originally-planned "no payload" claim standing.

### refuter found a real permanent-breakage bug, plus caught a wrong claim of mine

**The bug**: if `Island.compactFace` ever holds a value that isn't in
`pages/CompactPage.qml`'s own `faceOrder` array (a typo'd `ipc call island
setCompactFace <bad-id>`, or a face id renamed out from under a value that
survived a hot reload), `facesHost.setPage()` already rejects it safely -
but that alone leaves `Island.compactFace` permanently desynced from what's
actually showing, and `faceOrder.indexOf()` then returns -1 forever,
silently killing every future swipe in BOTH directions until a full
process restart. Confirmed via refuter's own qmltestrunner harness against
the real `ui/PageHost.qml`, not just read through the code. Fixed with a
`_syncFaceHost()` guard: if the wanted face isn't in `faceOrder`, self-heal
back to the default (`Island.setCompactFace(faceOrder[0])`) rather than
ever calling `setPage()` with a bad id at all - the reassignment
re-triggers the same function via the existing `Connections`, settling in
one extra round-trip. Verified live: sent a bogus face id via IPC, then a
real one - no "PageHost: unknown page" warning ever appeared in the log at
all (confirming the guard caught it *before* it ever reached PageHost),
and the next real face switch worked normally afterward.

**The wrong claim**: earlier in this same build, "verified persistence
across a real process restart" was reported after restarting and seeing
no crash - but that's not what was actually verified. Quickshell's
`PersistentProperties` is reload-scoped, not disk-backed (confirmed by
refuter reading its own `.qmltypes`: `prototype: "Reloadable"`, only
`loaded`/`reloaded` signals, no on-disk state file anywhere on this
machine) - it survives `scripts/dev.sh`'s live hot-reload, not a genuine
`kill` + relaunch. After a real restart, `compactFace` (like `expandedPage`
already does today, same mechanism) resets to its declared default. No
crash after a restart proved the mechanism doesn't error, not that a
non-default face actually survived - those are different claims, and the
second one was asserted without actually being able to see the screen to
check. If real cross-*session* persistence is ever wanted, that needs a
`FileView`-backed JSON file (the pattern `services/Wallpaper.qml`/
`services/Widgets.qml` already use for their own state) - out of scope
for this pass, not added speculatively.

### What's still genuinely unverified

The DRAG GESTURE itself - there's no way to simulate a mouse/touch drag
over IPC. Everything about the underlying mechanism (face switching,
self-heal, capsule resize) is verified via the `setCompactFace` IPC hook
and a real headless/live process; whether the swipe actually *feels*
right needs a live hands-on test. refuter's own harness measured the
effective swipe distance at closer to ~48px than the
`Motion.compactFaceSwipeThreshold: 40` constant implies (Qt's own built-in
~8-10px drag threshold has to clear before `DragHandler.active` even
becomes true, before this project's own 40px on top of that even starts
counting) - worth knowing before deciding it feels too stiff or too
trigger-happy.

## Correction: the lockscreen idea below was already shipped elsewhere

The entry directly below this one was written earlier the same session, on
the wrong assumption that no session-lock work existed anywhere in this
project family yet - a reasonable belief at the time (this repo's own
`shell.qml`/`pages/`/`services/` were the only things checked), but wrong.
`~/Projects/niri-lockscreen` already existed, already shipped through Slice
5 (real `WlSessionLock`, real PAM auth via `PamContext`, idle- and
suspend-triggered locking, a proven crash self-heal ritual), and was already
installed and running on the real host session. Both "open questions" listed
below were already answered in that shipped code before this note was ever
written. `refuter` caught this contradiction directly: the notifications IPC
bridge added to this file's own `shell.qml` in this same session exists
specifically to feed niri-lockscreen's "WHILE AWAY" panel - one file
describing that project as a live consumer, the other describing it as an
unstarted idea, in the same diff.

What actually happened once this was discovered: the mockup below became the
target for a real visual redesign of niri-lockscreen itself (its own
`docs/HANDOFF.md` has the full build), not new work in this repo. Kept below
for the mockup's own design reference value (colors, states, motion timings
are all still accurate to what was built), not as a live TODO.

## (historical, corrected above) Idea for a future slice: real session lockscreen

The maintainer, 2026-09-20: brought a full interactive mockup built in Claude
Design (`~/Downloads/Linux Lockscreen/Lockscreen.dc.html`, plus reference
images under its `uploads/`) as the target design for a real lockscreen.

What the mockup specifies (reference only - see niri-lockscreen's own
`docs/HANDOFF.md` for what actually got built):
- **Surface**: true `#000000`, deliberately darker than the rest of the
  shell's near-black. Clock centered (108px/500/-0.035em), a square (not
  capsule) 380x44 "AUTH" field below it - explicitly "the island owns round;
  the lock plate is a terminal field." Session/battery chrome top corners,
  CAPS/layout/attempts bottom-left, power actions (lock out / sleep / power)
  bottom-right. MPRIS now-playing panel left (read-only transport, no
  volume), notifications panel right - titles show, bodies dithered-hidden
  by default behind a REVEAL CONTENT toggle.
- **States**: RESTING -> TYPING -> CHECKING -> DENIED or GRANTED -> IDLE/OFF
  after 45s idle (everything but clock+battery fades to `#3a3a3a`). No
  spinner anywhere - CHECKING is a single 2px dither bar creeping along the
  field's bottom edge in 9 steps. DENIED: border+label to `#d75f5f`, 380ms
  shake, field clears; 5 failures freezes input 30s, counter always visible.
  GRANTED: 180ms hold, then the plate dither-dissolves and the island drops
  in from above (520ms spring) as the handoff.
- **Signature texture**: one 8x8px dithered square per typed password
  character instead of bullet dots - matches the halftone/dither accent this
  project already leans on elsewhere (see the wallpaper carousel, and
  `ryoku.dev` as the house reference).
- **Named data sources**: PAM via a helper process for auth, Mpris
  (read-only), `NotificationServer` (buffered), `wl_keyboard` modifiers for
  caps/layout, logind + UPower for power actions.
- **Stated rules worth keeping literally**: "the island never draws on the
  lock surface, this is its own surface, same vocabulary" - and "one plate,
  one clock, one user, no user switcher, no session list."

Both "open questions" originally listed here were already resolved in
niri-lockscreen's own shipped code before this note was written: Quickshell
does expose `ext-session-lock-v1` (`Quickshell.Wayland.WlSessionLock`,
confirmed present in the installed QML modules), and PAM auth works directly
from QML via `Quickshell.Services.Pam.PamContext` - no privileged helper
binary needed, contrary to what this note originally guessed. See the
correction above.

## Media Island Face: from title/artist text to a real player, plus a real MediaPeek upgrade

The maintainer, live-iterating against the real hot-reloading `qs -c kuroshima`
process (see niri-lockscreen's own docs/HANDOFF.md for the same discovery in that
sibling repo - this project's `-c` install turns out to hot-reload too, at least
for ordinary QML changes, not just new top-level IpcHandler registrations):
brought a reference screenshot of a media-player notch layout and asked for
`faces/MediaFace.qml` (one of the three swappable Island Faces) to grow from
plain title/artist text into something that actually looks like a player -
thumbnail left, title/artist/progress/transport on the right, an equalizer at
the trailing edge.

**Reuse, not new risk**: real album art (`Media.artUrl`) via the exact
`ClippingRectangle` + `Image` squircle pattern `pages/MediaExpanded.qml`
already uses, and `ui/EqualizerBars.qml` - this project's own already-shipped
Canvas-based ordered-dither EQ glyph - reused as-is for the equalizer, not a
new dithering attempt (the sibling niri-lockscreen project hit a real
unresolved ShaderEffect bug the same day trying exactly that; this component
uses a completely different, already-proven technique - a plain 2D Canvas
`fillRect` loop against a Bayer matrix, not a GLSL shader - and was never at
risk of that bug).

**`pages/CompactPage.qml`'s own `implicitHeight`** changed from a hardcoded
`Theme.compactH` to `content.implicitHeight`, tracking whichever face is
active via `ui/PageHost.qml`'s already-existing `targetHeight` binding - no
new plumbing needed there. `ui/Capsule.qml`'s own `animatedWidth`/
`animatedHeight` are continuously `Behavior`-bound to the host's target size
(refuter corrected an early comment here that called this a "page-swap
morph" - it's not discrete, it's continuous, which is also what makes a
live `Media.available` flip mid-face resize smoothly instead of leaving a
stale capsule size behind), so a taller face grows/shrinks the whole pill
for free, already proven for MediaExpanded<->SettingsExpanded.

**Iterated live against real feedback**, not a one-shot build - three real
rounds:
1. Initial build: content read as too small, and "nothing playing" had
   shrunk shorter than the original pill (root's height stopped being a
   fixed `Theme.compactH` once it became content-derived). Fixed: bigger
   art/fonts/spacing throughout the playing state, and the idle fallback
   pinned back to exactly `Theme.compactH` via an explicit height, not just
   the text's own implicit size.
2. "the top is near the edge" - the playing state's content sat flush
   against the pill's rounded top/bottom edges once it grew taller. Fixed:
   `Media.available ? content.height + 24 : content.height`, split evenly
   top/bottom by the existing `anchors.centerIn` - the idle state
   deliberately gets none of this padding, staying exactly compactH.
3. **refuter MUST-FIX, a real bug**: tapping the new prev/pause/next
   buttons also fired `pages/CompactPage.qml`'s own root
   `TapHandler` (anywhere-on-the-pill -> `requestExpand("MediaExpanded")`),
   since a plain default-policy `TapHandler` only takes a PASSIVE grab,
   which doesn't stop an ancestor handler from also firing for the same
   tap - so pressing pause also expanded the whole dashboard. This exact
   trap is already documented in `pages/NotificationPeek.qml`'s own action
   buttons, for the identical reason; missed here because this page's root
   tap handler lives one file away (`CompactPage.qml`), not obviously in
   view while writing the face. Fixed: `gesturePolicy:
   TapHandler.ReleaseWithinBounds` on all three transport TapHandlers,
   verified against the exact fix in a dedicated QtTest harness before
   landing it. Also wrapped each glyph in a proper 22-24px hit-target
   `Item` (refuter measured the bare `Text` glyphs alone at ~10x20px,
   fiddly to tap, against `MediaExpanded.qml`'s own 24x24/26x26 precedent
   for the same three buttons).

**Also upgraded in the same pass**: `pages/MediaPeek.qml` (the transient
popup that fires on `Media.trackChanged()`, separate from the Island Face)
had the identical "no real art" gap - `payload.artUrl` was already being
passed in from `app/Bridges.qml`, just never actually rendered, so it
always showed a flat gray placeholder swatch regardless of whether real art
existed. Fixed the same way, plus added the same trailing-edge
`EqualizerBars`. The maintainer's original idea was actually to swap this
peek for the full `MediaExpanded` dashboard on every track change - talked
through the tradeoff first (a full 700x650 dashboard auto-popping on every
track change, several times a session, breaks the whole "peek" contract of
being brief and non-blocking, and fights the same `Island.isExpanded` guard
`app/Bridges.qml` already has for the volume/brightness OSDs) - the
maintainer agreed and went with the smaller, lower-risk upgrade instead.

**Known, deliberately not fixed this pass**: `ui/IslandWindow.qml`'s
`exclusiveZone` still reserves a fixed `Theme.compactH` height regardless of
which face is showing - refuter flagged that the media face now makes the
pill ~113px tall while idle-parked on it (Island Faces persist via
`PersistentProperties`, so this isn't transient), meaning windows below can
sit up to ~73px under the pill's real bounds. Visual only (`mask: Region {
item: capsule }` already makes the pill click-through, confirmed clicks
still reach what's underneath) - not fixed here since it'd mean making the
window's own reserved-space calculation dynamic, a bigger, separate change
from this face's own content.

## App launcher: replacing fuzzel entirely

Haziq wanted `Mod+Space` to stop spawning fuzzel (a visually disconnected
centered popup) and open something that reads as part of the island itself
instead - search bar on top, apps below in a horizontally-scrollable row,
`//KUROSHIMA` corner mark. Explicitly not an Island Face (those live inside
the idle compact pill and are reached by swiping).

**Real architecture, corrected**: this went through two shapes in the same
build. First built as its own separate overlay window - a direct port of
`ui/WallpaperCarousel.qml`'s shape (own `PanelWindow`, `WlrLayer.Overlay`,
`WlrKeyboardFocus.Exclusive` only while mapped, `toggle()`/`_open()`/
`_cancel()`). That version worked, but was purely static - no morph
animation opening or closing. Haziq caught it live ("no morph animation at
all. very static... that thing should be apart of the island... so
basically it is inside the island") and asked for it to become a real page
instead. **What actually shipped**: `ui/AppLauncher.qml` is a plain `Item`
page in `ui/Capsule.qml`'s own `pageMap`, reached via
`Island.toggle("AppLauncher")` (`shell.qml`'s new `launcherToggle()`
IpcHandler function, which niri's `Mod+Space` keybind calls instead of
spawning fuzzel) - the same mechanism `MediaExpanded`/`SettingsExpanded`
already use, so it gets `ui/Capsule.qml`'s existing continuous
`animatedWidth`/`animatedHeight`/`animatedRadius` `Behavior` for free, no
new animation code. There is no `PanelWindow`, no `WlrLayer.Overlay`, and no
`toggle()`/`_open()`/`_cancel()` on this file anymore - an earlier version
of this note described the abandoned window version as if it had shipped;
that was wrong, refuter caught it, this is the correction.

The one genuinely new risk this created: `ui/IslandWindow.qml` is the
single, PERMANENTLY-mapped surface hosting the whole capsule - unlike the
carousel's own window (which only exists, and only needs keyboard focus,
while visible), this file's `WlrLayershell.keyboardFocus` had been
hardcoded `WlrKeyboardFocus.None` since the very first slice, and is now
reactive: `Island.page === "AppLauncher" ? WlrKeyboardFocus.Exclusive :
WlrKeyboardFocus.None`. This is a keyboard-interactivity change happening
WHILE the surface stays mapped, not at open/close - this file's own
existing comments already document a real historical niri hang from a
different surface-property change, which is why this got extra scrutiny.
`ui/Capsule.qml`'s existing hover-based auto-collapse
(`shouldAutoCollapse`) also gained a `&& Island.page !== "AppLauncher"`
exemption - every other expanded page is pointer-driven (fine to close once
the cursor leaves), but the launcher is keyboard-driven, typing a query
doesn't keep the cursor over the capsule.

**First real text-search + keyboard-nav + app-launching surface in this
codebase.** No Quickshell module does desktop-entry discovery
(`Bluetooth`/`DBusMenu`/`Hyprland`/`I3`/`Io`/`Networking`/`Services`/
`Wayland`/`Widgets`/`_Window`/`WindowManager`/`X11` - nothing named Apps or
Desktop), so `scripts/list-apps.py` (bundled Python, not hand-rolled QML/JS
parsing of a not-quite-INI format) does the real work: scans
`$XDG_DATA_HOME/applications` then each `$XDG_DATA_DIRS` entry's own
`applications/` dir, in priority order, dedupes by desktop-file ID (user
entries win over system, first-seen wins across dirs, matching the XDG spec's
own precedence rule), skips `NoDisplay=true`/`Hidden=true`, reads only bare
`Name=`/`Icon=`/`Exec=`/`Terminal=` keys (never localized `Name[xx]=`
variants), prints one JSON array. 245 raw `.desktop` files on this machine,
97 real launchable entries after filtering. Run fresh on every launcher open
(`services/Apps.qml`'s `refresh()`), not cached or polled - fast enough that
"always current after installing something new" wins over caching against a
stale list.

`Quickshell.iconPath(entry.icon, true)` (existing precedent,
`pages/NotificationPeek.qml`) resolves real icon theme entries; a hairline
placeholder square (matching `pages/MediaExpanded.qml`'s own art-fallback
convention) shows when one doesn't resolve. `Quickshell.execDetached()`
(existing precedent, `pages/MediaExpanded.qml`'s lock/sleep/power/
workspace-switch buttons) does the actual launch -
`Terminal=true` entries get wrapped in `["kitty", "-e", ...]` (this
project's own established terminal, replacing foot).

### refuter caught 4 real bugs, all fixed and re-verified

1. **A peek could steal keyboard focus mid-type and silently wipe the
   in-progress search.** `Island.page` becomes whatever transient is
   currently showing (`current ? current.page : (expandedPage ||
   "compact")`), and `core/Kinds.qml`'s own priority table lets a
   notification (50) or volume/brightness OSD (40) override ANY expanded
   page whenever `expandedBlockBelow` (40 by default) is at or below their
   priority - normally harmless (every other expanded page just re-renders
   from live services once the peek clears), but two things made it a real
   bug here: `ui/IslandWindow.qml`'s new keyboard-focus binding keys off
   `page` (not `expandedPage`), so it dropped to `None` for the peek's
   whole ~3.2s duration, leaking keystrokes into whatever window was
   underneath; and `ui/PageHost.qml` destroys and recreates the page
   instance on every `page` change, silently wiping the typed query and
   `currentIndex`, which are local state on `ui/AppLauncher.qml` itself
   (unlike every other page, which owns no state worth losing). Verified
   live via `niri msg layers`: opening the launcher then firing a demo
   notification/OSD dropped the real surface's keyboard interactivity to
   `none` for the peek's full duration. Fixed in `app/Island.qml`:
   `expandedBlockBelow: expandedPage === "AppLauncher" ? 999 : 40` - high
   enough that even a notification now queues behind the launcher instead
   of interrupting it, the same as power/media/workspace peeks already do
   for every other expanded page today.
2. **Nothing closed the launcher if the user clicked into a different
   window instead of dismissing it deliberately**, which could leave the
   island holding exclusive keyboard focus indefinitely while typing into
   that other window silently landed in the (invisible, elsewhere) search
   field instead. `ui/IslandWindow.qml`'s `mask: Region { item: capsule }`
   passes every click outside the capsule straight through to whatever's
   underneath (intentional, needed everywhere else), so this page never
   even sees that click to react to it - and the `shouldAutoCollapse`
   exemption above (needed so typing doesn't self-close it) also removed
   the only thing that would have caught this. No Quickshell API exists to
   detect "did the compositor actually move keyboard focus elsewhere", so
   this is bounded with a plain 20s idle timeout instead
   (`ui/AppLauncher.qml`'s `idleTimer`, restarted by any real activity -
   typing, arrow-key nav) rather than solved exactly - it doesn't stop the
   very first stray keystroke from a click-away, but it stops "stuck
   forever" from being possible.
3. **`scripts/list-apps.py` leaked a literal field code into a real launch
   command on this exact machine.** The original `strip_field_codes` only
   dropped tokens that were ENTIRELY a field code - `spotify.desktop`'s own
   `Exec=spotify --uri=%u` survived as `["spotify", "--uri=%u"]`, and
   `Quickshell.execDetached` passes that straight through. Confirmed live
   (Spotify is one of the apps installed here, and this project's whole
   media-face stack is built around exactly this kind of player). Fixed
   with a regex substring strip (`FIELD_CODE_RE.sub("", tok)`) instead of
   whole-token filtering, `%%` protected first so a literal percent sign
   round-trips correctly. Re-ran the script afterward: 0 of the 97 real
   entries contain a literal `%` anywhere in their `exec` array now.
4. **This section itself, and two shipped code comments, described the
   abandoned separate-window version as if it had shipped** - see the
   "Real architecture, corrected" paragraph above. `services/Apps.qml` had
   two matching stale comments: one crediting `AppLauncher`'s own `_open()`
   (that function doesn't exist on the page version), and one citing
   "services/Network.qml's own on-demand-not-timer poll" - there is no
   `services/Network.qml` in this repo at all, that line was copy-pasted
   from writing the sibling niri-lockscreen project's own service of the
   same name. Both corrected to describe the real `Component.onCompleted`-
   driven, no-timer refresh this file actually has.

**Verified live, methodically** in a nested niri sandbox (this repo's own
standing preferred approach): `bash scripts/lint.sh` and `bash
scripts/test.sh` both clean (24/24 tests passing, no new lint categories),
`python3 scripts/list-apps.py` re-run directly against the fixes above,
live `niri msg layers` checks confirming the keyboard-focus grab
transitions correctly through collapse/expand/six-rapid-toggles/a full hot
reload, and confirming the launcher and the wallpaper carousel can both
independently hold `exclusive` focus at once (niri resolves it sanely by
layer, and their identical `Shortcut` sequences never collide since
`Qt.WindowShortcut` context is scoped per-window, not global - each lives
in its own separate window). The one thing that still genuinely needs
Haziq's own hands-on check: typing a query and confirming Left/Right/
Home/End feel right and Enter launches the highlighted result - no way to
verify real keyboard *feel* from a scripted session, only that the
mechanism is wired correctly and not crashing.

**The actual "removing fuzzel" step** lives in a different repo:
`~/Projects/cachyos-setup/kuro/wm/niri/cfg/keybinds.kdl`'s `Mod+Space` line,
repointed from `spawn "fuzzel"` to `spawn-sh "qs -c kuroshima ipc call
island launcherToggle"`. niri live-reloads its config on save (confirmed via
its own journal: "loaded config from ... config.kdl" logged immediately
after the edit, no parse errors) - this is live on the real session now,
not just a sandbox change. `fuzzel` itself (the package, and
`~/.config/fuzzel/fuzzel.ini`) was deliberately left alone, not
uninstalled - only the keybind stopped using it.

## Environment notes worth not rediscovering

- Nested niri IPC (`niri msg`) hangs the whole socket if a client (e.g. `action spawn`)
  is left running/blocked; kill the stray client or restart the nested niri instance,
  don't keep retrying against a wedged socket.
- Quickshell config selection: `qs -p <dir>` runs `<dir>/shell.qml` directly, no need to
  symlink into `~/.config/quickshell/`.
- `pkill -f "qs -c kuroshima"` from a scripting/tool shell can self-match: `-f` matches
  the full command line of every process, including the invoking shell's own argv when
  the search string is literally embedded in the command being run (e.g. `bash -c 'pkill
  -f "qs -c kuroshima"; ...'` - that whole string is the shell's own cmdline too). Kills
  the wrapper instead of the target, silently, with no output. Use `pgrep -x qs` (exact
  binary name, not full args) to find the real PID, then `kill <pid>` by PID instead.
- **Correction to this note's own earlier self**: the real `qs -c kuroshima` process
  DOES hot-reload on file edits, confirmed repeatedly and directly (its own log
  shows "Reloading configuration..." after a save, and live screenshots/behavior
  changes confirm it) - this note originally claimed otherwise. The one real
  exception found: a BRAND NEW top-level `IpcHandler { target: "..." }` block (the
  kuroshima notifications bridge, added for niri-lockscreen) didn't register until
  an actual restart - ordinary property/content/logic edits to files already loaded
  hot-reload fine, adding a wholly new IPC target apparently doesn't. Given this,
  every edit to this repo reaches the real, live desktop session immediately on
  save, not just a sandbox copy - worth remembering as a real risk profile, not just
  a convenience, for anything touching auth-adjacent or keyboard-focus-adjacent code
  (see the app launcher's own `ui/IslandWindow.qml` keyboard-focus change for the
  one case this actually mattered this session).
- `pgrep -x qs` misses the ACTUAL system instance: niri's own autostart
  (`spawn-sh-at-startup "qs -c kuroshima"`) execs into the real binary,
  which shows up as comm name `quickshell`, not `qs` - `qs` is a thin
  dispatcher. Every "restart" this session that only checked `pgrep -x
  qs` was restarting a manually-launched COPY sitting alongside that
  original autostarted process, never touching it - it kept running
  stale code the whole time, invisibly, until it and a later manual
  instance were both alive at once and rendered two full sets of layer
  surfaces (island + wallpaper-bg + widgets), visible on screen as two
  overlapping dynamic islands. Confirmed via `niri msg --json layers`
  (duplicate `"namespace":"kuroshima"` entries) and cross-referencing
  `/run/user/1000/quickshell/by-pid/*` against which PIDs were actually
  alive - `ps -eo pid,cmd | grep -iE "quickshell|qs -c kuroshima"` is
  the check that actually catches every instance, not `pgrep -x qs`
  alone.
- **`niri msg layers`'s own `Keyboard interactivity` field does not reliably
  reflect a live property change** on an already-mapped layer surface - only
  discovered because `ui/AppLauncher.qml` needed exactly this (see that
  section above). Opening the launcher and immediately checking `niri msg
  layers` showed `none` even though `ui/IslandWindow.qml`'s own
  `WlrLayershell.keyboardFocus` binding had genuinely already flipped to
  `Exclusive` - confirmed independently via a temporary `console.log` inside
  that file reading `root.WlrLayershell.keyboardFocus` directly (printed
  `1`, i.e. `Exclusive`, correctly). Reproduced 3 times, including against a
  freshly-launched process, so this isn't a one-off race. If a future
  surface-property-change bug needs verifying, don't trust `niri msg layers`
  alone for it - read the QML-level property back directly (a temporary
  `console.log`/debug `IpcHandler`, same as this session's own approach) for
  ground truth instead.
- A 4th qmllint noise category, alongside the 3 `scripts/lint.sh` already documents:
  `Info: Set "pragma ComponentBehavior: Bound" in order to use IDs from outer
  components in nested components.` Fires for any `Repeater.delegate` (or similar
  inline component) that references an id from its enclosing scope - already 28
  occurrences in this codebase before the wallpaper carousel rework added 10 more.
  Real problems (missing properties, unknown types, typos) still surface distinctly
  from this too.
