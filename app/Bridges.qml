import QtQuick
import qs.services

// The only file that knows both services and the controller: one
// Connections per service, mapping its signal to Island.show(...). Lives
// in app/, not core/, same reason as Island.qml (needs Quickshell/service
// imports, core/ stays Quickshell-free for tests).
//
// A plain (non-singleton) type: instantiate it once from shell.qml so it
// exists at all. Referencing Audio/Media here (even just as Connections
// targets) is what makes the otherwise-lazy singletons actually start;
// a service nothing references never initializes.
Item {
    Connections {
        target: Audio
        function onChanged() {
            // pages/MediaExpanded.qml's CONTROLS section already shows
            // volume live while it's the expanded page, so popping the OSD
            // transient over it is always redundant, whether the change
            // came from that section's own slider or a hardware volume key
            // pressed while looking at it. Without this guard, the OSD
            // transient's own priority (40, equal to expandedBlockBelow)
            // clears IslandController's expanded gate, which morphs the
            // whole 700x604 dashboard down to the 320x58 OSD pill mid-
            // adjustment: refuter-caught, the slider vanishes from under
            // the cursor for the OSD's full dwell.
            if (Island.isExpanded && Island.expandedPage === "MediaExpanded") {
                return
            }
            Island.show("osd.volume", {
                kind: "volume",
                value: Audio.volume,
                muted: Audio.muted
            }, { key: "osd:volume" })
        }
    }

    Connections {
        target: Media
        function onTrackChanged() {
            if (!Media.available) {
                Island.clearKey("media")
                return
            }
            Island.show("media.track", {
                title: Media.title,
                artist: Media.artist,
                artUrl: Media.artUrl,
                isPlaying: Media.isPlaying
            }, { key: "media" })
        }
    }
}
