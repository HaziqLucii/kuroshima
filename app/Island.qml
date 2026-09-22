pragma Singleton
import QtQuick
import Quickshell
import qs.theme
import qs.core

// The real, singleton controller instance the app actually uses. Lives
// outside core/ deliberately: this file needs Quickshell (Singleton,
// PersistentProperties, qs.theme), and core/ has to stay Quickshell-free
// for tests. A qmldir declaring a singleton is resolved eagerly, so
// putting this in core/'s qmldir alongside Kinds broke `import "../core"`
// under plain qmltestrunner (which has no Quickshell) even though nothing
// in the tests ever references Island.
//
// Root type must be Quickshell's own Singleton (which extends
// ReloadPropagator/Reloadable), not the plain IslandController: a bare
// QtObject-rooted singleton is never registered by Quickshell's
// SingletonRegistry and is unreachable by reload propagation, so nothing
// under it can survive a hot reload no matter what PersistentProperties
// does. IslandController itself must stay a plain QtObject (Quickshell-free,
// for test standalone-ability), so it's a named child here, forwarded via
// aliases and one-line delegates instead of inherited directly.
Singleton {
    id: root

    property alias expandedPage: controller.expandedPage
    property alias hovered: controller.hovered
    property alias held: controller.held
    property alias kinds: controller.kinds
    property alias expandedBlockBelow: controller.expandedBlockBelow
    property alias hoverGrace: controller.hoverGrace
    readonly property alias queueCap: controller.queueCap
    readonly property alias current: controller.current
    readonly property alias queue: controller.queue
    readonly property alias page: controller.page
    readonly property alias payload: controller.payload
    readonly property alias isPeek: controller.isPeek
    readonly property alias isExpanded: controller.isExpanded

    // Island Faces: which face pages/CompactPage.qml's own nested PageHost
    // shows. A plain property here, NOT proxied through IslandController -
    // "compact" isn't a first-class concept in the controller at all (its
    // own `page` is just `expandedPage || "compact"`, a fallback string),
    // so which face is showing inside that fallback state is none of its
    // business. `faces/ClockEq.qml` is the default - originally clock + an
    // EqualizerBars glyph (matching what the compact pill always showed
    // before faces existed), simplified to clock-only once
    // faces/MediaFace.qml took over media-signaling on its own face.
    property string compactFace: "clockEq"

    signal transientStarted(var t)
    signal transientEnded(var t, string reason)

    function show(kind, payload, overrides) { controller.show(kind, payload, overrides) }
    function dismiss() { controller.dismiss() }
    function clearKey(key) { controller.clearKey(key) }
    function expand(pageId) { controller.expand(pageId) }
    function collapse() { controller.collapse() }
    function toggle(pageId) { controller.toggle(pageId) }
    function setCompactFace(id) { root.compactFace = id }

    IslandController {
        id: controller
        hoverGrace: Motion.hoverGrace
        // refuter caught a real bug: the default expandedBlockBelow (40)
        // lets a notification (priority 50) or volume/brightness OSD
        // (priority 40) preempt ANY expanded page, including the app
        // launcher - harmless for every other page (they just re-render
        // from live services once the peek clears), but ui/AppLauncher.qml
        // keeps its typed query/currentIndex as LOCAL instance state, and
        // ui/IslandWindow.qml's keyboard-focus binding keys off `page`
        // (which a peek temporarily overrides), not `expandedPage`. So a
        // single notification while typing silently destroyed the
        // in-progress search AND dropped keyboard focus for the peek's
        // full ~3.2s duration, leaking keystrokes into whatever window was
        // underneath - confirmed live via `niri msg layers`. Bumped high
        // enough that even the highest-priority kind (notification, 50)
        // queues behind the launcher instead of interrupting it, exactly
        // like power/media/workspace peeks already do for every other
        // expanded page today.
        expandedBlockBelow: expandedPage === "AppLauncher" ? 999 : 40
        onTransientStarted: (t) => root.transientStarted(t)
        onTransientEnded: (t, reason) => root.transientEnded(t, reason)
    }

    // expandedPage survives a hot reload via this: a genuine
    // default-property child of this Singleton (required for
    // ReloadPropagator::onReload to find and restore it; a *named*
    // property assignment, which an earlier version of this file used,
    // is invisible to that mechanism since it never enters mChildren).
    // Restoration happens on loaded/reloaded, not Component.onCompleted:
    // Quickshell restores PersistentProperties after the whole reloaded
    // tree is rebuilt, and Component.onCompleted runs before that point
    // on every generation, first launch or reload alike, so reading the
    // persisted value there always sees last generation's default.
    PersistentProperties {
        id: persisted
        reloadableId: "dynamicIslandExpandedPage"
        property string expandedPage: ""
        onLoaded: controller.expandedPage = persisted.expandedPage
        onReloaded: controller.expandedPage = persisted.expandedPage
    }

    Connections {
        target: controller
        function onExpandedPageChanged() { persisted.expandedPage = controller.expandedPage }
    }

    // Same pattern as expandedPage above, same reasons - a second, separate
    // PersistentProperties block (not folded into the one above) since
    // reloadableId is per-block, not per-property.
    PersistentProperties {
        id: persistedFace
        reloadableId: "dynamicIslandCompactFace"
        property string compactFace: "clockEq"
        onLoaded: root.compactFace = persistedFace.compactFace
        onReloaded: root.compactFace = persistedFace.compactFace
    }

    Connections {
        target: root
        function onCompactFaceChanged() { persistedFace.compactFace = root.compactFace }
    }
}
