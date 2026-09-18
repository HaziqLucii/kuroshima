import QtQuick
import QtTest
import "../core"

TestCase {
    id: testCase
    name: "IslandController"

    // Priorities loosely mirror the real Kinds table (notif 50, critical
    // 60, osd 40, power 35, media 30, workspace 20/low 10) but with 50ms
    // durations throughout so tests run fast instead of waiting out real
    // 1.5-5s timeouts. "noKey" mirrors the real "notification" row, which
    // deliberately has no static key (see test_show_without_key_is_rejected).
    readonly property var testKinds: ({
        "critical": { priority: 60, duration: 50, key: "critical", page: "P", requeue: false },
        "notif": { priority: 50, duration: 50, key: "notif", page: "P", requeue: true },
        "osd": { priority: 40, duration: 50, key: "osd", page: "P", requeue: false },
        "low": { priority: 10, duration: 50, key: "low", page: "P", requeue: false },
        "noKey": { priority: 50, duration: 50, page: "P", requeue: false },
        "forever": { priority: 50, duration: -1, key: "forever", page: "P", requeue: false }
    })

    property var controller
    Component {
        id: controllerComponent
        IslandController {}
    }

    SignalSpy {
        id: startedSpy
        signalName: "transientStarted"
    }
    SignalSpy {
        id: endedSpy
        signalName: "transientEnded"
    }

    function init() {
        controller = controllerComponent.createObject(testCase)
        controller.kinds = testKinds
        controller.hoverGrace = 30
        startedSpy.target = controller
        endedSpy.target = controller
        startedSpy.clear()
        endedSpy.clear()
    }

    function cleanup() {
        controller.destroy()
        controller = null
    }

    function test_coalesce_current() {
        controller.show("notif", { v: 1 })
        compare(controller.current.payload.v, 1)
        compare(startedSpy.count, 1)

        controller.show("notif", { v: 2 })
        compare(controller.current.payload.v, 2)
        compare(startedSpy.count, 1) // no new start, no exit animation
        compare(endedSpy.count, 0)
    }

    function test_coalesce_current_carries_priority_and_page() {
        // A same-key re-show with an escalated priority/page must actually
        // take effect, not just its payload/duration.
        controller.show("notif", {})
        controller.show("notif", {}, { priority: 60, page: "Escalated" })
        compare(controller.current.priority, 60)
        compare(controller.current.page, "Escalated")
    }

    function test_coalesce_queued() {
        controller.show("notif", {}) // becomes current
        controller.show("osd", { v: 1 }) // priority 40 < 50, enqueues
        compare(controller.queue.length, 1)

        controller.show("osd", { v: 2 }) // same key, coalesce in place
        compare(controller.queue.length, 1)
        compare(controller.queue[0].payload.v, 2)
    }

    function test_show_without_key_is_rejected() {
        controller.show("noKey", { id: 1 })
        compare(controller.current, null) // rejected, not silently coalesced

        controller.show("noKey", { id: 1 }, { key: "n1" })
        controller.show("noKey", { id: 2 }, { key: "n2" })
        compare(controller.current.key, "n1")
        compare(controller.queue.length, 1)
        compare(controller.queue[0].key, "n2")
    }

    function test_expanded_gate_blocks_below_threshold() {
        controller.expand("somepage")
        controller.show("low", {}) // priority 10 < expandedBlockBelow (40)
        compare(controller.current, null)
        compare(controller.page, "somepage")
    }

    function test_expanded_gate_allows_at_threshold() {
        controller.expand("somepage")
        controller.show("osd", {}) // priority 40, not < 40, shows over it
        compare(controller.current.key, "osd")
        compare(controller.page, "P")

        wait(120)
        compare(controller.current, null)
        compare(controller.page, "somepage") // falls back once it ends
    }

    function test_expanded_gate_applies_to_queue_advance_and_collapse_retries() {
        // Queue something while not expanded, then expand: when the
        // current transient ends, the queued item must NOT pop over the
        // expanded page (it's below threshold), but collapse() must
        // resurface it afterward.
        controller.show("notif", {}) // current
        controller.show("low", {}) // queued, priority 10
        controller.expand("mediaExpanded")

        wait(80) // notif (50ms) times out
        compare(controller.current, null)
        compare(controller.page, "mediaExpanded") // low did NOT pop over it
        compare(controller.queue.length, 1)

        controller.collapse()
        compare(controller.current.key, "low") // resurfaced
    }

    function test_preempt_and_requeue() {
        controller.show("notif", {}) // priority 50, requeue: true
        compare(controller.current.key, "notif")

        controller.show("critical", {}) // priority 60 > 50, preempts
        compare(controller.current.key, "critical")
        compare(endedSpy.count, 1)
        compare(endedSpy.signalArguments[0][1], "preempted")
        compare(controller.queue.length, 1)
        compare(controller.queue[0].key, "notif")

        // Window between critical's timeout (~50ms) and notif's own
        // resumed timeout (another ~50ms after that, i.e. ~100ms): wide
        // enough to be reliable, short enough not to catch notif timing
        // out too.
        wait(75)
        compare(controller.current.key, "notif") // resumed from queue
    }

    function test_no_requeue_when_not_flagged() {
        controller.show("osd", {}) // requeue: false
        controller.show("critical", {}) // preempts osd
        compare(controller.queue.length, 0) // osd dropped, not requeued
    }

    function test_queue_drains_priority_order_not_fifo() {
        controller.show("notif", {}) // current, blocks the rest
        controller.show("low", {}, { key: "low1" }) // priority 10, queued first
        controller.show("osd", {}, { key: "osd1" }) // priority 40, queued second
        compare(controller.queue.length, 2)

        wait(75) // notif times out, queue should drain highest priority first
        compare(controller.current.key, "osd1")
    }

    function test_queue_cap_drops_lowest_priority_oldest() {
        controller.show("notif", {}) // current, priority 50 blocks the rest from becoming current
        for (let i = 0; i < 8; i++) {
            controller.show("osd", { tag: i }, { key: "q" + i })
        }
        compare(controller.queue.length, 6)
        // q0 and q1 were the oldest of the (only, tied) priority tier once
        // the queue overflowed past cap, so they're the ones dropped.
        const keys = controller.queue.map(item => item.key)
        compare(keys.indexOf("q0"), -1)
        compare(keys.indexOf("q1"), -1)
        compare(keys.indexOf("q7") !== -1, true)
    }

    function test_queue_cap_cross_tier_drops_lowest_priority_not_oldest_overall() {
        controller.show("notif", {}) // current
        controller.show("low", {}, { key: "old-low" }) // priority 10, oldest overall
        for (let i = 0; i < 6; i++) {
            controller.show("osd", { tag: i }, { key: "osd" + i }) // priority 40
        }
        // Queue is now [old-low(10), osd0..osd5(40)] = 7 items, over cap.
        // The lowest-priority item is old-low, even though several osd
        // items are individually older in absolute terms than osd5.
        compare(controller.queue.length, 6)
        const keys = controller.queue.map(item => item.key)
        compare(keys.indexOf("old-low"), -1)
        compare(keys.indexOf("osd0") !== -1, true)
    }

    function test_queue_cap_drop_emits_transient_ended() {
        controller.show("notif", {})
        for (let i = 0; i < 7; i++) {
            controller.show("osd", { tag: i }, { key: "q" + i })
        }
        compare(endedSpy.count, 1)
        compare(endedSpy.signalArguments[0][0].key, "q0")
        compare(endedSpy.signalArguments[0][1], "dropped")
    }

    function test_clear_key_current() {
        controller.show("notif", {})
        controller.clearKey("notif")
        compare(controller.current, null)
        compare(endedSpy.signalArguments[endedSpy.count - 1][1], "cleared")
    }

    function test_clear_key_queued_leaves_current() {
        controller.show("notif", {})
        controller.show("osd", {}, { key: "q1" })
        controller.clearKey("q1")
        compare(controller.queue.length, 0)
        compare(controller.current.key, "notif")
    }

    function test_clear_key_queued_emits_transient_ended() {
        controller.show("notif", {})
        controller.show("osd", {}, { key: "q1" })
        endedSpy.clear()
        controller.clearKey("q1")
        compare(endedSpy.count, 1)
        compare(endedSpy.signalArguments[0][1], "cleared")
    }

    function test_dismiss_advances_queue() {
        controller.show("notif", {})
        controller.show("osd", {}, { key: "q1" })
        controller.dismiss()
        compare(controller.current.key, "q1")
    }

    function test_toggle_expands_and_collapses() {
        compare(controller.expandedPage, "")
        controller.toggle("settings")
        compare(controller.expandedPage, "settings")
        controller.toggle("settings")
        compare(controller.expandedPage, "")
    }

    function test_held_pauses_like_hovered() {
        controller.show("notif", {})
        controller.held = true
        wait(90)
        compare(controller.current !== null, true)
        controller.held = false
        wait(90)
        compare(controller.current, null)
    }

    function test_hover_hold_pauses_and_resumes() {
        controller.show("notif", {}) // duration 50ms
        controller.hovered = true

        wait(90) // well past 50ms, but held: must not have ended
        compare(controller.current !== null, true)
        compare(endedSpy.count, 0)

        controller.hovered = false
        wait(90) // resumes with max(remaining, hoverGrace=30) and times out
        compare(controller.current, null)
    }

    function test_hover_does_not_kill_a_forever_duration_peek() {
        // Regression: duration -1/null ("until dismissed") must survive a
        // hover-then-unhover cycle without a stale _remaining resurrecting
        // a timer for it.
        controller.show("osd", {}) // duration 50, establishes a stale _remaining
        controller.dismiss()

        controller.show("forever", {}) // duration -1
        controller.hovered = true
        controller.hovered = false

        wait(200)
        compare(controller.current !== null, true)
        compare(controller.current.key, "forever")
    }

    function test_reentrant_show_from_transient_ended_is_not_clobbered() {
        // A transientEnded handler calling show() synchronously (e.g.
        // Bridges reacting to "notification closed") must not have its
        // result immediately overwritten by the queue-advance that
        // follows the same _end() call.
        controller.show("notif", {})
        controller.show("low", {}, { key: "queued-low" }) // sits in queue

        function onEnded(t, reason) {
            if (t.key === "notif" && reason === "dismissed") {
                controller.show("critical", {})
            }
        }
        controller.transientEnded.connect(onEnded)
        controller.dismiss()
        controller.transientEnded.disconnect(onEnded)

        compare(controller.current.key, "critical")
    }
}
