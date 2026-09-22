import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.services
import qs.app

// Replaces fuzzel (Mod+Space used to spawn it directly from niri) - Haziq
// wanted the app launcher to read as literally part of the island, not a
// separate popup that just appears/disappears with no transition. First
// built as its own overlay window (ui/WallpaperCarousel.qml's own shape),
// but that meant no morph animation - Haziq caught it: "very static...
// that thing should be apart of the island... so basically it is inside
// the island." Rebuilt as a real page instead, reached through
// Island.toggle("AppLauncher") exactly like MediaExpanded/SettingsExpanded
// - ui/Capsule.qml's own existing animatedWidth/Height/Radius (a
// MorphAnimation Behavior already bound to whichever page is active)
// picks this up for free, no new animation code needed, same as every
// other page transition in this app.
//
// The one genuinely new thing this required: ui/IslandWindow.qml's
// WlrLayershell.keyboardFocus, permanently None before now, has to become
// Exclusive specifically while this page is active - see that file's own
// comment for why that's the one real risk in this slice (it's a
// permanently-mapped surface changing keyboard-interactivity WHILE
// mapped, not on open/close the way WallpaperCarousel's separate window
// safely did it).
//
// Page contract (implicitWidth/Height, payload, cornerRadius): same shape
// every other page in pages/ already follows, even though this file lives
// in ui/ (kept there since it started as a ui-owned overlay window and the
// actual content didn't need to move).
Item {
    id: root

    property var payload: null
    signal requestExpand(string pageId)
    readonly property real cornerRadius: Theme.radius

    implicitWidth: 560
    implicitHeight: content.y + content.implicitHeight + 16
    width: implicitWidth
    height: implicitHeight

    property int currentIndex: 0

    readonly property var filtered: {
        const q = searchInput.text.trim().toLowerCase()
        if (q.length === 0) return Apps.list
        const starts = []
        const contains = []
        for (const a of Apps.list) {
            const n = a.name.toLowerCase()
            if (n.startsWith(q)) starts.push(a)
            else if (n.includes(q)) contains.push(a)
        }
        return starts.concat(contains)
    }
    onFilteredChanged: root.currentIndex = 0

    function _launch(entry) {
        if (!entry) return
        const argv = entry.terminal ? ["kitty", "-e"].concat(entry.exec) : entry.exec
        Quickshell.execDetached(argv)
        Island.collapse()
    }

    // refuter caught a second real bug: nothing ever closed this page if
    // the user clicked into a different window instead of dismissing it
    // deliberately. ui/IslandWindow.qml's `mask: Region { item: capsule }`
    // makes every click outside the capsule pass straight through to
    // whatever's underneath (that's intentional, everywhere else), so this
    // page never even sees that click to react to it - and
    // ui/Capsule.qml's own hover-based auto-collapse is deliberately
    // exempted for this page (see that file's own comment: typing a query
    // doesn't keep the cursor over the capsule). Combined, clicking away
    // and typing into another app could leave the island holding exclusive
    // keyboard focus indefinitely, silently eating keystrokes meant for
    // that other window - confirmed live via `niri msg layers` sitting at
    // `exclusive` well past what any other page's own auto-collapse grace
    // period would allow. No Quickshell API exists to detect "did the
    // compositor actually move keyboard focus elsewhere" directly, so this
    // bounds the exposure with a plain idle timeout instead: any real
    // activity (typing, arrow-key nav) restarts it, and it fires from
    // Component.onCompleted so opening the launcher and then genuinely
    // walking away is bounded too, not just mid-session idling.
    function _registerActivity() {
        idleTimer.restart()
    }
    Timer {
        id: idleTimer
        interval: 20000
        running: true
        onTriggered: Island.collapse()
    }

    // Fresh app list and a clean query every time this page is (re)loaded
    // - PageHost creates a brand new instance per activation (see
    // ui/PageHost.qml's own setPage()), so there's no stale-state case to
    // guard against the way a persistent window's _open() would need to.
    // Qt.callLater, not a direct call: the same first-frame focus timing
    // fix WallpaperCarousel's own _open() already needed - forceActiveFocus()
    // called synchronously here doesn't reliably stick the same frame the
    // item is created.
    Component.onCompleted: {
        Apps.refresh()
        Qt.callLater(() => searchInput.forceActiveFocus())
    }

    Shortcut { sequence: "Left"; onActivated: { root.currentIndex = Math.max(0, root.currentIndex - 1); root._registerActivity() } }
    Shortcut { sequence: "Right"; onActivated: { root.currentIndex = Math.min(root.filtered.length - 1, root.currentIndex + 1); root._registerActivity() } }
    Shortcut { sequence: "Home"; onActivated: { root.currentIndex = 0; root._registerActivity() } }
    Shortcut { sequence: "End"; onActivated: { root.currentIndex = root.filtered.length - 1; root._registerActivity() } }
    Shortcut { sequences: ["Return", "Enter"]; onActivated: root._launch(root.filtered[root.currentIndex]) }
    Shortcut { sequence: "Esc"; onActivated: Island.collapse() }

    ColumnLayout {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        y: 16
        width: parent.width - 32
        spacing: 14

        // ── search field ────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 8
            color: "transparent"
            border.width: 1
            border.color: searchInput.activeFocus ? Theme.divider : Theme.hairline

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    // md-magnify, verified against this font's actual
                    // cmap via fontTools before use, same discipline
                    // every other icon glyph in this project follows.
                    text: String.fromCodePoint(0xf0349)
                    color: Theme.inkDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text.length === 0
                        text: "SEARCH APPS"
                        color: Theme.inkDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.letterSpacing: 2
                    }

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        onTextEdited: root._registerActivity()
                    }
                }

                Text {
                    visible: root.filtered.length > 0
                    text: (root.currentIndex + 1) + " / " + root.filtered.length
                    color: Theme.inkDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }
        }

        // ── results ──────────────────────────────────────────
        ListView {
            id: appList
            Layout.fillWidth: true
            Layout.preferredHeight: 84
            orientation: ListView.Horizontal
            clip: true
            spacing: 8
            model: root.filtered
            currentIndex: root.currentIndex
            highlightMoveDuration: 140
            onCurrentIndexChanged: root.currentIndex = currentIndex

            delegate: Item {
                id: card
                required property int index
                required property var modelData
                readonly property bool current: index === root.currentIndex
                width: 84
                height: appList.height

                TapHandler {
                    onTapped: root.currentIndex = card.index
                    onDoubleTapped: root._launch(card.modelData)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: card.current ? Theme.hairline : "transparent"
                    border.width: 1
                    border.color: card.current ? Theme.divider : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 40
                        height: 40

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: Theme.hairline
                            visible: iconImg.status !== Image.Ready
                        }
                        Image {
                            id: iconImg
                            anchors.fill: parent
                            source: Quickshell.iconPath(card.modelData.icon, true)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                    }

                    Text {
                        width: 80
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: card.modelData.name
                        color: card.current ? Theme.ink : Theme.inkFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.filtered.length === 0
            text: "NO MATCHES"
            color: Theme.inkDim
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.letterSpacing: 2
        }

        // ── hint row ─────────────────────────────────────────
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18

            Repeater {
                model: [["←  →", "SELECT"], ["ENTER", "LAUNCH"], ["ESC", "CLOSE"]]
                delegate: RowLayout {
                    required property var modelData
                    spacing: 6
                    Text { text: modelData[0]; color: Theme.inkMuted; font.family: Theme.fontFamily; font.pixelSize: 9 }
                    Text { text: modelData[1]; color: Theme.inkDim; font.family: Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 1.2 }
                }
            }
        }
    }

    // Corner mark, matching the same branding convention already used on
    // the yazi theme in this project family.
    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        text: "//KUROSHIMA"
        color: Theme.inkDim
        font.family: Theme.fontFamily
        font.pixelSize: 8
        font.letterSpacing: 1
        opacity: 0.6
    }
}
