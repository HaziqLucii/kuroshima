#!/usr/bin/env bash
# Symlinks this repo into Quickshell's config path so `qs -c dynamic-island`
# (and niri autostart, which uses the same invocation) finds it, and seeds
# ~/.config/dynamic-island/config.json from the example on first run. Never
# touches niri's or Noctalia's own config files: those are printed below for
# Haziq to apply by hand, since they're live host config this script has no
# business editing unattended.
set -euo pipefail
cd "$(dirname "$0")/.."
# -P (physical path, symlinks resolved): running this a second time FROM
# the installed symlink itself (`~/.config/quickshell/dynamic-island/scripts/
# install.sh`, the exact path a user re-runs it from) would otherwise leave
# REPO_DIR pointing at QS_TARGET's own logical path, making `ln -sfn` below
# link that path to itself - a self-referential symlink that looks like a
# success (exit 0, "linked X -> X") but breaks every future launch with
# "Too many levels of symbolic links".
REPO_DIR="$(pwd -P)"

QS_TARGET="$HOME/.config/quickshell/dynamic-island"
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

CONFIG_DIR="$HOME/.config/dynamic-island"
CONFIG_FILE="$CONFIG_DIR/config.json"
mkdir -p "$CONFIG_DIR"
if [ ! -e "$CONFIG_FILE" ]; then
    cp "$REPO_DIR/config.example.json" "$CONFIG_FILE"
    echo "wrote $CONFIG_FILE (edit it, then restart the island)"
else
    echo "$CONFIG_FILE already exists, left it alone"
fi

cat <<'EOF'

Next, apply these by hand (not touched by this script):

1. niri autostart (~/.config/niri/cfg/autostart.kdl):
       spawn-sh-at-startup "qs -c dynamic-island"

2. niri layer rule (~/.config/niri/cfg/rules.kdl), so niri's own gaps/rules
   treat the island as its own surface:
       layer-rule {
           match namespace="dynamic-island"
       }

3. Noctalia (~/.config/noctalia/settings.json), to stop it fighting the
   island for notifications and the volume OSD: set `notifications.enabled`
   and `osd.enabled` to false (leave the rest of the file alone - both are
   nested under existing keys with sibling settings, not top-level).
   Noctalia keeps its bar, launcher, lock and wallpaper - only these two
   toggle off. No keybind changes: the island reads PipeWire directly, so
   volume keys and `noctalia msg volume-up` keep working.

4. Restart niri (or just log out/in) to pick up the autostart line.

To enable the island's own notification server (off by default so it
doesn't silently lose a race with Noctalia's), set "notificationServer":
true in ~/.config/dynamic-island/config.json AFTER step 3 above.
EOF
