# Handoff

Read this first when resuming (new session, or after `/compact`).

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

## Next: Slice 3 (Wire)

`Island` singleton (`core/Island.qml`, `pragma Singleton` + `PersistentProperties` for
`expandedPage`), view binds to `Island.page`/`Island.payload`, `Demo` service, IPC
`demo/expand/collapse/toggle/dismiss`. This is also where slice 1.5's temporary
`TapHandler` toggle in `Capsule.qml` gets replaced with the real click contract
(`requestExpand()` -> `Island.expand()`). Verify: `qs -p . ipc call island demo <kind>`
previews every page; hover pauses the timeout; `expandedPage` survives a hot reload.

## Environment notes worth not rediscovering

- Nested niri IPC (`niri msg`) hangs the whole socket if a client (e.g. `action spawn`)
  is left running/blocked; kill the stray client or restart the nested niri instance,
  don't keep retrying against a wedged socket.
- Quickshell config selection: `qs -p <dir>` runs `<dir>/shell.qml` directly, no need to
  symlink into `~/.config/quickshell/`.
