pragma Singleton
import QtQuick
import Quickshell.Services.UPower

// This is a desktop (NucBox K8 Plus, no battery hardware at all), so
// `available` is expected to read false here permanently - confirmed live
// via `upower -i .../DisplayDevice`: "power supply: no", 0%,
// "battery-missing-symbolic". Built for correctness/portability anyway,
// matching the plan's own expectation ("Battery... available: false on
// this box... verify via demo power only"). Backs both the "power" Kind's
// PowerPeek transient and, later, the SESSION row's battery percentage.
QtObject {
    id: root

    // displayDevice is a CONSTANT property backed by a member object, not
    // actually nullable in Quickshell's own implementation - the
    // `device !== null` half of this guard is dead code in practice, kept
    // only because nothing documents that guarantee locally and it's a
    // harmless extra check either way.
    readonly property var device: UPower.displayDevice
    readonly property bool available: device !== null && device.isPresent
    // 0..100. refuter caught this backwards: Quickshell normalizes
    // UPower's raw D-Bus Percentage (already 0..100) down to a 0..1 ratio
    // itself (`device.hpp` documents it as "equivalent to energy /
    // energyCapacity"), so this multiplies back up rather than assuming
    // the D-Bus wire value passes through unchanged. Invisible on this
    // hardware only because `available` is false either way.
    readonly property real percentage: available ? device.percentage * 100 : 0
    // Not just `state === Charging`: refuter found real UPower state
    // sequences that never touch Charging at all while genuinely
    // plugged in (FullyCharged once topped up while still on AC;
    // PendingCharge on hardware with a charge-limit threshold) or that
    // go plugged->unplugged without passing back through Charging
    // (FullyCharged -> Discharging is a direct transition) - a check
    // against just the Charging enum value misses the real unplug event
    // in exactly that case. `UPower.onBattery` ("is the system currently
    // running on battery power, or discharging") is the semantically
    // correct signal for "is a charger connected" and updates correctly
    // across all of those transitions.
    readonly property bool charging: available && !UPower.onBattery
    // Seconds, per UPower's own TimeToEmpty/TimeToFull.
    readonly property real timeToEmpty: available ? device.timeToEmpty : 0
    readonly property real timeToFull: available ? device.timeToFull : 0

    // Fires whenever charging state flips (plugged/unplugged), the trigger
    // for the PowerPeek transient - app/Bridges.qml pops the peek on this,
    // not on every percentage tick.
    signal chargerChanged(bool charging)

    // Can't reproduce on this hardware (no battery at all, `charging` can
    // only ever compute false here), but this is the exact same class of
    // bug already found twice this session: services/Audio.qml's own
    // `_pastStartupBurst` gate exists because enumerating a real PipeWire
    // device at launch fires a burst of changes that would otherwise each
    // pop an OSD, and services/Workspaces.qml just had an equivalent
    // startup-look-like-a-change bug fixed by refuter. UPower enumerating
    // a REAL battery at launch risks the identical false "charger event"
    // on hardware that actually has one.
    //
    // Gated on device.ready, not a fixed timer: Audio.qml's own gate is a
    // 500ms heuristic (refuter flagged the equivalent risk here too - if
    // UPower resolves slower than that on a busy boot, the real burst
    // lands after the gate opens and leaks through anyway). `ready` is
    // Quickshell's own deterministic "this device's properties have
    // actually finished populating" signal, so there's no arbitrary
    // window to get wrong.
    onChargingChanged: {
        if (root.device && root.device.ready) {
            root.chargerChanged(root.charging)
        }
    }
}
