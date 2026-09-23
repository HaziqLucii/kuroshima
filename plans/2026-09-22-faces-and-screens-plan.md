# kuroshima: next Island Faces and Island Screens (roadmap, 2026-09-22, revised after reading Tide-Island-New)

## Context

Foundation frozen at Slice 9. Since then: Island Faces (4), Settings screen (Audio only),
in-island app launcher, widget canvas, wallpaper carousel. Haziq asked for a plan of new
faces, screens, and anything else worth doing, with one explicit goal: end up better than
and distinct from Tide-island, the repo the very first prototype came from. Another
session is concurrently building launcher favourites (touches `ui/AppLauncher.qml`,
`services/Apps.qml`, probably a new favourites persistence file). Nothing in wave 1
below touches those files.

Two real functional gaps drive the ranking, not just "more content":

1. **Nothing shows the system tray any more.** Noctalia is gone, no waybar or nm-applet
   running. `Quickshell.Services.SystemTray` is installed and unused.
2. **The dashboard's TOGGLES grid is 5/8 fake** (DND, NIGHT, VPN, CAPS, IDLE dimmed).
   DND and IDLE have real, cheap backends already on this machine (`services/Notifs.qml`
   history + a `Quickshell.Wayland.IdleInhibitor`). NIGHT/VPN/CAPS stay dimmed: no
   `wlsunset`/`gammastep`, no VPN profile, no caps-lock source exposed by Quickshell.

A third driver arrived with the replan: **Tide's authors restarted as a C++/OpenGL
rewrite whose entire pitch is footprint.** kuroshima cannot match a no-QML binary on RAM
and should not try, but it currently spawns two shell processes every five seconds for
nothing and runs the live session with verbose logging. One measured pass fixes the
careless parts and publishes honest numbers, which the new Tide has not done.

Everything below reuses the existing seams: a face is a `faces/*.qml` Item plus one
`faceOrder` entry; a screen is a `pages/*.qml` Item plus one `pageMap` entry and a
`requestExpand` call; a transient is one `core/Kinds.qml` row plus a `Bridges.qml`
`Connections`. Ranked by (value on this machine) / (new backend work + risk).

Nothing here is started; Haziq reads first, then picks a slice per session. Log each
slice in `docs/NOTES.md`.

## Versus Tide-island (old) and Tide-Island-New (both read 2026-09-22)

**Tide-island (old, Quickshell/QML/C++, unmaintained)** is the feature benchmark. It
ships: music player with lyrics, control center, timer, launcher, file shelf, clipboard
text history, weather + forecast (auto-detect or city), calendar (week numbers, relative
dates, wheel-scroll months, Home/Esc), wallpaper switcher, Hyprland workspace overview,
power menu, notification centre, a "Custom page" of static info tiles, a separate
Settings app (shortcuts, per-mouse-button click actions, weather units), Night Light via
`hyprsunset`/`gammastep`, IPC toggles per panel. Its still-open issues say what its users
wanted next: smart auto-hide / dodge windows (#52), multiple custom pages (#51), and a
plugin interface for custom modules (#49).

**Tide-Island-New (C/C++, sokol OpenGL, wlr-layer-shell, six weeks old, 20 stars,
pushed 2026-09-21, no issues filed)** is the footprint benchmark, not a feature one. Read
from its headers and commits, not its README: a rect/image/text renderer, an animation
struct (width, height, x, y, radius, colour over a duration), a timer/event system, a
`key = val` config backend (five of the last eight commits), and exactly one status, a
clock. No MPRIS, notifications, audio, workspaces, launcher, or IPC yet. Its stated reason
to exist: "better performance, less resource usage, and a higher ceiling", no Qt, QML, or
JavaScript. Expect it to reach feature parity with old Tide slowly (every D-Bus client is
hand-written C++), and to win on RAM permanently.

**Honest position.** kuroshima is far ahead on features and will stay ahead on services
breadth for a long time. It loses on footprint: the live process measured ~460 MB RSS
today (with `-vv` logging on) against an expected 20 to 50 MB for a sokol binary. The
plan neither chases that nor ignores it: Slice 3 measures, fixes the careless wastes, and
publishes the numbers.

**Where kuroshima is already ahead** (keep these as the identity, do not regress them):
- One morphing capsule for everything. Tide opens separate panels; here the launcher,
  settings, dashboard, and every peek are pages of the same spring-morphing pill (the
  static-window launcher was rejected live for exactly this reason).
- A tested priority/coalescing transient controller (8 rules, 24 tests) instead of
  15 string states with ad-hoc guards. Users feel this as "smooth" without knowing why.
- Island Faces: swipeable, per-user-ordered glanceable content instead of Tide's static
  "Custom page" tile grid. This is already the answer to Tide issue #51.
- Widget canvas with drop-in user `.qml` widgets and a wallpaper carousel with crossfade.
  Drop-in QML is already the answer to Tide issue #49, with no plugin API to design.
- A real file shelf via cross-app Wayland drag in and out (Tide's shelf is a list).
- Per-app mixer and output/input device pickers inside Settings, not a separate app.
- Ready-made service modules (Mpris, Pipewire, Notifications, UPower, Bluetooth,
  Networking, SystemTray) and a hot-reload dev loop. For a solo developer this is the
  real "higher ceiling": a new face is one file and a save, not a C++ D-Bus client.
- House style: bone-on-black dossier, mono uppercase, hairlines, dithered EQ, no accent
  hue. Both Tides are generic dark-glass Apple mimicry.

**Gaps this plan closes** (old Tide has them, kuroshima does not yet): timer (Slice 2,
as a pomodoro that echoes kuro-focus), weather (Slice 4), lyrics (Slice 6, as a subtitle
line), calendar (Slice 10), Bluetooth/Network screens (Slices 9, 12, Tide only toggles).
Things neither Tide has: tray face, screencast privacy indicator, keyboard window
switcher, user drop-in faces, published footprint numbers.

**Rules for every slice, deliberately different, not parity:**
1. No separate windows and no separate settings app. If it cannot be a page or a face,
   it does not ship.
2. Glanceable info is a face you swipe to, never a static tile grid. Faces must be
   discoverable: the indicator ticks in Slice 5 are part of the system, not decoration.
3. Data-honest: hide or dim what is not real on this machine (the existing ETH/VPN/SYNC
   and dimmed-toggle rule). Tide shows every tile regardless.
4. Weather uses explicit lat/lon in config, no IP geolocation call. Privacy over
   convenience, one fewer external dependency.
5. Compact tap stays one gesture (expand); face content, not per-mouse-button config,
   is what makes the pill contextual.
6. niri-first, Hyprland later, per `CLAUDE.md`. No Hyprland-only surfaces (Tide's
   workspace overview); niri has its own overview on `Mod+O`.
7. Footprint discipline: never add a polling subprocess when a Quickshell module exposes
   the same state as a property; every slice that adds a service records RSS before and
   after in its NOTES entry.
8. Extensibility over plugin APIs: anything a user might want to customise is a drop-in
   `.qml` file in `~/.config/kuroshima/` (widgets today, faces from Slice 5), never a
   plugin interface.

## Backend inventory (verified 2026-09-22, drives what is cheap)

| Backend | State | Used by |
|---|---|---|
| `services/Toggles.qml` wifiOn/btOn, `Audio.micMuted`, `Notifs.history`, `SystemStats.*`, `Workspaces.list/activeIndex`, `Media.*`, `Battery.*` | exists | faces can read directly |
| niri `event-stream` (`services/Workspaces.qml`) | exists, handles 2 of ~10 event types | extend for windows / focus / casts |
| `Quickshell.Services.SystemTray` + `QsMenuAnchor` | installed, unused | tray face |
| `Quickshell.Wayland.IdleInhibitor` | installed, unused | IDLE toggle |
| `Quickshell.Bluetooth` (adapter, devices, pair/connect/forget, battery) | installed, unused | footprint pass, Settings Bluetooth |
| `Quickshell.Networking` (wifiEnabled, WifiDevice, WifiNetwork, connectWithPsk) | installed, unused | footprint pass, Settings Network |
| `lrclib.net` (free, keyless synced-lyrics API), `open-meteo` (free, keyless weather) | reachable via `curl` | lyrics, weather |
| `cliphist`, `qalc`, `grim`+`slurp` | installed | backlog items |
| Battery / backlight / wf-recorder / wlsunset / khal | absent on this desktop | skip or dim |
| niri `keyboard-layouts` | one layout only | skip layout peek |

Live footprint at plan time: `qs -c kuroshima -vv` at ~460 MB RSS; `services/Toggles.qml`
spawns `nmcli` and `sh -c bluetoothctl` every 5 s forever; `services/SystemStats.qml`
polls `/proc` every 3 s forever; `EqualizerBars` and the LIVE pulse are already gated on
playback state (verified, no change needed).

## Wave 1: faces with zero new services, plus two real toggles

### Slice 1: DND + IDLE toggles real, then `faces/StatusFace.qml` and `faces/SystemFace.qml`

**DND** (`services/Notifs.qml`, `app/Bridges.qml`, `pages/MediaExpanded.qml`):
- `Notifs.dnd: bool` (persist later via the Faces/Config file, not now; hot-reload
  survival is enough for v1, same as `compactFace`).
- Gate in `app/Bridges.qml`'s `onReceived` handler (line ~96): when `Notifs.dnd` and
  urgency is not Critical, skip `Island.show("notification", ...)`. History is already
  appended inside `services/Notifs.qml`'s `onNotification` (line ~46) BEFORE `received`
  is emitted, so the gate preserves INBOX for free. Critical still peeks (the design's
  "critical stays" rule).
- **Must-do with the gate**: call `notification.expire()` immediately on the suppressed
  path. `Notifs.qml` sets `tracked = true`, which hands expiry to this shell; today the
  only close path is `Bridges.qml`'s `onTransientEnded` (line ~129), which never runs for
  a notification that never became a transient. Without the explicit expire, every
  suppressed notification stays tracked forever and `notify-send --wait` hangs, the exact
  bug refuter already caught once for queue-evicted notifications.
- TOGGLES grid DND button (`pages/MediaExpanded.qml` ~line 823):
  `available: Config.notificationServer` (DND means nothing when this shell is not the
  notification server), `isOn: Notifs.dnd`, `onClicked: Notifs.dnd = !Notifs.dnd`. Same
  shape as WIFI/BT.
- `pages/CompactPage.qml`'s bell: when `Notifs.dnd`, swap `cod-bell_dot` for the slashed
  bell glyph so the pill shows "muted" at a glance.

**IDLE** (`services/Toggles.qml`, `ui/IslandWindow.qml`, `pages/MediaExpanded.qml`):
- `Toggles.idleInhibit: bool` (state only; a QtObject service has no window to host the
  protocol object). `Toggles.qml`'s header comment claiming "no idle-inhibit daemon" is
  obsolete: niri exposes `zwp_idle_inhibit_manager_v1` (confirmed via `wayland-info`).
- `IdleInhibitor { enabled: Toggles.idleInhibit; window: root }` as an unnamed child of
  `ui/IslandWindow.qml`'s PanelWindow (already imports `Quickshell.Wayland`, permanently
  mapped, has a default property). Needs `import qs.services` there. This binds a new
  protocol object to the surface rather than reconfiguring it, a different class from the
  exclusiveZone/keyboardFocus hang history, but launch with the `timeout` discipline anyway.
- IDLE button (`pages/MediaExpanded.qml` ~line 858): `available: true`,
  `isOn: Toggles.idleInhibit`, `onClicked: Toggles.idleInhibit = !Toggles.idleInhibit`.

**`faces/StatusFace.qml`** (template: `faces/ClockDate.qml`): clock, hairline divider,
then a glyph row that only shows what is true: WIFI (on), BT (on), MIC-MUTED, DND, IDLE.
Nothing shown when a state is off, so the face collapses to just the clock when the
machine is in its default state (the pill should shrink, not show a row of dim icons).
Glyphs reuse the codepoints already in the TOGGLES grid. Read-only face, no handlers.

**`faces/SystemFace.qml`**: CPU / MEM / TEMP as three tabular-number cells with a 1px
hairline mini-bar under each (`SystemStats.cpuPercent/memPercent/tempCelsius`). Hide a
cell when its value is unavailable (`SystemStats` already exposes absence). Read-only.

Register both in `pages/CompactPage.qml`'s `faceOrder` (after `clockDate`, before
`media`). No `pageMap`, `shell.qml`, or `Capsule.qml` changes.

### Slice 2: `faces/FocusFace.qml` + `services/Focus.qml` (pomodoro, echoing kuro-focus)

Haziq's sibling app `~/Projects/kuro-focus` is an "expedition timer"; this face is its
desktop echo, same dossier aesthetic, no sync.

- `services/Focus.qml` (QtObject singleton, named-property children per the repo's
  standing QtObject rule): `presets: [25, 50, 5]` minutes, `remaining`, `running`,
  `phaseLabel`, `start(minutes)`, `pause()`, `reset()`, a 1s `Timer` running only while
  a session is active. On completion: spawn `notify-send -a kuroshima "Focus" "25 min
  done"` via a `Process`. That lands in INBOX and fires `NotificationPeek` through the
  existing bridge, no new `Kinds` row, no new peek page.
- `faces/FocusFace.qml`: idle state shows `FOCUS` + preset chips (tap a chip to start);
  running state shows `mm:ss` in tabular numerals, a hairline progress underline across
  the face, and pause/reset glyphs. Every `TapHandler` gets
  `gesturePolicy: TapHandler.ReleaseWithinBounds` (the documented trap in
  `faces/MediaFace.qml`: a passive-grab tap also fires `CompactPage`'s root
  tap-to-expand). Height stays `Theme.compactH` in both states.
- Face contract: `property var payload: null`, `implicitWidth/implicitHeight`, no
  `width/height` binding.

## Wave 2: footprint, weather, face system, lyrics, niri stream, tray

### Slice 3: footprint honesty pass (measure, fix the careless wastes, publish numbers)

Placed before weather on purpose: weather was scheduled "right after Focus" before the
Tide-Island-New read, and this pass is the replan's direct answer to that repo's pitch.
Swap the two if the order matters more than the reasoning.

- **Measure first, guess nothing.** Baseline RSS and 60 s idle CPU of the `quickshell`
  comm process launched WITHOUT `-vv` (`ps -o rss,pcpu -p <pid>`, `pidstat -p <pid> 5
  12`). Then per-component deltas by temporarily setting `Loader.active: false` on the
  wallpaper background layer, the widget canvas, and the carousel, one at a time, in the
  nested sandbox. Record every number in `docs/NOTES.md`.
- **Fix 1, verified waste:** `services/Toggles.qml` spawns `nmcli radio wifi` and
  `sh -c "bluetoothctl show | grep Powered"` every 5 s forever, whether or not anything
  displays the toggles. Replace with thin `services/Network.qml` (`Quickshell.Networking`:
  `Network.wifiEnabled`, writable) and `services/Bluetooth.qml` (`Quickshell.Bluetooth`:
  `Bluetooth.defaultAdapter.enabled`, writable), event-driven property bindings, zero
  subprocesses. `Toggles.qml` keeps its public API (`wifiOn/btOn/setWifi/setBt`) and
  delegates, so the dashboard grid is untouched. These two services then grow into the
  Bluetooth and Network settings screens (Slices 9 and 12) instead of being rewritten.
- **Fix 2, verified waste:** `services/SystemStats.qml` polls `/proc/stat`, `/proc/meminfo`,
  `df`, and hwmon every 3 s forever. Gate the poll `Timer` on a consumer being visible:
  `running: Island.isExpanded || Island.compactFace === "systemFace"`. Keep the existing
  250 ms first-sample follow-up so CPU% appears promptly when polling resumes.
- **Fix 3, operational:** the live autostart runs `qs -c kuroshima -vv`. Verbose logging
  costs CPU per line and inflates the baseline. Drop `-vv` from the niri autostart line
  in `~/Projects/cachyos-setup/kuro/wm/niri/cfg/` (separate repo; note it in NOTES, do not
  edit from this repo's session).
- **Candidate, measure before touching:** `ui/WallpaperBackground.qml` keeps two
  full-resolution decoded `Image` layers resident for the crossfade. After a fade
  completes, clearing the inactive layer's `source` drops one decoded texture. Only do it
  if the per-component measurement shows the wallpaper layer is a meaningful share.
- **Do not touch:** `EqualizerBars` (already `running: root.active`), the LIVE pulse
  (already `running: Media.isLive`), `Media`'s 1 s position tick (already only while
  playing), `System`'s 60 s uptime tick.
- **Deliverable:** a "Footprint" section in `README.md` with the measured RSS / idle CPU
  and what each optional layer costs, dated. A repo that says "lightweight" with numbers
  beats one that says it without.

### Slice 4: `faces/WeatherFace.qml` + `services/Weather.qml` + two `Config` keys

The only face with an external data source, so it is fenced off: nothing else depends on
it and it never fires a transient.

- `services/Config.qml` gains `weatherLat` / `weatherLon` (numbers, default `NaN` =
  unset), read from the existing `~/.config/kuroshima/config.json` (read once at
  startup, same as `notificationServer`). Update `config.example.json` and the README's
  config section. This satisfies the NOTES rule "add a config key only once something
  real consumes it".
- `services/Weather.qml` (QtObject singleton, named-property children): one reused
  `Process` running `curl -s` against open-meteo
  (`/v1/forecast?latitude=..&longitude=..&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code&timezone=auto`,
  no API key), `stdout` parsed as JSON the way `services/System.qml` parses
  `niri msg --json version`. Exposes `available` (location set AND at least one good
  response), `tempC`, `humidity`, `windKmh`, `code`, `label` (WMO code mapped to a short
  mono word: CLEAR / CLOUDY / FOG / RAIN / SNOW / STORM), `stale` (two consecutive
  failed polls), `updatedAt`. Poll `Timer` at 30 min, first fetch at startup via a
  reference from `app/Bridges.qml` (the lazy-singleton trap that bit `SystemStats` and
  `Brightness`). No location set: no `curl` ever runs. Process reuse coalesces
  overlapping calls the way `services/Brightness.qml` already does.
- `faces/WeatherFace.qml` (template `faces/ClockDate.qml`): clock, hairline divider,
  Nerd Font weather glyph for `code`, `tempC` in tabular numerals with a degree sign,
  `label` in mono uppercase. Dim the whole right half when `stale`. Unset location shows
  `WEATHER · SET LOCATION` dim (the discoverable-fallback precedent), so the face is
  still selectable and tells the user what to do.
- Register in `faceOrder` after `systemFace`.

### Slice 5: `services/Faces.qml`, Settings "FACES" panel, indicator ticks, user drop-in faces

Needed before the face count reaches 8+, otherwise swiping through everything to reach
one face gets tedious, and it answers the open questions logged in `docs/NOTES.md`
("Idea for a future slice: swipeable compact-mode pages").

- `services/Faces.qml` (QtObject singleton, FileView as a *named* property):
  `defaultOrder` (today's four ids plus the new ones), `order`, `current`,
  `setOrder(ids)`, `setCurrent(id)`, `_persist()`. Copy `services/Widgets.qml:114-132`'s
  `FileView { blockLoading: true; printErrors: false }` + try/JSON.parse/catch pattern
  verbatim. On load accept `order` only if it is a non-empty array of strings (dedupe),
  `current` only if a string; anything else leaves the defaults, identical to today.
  Add `singleton Faces 1.0 Faces.qml` to `services/qmldir`.
- **User drop-in faces** (rule 8): `Faces.qml` also scans `~/.config/kuroshima/faces/*.qml`
  the way `services/Widgets.qml` scans its `customTypes`, and `pages/CompactPage.qml`
  adds each as a `pageMap` entry via `Qt.createComponent(fileUrl)` alongside the bundled
  Components. A user face is a 40-line `Item` honouring the face contract in `CLAUDE.md`,
  no repo change. If wiring created Components into `PageHost.pageMap` proves awkward,
  ship bundled-only and log it; do not build a plugin API around it.
- `pages/CompactPage.qml` line ~54: `faceOrder` becomes
  `Faces.order.filter(id => facesHost.pageMap[id] !== undefined)`, falling back to
  `Faces.defaultOrder` when empty. Validating against `pageMap`, not just against itself,
  closes a hole `_syncFaceHost()` does not cover (an order entry missing from `pageMap`
  passes the membership guard, hits "PageHost: unknown page", and leaves a stale face).
  Add `onFaceOrderChanged: _syncFaceHost()` so disabling the current face heals at once.
- **Face indicator ticks** (rule 2): a row of 1px hairline ticks under the pill content,
  one per enabled face, the active one inverted to `Theme.ink`, shown for ~1 s after a
  swipe completes then faded out (`Motion.fadeDuration`). Makes the gesture a visible
  system instead of a secret; Tide's tile page is dumber but obvious, this closes that.
- `app/Island.qml`: keep `compactFace` as the live API (IPC `setCompactFace` unchanged).
  Line ~49 and the PersistentProperties default at line ~115 both become
  `Faces.current`, and `onCompactFaceChanged` (line ~122) adds
  `Faces.setCurrent(root.compactFace)`. `Faces` loads synchronously (blockLoading) on
  first evaluation, before `CompactPage`'s `Component.onCompleted` sync, so the existing
  loaded/reloaded race handling still covers everything. Needs `import qs.services`
  (precedent: `app/Bridges.qml`).
- `pages/SettingsFacesPanel.qml`: one row per face (bundled and user) with an enable
  toggle (`ui/ToggleButton.qml` reuse) and up/down arrows. Second `categories` entry in
  `pages/SettingsExpanded.qml` (the file was built for exactly this: an entry plus a
  Component).
- Also fixes the deliberately-deferred exclusive-zone issue partially: a user who
  dislikes the tall media face can now disable it. Dynamic `exclusiveZone` itself stays
  in the backlog (niri hang history, see there). Slice 4's `weatherFace` id joins
  `defaultOrder` here.

### Slice 6: lyrics as a subtitle line (`services/Lyrics.qml`, `faces/MediaFace.qml`, `pages/MediaExpanded.qml`)

Old Tide's headline media feature, moved out of the backlog because "shinier than Tide"
was the stated goal and this is the feature people screenshot. Kept deliberately small.

- `services/Lyrics.qml` (QtObject singleton): on `Media.trackChanged()` (already
  debounced and content-guarded), when `Media.available && title && artist && !isLive`,
  one reused `curl -s` `Process` against
  `https://lrclib.net/api/get?artist_name=..&track_name=..&duration=..` (free, keyless).
  Parse `syncedLyrics` (LRC `[mm:ss.xx] text` lines) into `[{t, text}]`; fall back to
  nothing if only `plainLyrics` exists (no sync, no subtitle). Expose `available`,
  `currentLine` derived from `Media.position` (1 s granularity, ±1 s sync is fine for a
  subtitle), `lines`. In-memory cache keyed on `Media.trackKey`, no disk cache. One fetch
  per track, never on position ticks. URL-encode with `encodeURIComponent`.
- `faces/MediaFace.qml`: when `Lyrics.currentLine` is non-empty, it replaces the artist
  line (crossfade via the existing `fadeDuration`), one mono line, elided. Never grows the
  face height.
- `pages/MediaExpanded.qml`: one dim mono line under the progress bar, same source.
- Data-honest: no line, no placeholder. Failure or 404 means the face looks exactly as it
  does today.

### Slice 7: niri event-stream extension, `faces/WorkspaceFace.qml`, cast indicator

- New `services/Niri.qml` (QtObject singleton, Process + SplitParser as named
  properties) takes over the single `niri msg --json event-stream` process from
  `services/Workspaces.qml:84-116`. It dispatches `workspacesChanged(var)` /
  `workspaceActivated(int)` signals and owns window/cast state; `Workspaces.qml` deletes
  its Process and replaces it with `Connections { target: Niri }` whose handlers hold
  the exact existing bodies, so its public API (and `WorkspacePeek`, `MediaExpanded`,
  `Bridges`) is untouched. One process, not two. Add `singleton Niri 1.0 Niri.qml` to
  `services/qmldir`. Lazy init still works: `Bridges` references `Workspaces`, whose
  `Connections.target` starts `Niri`.
- Confirmed live on niri 26.04: the stream opens with a full `WindowsChanged` snapshot
  (then `KeyboardLayoutsChanged`, `OverviewOpenedOrClosed`, `ConfigLoaded`,
  `CastsChanged`), so no separate `niri msg windows` query. Handlers: `WindowsChanged`
  replace, `WindowOpenedOrChanged` upsert by id, `WindowClosed` filter,
  `WindowFocusChanged` set `focusedId` only, `CastsChanged` replace. Seed `focusedId`
  from the snapshot's `is_focused`.
- Expose `windows` (`[{id, title, appId, workspaceId}]`, no focused flag stamped in),
  `focusedId: int`, and readonly derived scalars `focusedTitle` / `focusedAppId`
  (QML only notifies when the string value changes, so consumers do not churn on every
  retitle), `casts` raw plus `casting: casts.length > 0`. `title`/`app_id` are nullable,
  coerce with `|| ""`; live titles run ~150 chars, so every consumer elides.
- Reactivity trap (documented in `pages/WorkspacePeek.qml:44-56`): a Repeater whose
  model is a reassigned array tears down every delegate per event, and focus/retitle
  events are the most frequent ones. Repeaters over windows use `model: Niri.windows.length`
  and index in. Never fire a peek off `focusedTitle` (it is transiently `""` when a
  focus event names a window not yet in the list).
- The cast object shape (`stream_id`, `target`) is unverified (no cast was running);
  expose raw and check once with a real screencast before styling the indicator.
- `faces/WorkspaceFace.qml`: the dot row from `pages/WorkspacePeek.qml` (active dot grows
  to 14px, others 5px) plus `Niri.focusedAppId` in mono uppercase and the elided
  `focusedTitle`. Brings back the pre-plan prototype's window-title feature as a face.
- Cast indicator: a small `REC`-style glyph next to the bell in `pages/CompactPage.qml`
  when `Niri.casting` (privacy signal, always visible regardless of face). Plus a
  `cast` transient row in `core/Kinds.qml` (priority 35, 3200ms) shown from
  `app/Bridges.qml` on cast start/stop, reusing `pages/DummyWide.qml`'s label shape or a
  10-line `CastPeek`.

### Slice 8: `faces/TrayFace.qml`

Haziq's call (2026-09-22): a swipeable face, not a persistent row beside the bell.

- API confirmed in the installed qmltypes: `SystemTray.items` is Repeater-compatible;
  each `SystemTrayItem` has `icon` (url), `title`, `hasMenu`, `onlyMenu`, `menu`,
  `activate()`, `secondaryActivate()`. `Quickshell.Widgets.IconImage { source }` renders
  the icon. `QsMenuAnchor { menu; anchor.item; anchor.edges; anchor.gravity; open() }`:
  setting `anchor.item` derives the window from the item's PanelWindow, so the popup is
  an xdg_popup child of the layer surface, its own surface, unaffected by
  `IslandWindow`'s `mask: Region`.
- Delegate shape: a 16px `Item` slot per item with `IconImage` filling it, one
  `QsMenuAnchor` per slot (`anchor.edges/gravity: Edges.Bottom`), a left-button
  `TapHandler` (`onlyMenu ? menuAnchor.open() : activate()`) and a right-button one
  (`hasMenu ? menuAnchor.open() : secondaryActivate()`), both with
  `gesturePolicy: TapHandler.ReleaseWithinBounds`. Use `required property var modelData`
  inline (typed `required` properties stuck empty for external-file delegates, per NOTES).
- Empty state: `NO TRAY` dim text (the `faces/MediaFace.qml` idle-fallback precedent),
  still selectable so the face is discoverable.
- Two caveats to record in NOTES when shipping: `QsMenuAnchor` renders a native Qt popup,
  not a house-styled one (a themed menu means `QsMenuOpener` + a custom `PopupWindow`,
  much larger, backlog); and only one process can own `org.kde.StatusNotifierWatcher`,
  so if any other bar ever runs on the real session `SystemTray.items` is silently empty
  (same class as the notification-server D-Bus name conflict). If menus misbehave on
  niri, ship left-click-activate only and log the menu half as deferred.

## Wave 3: screens

### Slice 9: Settings "BLUETOOTH" panel (`pages/SettingsBluetoothPanel.qml`, grows `services/Bluetooth.qml`)

- `Quickshell.Bluetooth`: adapter power (already wired in Slice 3), `discovering`
  toggle, device list (name, icon, connected, paired, `battery` when
  `batteryAvailable`), connect/disconnect/forget. Same list-of-selectable-rows shape as
  `pages/SettingsAudioPanel.qml`'s device pickers.
- No keyboard needed, so lower risk than Network. Third `categories` entry.

### Slice 10: `pages/CalendarExpanded.qml` + push/pop table

- Month grid (pure QML date math, no ical), today inverted bone-on-black like the active
  workspace pill, prev/next month glyphs plus a `WheelHandler` for month browsing (Tide
  parity, cheap), week starts Monday, ISO week numbers as a dim left column. Reached by
  tapping the header date in `pages/MediaExpanded.qml`, back arrow returns (same chrome
  as `SettingsExpanded`). Distinct from Tide's: a dossier header row of tabular stat
  cells (DAY 265 / 365, WEEK 39, `Q3`) above the grid, hairline rules, no coloured event
  dots.
- Generalize `ui/Capsule.qml:32-44`'s `directionFor()` into a child->parent table:
  `pageParents: ({ "SettingsExpanded": "MediaExpanded", "CalendarExpanded": "MediaExpanded" })`,
  `pushRight` when `pageParents[next] === prev`, `popLeft` when
  `pageParents[prev] === next`, else `fade`. Both sides gate on the same lookup, so
  auto-collapse to `compact`, first launch (`prev === ""`), and a peek over Settings all
  stay `fade` (the one-sided match was a real refuter-caught bug). Nested stacks later are
  one more row. Call sites unchanged.
- Entry point: a `TapHandler` on the header date `Text` in `pages/MediaExpanded.qml`
  (~line 147). `MediaExpanded` has no root TapHandler, so no nested-grab trap there. Back
  button mirrors `pages/SettingsExpanded.qml:81`. `pageMap` + Component entry in
  `ui/Capsule.qml`.

### Slice 11: `wantsKeyboard` generalization + `pages/WindowSwitcher.qml`

- Replace the three `"AppLauncher"` string checks with the page contract's
  existing-but-unread `wantsKeyboard`. Do this only after the favourites session has
  committed (it touches the launcher's surroundings).
  - `ui/Capsule.qml`: `readonly property bool pageWantsKeyboard:
    host.currentItem !== null && host.currentItem.wantsKeyboard === true` (same
    optional-prop idiom as `cornerRadius` in `ui/PageHost.qml:47`; expect one more
    qmllint `missing-property` warning of the known class).
  - `ui/IslandWindow.qml:50`: `keyboardFocus: capsule.pageWantsKeyboard ? Exclusive : None`.
  - `ui/Capsule.qml:152`: `shouldAutoCollapse` adds `&& !pageWantsKeyboard`.
  - `expandedBlockBelow` cannot read the item: rule 2 runs inside the controller while a
    peek is current and the expanded page item does not exist then (PageHost destroys the
    outgoing slot). Use the view-writes-controller-input precedent (`Island.hovered`):
    `app/Island.qml` gains `property bool expandedWantsKeyboard: false`, line ~81 becomes
    `expandedBlockBelow: expandedWantsKeyboard ? 999 : 40`, and Capsule latches it:
    `onPageWantsKeyboardChanged: if (Island.expandedPage === "" || host.pageName ===
    Island.expandedPage) Island.expandedWantsKeyboard = pageWantsKeyboard`. The guard
    keeps it latched while a peek covers the page and resets on collapse.
  - `ui/AppLauncher.qml` declares `readonly property bool wantsKeyboard: true`.
  - **Rule**: `wantsKeyboard` must be a per-page constant. A page toggling it on
    TextInput focus would reconfigure the mapped layer surface repeatedly, the class of
    change with hang history. Any new keyboard page copies the launcher's three
    mitigations: idle timeout to `Island.collapse()`, the 999 gate, `Qt.callLater(forceActiveFocus)`.
  - Verify in the nested sandbox with `timeout`, reading `keyboardFocus` back via a
    temporary `console.log` (not `niri msg layers`).
- `pages/WindowSwitcher.qml`: keyboard-driven list of `Niri.windows` (app icon via
  `Quickshell.iconPath(app_id)`, title, workspace index), Up/Down or typed filter, Enter
  runs `timeout 2 niri msg action focus-window --id N` via `Process`, Esc closes. New
  IPC `switcherToggle()` in `shell.qml`, bound in niri to `Mod+Tab` (free today; `Mod+O`
  is the native overview). Reuses `ui/AppLauncher.qml`'s idle timeout and key handling
  shape.

### Slice 12: Settings "NETWORK" panel (`pages/SettingsNetworkPanel.qml`, grows `services/Network.qml`)

- `Quickshell.Networking`: wifi enabled (already wired in Slice 3), scanned `networks`
  with `signalStrength` and `security`, `known`, connect / `connectWithPsk` / forget.
- The PSK field is the first text input inside Settings. Because `wantsKeyboard` must be
  a page constant (Slice 11), password entry is its own pushed screen,
  `pages/WifiPasswordExpanded.qml` (`wantsKeyboard: true`, one row
  `"WifiPasswordExpanded": "SettingsExpanded"` in the parent table, the launcher's three
  mitigations copied). Simpler fallback if that is too much for one session: v1 connects
  to known networks only and defers PSK entry.

## Backlog (not scheduled, listed so they stop being re-derived)

- NIGHT toggle: needs `gammastep` installed (absent today). Then a Process-driven
  `Toggles.nightOn` (`gammastep -O 4500` / kill), `available` only when the binary
  resolves, same dim-when-absent rule.
- Weather 3-day forecast row (daily min/max) under the current conditions, once Slice 4
  has proven the fetch path.
- Themed tray menu: `QsMenuOpener` + a house-styled `PopupWindow` replacing the native Qt
  popup from Slice 8. Only if the native popup grates in daily use.
- `faces/InboxFace.qml`: latest notification app + summary + unread count. Marginal over
  the existing bell, cheap.
- Clipboard text history screen (cliphist): retry as an Island Screen, not a face. Root
  cause of the dropped face section's dead clicks was never found and the diagnosis ran
  on unreliable tooling (`grim` stale frames, binary `log.qslog`). Time-box one session.
- Dynamic `exclusiveZone` tracking the active face height (`ui/IslandWindow.qml`).
  Changing the zone live on a mapped surface reproduced a niri hang on the old centered
  anchor; the full-width anchor is proven but live changes are not. Sandbox only, with
  `timeout`, and the Slice 5 enable/disable already removes most of the pain.
- Launcher `=expr` calculator via `qalc` and a "run command" fallback: same file the
  favourites session owns, so after it lands.
- Widgets (not the ask, one line): NowPlaying and SystemStats widgets are near-free given
  the services, if the widget canvas gets more use.
- VPN toggle: needs a real profile to drive; CAPS: no caps-lock source exposed by
  Quickshell or niri IPC. Both stay dimmed.
- Weather location field in the Settings island screen: a lat/lon text input writing
  straight to `config.json`, replacing the current hand-edit-the-file workflow. Raised
  live once Slice 4's fetch was confirmed working (Kuala Lumpur coords). Deliberately
  deferred past Slice 4/5: Slice 5's FACES panel is enable/disable + reorder only, not
  per-face settings, and a one-off settings field for a single face doesn't earn a new
  panel pattern on its own. Worth a look once more than one face wants user-set config.

## Standing traps (every slice re-reads this list)

- Only one `qs` instance at a time; `ps -eo pid,cmd | grep -iE "quickshell|qs -c kuroshima"`
  is the check that catches the autostarted one.
- QtObject-rooted singletons need *named* child properties (FileView, Process, Timer).
- Manual `services/qmldir` needs an explicit `singleton` line per new service.
- Repeater over a reassigned array of plain objects destroys delegates every event.
- Nested TapHandlers inside the compact pill need `gesturePolicy: TapHandler.ReleaseWithinBounds`.
- A DND-suppressed notification must still be `expire()`d.
- `wantsKeyboard` is a per-page constant, never toggled at runtime.
- `Faces.order` entries are validated against `facesHost.pageMap`, not just each other.
- niri `title`/`app_id` are nullable; `focusedTitle` can be `""` transiently.
- Real `qs -c kuroshima` hot-reloads on save, so edits land on the live desktop; a brand
  new top-level `IpcHandler` target needs a restart.
- No new polling subprocess when a Quickshell module already exposes the state (rule 7).

## Files touched per wave (for the concurrent-session check)

- Wave 1: `faces/StatusFace.qml`, `faces/SystemFace.qml`, `faces/FocusFace.qml` (new);
  `services/Focus.qml` (new, plus a `services/qmldir` line); `services/Notifs.qml`,
  `services/Toggles.qml`, `app/Bridges.qml`, `ui/IslandWindow.qml` (one additive
  `IdleInhibitor` child only), `pages/MediaExpanded.qml` (TOGGLES grid only),
  `pages/CompactPage.qml` (`faceOrder` + Component entries). Not touched:
  `ui/AppLauncher.qml`, `services/Apps.qml`, `shell.qml`, `ui/Capsule.qml`.
- Wave 2: `faces/WeatherFace.qml`, `faces/WorkspaceFace.qml`, `faces/TrayFace.qml`
  (new); `services/Network.qml`, `services/Bluetooth.qml`, `services/Weather.qml`,
  `services/Faces.qml`, `services/Lyrics.qml`, `services/Niri.qml` (new, plus qmldir
  lines); `services/Toggles.qml`, `services/SystemStats.qml`, `services/Config.qml`,
  `config.example.json`, `README.md`, `services/Workspaces.qml`, `core/Kinds.qml`,
  `app/Bridges.qml`, `app/Island.qml`, `pages/CompactPage.qml`, `faces/MediaFace.qml`,
  `pages/MediaExpanded.qml` (lyrics line only), `pages/SettingsExpanded.qml` (one
  `categories` entry), `pages/SettingsFacesPanel.qml` (new). Still not touched:
  `ui/AppLauncher.qml`, `services/Apps.qml`, `shell.qml`, `ui/Capsule.qml`.
- Wave 3: `ui/Capsule.qml`, `ui/IslandWindow.qml`, `app/Island.qml`, `shell.qml`, new
  pages and services listed per slice. Start only after the favourites work is
  committed.

## Verification (every slice)

1. `bash scripts/lint.sh` clean apart from the 4 documented `qs.*` noise categories;
   `bash scripts/test.sh` still 24/24 (add controller tests only if `Kinds` rows change).
2. Nested sandbox (`niri -c ~/dev-niri.kdl`, `Mod+I`), every `niri msg` wrapped in
   `timeout`. One `qs` instance at a time (`ps -eo pid,cmd | grep -iE "quickshell|qs -c kuroshima"`).
3. Footprint (rule 7): `ps -o rss,pcpu -p <pid>` before and after any slice that adds a
   service; the number goes in the NOTES entry. Slice 3 additionally records the
   per-layer deltas and 60 s idle CPU.
4. Faces: `qs -p . ipc call island setCompactFace <id>` lands on the new face, capsule
   width/height follow the face, swipe left/right still cycles, a bogus id self-heals,
   the indicator ticks appear after a swipe and fade. Tap a face control and confirm the
   dashboard does NOT expand (ReleaseWithinBounds).
5. DND: `notify-send` with DND on records in INBOX and shows no peek; critical urgency
   still peeks; DND off restores peeks. IDLE: watch the idle timeout not fire in the
   sandbox while the toggle is on.
6. Screens: `ipc call island expand <PageId>` morphs correctly, back arrow pops, a
   transient over the screen fades (no spurious slide), auto-collapse still works, and
   for keyboard pages read the `keyboardFocus` property back via a temporary
   `console.log` (not `niri msg layers`, documented unreliable).
7. Ask Haziq to look at the real screen for anything visual; self-captured `grim`
   frames can be stale on this machine.
8. Run the `refuter` agent on the diff before each commit; add a `docs/NOTES.md` entry
   and a `CHANGELOG.md` line per slice.
