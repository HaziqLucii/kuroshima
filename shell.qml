import Quickshell
import Quickshell.Io
import qs.app
import qs.services
import qs.ui

ShellRoot {
    IslandWindow {}
    ReservedSpaceWindow {}

    // Instantiating this is what makes the otherwise-lazy Audio singleton
    // actually start; nothing else references it.
    Bridges {}

    IpcHandler {
        target: "island"

        // Raw page-name override, bypassing the controller entirely.
        // Equivalent today to expand(name); kept distinct per the plan's
        // IPC surface in case that diverges later (e.g. a debug-only mode
        // that doesn't touch expandedPage's persisted state).
        function page(name: string): void {
            Island.expand(name)
        }

        function demo(kind: string): void {
            Island.show(kind, Demo.payloadFor(kind), Demo.overridesFor(kind))
        }

        function expand(name: string): void {
            Island.expand(name)
        }

        function collapse(): void {
            Island.collapse()
        }

        function toggle(name: string): void {
            Island.toggle(name)
        }

        function dismiss(): void {
            Island.dismiss()
        }
    }
}
