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

## Widget contract (`widgets/*.qml`)

Every file in `widgets/*.qml` (bundled) or `~/.config/kuroshima/widgets/*.qml` (user
custom, dropped in without touching this repo) is a plain `Item`. Required:
`implicitWidth`, `implicitHeight`. **Unlike the page contract, do NOT bind your own
`width`/`height`** - `ui/WidgetFrame.qml` hosts every widget through a `Loader` with
`anchors.fill: parent` specifically so the user's resize handle (drag the bottom-right
corner in edit mode) can actually resize the widget's content, not just the frame
around it; a widget binding `width: implicitWidth` itself would fight that anchor and
never grow or shrink. `implicitWidth`/`implicitHeight` are only the *natural/default*
size, used until the widget's first resize. Lay content out so it adapts to whatever
size it's actually given (`anchors.centerIn`/`anchors.fill` on your content, not fixed
pixel values) - see `widgets/Clock.qml` for the minimal version of this.

No `payload`: a widget reads live services directly (`SystemClock`, `Media`, etc.),
same as pages already do. Must tolerate being placed more than once (no widget-root
singleton state) - a user can add the same type twice.

Unlike pages, widget *content* is explicitly not held to this repo's bone-on-black/
no-accent-hue rule - it's user content, placed via the edit mode `Mod+Shift+W` toggles
(`services/Widgets.qml`, `ui/WidgetCanvas.qml`, `ui/WidgetFrame.qml`), styled however
its author wants. Only the edit-mode chrome itself (drag handles, the add-widget picker)
follows house style.

## Working style for this repo

- One slice per session (see the plan's slice list). Build on Sonnet, then run the
  `refuter` agent on the diff before committing.
- Escalate to Opus/Fable only when a slice's design needs rethinking, not for building.
- Only one Claude Code session edits this repo at a time. Check `docs/NOTES.md` first.
