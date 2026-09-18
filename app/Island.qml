pragma Singleton
import QtQuick
import Quickshell
import qs.theme
import qs.core

// The real, singleton controller instance the app actually uses. Lives
// outside core/ deliberately: this file needs Quickshell (PersistentProperties,
// qs.theme), and core/ has to stay Quickshell-free for tests. A qmldir
// declaring a singleton is resolved eagerly, so putting this in core/'s
// qmldir alongside Kinds broke `import "../core"` under plain
// qmltestrunner (which has no Quickshell) even though nothing in the
// tests ever references Island.
//
// IslandController.qml itself stays a plain (non-singleton) type so tests
// can create fresh, isolated instances; this is the one live instance.
IslandController {
    id: root

    hoverGrace: Motion.hoverGrace

    // Named property, not an unnamed child: QtObject (what IslandController
    // extends) has no default property to hold unnamed children, only
    // Item and similar types do.
    //
    // expandedPage survives a hot reload: PersistentProperties instances
    // are kept alive across reloads by Quickshell (keyed on reloadableId),
    // unlike this IslandController instance itself, which gets recreated.
    // Not a live two-way binding: `expandedPage` is also assigned
    // internally by expand()/collapse()/toggle(), and a direct assignment
    // to a property removes any binding on it, so mirroring is done
    // imperatively in both directions instead.
    property PersistentProperties _persisted: PersistentProperties {
        reloadableId: "dynamicIslandExpandedPage"
        property string expandedPage: ""
    }

    Component.onCompleted: root.expandedPage = root._persisted.expandedPage
    onExpandedPageChanged: root._persisted.expandedPage = root.expandedPage
}
