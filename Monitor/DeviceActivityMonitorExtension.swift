import DeviceActivity
import Foundation

/// Runs in its own process. iOS wakes it at the start and end of each scheduled
/// window and applies/removes the matching blocklist's shields, so scheduled
/// blocks work even when the app isn't running.
///
/// Schedule activities are named `sch.<scheduleUUID>.<weekday>` (see
/// ScheduleManager). A manual timed session uses a different name and is
/// handled by the app, not here.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // The manual timed session is set up by the app; nothing to do here.
        guard activity != BlockingManager.manualActivity else { return }
        guard let scheduleID = Self.scheduleID(from: activity),
              let schedule = ScheduleStore.get(scheduleID),
              let blocklist = BlocklistStore.get(schedule.blocklistID) else { return }

        BlockingManager.shared.activate(blocklist,
                                        denyRemoval: SharedState.strictLevel != .off)
        SharedState.isBlocking = true
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // A manual timed session ending: tear it down.
        if activity == BlockingManager.manualActivity {
            BlockingManager.shared.deactivate()
            SharedState.manualRunning = false
            SharedState.isBlocking = false
            return
        }
        // A schedule ending: don't tear down a block the user started by hand.
        guard !SharedState.manualRunning else { return }
        BlockingManager.shared.deactivate()
        SharedState.isBlocking = false
    }

    /// Extract the schedule UUID from `sch.<uuid>.<weekday>`.
    static func scheduleID(from name: DeviceActivityName) -> UUID? {
        let parts = name.rawValue.split(separator: ".")
        guard parts.count >= 3, parts[0] == "sch" else { return nil }
        return UUID(uuidString: String(parts[1]))
    }
}
