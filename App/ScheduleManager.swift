import Foundation
import DeviceActivity

/// Registers DeviceActivity monitoring for every enabled schedule. Each
/// schedule is expanded into one monitored activity per weekday, named
/// `sch.<scheduleUUID>.<weekday>` so the monitor extension can map it back.
@MainActor
final class ScheduleManager: ObservableObject {
    static let shared = ScheduleManager()
    private let center = DeviceActivityCenter()

    /// Re-register all schedules. Call after any schedule or blocklist change.
    func refreshAll() {
        // Clear only our schedule activities; leave a manual session alone.
        let existing = center.activities.filter { $0.rawValue.hasPrefix("sch.") }
        if !existing.isEmpty { center.stopMonitoring(existing) }

        for schedule in ScheduleStore.all where schedule.enabled && schedule.isSameDay {
            for weekday in schedule.weekdays {
                let name = DeviceActivityName("sch.\(schedule.id.uuidString).\(weekday)")
                let activitySchedule = DeviceActivitySchedule(
                    intervalStart: DateComponents(hour: schedule.startHour,
                                                  minute: schedule.startMinute,
                                                  weekday: weekday),
                    intervalEnd: DateComponents(hour: schedule.endHour,
                                                minute: schedule.endMinute,
                                                weekday: weekday),
                    repeats: true
                )
                do {
                    try center.startMonitoring(name, during: activitySchedule)
                } catch {
                    print("startMonitoring \(name.rawValue) failed: \(error)")
                }
            }
        }
    }

    /// Stop every schedule activity (e.g. when the user disables all schedules).
    func stopAll() {
        let existing = center.activities.filter { $0.rawValue.hasPrefix("sch.") }
        if !existing.isEmpty { center.stopMonitoring(existing) }
    }
}
