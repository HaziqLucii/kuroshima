import QtQuick

// Pure state machine, no Quickshell imports, so tests load it standalone
// via `import "../core"` and qmltestrunner needs no shell runtime.
//
// "Peek" (a transient) is not a stored mode: isPeek/isExpanded are derived
// from current/expandedPage, so there is no "return to previous mode"
// bookkeeping to get wrong.
QtObject {
    id: root

    // --- Inputs ---
    property string expandedPage: "" // "" = compact; user intent
    property bool hovered: false // from Capsule HoverHandler
    property bool held: false // from page.holdOpen
    property var kinds: Kinds.table // injectable for tests
    property int expandedBlockBelow: 40
    // Duplicated default from theme/Motion.qml rather than importing it
    // (would pull in Quickshell). Island.qml (slice 3) rebinds this to
    // Motion.hoverGrace for the real instance.
    property int hoverGrace: 700
    readonly property int queueCap: 6

    // --- Derived state ---
    // `readonly property alias` to a plain writable backing property: Qt6
    // genuinely enforces readonly (unlike some older QML lore), so the
    // internal functions below write `_current`/`_queue`, and only the
    // alias is exposed, giving external consumers real enforcement rather
    // than a naming convention.
    property var _current: null // {kind,key,priority,page,payload,duration,requeue}
    property var _queue: [] // priority desc, FIFO within priority, cap queueCap
    readonly property alias current: root._current
    readonly property alias queue: root._queue

    readonly property string page: current ? current.page : (expandedPage || "compact")
    readonly property var payload: current ? current.payload : null
    readonly property bool isPeek: current !== null
    readonly property bool isExpanded: !current && expandedPage !== ""

    signal transientStarted(var t)
    signal transientEnded(var t, string reason) // timeout|dismissed|preempted|cleared

    // --- Timer bookkeeping (rule 7: hover-hold) ---
    property real _startedAt: 0
    property real _remaining: 0

    property Timer _timer: Timer {
        repeat: false
        onTriggered: root._onTimeout()
    }

    // Explicit tiebreaker for "FIFO within priority": this engine's
    // Array.sort is NOT stable for equal comparator results (verified
    // empirically, contrary to the ES2019+ spec guarantee some engines
    // provide), so ties must be broken by an explicit sequence number,
    // not by relying on sort preserving insertion order.
    property int _seqCounter: 0

    // --- Public API ---

    function show(kind, payload, overrides) {
        overrides = overrides || {}
        const def = root.kinds[kind]
        if (!def) {
            console.warn("IslandController.show: unknown kind", kind)
            return
        }

        const t = {
            kind: kind,
            key: overrides.key !== undefined ? overrides.key : def.key,
            priority: overrides.priority !== undefined ? overrides.priority : def.priority,
            page: overrides.page !== undefined ? overrides.page : def.page,
            duration: overrides.duration !== undefined ? overrides.duration : def.duration,
            requeue: def.requeue === true,
            payload: payload,
            seq: ++root._seqCounter
        }

        // Rule 1: coalesce with current, no exit animation.
        if (root._current && t.key === root._current.key) {
            root._current = Object.assign({}, root._current, { payload: t.payload, duration: t.duration })
            root._restartTimer(t.duration)
            return
        }
        // Rule 1: coalesce with a queued item, in place, no reorder.
        for (let i = 0; i < root._queue.length; i++) {
            if (root._queue[i].key === t.key) {
                const q = root._queue.slice()
                q[i] = Object.assign({}, q[i], { payload: t.payload, duration: t.duration })
                root._queue = q
                return
            }
        }

        // Rule 2: expanded gate. OSD/notifications (priority >= threshold)
        // still show over an expanded page; page falls back to
        // expandedPage once they end, via the `page` derived property.
        if (root.expandedPage !== "" && t.priority < root.expandedBlockBelow) {
            return
        }

        // Rule 3: empty.
        if (!root._current) {
            root._start(t)
            return
        }

        // Rule 4: preempt.
        if (t.priority > root._current.priority) {
            const old = root._current
            root._end(old, "preempted")
            if (old.requeue) {
                root._queue = [old].concat(root._queue)
            }
            root._start(t)
            return
        }

        // Rule 5: enqueue. Cap queueCap; overflow drops the
        // lowest-priority oldest.
        root._enqueue(t)
    }

    function dismiss() {
        if (!root._current) {
            return
        }
        const t = root._current
        root._end(t, "dismissed")
        root._advanceQueue()
    }

    function clearKey(key) {
        if (root._current && root._current.key === key) {
            const t = root._current
            root._end(t, "cleared")
            root._advanceQueue()
            return
        }
        root._queue = root._queue.filter(item => item.key !== key)
    }

    function expand(pageId) {
        root.expandedPage = pageId
    }

    function collapse() {
        root.expandedPage = ""
    }

    function toggle(pageId) {
        root.expandedPage = (root.expandedPage === pageId) ? "" : pageId
    }

    // --- Internals ---

    function _enqueue(t) {
        let q = root._queue.concat([t])
        // Priority desc, ties broken by seq ascending (oldest first): see
        // the _seqCounter comment above for why this can't just be a
        // stable sort. This also makes the oldest of any priority tier
        // always the first occurrence of that priority value below.
        q.sort((a, b) => (b.priority - a.priority) || (a.seq - b.seq))

        while (q.length > root.queueCap) {
            // Lowest priority sorts last; drop its oldest (first) member,
            // not its newest, per "overflow drops the lowest-priority
            // oldest."
            const minPriority = q[q.length - 1].priority
            const dropIndex = q.findIndex(item => item.priority === minPriority)
            q.splice(dropIndex, 1)
        }
        root._queue = q
    }

    function _start(t) {
        root._current = t
        root.transientStarted(t)
        root._restartTimer(t.duration)
    }

    function _restartTimer(duration) {
        root._timer.stop()
        if (duration === undefined || duration === null || duration < 0) {
            return // stays until dismissed
        }
        root._remaining = duration
        if (root.hovered || root.held) {
            // Rule 7: don't count down while held; _updateHold resumes it.
            return
        }
        root._startedAt = Date.now()
        root._timer.interval = duration
        root._timer.start()
    }

    function _onTimeout() {
        const t = root._current
        root._end(t, "timeout")
        root._advanceQueue()
    }

    function _end(t, reason) {
        root._timer.stop()
        root._current = null
        root.transientEnded(t, reason)
    }

    function _advanceQueue() {
        if (root._queue.length === 0) {
            return
        }
        const next = root._queue[0]
        root._queue = root._queue.slice(1)
        root._start(next)
    }

    function _updateHold() {
        const holding = root.hovered || root.held
        if (holding) {
            if (root._timer.running) {
                const elapsed = Date.now() - root._startedAt
                root._remaining = Math.max(0, root._remaining - elapsed)
                root._timer.stop()
            }
            return
        }

        if (root._current && !root._timer.running && root._current.duration >= 0) {
            const resumeDuration = Math.max(root._remaining, root.hoverGrace)
            root._startedAt = Date.now()
            root._timer.interval = resumeDuration
            root._timer.start()
        }
    }

    onHoveredChanged: root._updateHold()
    onHeldChanged: root._updateHold()
}
