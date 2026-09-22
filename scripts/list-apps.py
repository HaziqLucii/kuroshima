#!/usr/bin/env python3
"""List launchable desktop applications as JSON, for the app launcher
(ui/AppLauncher.qml via services/Apps.qml). Run fresh on every launcher
open, not cached - 245 real .desktop files on this machine parse in well
under the time a launcher needs to open anyway, and "always current after
installing something new" beats caching against a stale list.

Scans $XDG_DATA_HOME/applications first (user overrides), then each dir in
$XDG_DATA_DIRS + "/applications" in order - first occurrence of a desktop
file ID wins, matching the XDG spec's own precedence rule. Recurses one
level into subdirectories (some vendor packages nest their .desktop files),
computing the ID the same way the spec does: the path relative to the
applications/ dir, with "/" replaced by "-".
"""
import json
import os
import re
import shlex
import sys

# A regex, not a whole-token set: refuter caught a real regression against
# the actual apps installed here - spotify.desktop's own
# `Exec=spotify --uri=%u` used to survive intact as "--uri=%u" (the old
# version only dropped tokens that were ENTIRELY a field code, never one
# embedded inside a larger argument), leaking a literal "%u" into every
# real launch of Spotify. This substring-strips a field code from anywhere
# inside a token instead.
FIELD_CODE_RE = re.compile(r"%[fFuUdDnNickvm]")


def data_dirs():
    home = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share")
    dirs = [home]
    xdg_dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    dirs.extend(d for d in xdg_dirs.split(":") if d)
    return [os.path.join(d, "applications") for d in dirs]


def find_desktop_files(base):
    if not os.path.isdir(base):
        return
    for root, _dirs, files in os.walk(base):
        depth = os.path.relpath(root, base).count(os.sep) if root != base else -1
        if depth > 0:
            continue
        for f in files:
            if f.endswith(".desktop"):
                full = os.path.join(root, f)
                rel = os.path.relpath(full, base)
                entry_id = rel.replace(os.sep, "-")
                yield entry_id, full


def parse_desktop_file(path):
    """Returns a dict of bare (non-localized) keys from the [Desktop Entry]
    section only - [Desktop Action ...] sections are ignored entirely."""
    fields = {}
    in_entry_section = False
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if line.startswith("[") and line.endswith("]"):
                    in_entry_section = (line == "[Desktop Entry]")
                    continue
                if not in_entry_section or "=" not in line:
                    continue
                key, _, value = line.partition("=")
                key = key.strip()
                # Bare keys only - "Name[de]", "Comment[fr]" etc are
                # localized variants, never what should render here.
                if "[" in key:
                    continue
                fields[key] = value.strip()
    except OSError:
        return None
    return fields


def strip_field_codes(exec_line):
    try:
        tokens = shlex.split(exec_line)
    except ValueError:
        tokens = exec_line.split()
    result = []
    for tok in tokens:
        # "%%" is a literal percent sign per the spec - protect it before
        # stripping real field codes, then restore it after, so a
        # (hypothetical, none seen on this machine) "--percent=%%" doesn't
        # get mangled by the field-code substitution below.
        tok = tok.replace("%%", "\x00")
        tok = FIELD_CODE_RE.sub("", tok)
        tok = tok.replace("\x00", "%")
        if tok:
            result.append(tok)
    return result


def main():
    seen_ids = set()
    apps = []

    for base in data_dirs():
        for entry_id, path in find_desktop_files(base):
            if entry_id in seen_ids:
                continue
            seen_ids.add(entry_id)

            fields = parse_desktop_file(path)
            if not fields:
                continue
            if fields.get("Type", "Application") != "Application":
                continue
            if fields.get("NoDisplay", "false").lower() == "true":
                continue
            if fields.get("Hidden", "false").lower() == "true":
                continue

            name = fields.get("Name", "").strip()
            exec_line = fields.get("Exec", "").strip()
            if not name or not exec_line:
                continue

            argv = strip_field_codes(exec_line)
            if not argv:
                continue

            apps.append({
                "id": entry_id,
                "name": name,
                "icon": fields.get("Icon", ""),
                "exec": argv,
                "terminal": fields.get("Terminal", "false").lower() == "true",
            })

    apps.sort(key=lambda a: a["name"].lower())
    json.dump(apps, sys.stdout)


if __name__ == "__main__":
    main()
