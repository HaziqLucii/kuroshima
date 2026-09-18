import Quickshell
import Quickshell.Io
import qs.ui

ShellRoot {
    IslandWindow {
        id: island
    }

    IpcHandler {
        target: "island"

        function page(name: string): void {
            island.setPage(name, null)
        }
    }
}
