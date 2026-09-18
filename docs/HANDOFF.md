# Handoff

Read this first when resuming (new session, or after `/compact`).

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

## Slice 4.5 done: reserved space via a separate spacer surface

Haziq asked for the compact pill's height to be reserved space (tiled windows shouldn't
render directly under the clock), matching how other Dynamic Island implementations
behave, and matching what the original plan itself anticipated
(`exclusiveZone: Config.reserveSpace ? Theme.compactH + Theme.topInset : 0`).

**The naive one-line version genuinely hangs niri, this is real, don't try it again**:
setting `ui/IslandWindow.qml`'s `exclusiveZone` directly to `Theme.compactH +
Theme.topInset` (44) hung the whole nested niri session's layer-shell configure
handshake, confirmed reproducibly multiple times (toggling the value back and forth;
`qs` sits at 0% CPU, `Configuration Loaded` never prints). niri itself recovered on its
own within a few seconds of the client dying each time (`niri msg` IPC came back), so it
wasn't a permanent deadlock, but it visibly froze the session while stuck. Root cause,
confirmed by isolated testing (a minimal throwaway `qs` config outside this repo, not
found in either niri's or Quickshell's issue trackers): a `PanelWindow` anchored `top`
only (not also `left`+`right`) has a compositor-decided, centered horizontal position;
reserving a nonzero exclusive zone for a surface whose position isn't fixed apparently
creates something niri's layout solver can't resolve. Anchoring `top`+`left`+`right`
(full width) with the identical `exclusiveZone` value loaded instantly in the same
isolated test; centered top-only reproduced the hang every time. Not confirmed against
niri's own source, and not filed upstream (Haziq's call if that's ever wanted), but the
empirical A/B result was clean enough to build on.

**The fix**: two separate layer-shell surfaces, not one.
`ui/ReservedSpaceWindow.qml` is a new, invisible, `mask: Region {}` (fully click-through)
`PanelWindow` anchored `top`+`left`+`right`, with `exclusiveZone: Theme.compactH +
Theme.topInset`: it does nothing but reserve the layout space. `ui/IslandWindow.qml`
keeps rendering and animating the capsule exactly as before, still centered
(`anchors.top` only). Both are instantiated from `shell.qml`. This sidesteps the hang
entirely (the reserving surface's position is never ambiguous) while keeping the
capsule's own morph/overlay behavior exactly as designed: it can still grow past the
reserved strip's height for a peek or the expanded state, since only the *reservation*
is fixed at compact height, not the capsule's own rendering surface.

**One more real bug this surfaced, fixed immediately after**: with the spacer surface
in place, the pill rendered *below* the reserved strip instead of inside it.
`IslandWindow.qml`'s `exclusiveZone` was `0`, and per wlr-layer-shell semantics, `0`
means "I don't reserve space myself, but I still respect *other* surfaces'
reservations", so it was getting pushed down by `ReservedSpaceWindow`'s zone instead of
overlaying inside it. `-1` means "ignore other surfaces' exclusive zones, anchor to the
true edge regardless", which is what a floating overlay actually needs once a sibling
surface is reserving space at all; `IslandWindow.qml` is now `exclusiveZone: -1`.
Verified live, same bounded-`timeout` caution as the rest of this incident (this is the
same window that hung on a *positive* exclusiveZone; `-1` specifically hadn't been
tested yet): loaded cleanly, no hang, and visually confirmed by Haziq the pill now sits
inside the reserved gap correctly.

**Vertical spacing tuned live, non-obvious finding along the way**: `Theme.topInset`
settled at `5` (tried `14` first per an ambiguous "a little lower" request that turned
out to mean "less gap", then `5` per "looks more minimalist"). The *bottom* gap (pill's
bottom edge to where tiled windows start) turned out not to just be `topInset` again:
a mathematically symmetric reserved strip (`compactH + 2*topInset`) looked visibly
*bottom-heavy* despite the equal math. Cause, found by Haziq: **niri's own `gaps`
setting** (`~/.config/niri/cfg/layout.kdl`, currently `12`) adds spacing "between
windows and to screen edges", which stacks on top of whatever `Theme.qml` reserves for
the bottom, since the reserved strip's lower boundary is now effectively a screen edge
from niri's layout perspective. Nothing analogous exists for the *top* gap, there's no
window above it to trigger niri's own gap logic, so top and bottom were never going to
match by using one symmetric formula. Fixed: added a separate `Theme.bottomInset`
(distinct from `topInset`, tuned independently, not derived from it), set to `0` so
niri's own `12px` gap is the entire bottom spacing. `ui/ReservedSpaceWindow.qml`'s
height/`exclusiveZone` is now `Theme.compactH + Theme.topInset + Theme.bottomInset`.
**If `~/.config/niri/cfg/layout.kdl`'s `gaps` value ever changes, re-check this balance,
it's tuned against `12` specifically, not derived from it.**

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

## Next: Slice 5 (Media)

`services/Media.qml` (`Mpris.players`, active player chosen reactively preferring
`isPlaying` else most recently changed; `trackChanged()` gated on readiness the same way
`Audio` gates on `Pipewire.ready`; a 1s `Timer` for `positionChanged` while playing),
`pages/MediaPeek.qml` (art + title/artist) and `pages/MediaExpanded.qml` (art, controls,
progress), `CompactPage`'s now-playing marquee (per the plan's file layout, `CompactPage`
ultimately shows clock + now-playing, not clock alone). Verify: `playerctl next` peeks;
switching the playing app switches the active player; progress advances.

**This is also where the deferred slice-3 item finally gets resolved**: the click
contract still routes through a hardcoded `Island.toggle("dummyExpanded")` in
`ui/Capsule.qml` rather than a page emitting `requestExpand()`, because no page that
would plausibly want click-to-expand has existed until now. `MediaPeek` clicked ->
`Island.expand("MediaExpanded")` then `Island.dismiss()` is the plan's actual rule 8
example; wire the real contract here and remove the placeholder toggle.

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
