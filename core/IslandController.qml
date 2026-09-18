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
    // `readonly property alias` to a plain writable backing property.
    // NOTE this is a naming convention, not real enforcement: `current`
    // genuinely can't be written from outside, but nothing stops external
    // code that knows the underscore name from writing `_current` directly.
    // Don't do that; treat the underscore as private by agreement.
    property var _current: null // {kind,key,priority,page,payload,duration,requeue,seq}
    property var _queue: [] // priority desc, FIFO within priority, cap queueCap
    readonly property alias current: root._current
    readonly property alias queue: root._queue

    readonly property string page: current ? current.page : (expandedPage || "compact")
    readonly property var payload: current ? current.payload : null
    readonly property bool isPeek: current !== null
    readonly property bool isExpanded: !current && expandedPage !== ""

    // Reasons beyond the plan's original four (timeout|dismissed|preempted|
    // cleared): "dropped" (queue-cap overflow evicted it before it ever
    // showed) and "cleared" also now covers a queued (never-shown) item
    // removed via clearKey. Both matter for slice 6's RetainableLock: a
    // notification needs its lock released even if it never became current.
    signal transientStarted(var t)
    signal transientEnded(var t, string reason)

    // --- Timer bookkeeping (rule 7: hover-hold) ---
    property real _startedAt: 0
    property real _remaining: -1

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

        if (t.key === undefined || t.key === null) {
            // A kind whose table entry has no static key (e.g.
            // "notification", which needs a per-id key) MUST get one via
            // overrides.key. Without this guard, every call silently
            // coalesces into a single slot under key `undefined`.
            console.warn("IslandController.show: kind", kind, "has no key; pass overrides.key")
            return
        }

        // Rule 1: coalesce with current, no exit animation. Carries
        // priority/page too, not just payload/duration: an escalating
        // same-key event (e.g. a notification's urgency bumped to
        // critical) needs its new priority to actually take effect.
        if (root._current && t.key === root._current.key) {
            root._current = Object.assign({}, root._current, {
                payload: t.payload, duration: t.duration, priority: t.priority, page: t.page
            })
            root._restartTimer(t.duration)
            return
        }
        // Rule 1: coalesce with a queued item, in place. Re-normalizes
        // (sort+cap) after, since a priority change can change its
        // position.
        for (let i = 0; i < root._queue.length; i++) {
            if (root._queue[i].key === t.key) {
                const q = root._queue.slice()
                q[i] = Object.assign({}, q[i], {
                    payload: t.payload, duration: t.duration, priority: t.priority, page: t.page
                })
                root._queue = root._normalizeQueue(q)
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
                // old.priority >= every item already in the queue (it was
                // current, so it out-prioritized all of them when it
                // started or resumed), so front-pushing can't violate the
                // priority-desc invariant; _normalizeQueue still re-sorts
                // and re-caps for safety rather than assuming that holds.
                root._queue = root._normalizeQueue([old].concat(root._queue))
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
        const removed = root._queue.filter(item => item.key === key)
        if (removed.length === 0) {
            return
        }
        root._queue = root._queue.filter(item => item.key !== key)
        for (const item of removed) {
            root.transientEnded(item, "cleared")
        }
    }

    function expand(pageId) {
        root.expandedPage = pageId
    }

    function collapse() {
        root.expandedPage = ""
        // Rule 2 can have left eligible items stuck in the queue while
        // expanded; retry now that the gate is open.
        root._advanceQueue()
    }

    function toggle(pageId) {
        if (root.expandedPage === pageId) {
            root.collapse()
        } else {
            root.expand(pageId)
        }
    }

    // --- Internals ---

    function _isInfiniteDuration(duration) {
        return duration === undefined || duration === null || duration < 0
    }

    function _normalizeQueue(q) {
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
            const dropped = q.splice(dropIndex, 1)[0]
            root.transientEnded(dropped, "dropped")
        }
        return q
    }

    function _enqueue(t) {
        root._queue = root._normalizeQueue(root._queue.concat([t]))
    }

    function _start(t) {
        root._current = t
        root.transientStarted(t)
        root._restartTimer(t.duration)
    }

    function _restartTimer(duration) {
        root._timer.stop()
        if (root._isInfiniteDuration(duration)) {
            root._remaining = -1
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
        if (root._current) {
            // Something already claimed current re-entrantly (e.g. a
            // transientEnded handler called show() synchronously during
            // _end's signal emission, before we got here). Don't stomp it.
            return
        }
        if (root._queue.length === 0) {
            return
        }
        const next = root._queue[0]
        if (root.expandedPage !== "" && next.priority < root.expandedBlockBelow) {
            // Rule 2 applies to dequeuing too. The queue is priority-desc,
            // so if the head is gated, everything behind it is too (same
            // or lower priority); leave the whole queue as is and retry
            // from collapse().
            return
        }
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

        if (root._current && !root._timer.running && !root._isInfiniteDuration(root._current.duration)) {
            const resumeDuration = Math.max(root._remaining, root.hoverGrace)
            root._startedAt = Date.now()
            root._timer.interval = resumeDuration
            root._timer.start()
        }
    }

    onHoveredChanged: root._updateHold()
    onHeldChanged: root._updateHold()
}
