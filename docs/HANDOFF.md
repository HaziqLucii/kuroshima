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

**Real UX gap found live by Haziq, fixed same session**: clicking only worked during
`MediaPeek`'s brief ~3s transient window right when a track changes. The now-playing
marquee that's actually visible most of the time lives on `CompactPage`, which had no
click handling at all. Added a `TapHandler` there too (`enabled: Media.available`,
`requestExpand("MediaExpanded")`), so clicking the persistent compact view works, not
just the narrow peek window.

**Transport controls redesigned live, twice, per Haziq's aesthetic direction**: v1 was
plain text labels (PREV/PLAY/NEXT). v2 was a solid white filled circle with a black
play/pause glyph, Haziq's own suggestion, but a filled circle plus solid white breaks
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

Haziq asked for the compact pill's height to be reserved space (tiled windows shouldn't
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
upstream yet (Haziq's call); if revisited, this is the accurate framing to file it with.

**First fix attempt, since superseded**: two separate layer-shell surfaces, an
invisible full-width spacer (`ui/ReservedSpaceWindow.qml`, anchored `top`+`left`+`right`,
doing only the `exclusiveZone` reservation) plus the existing centered `IslandWindow.qml`
(unchanged, rendering the capsule). This sidestepped the hang (confirmed working,
screenshotted), but a second `refuter` pass caught a real regression it introduced,
invisible in the nested-niri sandbox because nothing else there has a top-anchored bar:
Haziq's real session runs `noctalia` with a floating top bar and its own exclusion zone
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
stayed responsive (`niri msg` instant) throughout. Visually confirmed by Haziq: pill
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
*bottom-heavy* despite the equal math. Cause, found by Haziq: **niri's own `gaps`
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
by Claude via a scripting shell, one Haziq had separately running in his own terminal)
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

Deliberately left minimal, confirmed with Haziq: `OsdPeek` shows an icon label + bar, no
percentage readout. Visual polish is explicitly his design-phase work after slice 9, this
slice's job was proving the real PipeWire data path end to end, which it now does.

## Status: Slice 3.5 done (auto-collapse on cursor-away, inserted by Haziq)

Not in the original plan; Haziq asked whether hovering *off* the island for a while
auto-collapses it (symmetric to the earlier hover-to-expand question, also not planned).
Added `theme/Motion.qml`'s `expandCollapseGrace` (1500ms, longer than `hoverGrace` since
an expanded page is something the user is likely reading, not a transient peek) and
`ui/Capsule.qml`'s `shouldAutoCollapse` (`Island.isExpanded && !Island.hovered`) driving
a one-shot `Timer` that calls `Island.collapse()`. View-level, not controller-level, same
reasoning as the slice-1.5 click toggle: this is UI convenience layered on the state
machine, not one of its 8 core rules, so it doesn't belong in `IslandController.qml`.

Verified live: `expand("dummyExpanded")` via IPC with the cursor elsewhere, capsule
auto-collapsed to the compact clock after ~1.5s. Confirmed by Haziq: "very nice, i like it."

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
size: 65536`. This happened live, on Haziq's actual desktop GPU (the nested-niri sandbox
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

## Status: Slice 1.5 done (click-to-morph + spring bounce, inserted by Haziq)

Not in the original plan's slice list; Haziq asked for it directly after seeing slice 1's
smooth morph, wanted to feel a spring/bounce motion and trigger it by clicking the capsule
rather than only via IPC. Two changes:

- `theme/Motion.qml`'s `morph`/`morphEasing` (duration+easing tokens) replaced with
  `morphSpring`/`morphDamping`/`morphMass`. `ui/MorphAnimation.qml` now wraps
  `SpringAnimation`, not `NumberAnimation`: springs have no fixed duration, they
  overshoot and settle based on the three physics params, tuned live with Haziq
  (`spring: 3.5, damping: 0.4, mass: 1.0`).
- `ui/Capsule.qml` has a `TapHandler` that toggles `expanded` and calls
  `setPage("dummyWide"/"compact")` directly. **This is temporary**: slice 3's real click
  contract is a page emitting `requestExpand()`, which the view routes through
  `IslandController.expand()`. Replace this direct toggle when slice 3 wires the
  controller into `Capsule`/`IslandWindow`, don't leave both mechanisms in place.

Confirmed by Haziq: "looks very cool."

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
a fade+scale crossfade, confirmed by Haziq ("morphs really nice"). No corner
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

**IPC gotcha for Haziq specifically**: Quickshell's `ipc call` instance
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
  Haziq: real Dynamic Island doesn't reserve bar space either), `WlrLayershell`
  namespace/layer/keyboardFocus set, `mask: Region { item: capsule }` so clicks outside
  the capsule always pass through regardless of capsule size.
- `ui/Capsule.qml`: `ClippingRectangle` (Quickshell.Widgets), black, no border, static
  size for now (sized to `CompactPage`'s implicit size). `MultiEffect` drop shadow
  behind it, tuned live with Haziq: `shadowOpacity: 0.38`, `shadowBlur: 0.85`,
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

**Deviation from the plan's aspirational Kuro tokens**: bg and font are Haziq's explicit
per-project asks (pure black, Plus Jakarta Sans), not the plan's original Kuro-default
`#0b0a09` / `Inter`. Theme.qml comments record this so it isn't "fixed" back later by
accident.

## Not built yet (slice 0 explicitly excludes)

No morph (capsule is static size), no `IslandController`, no services, no other pages,
no IPC. Window-focus-title and MPRIS now-playing (both working in the pre-plan raw
prototype) are intentionally dropped for now; now-playing comes back in slice 5 as part
of `CompactPage`, per the plan. There is currently no page showing anything but a clock.

## Claude Design reference swap (theme/motion token pass)

Per Haziq's explicit "replicate 100%" direction, `plans/Claude Design - Dynamic Island/Dynamic Island.dc.html`
now supersedes the earlier Kuro-derived `theme/Theme.qml` (bone ink, pure black,
Plus Jakarta Sans, one fixed radius) and the spring-based `theme/Motion.qml`/
`ui/MorphAnimation.qml`. New tokens: ink ramp `#ededed`/`#8f8f8f`/`#7a7a7a`/`#6f6f6f`/
`#5c5c5c`, surface `#050506`, JetBrains Mono + Noto Sans JP, per-state size/radius
constants (`compactH`/`peekH`/`osdW`/`osdH`/`osdRadius`/`expandedW`/`expandedH`/
`expandedRadius`). The design's `accent` token defaults to (and every swatch renders
as) plain `#e8e8e8`, so fills/dots/highlights just use `ink` directly rather than
adding a real accent-hue system, consistent with Haziq's standing no-accent-hue
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
(700x604, r30, sized/radiused to the design's EXPANDED state) per Haziq: "for the
expanded part you can just put an empty box with border as placeholder, so next slices
will replace that placeholder." The real dashboard (identity/media/controls/toggles/
system/inbox/session, see the design's ANATOMY panel) is real backend work spanning
several future slices, not a style pass.

**Known, deliberate divergences from the literal design values** (Haziq tuned these
live after seeing them rendered; don't "fix" them back to the design's numbers):
- **Capsule border removed entirely.** The design specifies
  `border: 1px solid rgba(255,255,255,0.08)` on every state; Haziq tried it live and
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

**`pages/MediaExpanded.qml`'s placeholder was too broad.** Haziq caught that the "empty
box" instruction had swallowed real, working functionality (title/artist/progress/
transport, backed by `services/Media.qml` since slice 5), not just the design's new,
not-yet-built sections. Restored the MEDIA section for real (title/artist, tabular
elapsed/remaining, prev/play-pause/next as plain glyph text per the design, not the old
bordered Canvas buttons), plus a squircle-clipped album art thumbnail (`ClippingRectangle`
+ `Image { source: Media.artUrl }`, falling back to a flat hairline swatch when there's no
art) per Haziq's ask. The squircle is a large-radius rounded rect, not a true
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
this doc's "empty bordered placeholder box" wording — that's not a bug, Haziq asked for
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
regardless of what MPRIS's own `canGoNext` claims (Haziq: "for live video you cant go
forward, only backwards, since it is well, live" - there's nothing ahead of live to skip
into).

**New: `services/System.qml`**, backing the design's "01 IDENTITY" header row that
Haziq flagged as missing ("dont forget the things above the media player"). Exposes
`userHost` (`$USER`/`$LOGNAME` via `Quickshell.env()`, `+`/etc/hostname`), `uptimeLabel`
(one blocking read of `/proc/uptime` at startup plus a live wall-clock offset, not
re-read on a timer) and `niriVersion` (`niri msg --json version` via a `Process`,
`stdout` parsed as JSON). Each field hides independently when absent, same rule as
every other module: on Hyprland (Haziq's other target compositor) `niri msg` simply
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

**BRI is not built, on purpose, not just deferred.** This desktop has no
`/sys/class/backlight` (confirmed earlier in this doc). Investigated the only real
alternative, DDC/CI over the monitor's I2C bus (`ddcutil`): it actually works, found the
real monitor (`ddcutil detect` -> Acer XZ306C X on `/dev/i2c-7`, no root needed, a udev
ACL already grants the seat user access) and both `getvcp 10`/`setvcp 10 <n>` round-trip
correctly. But every single call measured **~8 seconds** on this hardware (confirmed 3x,
consistent to the tenth of a second, reads like a fixed retry/backoff policy on
`ddcutil`'s side more than raw I2C latency). Asked Haziq how to handle it (skip / show a
pending state / fire-and-forget with drift); he chose skip. If this ever gets revisited
(different monitor, faster DDC path, or accept the latency with a visible "pending"
state), `Audio.qml`'s pattern doesn't transfer directly: DDC calls need to go through a
`Quickshell.Io.Process`, not a live property binding, so a `Brightness.qml` service
would look more like `services/System.qml`'s niri-version `Process` than like the
audio/mic sliders next to it.

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

## Next: Slice 6 (Notifications)

`services/Notifs.qml` (`NotificationServer` inside `Loader { active: Config.notificationServer }`
per the plan, but `Config.qml` doesn't exist yet, hardcode `active: true` for now and
revisit when Config lands; `keepOnReload: true`, `actionsSupported`/`imageSupported`/
`bodySupported: true`), `pages/NotificationPeek.qml` (icon/summary/body/actions,
`RetainableLock` on the payload so a notification destroyed mid-fade doesn't crash).
This is the first kind with a real per-instance key (`notif:<id>`, no static key in
`Kinds.table`, `show()` already rejects a missing key since slice 2's refuter fixes).
Verify under `scripts/dev.sh --isolated-bus` (doesn't exist yet either, see the plan):
`notify-send -A ok=OK hi body` peeks; the action invokes; a critical notification stays
until dismissed (`duration: -1` override, already correctly handled per slice 3's
`_isInfiniteDuration` fix); an external close clears the peek via `Island.clearKey`.

**Standing reminder for every future slice** (found 3 times now: `PersistentProperties`
in `app/Island.qml`, a debug `Connections` in `services/Audio.qml`, and the `_timer` in
`core/IslandController.qml` got it right from the start): a `QtObject`-rooted
singleton/service has no default property, so any child object needs a named property
(`property Foo _x: Foo {...}`), never an unnamed one, or it fails to load with "Cannot
assign to non-existent default property". Only `Item`-rooted types and Quickshell's own
`Singleton`/`ReloadPropagator` accept bare unnamed children.

## Environment notes worth not rediscovering

- Nested niri IPC (`niri msg`) hangs the whole socket if a client (e.g. `action spawn`)
  is left running/blocked; kill the stray client or restart the nested niri instance,
  don't keep retrying against a wedged socket.
- Quickshell config selection: `qs -p <dir>` runs `<dir>/shell.qml` directly, no need to
  symlink into `~/.config/quickshell/`.
