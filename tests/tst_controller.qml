import QtQuick
import QtTest
import "../core"

TestCase {
    id: testCase
    name: "IslandController"

    // Priorities loosely mirror the real Kinds table (notif 50, critical
    // 60, osd 40, power 35, media 30, workspace 20/low 10) but with 50ms
    // durations throughout so tests run fast instead of waiting out real
    // 1.5-5s timeouts.
    readonly property var testKinds: ({
        "critical": { priority: 60, duration: 50, key: "critical", page: "P", requeue: false },
        "notif": { priority: 50, duration: 50, key: "notif", page: "P", requeue: true },
        "osd": { priority: 40, duration: 50, key: "osd", page: "P", requeue: false },
        "low": { priority: 10, duration: 50, key: "low", page: "P", requeue: false }
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

    function test_coalesce_queued() {
        controller.show("notif", {}) // becomes current
        controller.show("osd", { v: 1 }) // priority 40 < 50, enqueues
        compare(controller.queue.length, 1)

        controller.show("osd", { v: 2 }) // same key, coalesce in place
        compare(controller.queue.length, 1)
        compare(controller.queue[0].payload.v, 2)
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
}
