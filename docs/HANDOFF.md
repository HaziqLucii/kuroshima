# Handoff

Read this first when resuming (new session, or after `/compact`).

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

## Next: Slice 2 (Controller)

`IslandController`, `Kinds`, `tests/tst_controller.qml`, `scripts/test.sh` green with
durations injected at 50ms. No UI change this slice. See the plan for the full rule
list (coalesce, expanded gate, preempt, enqueue, hover-hold, cap 6, clearKey).

## Environment notes worth not rediscovering

- Nested niri IPC (`niri msg`) hangs the whole socket if a client (e.g. `action spawn`)
  is left running/blocked; kill the stray client or restart the nested niri instance,
  don't keep retrying against a wedged socket.
- Quickshell config selection: `qs -p <dir>` runs `<dir>/shell.qml` directly, no need to
  symlink into `~/.config/quickshell/`.
