pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// User-facing config surface, per the plan's "JSON config (under 8 keys)".
// Read once at startup from ~/.config/kuroshima/config.json (NOT the
// repo's config.example.json, which is just the template `install.sh`
// copies from on first run). Missing file or bad JSON both degrade to the
// same defaults a fresh install ships with - this is a convenience surface,
// never a hard dependency the rest of the app assumes exists.
QtObject {
    id: root

    // Off by default: Quickshell's own NotificationServer competing for
    // org.freedesktop.Notifications with whatever the user's compositor
    // setup already runs (Noctalia, on this project's real target) fails
    // silently (Quickshell only logs it, see docs/NOTES.md), so shipping
    // this on by default would silently do nothing on a fresh install
    // until the user also disables the other daemon. README walks through
    // flipping this on alongside Noctalia's own `notifications.enabled`.
    property bool notificationServer: false

    // Slice 4. NaN means unset (a real lat/lon of exactly 0 is a legitimate
    // coordinate off Africa's west coast, so 0 can't double as "unset").
    // services/Weather.qml treats "unset" as "never run curl at all" -
    // this config key only exists because that real consumer needs it, per
    // the NOTES rule "add a config key only once something real consumes it".
    property real weatherLat: NaN
    property real weatherLon: NaN

    property FileView _configFile: FileView {
        path: Quickshell.env("HOME") + "/.config/kuroshima/config.json"
        blockLoading: true
        printErrors: false
        Component.onCompleted: {
            try {
                const parsed = JSON.parse(text())
                if (typeof parsed.notificationServer === "boolean") {
                    root.notificationServer = parsed.notificationServer
                }
                if (typeof parsed.weatherLat === "number" && typeof parsed.weatherLon === "number") {
                    root.weatherLat = parsed.weatherLat
                    root.weatherLon = parsed.weatherLon
                }
            } catch (e) {
                // Missing file or invalid JSON: keep the defaults above.
            }
        }
    }
}
