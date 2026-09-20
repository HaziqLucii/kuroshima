# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows
[Semantic Versioning](https://semver.org/).

Tags mark logical checkpoints, not every commit. See `git log` for the full
history and `docs/NOTES.md` for decision-level detail.

## [Unreleased]

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
