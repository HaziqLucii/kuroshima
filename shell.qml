import Quickshell
import Quickshell.Io
import qs.app
import qs.services
import qs.ui

ShellRoot {
    IslandWindow {}

    // Instantiating this is what makes the otherwise-lazy Audio singleton
    // actually start; nothing else references it.
    Bridges {}

    // Always-on: paints whatever Wallpaper.currentPath points at, whether
    // or not the picker below is currently open.
    WallpaperBackground {}

    // Hidden until toggled via IPC (see wallpaperToggle below) or the
    // niri keybind that calls it.
    WallpaperCarousel { id: wallpaperCarousel }

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

        // Not routed through Island (the capsule/peek state machine):
        // the carousel is its own full-screen overlay window, entirely
        // separate from the capsule's small-panel PageHost model.
        function wallpaperToggle(): void {
            wallpaperCarousel.toggle()
        }
    }
}
