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

    // Sits above the wallpaper (instantiated after it), below real windows
    // (same WlrLayer.Background). Toggled via IPC (see toggleWidgetEdit
    // below) or the niri keybind that calls it.
    WidgetCanvas {}

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

        function toggleWidgetEdit(): void {
            Widgets.editMode = !Widgets.editMode
        }

        // Island Faces - not routed through expand/collapse/toggle above,
        // those are all about the expanded dashboard's page, this is about
        // which face the compact pill itself shows. Mainly a test hook (no
        // way to simulate a mouse/touch drag over IPC), but doubles as a
        // manual override.
        function setCompactFace(id: string): void {
            Island.setCompactFace(id)
        }
    }

    // Full Noctalia handoff: niri's hardware media keys previously called
    // `noctalia msg volume-up` etc, which actually performed the PipeWire/
    // DDC-CI change (this project's own OSD only ever observed the result
    // and popped a peek - it never drove the hardware itself). These three
    // handlers are what niri's keybinds now call directly instead, using
    // the exact same Audio/Media/Brightness services already backing this
    // project's own CONTROLS UI.
    IpcHandler {
        target: "audio"

        readonly property int step: 5

        function volumeUp(): void {
            Audio.setVolume(Math.min(100, Math.round(Audio.volume * 100) + step))
        }

        function volumeDown(): void {
            Audio.setVolume(Math.max(0, Math.round(Audio.volume * 100) - step))
        }

        function toggleMute(): void {
            Audio.toggleMuted()
        }

        function toggleMicMute(): void {
            Audio.toggleMicMuted()
        }
    }

    IpcHandler {
        target: "media"

        function next(): void {
            Media.next()
        }

        function previous(): void {
            Media.previous()
        }

        function toggle(): void {
            Media.togglePlaying()
        }
    }

    IpcHandler {
        target: "brightness"

        readonly property int step: 5

        // Brightness.value is -1 until the first ddcutil read completes
        // (~8s on this hardware, see Brightness.qml's own comment) - a
        // key pressed in that window has no current value to step from,
        // so it's a no-op rather than guessing a starting point.
        function up(): void {
            if (Brightness.value < 0) return
            Brightness.setBrightness(Math.min(100, Math.round(Brightness.value * 100) + step))
        }

        function down(): void {
            if (Brightness.value < 0) return
            Brightness.setBrightness(Math.max(0, Math.round(Brightness.value * 100) - step))
        }
    }
}
