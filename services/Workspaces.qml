pragma Singleton
import QtQuick
import Quickshell.Io

// Slice 7. Tried Quickshell's generic Quickshell.WindowManager abstraction
// first; on this test setup WindowManager.windowsets only ever reflected a
// single windowset, but that test was inconclusive (the sandbox genuinely
// only had one real workspace at the time, confirmed separately against
// `niri msg --json workspaces` - refuter later proved a differently-
// configured niri instance can report windowsets fine). Went with niri's
// own event-stream directly regardless, per the plan's documented fallback
// for exactly this uncertainty, rather than resolve which abstraction to
// trust.
//
// Spawns `niri msg --json event-stream` as a long-running Process rather
// than hand-rolling the raw NIRI_SOCKET wire protocol the plan describes
// (write "EventStream"\n, skip the ack line): the CLI already implements
// that handshake correctly, and its stdout is already clean newline-
// delimited JSON, one event object per line, first line always a full
// WorkspacesChanged snapshot (confirmed live). No retry/reconnect logic:
// if this process dies (niri restarts, itself crashes), workspace peeks
// just stop updating until qs itself restarts - an accepted simplification,
// same as services/System.qml's niriVersion has no retry either.
QtObject {
    id: root

    // [{id, name, active, urgent}], sorted by niri's own per-output idx so
    // the order matches what's shown on screen (niri's own JSON array
    // order isn't guaranteed to match idx).
    property var list: []

    readonly property int activeIndex: {
        for (let i = 0; i < list.length; i++) {
            if (list[i].active) return i
        }
        return -1
    }

    // Fires only when the ACTIVE workspace id genuinely changes, not on
    // every list mutation: a workspace being created/renamed/removed
    // elsewhere (not the currently-focused one) would otherwise pop a
    // peek for a switch that never happened.
    signal activeChanged()

    property int _lastActiveId: -1
    // refuter-caught: the event stream's very first line is always a full
    // WorkspacesChanged snapshot, which flips _lastActiveId from its -1
    // init to whatever's really active - that's establishing the starting
    // state, not a switch, but without this guard it fired activeChanged()
    // on every single shell startup, popping a workspace peek nobody
    // triggered. Suppresses exactly the first check, however it arrives.
    property bool _seeded: false

    function _normalize(rawWorkspaces) {
        return rawWorkspaces.slice().sort((a, b) => a.idx - b.idx).map((w) => ({
            id: w.id,
            name: w.name ? w.name : String(w.idx),
            active: w.is_active === true,
            urgent: w.is_urgent === true
        }))
    }

    function _checkActiveChanged() {
        const idx = root.activeIndex
        const activeId = idx >= 0 ? root.list[idx].id : -1

        if (!root._seeded) {
            root._seeded = true
            root._lastActiveId = activeId
            return
        }

        // idx < 0 (no workspace currently flagged active) is a transient,
        // inconsistent state - refuter reproduced it via a WorkspaceActivated
        // for an id not yet in `list` (an ordering race this dual-event-path
        // design exists to tolerate). Not something to peek about: the page
        // would render a broken-looking "0 / N".
        if (idx >= 0 && activeId !== root._lastActiveId) {
            root._lastActiveId = activeId
            root.activeChanged()
        }
    }

    property Process _eventStreamProc: Process {
        command: ["niri", "msg", "--json", "event-stream"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (!line) return
                let event
                try {
                    event = JSON.parse(line)
                } catch (e) {
                    return
                }

                if (event.WorkspacesChanged) {
                    root.list = root._normalize(event.WorkspacesChanged.workspaces)
                    root._checkActiveChanged()
                } else if (event.WorkspaceActivated) {
                    // Lightweight complement to WorkspacesChanged, in case
                    // niri doesn't re-send the whole list on a plain focus
                    // switch (undocumented locally, no niri-ipc man page on
                    // this system to confirm either way) - patches just the
                    // active flag rather than assuming a full list refetch.
                    const id = event.WorkspaceActivated.id
                    root.list = root.list.map((w) => ({
                        id: w.id, name: w.name, urgent: w.urgent, active: w.id === id
                    }))
                    root._checkActiveChanged()
                }
            }
        }
    }
}
