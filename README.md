# dynamic-island

Apple-style Dynamic Island for niri, built with Quickshell/QML. A single top-anchored
capsule that morphs between a compact idle pill and transient peeks (volume/brightness
OSD, media, notifications, workspace switches, power/battery), plus a full dashboard on
click/expand: identity, media controls, volume/brightness/mic, quick toggles, system
stats, notification inbox, and workspace/session controls.

Compositor support: niri only, for now.

## Install

```sh
./scripts/install.sh
```

This symlinks the repo into `~/.config/quickshell/dynamic-island` (so `qs -c
dynamic-island` finds it), seeds `~/.config/dynamic-island/config.json` from
`config.example.json` on first run, and links `fuzzel/fuzzel.ini` (bundled - see
Fuzzel theme below) to `~/.config/fuzzel/fuzzel.ini` unless you already have a real
(non-symlink) fuzzel config, which it leaves alone. It does not touch niri's or
Noctalia's config - those are printed for you to apply by hand:

1. **niri autostart** (`~/.config/niri/cfg/autostart.kdl` or wherever your `spawn-sh-at-startup`
   lines live):
   ```kdl
   spawn-sh-at-startup "qs -c dynamic-island"
   ```

2. **niri layer rule** (`~/.config/niri/cfg/rules.kdl`), so niri treats the island as its
   own layer-shell surface:
   ```kdl
   layer-rule {
       match namespace="dynamic-island"
   }
   ```

3. **If you run Noctalia** (or any other shell providing notifications/OSD), disable its
   overlapping surfaces so the island doesn't compete with it for the same D-Bus name or
   screen space, in `~/.config/noctalia/settings.json`: set `notifications.enabled` and
   `osd.enabled` to `false` (both are nested under existing keys with sibling settings,
   not top-level - edit in place rather than pasting a replacement object over them).
   Noctalia keeps its bar, launcher, lock and wallpaper. No keybind changes: the island
   reads PipeWire directly, so volume keys and `noctalia msg volume-up` keep working.

4. Restart niri (or log out/in) to pick up the autostart line.

## Config

`~/.config/dynamic-island/config.json`, copied from `config.example.json` on install:

| key | default | effect |
|---|---|---|
| `notificationServer` | `false` | Registers Quickshell's own D-Bus notification server. Off by default because a second server competing for `org.freedesktop.Notifications` with an already-running one (Noctalia, `mako`, etc.) fails silently - Quickshell just logs a warning and the island never receives anything. Turn this on only after disabling any other notification daemon. |

Missing file or invalid JSON both fall back to the defaults above; the island never
fails to start over a config problem. Config is read once at startup (no live-reload),
so restart the island after editing it.

## Fuzzel theme

`fuzzel/fuzzel.ini`, linked to `~/.config/fuzzel/fuzzel.ini` by `install.sh`: bone-on-
black, sharp corners (`radius=0`), same tokens as `theme/Theme.qml`, and the same full
invert on the selected entry (bone background, near-black text) as the island's own
hover/active treatment. Prompt is `//kuro. ` instead of the default `> `. Icons are
kept (not disabled) - a strict monochrome palette usually looks cleaner without them,
but losing at-a-glance app recognition was a real tradeoff, not an obvious win, so this
keeps them. Fuzzel has no way to pin arbitrary text to a corner of its window (it's a
plain list launcher, not a custom canvas), so `//kuro.` lives in the prompt slot rather
than as a separate label.

## Dev loop

- Nested niri sandbox: `niri -c ~/dev-niri.kdl`.
- `scripts/dev.sh` runs `qs -n -p .` against the repo directly; QML/theme edits hot-reload
  on save, no relaunch needed.
- `scripts/lint.sh` runs `qmllint` over every `.qml` file (`qs.*` import warnings are
  expected - qmllint can't resolve Quickshell's directory-as-module convention outside
  the runtime; anything else is a real issue).
- `scripts/test.sh` runs the `IslandController` state-machine test suite via
  `qmltestrunner`.
- IPC surface (`qs -p . ipc call island <fn>`, or `qs -c dynamic-island ipc call island
  <fn>` once installed): `demo <kind>`, `expand <page>`, `page <page>`, `collapse`,
  `toggle <page>`, `dismiss`.
- Never run `niri msg action <...>` against a live niri instance from a scripting/tool
  context without a timeout: a hung client has reproducibly wedged the whole IPC socket
  for every other client in this project's own testing, requiring a full niri restart.
  Read-only query subcommands (`workspaces`, `version`, `outputs`, `event-stream`) are
  safe.

Full architecture: `plans/2026-09-18-foundation-plan.md`. Decision log and known
quirks: `docs/NOTES.md`.

## Status

The foundation (window, state machine, morph animation, system services, IPC, config,
install) is frozen as of Slice 9. All 7 dashboard sections are backed by real services;
a few toggle cells (DND/NIGHT/CAPS/IDLE, the network/VPN/sync tray row) render dimmed
with no backend on this hardware, and battery% is unreachable on a desktop with no
battery. From here, changes are visual/design iteration on `theme/Theme.qml`,
`theme/Motion.qml`, and page internals behind the fixed page contract in `CLAUDE.md`,
not foundation work.
