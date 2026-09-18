# Dynamic Island for niri: foundation plan

Date: 2026-09-18. Project: `/home/deprecated/Projects/dynamic-island`.

## Context

Haziq wants an Apple-style Dynamic Island for Linux, built from scratch so the frontend is fully his. Reference: Tide-island (Quickshell + QML + C++). His interest is the visual layer only, so the foundation (window, state machine, morph animation, system services, config, IPC, dev loop) must be built right once, then left alone while he iterates on design.

Decisions confirmed with Haziq:

- **Stack**: Quickshell 0.3.1, QML-only. No C++ in the foundation. Quickshell already ships MPRIS, PipeWire, UPower, a notification server, layer-shell, IPC and hot reload.
- **Compositor**: niri only, for now. No KDE or Hyprland code paths. Dev loop stays as today: nested niri (`~/dev-niri.kdl`) inside the KDE host session.
- **Noctalia**: the island takes over notifications and the volume OSD on niri. Haziq sets `notifications.enabled` and `osd.enabled` to `false` in `~/.config/noctalia/settings.json`. Noctalia keeps bar, launcher, lock, wallpaper. No keybind changes: the island observes PipeWire, so `noctalia msg volume-up` keeps working.

### On-disk state when this plan was written (2026-09-18 19:17)

A second Claude Code session was editing this directory concurrently. State at that moment:

- git repo on `main`, one commit `d44dfe2` "Slice 0+1: layer-shell anchored pill with live clock and niri window title" (the standalone Qt6 + LayerShellQt + `NiriEventStream.cpp` version).
- Working tree: all C++ files and `qml/Island.qml` deleted (staged), `.gitignore` modified, and an untracked single-file Quickshell `shell.qml` (a `PanelWindow` pill: Timer clock, `ToplevelManager.activeToplevel.title`, MPRIS now-playing). The pivot to Quickshell had already begun there.
- That file proves `Quickshell.Wayland.ToplevelManager` works on niri 26.04, which raises confidence that `Quickshell.WindowManager` (ext-workspace) will too.

**Hazard**: two sessions writing the same directory will clobber each other. Exactly one session executes this plan. Stop or park the other one first. Slice 0 starts from the state above, not from the CMake scaffold.

Known flaws in that `shell.qml` that Slice 0 fixes by design rather than patching:
- The layer surface itself resizes with content (`implicitWidth: content.implicitWidth + 32`). The plan uses a fixed canvas with a capsule drawn inside.
- Clock via a 1 s `Timer` writing `text`. Use `SystemClock`.
- `activeMprisPlayer()` is a plain function call in a binding, so `isPlaying` changes on a player never re-evaluate it. The Media service tracks the active player reactively.

### Verified environment facts

| Fact | Consequence |
|---|---|
| Quickshell 0.3.1 modules: Mpris, Pipewire, UPower, Notifications, Networking, Bluetooth, Wayland, WindowManager, Io, Widgets | All services are QML imports |
| Quickshell binary speaks `ext_workspace_manager_v1` and `zwlr_foreign_toplevel_manager_v1`; niri 26.04 exports both | Workspaces via `WindowManager`, focused window via `ToplevelManager`; no niri IPC parsing unless the runtime check fails |
| `qs -p <dir>` hot-reloads on save | Design iteration without restarts |
| Nested niri shares the KDE host's D-Bus session bus; plasmashell owns `org.freedesktop.Notifications` | Notification tests need `dbus-run-session -- niri -c ~/dev-niri.kdl` |
| Desktop: no `/sys/class/backlight`, UPower exposes only `DisplayDevice` | Brightness and battery are laptop features here. Services report `available: false` and are demo-mockable |
| One 2560x1080 output `DP-1` at 200 Hz, scale 1 | 5 ms frame budget. No per-frame layer effects |
| Fonts: Inter, Inter Display, JetBrainsMono Nerd Font. Space Mono / Fraunces / Space Grotesk absent | Theme tokens default to JetBrainsMono NF and Inter; swappable later |
| `qmllint`, `qmltestrunner`, `qmlformat` in qt6-declarative 6.11 | Lint and controller tests need no extra packages |
| `~/.config/niri` -> `Projects/cachyos-setup/kuro/wm/niri`; Noctalia started via `spawn-sh-at-startup` in `cfg/autostart.kdl` | Island autostarts the same way |
| `~/dev-niri.kdl` binds Mod+I to the old binary `build/dynamic-island` | Rebind to `qs -p /home/deprecated/Projects/dynamic-island` |

## Scope

IN (the foundation):

1. Layer-shell canvas, transparent, fixed size, input mask that follows the capsule.
2. `IslandController`: derived page + prioritised transient queue (replaces Tide-island's 15 string states and ad-hoc guards).
3. Morph animation: capsule geometry driven by page content size, cross-fading content, motion tokens in one file.
4. Services as QML singletons: Audio, Media, Notifs, Workspaces, Battery, Brightness, Config, Demo.
5. Pages: CompactPage (clock, now-playing), OsdPeek, MediaPeek, MediaExpanded, NotificationPeek with actions, WorkspacePeek, PowerPeek.
6. IPC surface, JSON config (under 8 keys), demo script, niri autostart, install script, handoff doc.
7. Tests: qmllint plus Qt Quick Test for `IslandController` only.

OUT (his design phase, later): control center, notification center, calendar, launcher, clipboard, wallpaper picker, lyrics, weather, file shelf, hover-to-expand, multi-compositor abstraction, systemd unit, per-screen instances, Network/Bluetooth/SysStats pages.

## Architecture

### Canvas and capsule

`ui/IslandWindow.qml` is one `PanelWindow` anchored `top` only (layer-shell centres it horizontally), `implicitWidth: Theme.canvasW` (800), `implicitHeight: Theme.canvasH` (420), `color: "transparent"`, `WlrLayershell.namespace: "dynamic-island"`, `exclusiveZone: Config.reserveSpace ? Theme.compactH + Theme.topInset : 0`. The surface never resizes. `screen` is bound to the `Quickshell.screens` entry whose name equals `Config.screen`, falling back to the first screen.

`ui/Capsule.qml` is a `ClippingRectangle` (Quickshell.Widgets, shader clip, no `layer.enabled`) inside the canvas: `anchors.horizontalCenter` with `horizontalCenterOffset: Config.offsetX`, `y: Theme.topInset`, `width/height/radius` bound to the host's target values with `Behavior on` each using `ui/MorphAnimation.qml` (a `NumberAnimation` reading `Motion.morph` and `Motion.morphEasing`). A `HoverHandler` drives `Island.hovered`.

Input mask: `mask: Region { x: capsule.x; y: capsule.y; width: host.targetWidth; height: host.targetHeight }`, bound to the target rect so there are no per-frame input-region commits. If hover-out during shrink feels wrong, switch to `Region { item: capsule }`.

Keyboard: `WlrLayershell.keyboardFocus: page.wantsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None`, never `Exclusive` (steals compositor binds; his wallpaper picker hit this). Call `forceActiveFocus()` on the page when it gains keyboard.

### Content crossfade (`ui/PageHost.qml`)

Two synchronous `Loader`s (`slotA`, `slotB`), no `StackView` (its transitions assume the container owns the size). On page change: load the incoming page into the idle slot; on `onLoaded` copy its `implicitWidth/Height` into `targetWidth/Height` so morph and fade start in the same frame; run a `ParallelAnimation`: outgoing `opacity 1 -> 0`, `scale 1 -> Motion.scaleFrom` over `Motion.fadeOut`; incoming `opacity 0 -> 1`, `scale Motion.scaleFrom -> 1` over `Motion.fadeIn` after `Motion.fadeInDelay`. Set outgoing `source = ""` only in `onFinished`. `layer.enabled: opacity < 1` on page items only, never on the canvas. Pages larger than the canvas minus inset are clamped with a console warning.

Same-page payload updates (a coalesced volume OSD) do not reload: the host sets `payload` on the live item.

### IslandController (`core/IslandController.qml`, pure `QtObject`, imports only `QtQuick`)

Two inputs, one derived output. "Peek" is not a stored mode, so there is no "return to previous mode" bookkeeping.

```qml
QtObject {
    property string expandedPage: ""          // "" = compact; user intent, persisted
    property bool hovered: false              // from Capsule HoverHandler
    property bool held: false                 // from page.holdOpen
    readonly property var current: null       // {kind,key,priority,page,payload,duration,requeue}
    readonly property var queue: []           // priority desc, FIFO within priority, cap 6
    readonly property string page: current ? current.page : (expandedPage || "compact")
    readonly property var payload: current ? current.payload : null
    readonly property bool isPeek: current !== null
    readonly property bool isExpanded: !current && expandedPage !== ""
    property var kinds: Kinds.table           // injectable for tests
    property int expandedBlockBelow: 40
    signal transientStarted(var t)
    signal transientEnded(var t, string reason) // timeout|replaced|dismissed|preempted|cleared
    function show(kind, payload, overrides)   // overrides: {duration,key,priority,page}
    function dismiss()
    function clearKey(key)
    function expand(pageId); function collapse(); function toggle(pageId)
}
```

`core/Kinds.qml` (data only):

| kind | priority | duration ms | key | page | requeue on preempt |
|---|---|---|---|---|---|
| notification | 50 (critical 60) | 5000 normal, 3000 low, critical until dismissed | `notif:<id>` | NotificationPeek | yes |
| osd.volume | 40 | 1500 | `osd:volume` | OsdPeek | no |
| osd.brightness | 40 | 1500 | `osd:brightness` | OsdPeek | no |
| power | 35 | 3000 | `power` | PowerPeek | no |
| media.track | 30 | 3000 | `media` | MediaPeek | no |
| workspace | 20 | 1200 | `workspace` | WorkspacePeek | no |

Rules for `show(t)`, in order:

1. **Coalesce**: same `key` as `current` replaces payload in place and restarts the timer, no exit animation. Same key as a queued item replaces it in place.
2. **Expanded gate**: if `expandedPage !== ""` and `t.priority < expandedBlockBelow`, drop it. OSD and notifications still show over an expanded page; `page` falls back to `expandedPage` when they end.
3. **Empty**: no `current`, so `t` becomes current and the timer starts.
4. **Preempt**: `t.priority > current.priority` ends current with reason `preempted`; if `current.requeue`, push it to the queue front.
5. **Enqueue** otherwise. Cap 6; overflow drops the lowest-priority oldest.
6. **End** (timeout, `dismiss`, `clearKey`): pop the queue head into current, else `null`.
7. **Hover-hold**: `hovered || held` pauses the single `Timer`, recording remaining time; on release restart with `max(remaining, Motion.hoverGrace)`.
8. **Click on a peek**: the page emits `requestExpand("media")`; the view calls `expand("media")` then `dismiss()`.

`core/Island.qml` is the `pragma Singleton` instance plus `PersistentProperties` for `expandedPage` (survives hot reload). `core/Bridges.qml` is the only file that knows both services and the controller: one `Connections` per service mapping signals to `Island.show(...)`.

### Page contract (every `pages/*.qml` is an `Item`)

Required: `implicitWidth`, `implicitHeight`, `property var payload`.
Optional: `property bool wantsKeyboard: false`, `property bool holdOpen: false`, `signal requestClose()`, `signal requestExpand(string pageId)`.

This is the seam Haziq designs against later: a new page only has to honour this contract.

### Services (`services/*.qml`, all `pragma Singleton`)

- **Audio**: `Pipewire.defaultAudioSink` bound through `PwObjectTracker`; exposes `volume`, `muted`, `available`; emits `changed()` after a `Motion.debounceOsd` (16 ms) debounce; suppresses emission until 500 ms after `Pipewire.ready` to swallow the startup burst.
- **Media**: `active` player chosen reactively from `Mpris.players` (prefer `isPlaying`, else most recently changed), `trackChanged()` gated on readiness so startup does not fire per player; a 1 s `Timer` emits `positionChanged` while playing so progress advances.
- **Notifs**: `NotificationServer` inside `Loader { active: Config.notificationServer }` with `keepOnReload: true`, `actionsSupported: true`, `imageSupported: true`, `bodySupported: true`; sets `tracked = true` on incoming; emits `received(notification)`; forwards `closed` to `Island.clearKey`.
- **Workspaces**: normalised `list` of `{id, name, active, urgent}` and `activeChanged()` from `WindowManager.windowsets`. If `windowsets` is empty on niri at runtime, add a `Quickshell.Io.Socket` backend on `NIRI_SOCKET` that writes `"EventStream"\n`, skips the ack line, and parses `WorkspacesChanged` and `WorkspaceActivated`.
- **Battery**: `UPower.displayDevice`; `available: displayDevice.isPresent`; emits `chargerChanged(charging)`.
- **Brightness**: `available` flag from `/sys/class/backlight` existence via `FileView`; `refresh()` called from IPC (sysfs has no inotify, so no `watchChanges`). Nothing more on this hardware.
- **Config**: `FileView` + `JsonAdapter` on `~/.config/dynamic-island/config.json`. Keys: `screen`, `notificationServer`, `reserveSpace`, `offsetX`, `osdEnabled`, `workspacesEnabled`, `debug`. Visual tokens live in `Theme.qml`, not JSON: he edits QML anyway and hot reload gives live tuning.
- **Demo**: fake payload factories so every page can be previewed without real events.

### Theme and motion (`theme/`)

`Theme.qml`: Kuro tokens (ink `#cdc4ba`, bg `#0b0a09`, hairline `rgba(205,196,186,.2)`), fonts (`mono: "JetBrainsMono Nerd Font"`, `sans: "Inter"`, `display: "Inter Display"`, with the Space Mono / Fraunces / Space Grotesk names as commented alternates), radii, `compactH`, `topInset`, `canvasW`, `canvasH`. `Motion.qml`: `morph 420`, `morphEasing Easing.OutQuint`, `fadeOut 140`, `fadeIn 220`, `fadeInDelay 60`, `scaleFrom 0.96`, `hoverGrace 700`, `debounceOsd 16`. Swapping `NumberAnimation` for `SpringAnimation` later is a one-file change in `MorphAnimation.qml`.

### IPC (`IpcHandler { target: "island" }` in `shell.qml`)

Typed parameters only (`string`, `int`, `bool`). Functions: `page(name)`, `demo(kind)`, `expand(name)`, `collapse()`, `toggle(name)`, `dismiss()`, `brightnessRefresh()`. Invoked with `qs -p . ipc call island demo notification`.

## File layout

```
shell.qml                    ShellRoot; IslandWindow; IpcHandler "island"; Bridges; references services so lazy singletons instantiate
core/IslandController.qml    state + queue + single Timer; imports QtQuick only (tests load it directly)
core/Kinds.qml               kind table
core/Island.qml              singleton instance + PersistentProperties(expandedPage)
core/Bridges.qml             service signals -> Island.show(...)
ui/IslandWindow.qml          PanelWindow canvas, layer, keyboardFocus, mask Region
ui/Capsule.qml               ClippingRectangle with morph Behaviors, HoverHandler
ui/PageHost.qml              two-slot Loader crossfade; exposes targetWidth/Height/Radius
ui/MorphAnimation.qml        NumberAnimation preconfigured from Motion
pages/CompactPage.qml        SystemClock time + now-playing marquee
pages/OsdPeek.qml            icon + Bar; payload.kind volume|brightness
pages/MediaPeek.qml          art + title/artist
pages/MediaExpanded.qml      art, controls, progress
pages/NotificationPeek.qml   icon/summary/body/actions; RetainableLock on payload
pages/WorkspacePeek.qml      dots + active name
pages/PowerPeek.qml          battery %, charger state
components/Label.qml Icon.qml Art.qml Bar.qml ActionButton.qml
services/Audio.qml Media.qml Notifs.qml Workspaces.qml Battery.qml Brightness.qml Config.qml Demo.qml
theme/Theme.qml Motion.qml
tests/tst_controller.qml     qmltestrunner: coalesce, preempt, requeue, expanded gate, hover-hold, cap, clearKey
scripts/dev.sh               qs -p . ; --isolated-bus wraps nested niri in dbus-run-session
scripts/demo.sh              notify-send / wpctl / playerctl / qs ipc call island demo <kind>
scripts/lint.sh              qmllint -I /usr/lib/qt6/qml over all .qml, qs.* imports allow-listed
scripts/test.sh              qmltestrunner -input tests
scripts/install.sh           symlink ~/.config/quickshell/dynamic-island -> repo; print niri autostart + layer-rule snippet; print Noctalia toggles
config.example.json
plans/                       this plan and future plans
docs/HANDOFF.md              slice status, decisions, how to resume (reload after /compact)
CLAUDE.md                    repo-level: dev loop commands, page contract, "build with Sonnet, refute with Opus"
README.md
```

Imports use Quickshell's root-relative form (`import qs.services`, `import qs.theme`). If 0.3.1 rejects it, fall back to relative imports (`import "../services"`). Tests import `../core` directly, which is why `core/` must not import Quickshell.

## Slices

Each slice is one Claude Code build session (Sonnet), followed by a `refuter` pass (Opus), then a commit. Each ends runnable in nested niri via `scripts/dev.sh` with Mod+I in `~/dev-niri.kdl`.

0. **Baseline and skeleton**. Commit the pending pivot as-is (deletions plus the single-file `shell.qml`) so history shows the switch. Then create the layout above with `Theme`, `IslandWindow` (fixed canvas), a static `Capsule`, `CompactPage` using `SystemClock`, `docs/HANDOFF.md`, `CLAUDE.md`, `scripts/dev.sh`, `scripts/lint.sh`. Rebind Mod+I in `~/dev-niri.kdl`. Verify: pill top-centre; clicks outside the pill pass through to windows below; editing `Theme.ink` hot-reloads; `lint.sh` clean.
1. **Morph**. `Motion`, `MorphAnimation`, `PageHost`, two dummy pages of different sizes, IPC `island page <name>`. Verify: alternating pages morphs width, height and radius smoothly at 200 Hz; no rectangular clip corners mid-morph; mask follows the target rect.
2. **Controller**. `IslandController`, `Kinds`, `tests/tst_controller.qml`, `scripts/test.sh` green with durations injected at 50 ms. No UI change. Verify: tests cover every rule in the list above.
3. **Wire**. `Island` singleton, `PersistentProperties`, view binds to `Island.page` and `Island.payload`, `Demo` service, IPC `demo/expand/collapse/toggle/dismiss`. Verify: `qs -p . ipc call island demo <kind>` previews every page; hover pauses the timeout; `expandedPage` survives a hot reload.
4. **Audio OSD**. `Audio`, `OsdPeek`, `Bridges` entry. Verify: `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+` repeated fast coalesces into one bar; no OSD burst on startup.
5. **Media**. `Media`, `MediaPeek`, `MediaExpanded`, compact now-playing. Verify: `playerctl next` peeks; click expands; play/pause/next work; progress advances; switching the playing app switches the active player.
6. **Notifications**. `Notifs`, `NotificationPeek` with actions and `RetainableLock`, `Config.notificationServer`. Verify under `scripts/dev.sh --isolated-bus`: `notify-send -A ok=OK hi body` peeks; the action invokes; a critical notification stays until dismissed; an external close clears the peek.
7. **Workspaces**. `Workspaces` via `WindowManager`, `WorkspacePeek`. Verify: Mod+1..3 in nested niri peeks with the right active index. If `windowsets` is empty, implement the Socket fallback and re-verify.
8. **Power and brightness**. `Battery`, `Brightness` with `available: false` on this box, `PowerPeek`, IPC `brightnessRefresh`. Verify via `demo power` and `demo osd.brightness` only.
9. **Ship**. `scripts/install.sh`, `config.example.json`, README with the Noctalia toggles and the niri snippets (`spawn-sh-at-startup "qs -c dynamic-island"` in `cfg/autostart.kdl`, `layer-rule { match namespace="dynamic-island" }` in `cfg/rules.kdl`), `lint.sh` clean, handoff doc marked complete. Verify in the real niri session with Noctalia's notifications and OSD off.

After slice 9 the foundation is frozen and Haziq's design work starts: `Theme.qml`, `Motion.qml`, `components/`, and page internals, all behind the page contract.

## Pitfalls and mitigations

- **Lazy singletons**: `Notifs` and `Workspaces` never start unless referenced. `shell.qml` references them through `Bridges`.
- **Singleton init order**: never read another singleton in `Component.onCompleted`; bind instead.
- **Hot reload state**: `PersistentProperties` for `expandedPage`; `keepOnReload: true` on the notification server.
- **Notification destroyed mid-fade**: `RetainableLock { object: payload; locked: true }` inside `NotificationPeek`.
- **D-Bus name already owned**: Quickshell only logs it. Default `notificationServer: false` in `config.example.json`; README lists the Noctalia toggles; nested-niri testing uses `dbus-run-session` (MPRIS players are then invisible, so test media in normal mode).
- **PipeWire**: `audio` is null until `PwObjectTracker` binds the node; startup volume bursts are suppressed for 500 ms after `Pipewire.ready`.
- **MPRIS**: gate `trackChanged` on readiness; `position` only updates when `positionChanged` is emitted by the 1 s Timer.
- **Region**: an empty `Region {}` means nothing is clickable, `null` means everything; integer geometry only.
- **exclusiveZone**: never animate it; every change relayouts all tiled windows.
- **200 Hz**: no `layer.enabled` on the canvas; no `MultiEffect` shadow on animated geometry; synchronous Loaders (an async load gives a visible two-step morph); `Timer.restart()` for debounce.
- **Transparency**: `color: "transparent"` on `PanelWindow` suffices; the old alpha-format dance from `main.cpp` is gone.
- **IpcHandler** parameters must be typed, never `var`.
- **qmllint** needs `-I /usr/lib/qt6/qml`; `qs.*` imports warn and are allow-listed in `lint.sh`.
- **Two sessions**: only one Claude Code session edits this repo at a time; `docs/HANDOFF.md` is the handover between sessions.

## Verification (end to end)

1. `scripts/lint.sh` and `scripts/test.sh` pass.
2. In nested niri (`niri -c ~/dev-niri.kdl`, Mod+I): every `qs -p . ipc call island demo <kind>` renders its page; morphs are smooth; clicks outside the capsule reach the window below.
3. Real events: `wpctl` volume steps, `playerctl next`, Mod+1..3 workspace switch, `notify-send -A ok=OK` under `--isolated-bus`.
4. Real niri session: `install.sh`, Noctalia notifications and OSD off, autostart line added, island appears at login, notifications and volume OSD arrive in the island, `qs -n -c dynamic-island` does not spawn a duplicate.

## How to run this plan with Claude Code

1. One slice per session. Open with `/model sonnet`, paste: "Execute slice N of plans/2026-09-18-foundation-plan.md. Read docs/HANDOFF.md first."
2. After the builder reports done, run the `refuter` agent on the diff and the verification step for that slice. Fix, then commit.
3. Update `docs/HANDOFF.md` (slice status, anything learned) before ending the session.
4. Escalate to Opus or Fable only when a slice's design needs rethinking, not for building.

## Sources consulted

- Tide-island (reference): https://github.com/enhaoswen/Tide-island and its successor https://github.com/enhaoswen/Tide-Island-New (pure OpenGL rewrite, not relevant to this stack choice).
- Quickshell type index: https://quickshell.org/docs/v0.3.1/types/
