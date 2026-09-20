# kuroshima

Apple-style Dynamic Island for niri (target: Hyprland later), built in Quickshell/QML.
Full architecture: `plans/2026-09-18-foundation-plan.md`. Progress: `docs/NOTES.md`.

## Dev loop

- Nested niri sandbox: `niri -c ~/dev-niri.kdl`, then `Mod+I` (bound to `scripts/dev.sh`).
- `scripts/dev.sh` runs `qs -n -p .` against the repo directly; edits hot-reload on save,
  no relaunch needed for QML/theme changes.
- `scripts/lint.sh` runs `qmllint` over every `.qml` file. `qs.*` import warnings from
  qmllint are expected (it can't resolve Quickshell's directory-as-module convention);
  anything else is a real issue.
- Never run raw `niri msg <cmd>` from a scripting/tool shell without a `timeout` wrapper.
  A hung client can wedge the whole IPC socket for every other client, requiring a
  full nested-niri restart to recover.

## Page contract (`pages/*.qml`)

Every page is an `Item`. Required: `implicitWidth`, `implicitHeight`, `property var payload`.
Optional: `property bool wantsKeyboard: false`, `property bool holdOpen: false`,
`signal requestClose()`, `signal requestExpand(string pageId)`.
A page also sets `width: implicitWidth` / `height: implicitHeight` itself (plain `Item`
doesn't self-size the way a Control does).

This is the seam design work happens against later: a new page only has to honour this
contract, nothing in `ui/` or `core/` should need to change for it.

## Working style for this repo

- One slice per session (see the plan's slice list). Build on Sonnet, then run the
  `refuter` agent on the diff before committing.
- Escalate to Opus/Fable only when a slice's design needs rethinking, not for building.
- Only one Claude Code session edits this repo at a time. Check `docs/NOTES.md` first.
