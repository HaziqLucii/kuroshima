#!/usr/bin/env bash
# Symlinks this repo into Quickshell's config path so `qs -c kuroshima`
# (and niri autostart, which uses the same invocation) finds it, and seeds
# ~/.config/kuroshima/config.json from the example on first run. Never
# touches niri's or Noctalia's own config files: those are printed below for
# Haziq to apply by hand, since they're live host config this script has no
# business editing unattended.
set -euo pipefail
cd "$(dirname "$0")/.."
# -P (physical path, symlinks resolved): running this a second time FROM
# the installed symlink itself (`~/.config/quickshell/kuroshima/scripts/
# install.sh`, the exact path a user re-runs it from) would otherwise leave
# REPO_DIR pointing at QS_TARGET's own logical path, making `ln -sfn` below
# link that path to itself - a self-referential symlink that looks like a
# success (exit 0, "linked X -> X") but breaks every future launch with
# "Too many levels of symbolic links".
REPO_DIR="$(pwd -P)"

QS_TARGET="$HOME/.config/quickshell/kuroshima"
mkdir -p "$HOME/.config/quickshell"
if [ -e "$QS_TARGET" ] && [ ! -L "$QS_TARGET" ]; then
    echo "error: $QS_TARGET already exists and isn't a symlink, not touching it" >&2
    exit 1
fi
if [ "$REPO_DIR" = "$QS_TARGET" ]; then
    echo "already installed at $QS_TARGET, nothing to link"
else
    ln -sfn "$REPO_DIR" "$QS_TARGET"
    echo "linked $QS_TARGET -> $REPO_DIR"
fi

CONFIG_DIR="$HOME/.config/kuroshima"
CONFIG_FILE="$CONFIG_DIR/config.json"
mkdir -p "$CONFIG_DIR"
if [ ! -e "$CONFIG_FILE" ]; then
    cp "$REPO_DIR/config.example.json" "$CONFIG_FILE"
    echo "wrote $CONFIG_FILE (edit it, then restart the island)"
else
    echo "$CONFIG_FILE already exists, left it alone"
fi

# Bundled fuzzel theme (bone-on-black, sharp corners, matches the island's
# own hover/active treatment) - same not-a-symlink-already caution as
# QS_TARGET above, since this is a real user config file fuzzel itself
# also reads, not something this project owns exclusively the way
# QS_TARGET is.
FUZZEL_TARGET="$HOME/.config/fuzzel/fuzzel.ini"
mkdir -p "$HOME/.config/fuzzel"
if [ -e "$FUZZEL_TARGET" ] && [ ! -L "$FUZZEL_TARGET" ]; then
    echo "$FUZZEL_TARGET already exists and isn't a symlink, leaving your fuzzel theme alone"
elif [ -L "$FUZZEL_TARGET" ] && [ "$(readlink -f "$FUZZEL_TARGET")" = "$REPO_DIR/fuzzel/fuzzel.ini" ]; then
    echo "fuzzel theme already linked"
else
    ln -sfn "$REPO_DIR/fuzzel/fuzzel.ini" "$FUZZEL_TARGET"
    echo "linked $FUZZEL_TARGET -> $REPO_DIR/fuzzel/fuzzel.ini"
fi

# Bundled kitty theme (bone-on-black, matches the island's own palette
# exactly - same tokens as theme/Theme.qml). Default terminal: kitty
# supports the Drag and Drop protocol yazi needs (foot doesn't), and
# renders the default fastfetch config's image logo natively via its own
# graphics protocol. `shell fish` is required in kitty.conf, not optional
# polish: niri's own environment has SHELL=/usr/bin/zsh, so without it
# every kitty window silently launches zsh instead of fish, dropping the
# `y` function and fastfetch's own default greeting.
KITTY_TARGET="$HOME/.config/kitty/kitty.conf"
mkdir -p "$HOME/.config/kitty"
if [ -e "$KITTY_TARGET" ] && [ ! -L "$KITTY_TARGET" ]; then
    echo "$KITTY_TARGET already exists and isn't a symlink, leaving your kitty theme alone"
elif [ -L "$KITTY_TARGET" ] && [ "$(readlink -f "$KITTY_TARGET")" = "$REPO_DIR/kitty/kitty.conf" ]; then
    echo "kitty theme already linked"
else
    ln -sfn "$REPO_DIR/kitty/kitty.conf" "$KITTY_TARGET"
    echo "linked $KITTY_TARGET -> $REPO_DIR/kitty/kitty.conf"
fi

# Bundled fastfetch config: plain text, no image logo - a "//kuroshima
# クロシマ" header line above the spec box, avoiding image-scaling/terminal
# row-rounding edge cases entirely.
mkdir -p "$HOME/.config/fastfetch"
for f in config.jsonc; do
    FF_TARGET="$HOME/.config/fastfetch/$f"
    if [ -e "$FF_TARGET" ] && [ ! -L "$FF_TARGET" ]; then
        echo "$FF_TARGET already exists and isn't a symlink, leaving it alone"
    elif [ -L "$FF_TARGET" ] && [ "$(readlink -f "$FF_TARGET")" = "$REPO_DIR/fastfetch/$f" ]; then
        echo "fastfetch/$f already linked"
    else
        ln -sfn "$REPO_DIR/fastfetch/$f" "$FF_TARGET"
        echo "linked $FF_TARGET -> $REPO_DIR/fastfetch/$f"
    fi
done

# Fish function: `y` cd's the shell to wherever yazi ends up browsing,
# since exiting yazi normally doesn't.
mkdir -p "$HOME/.config/fish/functions"
for fn in y.fish; do
    FN_TARGET="$HOME/.config/fish/functions/$fn"
    if [ -e "$FN_TARGET" ] && [ ! -L "$FN_TARGET" ]; then
        echo "$FN_TARGET already exists and isn't a symlink, leaving it alone"
    elif [ -L "$FN_TARGET" ] && [ "$(readlink -f "$FN_TARGET")" = "$REPO_DIR/fish/functions/$fn" ]; then
        echo "$fn already linked"
    else
        ln -sfn "$REPO_DIR/fish/functions/$fn" "$FN_TARGET"
        echo "linked $FN_TARGET -> $REPO_DIR/fish/functions/$fn"
    fi
done

# Bundled yazi theme + keymap (bone-on-black, smart-enter so <Enter>/`l`
# navigate directories instead of stock yazi's surprising "open in $EDITOR"
# default) - see the Yazi section in README for why that default matters.
mkdir -p "$HOME/.config/yazi"
for f in theme.toml init.lua keymap.toml package.toml; do
    YAZI_TARGET="$HOME/.config/yazi/$f"
    if [ -e "$YAZI_TARGET" ] && [ ! -L "$YAZI_TARGET" ]; then
        echo "$YAZI_TARGET already exists and isn't a symlink, leaving it alone"
    elif [ -L "$YAZI_TARGET" ] && [ "$(readlink -f "$YAZI_TARGET")" = "$REPO_DIR/yazi/$f" ]; then
        echo "yazi/$f already linked"
    else
        ln -sfn "$REPO_DIR/yazi/$f" "$YAZI_TARGET"
        echo "linked $YAZI_TARGET -> $REPO_DIR/yazi/$f"
    fi
done
if command -v ya >/dev/null 2>&1; then
    (cd "$HOME/.config/yazi" && ya pkg install >/dev/null 2>&1) \
        && echo "installed yazi plugins from package.toml (smart-enter)" \
        || echo "warning: 'ya pkg install' failed, run it yourself in ~/.config/yazi"
else
    echo "yazi not installed yet - after installing it, run: cd ~/.config/yazi && ya pkg install"
fi

cat <<'EOF'

Next, apply these by hand (not touched by this script):

1. niri autostart (~/.config/niri/cfg/autostart.kdl):
       spawn-sh-at-startup "qs -c kuroshima"

2. niri layer rule (~/.config/niri/cfg/rules.kdl), so niri's own gaps/rules
   treat the island as its own surface:
       layer-rule {
           match namespace="kuroshima"
       }

3. Noctalia (~/.config/noctalia/settings.json), to stop it fighting the
   island for notifications and the volume OSD: set `notifications.enabled`
   and `osd.enabled` to false (leave the rest of the file alone - both are
   nested under existing keys with sibling settings, not top-level).
   Noctalia keeps its bar, launcher, lock and wallpaper - only these two
   toggle off. No keybind changes: the island reads PipeWire directly, so
   volume keys and `noctalia msg volume-up` keep working.

4. niri keybinds (~/.config/niri/cfg/keybinds.kdl), to make kitty your
   terminal and yazi your Mod+E file manager instead of whatever you have
   bound now:
       Mod+T hotkey-overlay-title="Open Terminal: kitty" { spawn "kitty"; }
       Mod+E hotkey-overlay-title="File Manager: Yazi" { spawn-sh "kitty yazi"; }

5. niri environment (~/.config/niri/cfg/misc.kdl's environment{} block),
   so yazi's default "open with $EDITOR" opener has something to run
   (without this it fails with "process exited with status code: 127"
   the moment you try to open a file, or a directory, that isn't handled
   by the smart-enter keymap):
       EDITOR "nvim"
       VISUAL "nvim"
   This only takes effect for processes niri spawns AFTER a niri restart
   or relogin (environment{} is applied once at niri's own startup, not
   on a live config reload) - `set -gx EDITOR nvim` in your shell config
   covers anything launched from an interactive terminal in the meantime.

6. Restart niri (or just log out/in) to pick up the autostart line and
   the environment block above.

To enable the island's own notification server (off by default so it
doesn't silently lose a race with Noctalia's), set "notificationServer":
true in ~/.config/kuroshima/config.json AFTER step 3 above.
EOF
