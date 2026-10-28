import DeviceActivity
import Foundation

/// Runs in its own process. iOS wakes it at the start and end of each scheduled
/// window and adds/removes that schedule's blocklist from the active set, so
/// scheduled blocks work even when the app isn't running. The enforced block is
/// always the union of every active blocklist (see BlockingManager).
///
/// Schedule activities are named `sch.<scheduleUUID>.<weekday>` (plus a `.b`
/// segment for the after-midnight half of an overnight window). A manual timed
/// session uses `BlockingManager.manualActivity`.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity != BlockingManager.manualActivity else { return }
        guard let scheduleID = Self.scheduleID(from: activity),
              let schedule = ScheduleStore.get(scheduleID) else { return }
        for blocklistID in schedule.blocklistIDs {
            BlockingManager.shared.addScheduled(blocklistID)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity == BlockingManager.manualActivity {
            BlockingManager.shared.stopManual()
            SharedState.lockedUntil = nil
            return
        }
        guard let scheduleID = Self.scheduleID(from: activity),
              let schedule = ScheduleStore.get(scheduleID) else { return }
        for blocklistID in schedule.blocklistIDs {
            BlockingManager.shared.removeScheduled(blocklistID)
        }
    }

    /// Extract the schedule UUID from `sch.<uuid>.<weekday>[.b]`.
    static func scheduleID(from name: DeviceActivityName) -> UUID? {
        let parts = name.rawValue.split(separator: ".")
        guard parts.count >= 3, parts[0] == "sch" else { return nil }
        return UUID(uuidString: String(parts[1]))
    }
}
