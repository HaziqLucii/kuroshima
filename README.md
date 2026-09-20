# kuroshima

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

This symlinks the repo into `~/.config/quickshell/kuroshima` (so `qs -c
kuroshima` finds it), seeds `~/.config/kuroshima/config.json` from
`config.example.json` on first run, and links every bundled dotfile below
(fuzzel, kitty, fastfetch, the `y` fish function, yazi) to its real config path,
unless you already have a real (non-symlink) file there, which it leaves
alone. It does not touch niri's or Noctalia's config - those are printed for
you to apply by hand:

1. **niri autostart** (`~/.config/niri/cfg/autostart.kdl` or wherever your `spawn-sh-at-startup`
   lines live):
   ```kdl
   spawn-sh-at-startup "qs -c kuroshima"
   ```

2. **niri layer rule** (`~/.config/niri/cfg/rules.kdl`), so niri treats the island as its
   own layer-shell surface:
   ```kdl
   layer-rule {
       match namespace="kuroshima"
   }
   ```

3. **If you run Noctalia** (or any other shell providing notifications/OSD), disable its
   overlapping surfaces so the island doesn't compete with it for the same D-Bus name or
   screen space, in `~/.config/noctalia/settings.json`: set `notifications.enabled` and
   `osd.enabled` to `false` (both are nested under existing keys with sibling settings,
   not top-level - edit in place rather than pasting a replacement object over them).
   Noctalia keeps its bar, launcher, lock and wallpaper. No keybind changes: the island
   reads PipeWire directly, so volume keys and `noctalia msg volume-up` keep working.

4. **niri keybinds** (`~/.config/niri/cfg/keybinds.kdl`), to make kitty your terminal
   and yazi your `Mod+E` file manager instead of whatever you have bound now:
   ```kdl
   Mod+T hotkey-overlay-title="Open Terminal: kitty" { spawn "kitty"; }
   Mod+E hotkey-overlay-title="File Manager: Yazi" { spawn-sh "kitty yazi"; }
   ```

5. **niri environment** (`~/.config/niri/cfg/misc.kdl`'s `environment{}` block), so
   yazi's default "open with `$EDITOR`" opener has something to run:
   ```kdl
   EDITOR "nvim"
   VISUAL "nvim"
   ```
   Without this, opening a file (or a directory the smart-enter keymap below
   doesn't catch) fails with `process exited with status code: 127` - stock yazi's
   `<Enter>` tries `${EDITOR:-vi} %s` on directories before anything else, and this
   system ships neither. `environment{}` only applies to processes niri spawns after
   its own startup, so this needs a niri restart/relogin to take effect; adding `set
   -gx EDITOR nvim` / `set -gx VISUAL nvim` to your own shell config covers anything
   launched from an interactive terminal in the meantime (not bundled - it's a couple
   of lines in your own `config.fish`, not something this repo should own).

6. **niri keybind** (`~/.config/niri/cfg/keybinds.kdl`), to toggle the widget canvas's
   edit mode (see Widgets below):
   ```kdl
   Mod+Shift+W hotkey-overlay-title="Toggle Widget Edit Mode" { spawn-sh "qs -c kuroshima ipc call island toggleWidgetEdit"; }
   ```

7. Restart niri (or log out/in) to pick up the autostart line and the environment
   block above.

## Config

`~/.config/kuroshima/config.json`, copied from `config.example.json` on install:

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

## Kitty theme

`kitty/kitty.conf`, linked to `~/.config/kitty/kitty.conf`: same tokens as
`theme/Theme.qml` (`#050506` background, `#ededed` foreground). The only terminal
this repo bundles or targets (foot was dropped - see `docs/NOTES.md` if you're
wondering why an earlier version of this README mentioned it): kitty supports
the Drag and Drop protocol needed to drag files out of yazi into another app,
which foot doesn't implement at all.

Two settings here are load-bearing, not preference:
- `shell fish` - niri's own environment has `SHELL=/usr/bin/zsh` (not the account's
  real login shell), so without this every kitty window silently launches zsh
  instead of fish, dropping the `y` function and fastfetch's own greeting.
- `confirm_os_window_close 0` - kitty's default asks for confirmation whenever a
  foreground process (yazi, an editor) is still running in the window, which is
  every single time you exit yazi via `Mod+E`.

## Fastfetch

`fastfetch/config.jsonc`, linked to `~/.config/fastfetch/config.jsonc`: a plain
text `//kuroshima クロシマ` header line above a flat key/value spec box. No image
logo - an earlier dithered-wordmark version kept clipping unpredictably at the
bottom (fastfetch's column-based image sizing doesn't map cleanly onto whole
terminal rows), and chasing that down through padding tweaks made it worse each
time. Plain text sidesteps the whole class of bug and reads just as clean.

## Yazi

Bone-on-black theme (`yazi/theme.toml`, built from yazi's own upstream defaults, not
guessed - same monochrome/no-accent-hue rule as the rest of this repo, differentiation
via bold/underline/italic instead of hue) plus a `//kuro.` mark in the status bar's
corner (`yazi/init.lua`), same placement logic as the fuzzel prompt.

`yazi/keymap.toml` binds `<Enter>` and `l` to the official `smart-enter` plugin
(`yazi/package.toml`, restored by `install.sh` via `ya pkg install` - or run that
yourself in `~/.config/yazi` if yazi wasn't installed yet when you ran `install.sh`).
This isn't just a preference: stock yazi's `<Enter>` tries to open a directory with
`${EDITOR:-vi}` before falling back to anything else, which is surprising on its own
and fails outright on a system with no `vi` (see the niri environment step above) -
smart-enter makes `<Enter>`/`l` navigate directories and open files, the behavior
most file managers already have.

`fish/functions/y.fish` (linked to `~/.config/fish/functions/y.fish`) adds a `y`
shell function: exiting yazi normally doesn't change your shell's directory, `y`
does, via yazi's own documented `--cwd-file` pattern.

## Widgets

`Mod+Shift+W` toggles edit mode on a desktop-background surface (`ui/WidgetCanvas.qml`,
sitting one wlr-layer above the wallpaper, still below real windows): a dim tint and an
"+ ADD WIDGET" picker (bottom-right) listing every available widget type. Any widget can
be dragged to move it regardless of focus; click one to focus it and reveal its
resize handle (bottom-right corner, drag to resize) and delete badge. `<Enter>` defocuses
the current widget (stays in edit mode - click another to keep editing); `<Escape>` exits
edit mode entirely, same as pressing `Mod+Shift+W` again. Position and size persist to
`~/.config/kuroshima/widgets.json` (`services/Widgets.qml`) as soon as you add, move,
resize, or remove something - no save step.

Two sources of widget types, both listed together in the picker:
- **Bundled**: `widgets/*.qml` in this repo. Just `widgets/Clock.qml` for now, a
  minimal placeholder proving the mechanics - not the point of this feature.
- **Custom**: drop your own `.qml` file into `~/.config/kuroshima/widgets/`, following
  the widget contract in `CLAUDE.md` (`implicitWidth`/`implicitHeight`, nothing else
  required). Rescanned every time edit mode opens, so a freshly-dropped file shows up
  without restarting the shell. Widget content is explicitly *not* held to this repo's
  bone-on-black rule - style it however you want.

## Dev loop

- Nested niri sandbox: `niri -c ~/dev-niri.kdl`.
- `scripts/dev.sh` runs `qs -n -p .` against the repo directly; QML/theme edits hot-reload
  on save, no relaunch needed.
- `scripts/lint.sh` runs `qmllint` over every `.qml` file (`qs.*` import warnings are
  expected - qmllint can't resolve Quickshell's directory-as-module convention outside
  the runtime; anything else is a real issue).
- `scripts/test.sh` runs the `IslandController` state-machine test suite via
  `qmltestrunner`.
- IPC surface (`qs -p . ipc call island <fn>`, or `qs -c kuroshima ipc call island
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
