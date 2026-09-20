# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows
[Semantic Versioning](https://semver.org/).

Tags mark logical checkpoints, not every commit. See `git log` for the full
history and `docs/NOTES.md` for decision-level detail.

## [Unreleased]

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
