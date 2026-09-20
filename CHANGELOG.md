# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows
[Semantic Versioning](https://semver.org/).

Tags mark logical checkpoints, not every commit. See `git log` for the full
history and `docs/NOTES.md` for decision-level detail.

## [Unreleased]

### Added

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

### Fixed

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
