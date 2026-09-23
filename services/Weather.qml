pragma Singleton
import QtQuick
import Quickshell.Io

// Slice 4. The only face with an external data source, so it's fenced off
// deliberately: nothing else in the app depends on this file, and it never
// fires a transient (faces/WeatherFace.qml reads it directly, same as
// faces/StatusFace.qml reads services/Toggles.qml).
//
// No location configured (services/Config.qml's weatherLat/weatherLon both
// NaN): `available` stays false and no `curl` ever runs, not even once -
// same "absent module hides itself, does nothing" rule as every other
// service here, just applied to "never fetch" instead of "fetch and get
// nothing back".
QtObject {
    id: root

    readonly property bool locationSet: !isNaN(Config.weatherLat) && !isNaN(Config.weatherLon)

    property bool _everSucceeded: false
    readonly property bool available: root.locationSet && root._everSucceeded

    // refuter-caught: faces/WeatherFace.qml's fallback text was gated on
    // plain `!available`, which is also true while a correctly-configured
    // location is still waiting on its first response, AND when it has
    // failed outright (bad coordinates, curl missing, a dead API) - all
    // three rendered the exact same "SET LOCATION" string, telling a user
    // who already set one to do the thing they already did, with nothing
    // in the log to explain why. Single source of truth here instead of
    // three ad-hoc booleans re-derived in the face:
    // "unset" - no coordinates configured at all.
    // "loading" - configured, first response still in flight (or every
    //   response so far has failed but hasn't hit the stale threshold yet).
    // "unavailable" - configured, two-plus consecutive failures, never once
    //   succeeded (bad coordinates, curl not installed, API down at first
    //   boot). If `curl` itself can't spawn (missing binary), the Process
    //   never emits streamFinished at all and this stays "loading" forever
    //   rather than flipping to "unavailable" - an accepted gap, see
    //   docs/NOTES.md: the face just stays quietly blank, never shows a
    //   wrong instruction.
    // "ok" - at least one successful fetch ever; faces/WeatherFace.qml
    //   dims this further via `stale` for a currently-failing-but-was-
    //   working-before location.
    readonly property string status: {
        if (!root.locationSet) return "unset"
        if (root._everSucceeded) return "ok"
        if (root._failStreak >= 2) return "unavailable"
        return "loading"
    }

    property real tempC: NaN
    property int humidity: -1
    property real windKmh: -1
    property int code: -1
    property string label: ""
    // Two consecutive failed polls (60 min of a dead network/API), not one -
    // open-meteo.org or the local link can drop a single request without
    // actually being down.
    property bool stale: false
    property var updatedAt: null

    property int _failStreak: 0

    // WMO weather_code (open-meteo's `current.weather_code`) collapsed to
    // six short mono words, mirroring faces/SystemFace.qml's own "a handful
    // of coarse states, not a precise readout" approach. faces/WeatherFace.qml
    // derives its glyph from this label rather than re-switching on the raw
    // code itself, so the WMO mapping lives in exactly one place.
    function _labelFor(wmoCode) {
        if (wmoCode === 0 || wmoCode === 1) return "CLEAR"
        if (wmoCode === 2 || wmoCode === 3) return "CLOUDY"
        if (wmoCode === 45 || wmoCode === 48) return "FOG"
        if (wmoCode === 95 || wmoCode === 96 || wmoCode === 99) return "STORM"
        if ([71, 73, 75, 77, 85, 86].indexOf(wmoCode) !== -1) return "SNOW"
        if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].indexOf(wmoCode) !== -1) return "RAIN"
        return "CLOUDY"
    }

    function poll() {
        if (!root.locationSet) return
        root._fetchProc.command = ["curl", "-s", "--max-time", "10",
            "https://api.open-meteo.com/v1/forecast?latitude=" + Config.weatherLat +
            "&longitude=" + Config.weatherLon +
            "&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code&timezone=auto"]
        root._fetchProc.running = true
    }

    // One reused Process, command rebuilt per call and re-triggered by
    // toggling `running` - same idiom services/Brightness.qml's setBrightness()
    // uses for its own _setProc. refuter-corrected: this does NOT coalesce
    // overlapping calls the way that comment used to claim - Quickshell's
    // `running = true` is a no-op while already running, so an overlapping
    // poll() would be silently dropped, not queued. Harmless today since
    // only the 30-min Timer below ever calls poll(), never concurrently
    // with itself.
    property Process _fetchProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text)
                    const cur = parsed.current
                    if (!cur || typeof cur.temperature_2m !== "number" || typeof cur.weather_code !== "number") {
                        throw new Error("unexpected payload shape")
                    }
                    root.tempC = cur.temperature_2m
                    root.humidity = typeof cur.relative_humidity_2m === "number" ? Math.round(cur.relative_humidity_2m) : -1
                    root.windKmh = typeof cur.wind_speed_10m === "number" ? cur.wind_speed_10m : -1
                    root.code = cur.weather_code
                    root.label = root._labelFor(cur.weather_code)
                    root.updatedAt = new Date()
                    root._everSucceeded = true
                    root._failStreak = 0
                    root.stale = false
                } catch (e) {
                    // Bad JSON, curl timeout/network error (empty stdout),
                    // or a shape change on open-meteo's side: same "degrade,
                    // don't crash" handling every other JSON-parsing
                    // Process in this codebase already uses. refuter-caught:
                    // this used to fail completely silently - a bad
                    // coordinate or a dead API was undiagnosable from both
                    // the UI and the logs. One line, not full response
                    // dumping (could contain nothing sensitive here, but
                    // matches this codebase's terse warn style elsewhere).
                    console.warn("Weather: fetch failed (" + root._failStreak + " -> " + (root._failStreak + 1) + "): " + e)
                    root._failStreak += 1
                    if (root._failStreak >= 2) {
                        root.stale = true
                    }
                }
            }
        }
    }

    // 30 min: weather doesn't change fast enough to justify anything
    // shorter, and this is the one service in the app that leaves the
    // machine to hit a real external API. Only runs at all once a location
    // is configured - `running: root.locationSet` re-evaluates live, so
    // setting a location after a fresh install (no shell restart needed)
    // starts polling immediately via triggeredOnStart.
    property Timer _pollTimer: Timer {
        interval: 30 * 60 * 1000
        running: root.locationSet
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }
}
