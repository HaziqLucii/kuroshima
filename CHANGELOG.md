# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows
[Semantic Versioning](https://semver.org/).

Tags mark logical checkpoints, not every commit. See `git log` for the full
history and `docs/NOTES.md` for decision-level detail.

## [Unreleased]

### Added

- `faces/FocusFace.qml` + `services/Focus.qml`: a pomodoro-style timer
  Island Face, desktop echo of the maintainer's own `~/Projects/kuro-focus`
  "expedition timer" (same dossier aesthetic, no sync between the two
  apps). Idle shows preset chips (25/50/5 min, tap to start); a running
  session shows `mm:ss`, pause/reset glyphs, and a hairline progress bar.
  On completion, a `notify-send` lands in INBOX and fires the existing
  `NotificationPeek` bridge like any other notification - no new
  `core/Kinds.qml` row needed. Tried pinning the face to exactly
  `Theme.compactH` in both states first (the original plan) - overflowed
  the pill live, so it grows with real padding once a session is running,
  same resolution `faces/MediaFace.qml` already reached for the identical
  reason.
- DND and IDLE toggles in the TOGGLES grid are real now, not dimmed
  placeholders: DND (`services/Notifs.qml`) suppresses notification peeks
  (critical urgency still shows) while keeping them in INBOX, and swaps the
  compact pill's shared bell indicator for a slashed glyph, visible on
  every face; IDLE (`services/Toggles.qml`) inhibits the compositor's idle
  timeout via niri's `zwp_idle_inhibit_manager_v1`. Two new Island Faces:
  `faces/StatusFace.qml` (clock plus whatever's currently true -
  WIFI/BT/IDLE/mic-muted - collapsing to just the clock otherwise; no DND
  glyph here specifically, the shared bell above already covers it and
  showing it twice was a duplicate caught live) and
  `faces/SystemFace.qml` (CPU/MEM/TEMP mini-bars, compact-pill sized).
- Favorite apps in the launcher (`Mod+Space`): star up to 4 apps and they
  show in a dedicated FAVORITES section above the results, visible only
  while the search box is empty. Single-tap launches a favorite directly
  (no select-then-launch step, unlike the main results row) - the whole
  point is fastest possible access. Star toggle on every card in both
  rows, persisted to `~/.config/kuroshima/favorites.json`
  (`services/Favorites.qml`, same `FileView` pattern `services/
  Widgets.qml` already established). The shared card markup moved out of
  `ui/AppLauncher.qml`'s own inline `ListView` delegate into a new
  `ui/AppCard.qml`, reused by both rows.
- A "clipboard" Island Face (`faces/ClipboardFace.qml`, `services/Clipboard.qml`):
  drag files onto it from one workspace, they stay staged as removable chips,
  drag them back out to another app/workspace elsewhere. Real cross-application
  Wayland drag-and-drop on this project's own wlr-layer-shell surface, proven
  working both directions via a standalone feasibility spike before this was
  built. Chips wrap onto new rows (`Flow`, not a scrolling `ListView` - the
  first version scrolled, but that competed with the face-swipe gesture for
  the same horizontal drag, see the fix below) with a real-file thumbnail
  (`Item.grabToImage`-based, capped to a small `sourceSize` so a dropped
  photo doesn't decode at full native resolution) or an extension-text
  fallback for non-images, each with a remove badge. Dragging a chip back out
  shows a correctly-sized, rounded drag-cursor icon (also grabbed, not the
  raw file). Pure in-memory staging, not persisted across restarts. A
  text-clipboard section (backed by `cliphist`) was built and tried
  alongside this too, but dropped - its rows never received clicks no matter
  what was tried, while the file half worked correctly throughout, so it
  shipped without that half rather than keep chasing it.
- Fixed a real gesture-conflict bug in `pages/CompactPage.qml`'s face-swipe
  `DragHandler` while building the clipboard face above: it had no explicit
  `dragThreshold`, so it claimed the pointer grab on almost any movement
  anywhere on the pill (Qt's small platform default), before a chip's own
  nested drag-out `DragHandler` ever got a chance to react - dragging a file
  back out was completely impossible, the pill just swiped between faces
  instead. Now gated on the same `Motion.compactFaceSwipeThreshold` (40px)
  already used to decide whether a genuine swipe happened, so it doesn't
  even start tracking until that's exceeded. See `theme/Motion.qml`'s own
  comment on that constant before lowering it.
- An in-island app launcher (`Mod+Space`), replacing fuzzel entirely: a
  search bar plus a horizontally-scrollable, keyboard-navigable app row. A
  real page in the capsule (`ui/AppLauncher.qml`), not a separate popup
  window - morphs open/closed through the same spring animation every other
  page already uses. Real desktop-entry discovery (`scripts/list-apps.py`,
  `services/Apps.qml`) - 97 launchable apps on this machine, real icons via
  `Quickshell.iconPath`, real launching via `Quickshell.execDetached`
  (terminal apps wrapped in `kitty -e`).
- The "media" Island Face is a real player now, not just title/artist text:
  real album art, progress bar, prev/pause/next transport, and an equalizer
  at the trailing edge (reusing the existing `ui/EqualizerBars.qml`, not new
  dithering code). The compact pill's own height now tracks whichever face
  is active instead of a fixed size, so this face grows/shrinks it smoothly.
  `pages/MediaPeek.qml` (the transient track-change popup) got the same
  real-art-plus-equalizer treatment.
- Read-only IPC bridge for the sibling `niri-lockscreen` project's "WHILE
  AWAY" notifications panel: `qs ipc call notifications history` returns the
  same capped `services/Notifs.qml` history the dashboard's INBOX already
  shows, as a JSON string. No new state, no change to the real notification
  lifecycle - kuroshima owns `org.freedesktop.Notifications` on this
  machine, so a sibling shell can't run its own `NotificationServer` to get
  the same data.
- Island Faces: the compact pill swipes between several faces of content
  instead of one fixed layout (`faces/ClockEq.qml`, `faces/ClockDate.qml`,
  `faces/MediaFace.qml`). Reuses `ui/PageHost.qml` (a second, independent
  instance nested in `pages/CompactPage.qml`) for the switch, so it gets
  the same spring-eased slide transition real pages already have, no new
  animation code. Selected face persists across hot reload
  (`app/Island.qml`'s `compactFace`, same `PersistentProperties` pattern
  as `expandedPage` - not across a real process restart, that would need a
  `FileView`, not added). A new `IpcHandler` function,
  `qs ipc call island setCompactFace <id>`, switches faces directly.
- Desktop widget canvas: `Mod+Shift+W` toggles an edit mode on a new
  background-layer surface (`ui/WidgetCanvas.qml`, `ui/WidgetFrame.qml`,
  `services/Widgets.qml`). Any widget can be dragged to move; click one to
  focus it and reveal its resize handle and delete badge. `<Enter>` defocuses
  (stays in edit mode), `<Escape>` exits edit mode entirely. An
  "+ ADD WIDGET" picker lists every available type. Widgets are plain `.qml`
  files - bundled ones in `widgets/` or user-dropped ones in
  `~/.config/kuroshima/widgets/`, no repo changes needed for the latter.
  Position and size persist to `~/.config/kuroshima/widgets.json`. New widget
  contract documented in `CLAUDE.md`. Widget content is explicitly not held
  to this repo's bone-on-black rule - see `docs/NOTES.md`.
- `widgets/GoodNight.qml`: a centered greeting/day/date/time card (inspired
  by a ryoku.dev showcase widget), the first real bundled widget alongside
  the `Clock` placeholder. "Fraunces 144pt" (Black) for the day abbreviation
  - needs `ttf-fraunces` from the AUR, see the README's Widgets section.
  Two-line greeting ("GOOD" / mood-word, always, so "GOOD AFTERNOON" isn't
  visibly wider than the other three), long thin `Theme.ink` hairline ticks
  with a real gap around them, tight spacing within the text block itself.
  Greeting, date, and time lines use "Poppins" (greeting: Medium, wide
  letter-spacing) instead of the monospace meta font - needs `ttf-poppins`
  from the AUR, see the README's Widgets section.
- Wallpaper carousel (`Mod+P`, `ui/WallpaperCarousel.qml`,
  `services/Wallpaper.qml`) documented for the first time: it existed and
  worked, but had no README section and no printed `install.sh` keybind
  step. Both added, see the README's Wallpaper carousel section.
- Wallpaper background (`ui/WallpaperBackground.qml`) crossfades between
  wallpapers (~480ms, slight zoom-settle) instead of popping instantly,
  on both live-preview and commit.
- Wallpaper carousel's tiles are now an accordion of thin vertical strips,
  the current one widening into a full bordered rectangle - not a
  uniform-width filmstrip. Header and statusline text sit on their own
  bordered backing panel for readability over bright wallpapers; the
  per-tile filename caption is gone.
- Settings island screen: a new gear button in the dashboard header
  (`pages/MediaExpanded.qml`) pushes `pages/SettingsExpanded.qml` in with
  a real slide + back button, not the usual plain crossfade -
  `ui/PageHost.qml` gained a `direction` param
  (`"pushRight"`/`"popLeft"`/default `"fade"`, every other page
  transition unchanged) for it. Left sidebar of icon "bubbles" (Audio
  today, built to take more categories later without restructuring).
  `pages/SettingsAudioPanel.qml`: output/input device pickers, master
  volume, and a per-app volume mixer, backed by new
  `Audio.sinks`/`sources`/`appStreams` (`services/Audio.qml`, from
  `Quickshell.Services.Pipewire`'s `Pipewire.nodes`) and
  `Audio.setDefaultSink()`/`setDefaultSource()`.
- Settings push/pop transition: a full Android/iOS-style stack push (solid,
  no fade, full-width travel) didn't match this app's own restraint
  elsewhere and got dropped after seeing it live. What ships instead is
  the same fade/4px-rise every other page transition already has, plus a
  small fixed 32px directional `riseX` nudge (`Motion.pushSlideDistance`)
  spring-eased with the exact same values (`Motion.morphSpring`/
  `morphDamping`/`morphMass`) the capsule's own width/height/radius morph
  already uses.
- A "weather" Island Face (`plans/2026-09-22-faces-and-screens-plan.md`'s
  Slice 4): `services/Weather.qml` polls open-meteo.org (no API key) every
  30 minutes for the two new `config.json` coordinates
  (`weatherLat`/`weatherLon`), exposing temperature, a short WMO-code-derived
  label (CLEAR/CLOUDY/FOG/RAIN/SNOW/STORM), and a `stale` flag after two
  consecutive failed polls. `faces/WeatherFace.qml` shows a Nerd Font glyph,
  `°C`, and the label next to the clock, distinguishing three non-fetching
  states (no location configured, first fetch still pending, or configured
  but never once succeeded) rather than collapsing them into one misleading
  "set your location" message - refuter caught the original version doing
  exactly that. The only face with an external data source; nothing else in
  the app depends on it.
- Island Faces are user-configurable now (`plans/2026-09-22-faces-and-screens-plan.md`'s
  Slice 5): a new Settings category, FACES, lists every bundled face as a
  card with a live preview (the real face Component, rendered inside a
  small replica of the actual floating capsule - not a mockup), a
  track-and-thumb enable/disable switch, and up/down reorder chevrons,
  with a column legend above the list naming what each control does. State
  (`services/Faces.qml`) persists to `~/.config/kuroshima/faces.json`
  across real restarts, unlike `app/Island.qml`'s existing hot-reload-only
  persistence. Disabling a face always leaves at least one enabled.
  Rebuilt twice from live feedback: an initial single-line row cut most
  faces' content off, and a first card version still forced every preview
  into one shared fixed-height strip (illegible for
  `faces/ClipboardFace.qml`'s taller idle state) before landing on the
  per-face capsule-replica sizing that shipped. User drop-in faces (a
  `~/.config/kuroshima/faces/*.qml` scan) were in the original plan for
  this slice but dropped - see `services/Faces.qml`'s own comment. A face
  indicator-ticks overlay was also built, live-tested, and then removed
  entirely after the maintainer felt it broke the pill's own visual
  identity ("lost the feel of dynamic island").

### Fixed

- App launcher: a real notification or volume/brightness OSD firing while
  the launcher was open used to preempt it entirely - silently wiping the
  in-progress search and dropping the island's keyboard focus for the
  peek's whole duration, leaking keystrokes into whatever window was
  underneath. Notifications and OSDs now queue behind the launcher instead
  of interrupting it. Also: `scripts/list-apps.py` was leaking a literal
  field code (e.g. `%u`) into real launch commands for apps whose `Exec=`
  embeds one inside a larger argument (confirmed against the real Spotify
  entry on this machine) - fixed to strip field codes as substrings, not
  just whole tokens.
- Island Faces: an unrecognized `compactFace` value (a typo'd IPC call, or
  a face id renamed out from under a value that survived a hot reload)
  would have permanently killed the swipe gesture in both directions until
  a full process restart, since the same bad value never got corrected
  once `Island.compactFace` held it (refuter-caught before this ever
  shipped). Self-heals back to the default instead.
- Opening the expanded dashboard's INBOX after a notification's peek had
  timed out crashed the whole shell (real segfault, not a QML warning) if
  that notification had an action - `app/Bridges.qml` destroys the
  underlying notification object almost immediately once its peek ends,
  and a since-reverted attempt at keeping its actions clickable from
  history held onto a dangling reference to it. Reverted; acting on a
  notification only works from the transient peek now, same as before -
  see `docs/NOTES.md` for why that's not really a regression given how
  this app's notification lifecycle actually works.
- `pages/NotificationPeek.qml` rendered a sender's implicit "default"
  action (freedesktop spec: invoke on body click, not a separate button)
  as a literal button and hid the real message underneath it - visible
  as e.g. WhatsApp Web notifications via Firefox showing "Activate"
  instead of the message. Filtered out of the rendered action list; tapping
  the body now invokes it if present, matching the spec's own convention.
- `pages/NotificationPeek.qml` had a fixed 100px height (`Theme.notificationH`,
  now removed) regardless of actual content, leaving real dead space
  above/below shorter notifications. Height now derives from the icon/
  text content itself, as compact as the content allows.
- Expanded dashboard's overall height (`Theme.expandedH`, fixed 650px)
  left a large dead gap between 06 INBOX and the 07 SESSION footer
  whenever INBOX had few/no notifications - `pages/MediaExpanded.qml`'s
  height is content-derived now, and the footer sits directly below the
  rest of the content instead of being separately anchored to the page's
  bottom to work around the old fixed-height gap.
- Wallpaper carousel's background scrim was too light for its header/footer
  text (WALLPAPER label, selection counter, keyboard hints) to read clearly
  over a bright wallpaper - `opacity: 0.34` -> `0.62`.
- Wallpaper background crossfade could silently stall one step when
  stepping back onto a recently-shown wallpaper (reassigning an `Image`
  source to a URL it already held fired no change signal), skipping
  straight past that image instead of crossfading to it.
- `services/Audio.qml`'s new sink/source/app-stream filters used "any bit
  overlaps" (`!== 0`) instead of mask-equality against `PwNodeType`'s
  composite bitflags, so every list matched almost every audio node
  regardless of kind (refuter-caught before this ever shipped, full
  writeup in `docs/NOTES.md`).
- `app/Bridges.qml`'s OSD-suppression guard only recognized
  `"MediaExpanded"` by name, so adjusting volume from the new Settings
  Audio panel re-triggered the exact "OSD morphs the expanded dashboard
  down mid-drag" bug its own comment already documented being fixed once.
  Generalized to plain `Island.isExpanded`.
- App launcher: Left/Right/Home/End keyboard navigation was a real,
  pre-existing bug, not just untested - plain top-level `Shortcut` items
  on the assumption that `Qt.WindowShortcut` context fires regardless of
  which item has focus, but the focused search `TextInput`'s own native
  cursor-movement handling for those exact keys consumed them first, so
  the `Shortcut` items never activated at all (confirmed via a real
  console.log trail, surfaced while building the favorites feature
  above). Moved onto `searchInput` itself as explicit `Keys.onXPressed`
  handlers that mark the event accepted before TextInput's own handling
  can claim it.

### Changed

- Footprint honesty pass (`plans/2026-09-22-faces-and-screens-plan.md`'s
  Slice 3): `services/Toggles.qml`'s WIFI/BT state used to come from
  polling `nmcli`/`bluetoothctl` as subprocesses every 5s forever,
  regardless of whether the toggle was ever on screen. Replaced with
  `services/Network.qml`/`services/Bluetooth.qml`, thin event-driven
  wrappers around Quickshell's own `Quickshell.Networking`/
  `Quickshell.Bluetooth` modules - zero subprocesses, `Toggles.qml`'s own
  public API unchanged so nothing downstream needed to change.
  `services/SystemStats.qml`'s own 3s `/proc`/hwmon poll is now gated on
  a real consumer being visible (the dashboard's SYSTEM section, or the
  compact-pill `SystemFace`) instead of running forever. Measured, not
  asserted: idle CPU dropped roughly 4x (~0.35% -> ~0.083% over a 60s
  window); RSS stayed flat (~454 -> ~459 MB), as expected - it's
  dominated by the Qt/QML engine itself, not these subprocesses. Full
  numbers and methodology in the README's new Footprint section.

## [0.3.0] - 2026-09-20

### Added

- Bundled `fastfetch/config.jsonc`: a plain-text `//kuroshima クロシマ` header
  line above the spec box, replacing a machine-specific FF7-disc image logo. No
  image logo at all, after an image wordmark kept clipping unpredictably
  regardless of padding - see `docs/NOTES.md`.

### Changed

- Default (and now only bundled) terminal switched from foot to kitty: kitty
  supports yazi's Drag and Drop protocol, which foot doesn't implement at all.
  Dropped foot entirely - `foot/`, `fastfetch/foot.jsonc`, and the
  `fastfetch.fish` $TERM-routing wrapper are gone, `keybinds.kdl`'s
  `Mod+T`/`Mod+E` now spawn kitty.

### Fixed

- `kitty.conf` needed `shell fish` (niri's own environment has `SHELL=/usr/bin/zsh`,
  not the account's real login shell, so kitty was silently launching zsh) and
  `confirm_os_window_close 0` (kitty was asking "are you sure?" every time yazi was
  exited via `Mod+E`).

## [0.2.0] - 2026-09-20

### Added

- Bundled dotfiles, installed and symlinked by `install.sh` the same way as the
  existing fuzzel theme: `foot/foot.ini` (bone-on-black, opaque), `fastfetch/foot.jsonc`
  (no image logo, foot can't render it) with a `fish/functions/fastfetch.fish` wrapper
  that routes to it whenever `$TERM` is `foot`, and a full `yazi/` setup (bone-on-black
  `theme.toml` built from yazi's own upstream defaults, `//kuro.` status-bar mark via
  `init.lua`, `smart-enter` plugin wired through `keymap.toml`/`package.toml`) plus a
  `fish/functions/y.fish` shell wrapper. See the README's Foot/Fastfetch/Yazi sections.
- `install.sh` now prints the extra manual steps these need: a `Mod+E` niri keybind for
  yazi, and an `EDITOR`/`VISUAL` addition to niri's `environment{}` block.

### Fixed

- Yazi's `<Enter>` crashed on every directory (`process exited with status code: 127`):
  stock yazi tries to open directories with `${EDITOR:-vi}` before navigating into them,
  and this system has neither set. Fixed via the `smart-enter` plugin (navigate dirs,
  open files) and by actually setting `EDITOR`/`VISUAL`. Full root-cause writeup in
  `docs/NOTES.md`.
- Media thumbnail in the expanded dashboard's MEDIA section was a fixed 54x54 box
  regardless of the row's real (taller) height, floating with visible dead space
  above/below. Now sized off the info column's own `implicitHeight`.

### Changed

- Renamed the project from `dynamic-island` to `kuroshima` (黒島, "black island"):
  repo, Quickshell scope name (`qs -c kuroshima`), config directory
  (`~/.config/kuroshima/`), and `WlrLayershell` namespaces. See `docs/NOTES.md`
  for the full list of what moved and what was deliberately left as historical
  record.

## [0.1.0] - 2026-09-20

First release. Covers the whole project as it stands: full Noctalia
replacement for niri (bar-adjacent OSD/notifications/media/power), not a
retroactive split of the ~47 commits that got here.

### Added

- Layer-shell anchored capsule window with a state machine (`IslandController`)
  driving compact-idle <-> transient-peek <-> expanded-dashboard morphs, spring
  animation, and page crossfade.
- Transient peeks: volume/brightness OSD, media, notifications, workspace
  switches, power/battery.
- Full expanded dashboard, 7 sections: identity (clock/date/host/uptime),
  media (MPRIS via `Media.qml`, click-drag scrubbing), controls (volume/mic/
  brightness via PipeWire and DDC/CI), toggles (WiFi/BT/mic + dimmed
  no-backend cells), system stats (CPU/RAM), inbox (notification history,
  clear-all), session (workspace pills, lock/sleep/power actions).
- IPC surface (`qs ipc call island <fn>`): `demo`, `expand`, `page`,
  `collapse`, `toggle`, `dismiss`.
- Config system (`~/.config/dynamic-island/config.json`, seeded from
  `config.example.json`), off-by-default notification server to avoid
  fighting an existing daemon for the D-Bus name.
- `install.sh`: symlinks the repo into Quickshell's config path, seeds
  config, links a bundled Kuro-matched fuzzel theme (`fuzzel/fuzzel.ini`).
- `scripts/dev.sh` (hot-reload dev loop), `scripts/lint.sh` (qmllint sweep),
  `scripts/test.sh` (`IslandController` state-machine suite via
  `qmltestrunner`).
- Bone-on-black theme (`theme/Theme.qml`, `theme/Motion.qml`): no accent hue,
  hierarchy via ink brightness, full invert on hover/active states.

### Fixed

Selected real-use fixes from the post-freeze polish pass (full detail in
`docs/NOTES.md`):

- Brightness/CPU stats appearing late after a restart (lazy-singleton
  instantiation, DDC/CI bus auto-detection overhead).
- INBOX section clipping/overlap bugs (ListView clip height, SESSION row
  collision), then turned into a deliberate 1.5-card "sneak peek".
- INBOX header now always shows; the unread badge hides only at zero.
- Media remaining-time showing "0:00" during the async MPRIS metadata window,
  with a "please refresh" fallback if it's genuinely stuck.
- Text/icon misalignment in LOCK/SLEEP/POWER and media transport buttons.
- Compact pill collapsing to clock-only the instant playback actually stops,
  not just when the player object disappears.
