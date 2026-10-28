import Foundation
import DeviceActivity

/// Registers DeviceActivity monitoring for every enabled schedule. A same-day
/// window becomes one activity per weekday (`sch.<id>.<weekday>`); an overnight
/// window is split across midnight into an `.a` segment (start→23:59 on the
/// weekday) and a `.b` segment (00:00→end on the next weekday). An all-day
/// schedule uses one full-day window (00:00→23:59) per weekday. The block lifts
/// for under a minute at the midnight boundary — acceptable for a focus app.
@MainActor
final class ScheduleManager: ObservableObject {
    static let shared = ScheduleManager()
    private let center = DeviceActivityCenter()

    func refreshAll() {
        let existing = center.activities.filter { $0.rawValue.hasPrefix("sch.") }
        if !existing.isEmpty { center.stopMonitoring(existing) }

        for schedule in ScheduleStore.all where schedule.isValid {
            for weekday in schedule.weekdays {
                if schedule.allDay {
                    register("sch.\(schedule.id.uuidString).\(weekday)",
                             startHour: 0, startMinute: 0,
                             endHour: 23, endMinute: 59, weekday: weekday)
                } else if schedule.crossesMidnight {
                    register("sch.\(schedule.id.uuidString).\(weekday).a",
                             startHour: schedule.startHour, startMinute: schedule.startMinute,
                             endHour: 23, endMinute: 59, weekday: weekday)
                    let next = BlockSchedule.nextWeekday(weekday)
                    register("sch.\(schedule.id.uuidString).\(weekday).b",
                             startHour: 0, startMinute: 0,
                             endHour: schedule.endHour, endMinute: schedule.endMinute, weekday: next)
                } else {
                    register("sch.\(schedule.id.uuidString).\(weekday)",
                             startHour: schedule.startHour, startMinute: schedule.startMinute,
                             endHour: schedule.endHour, endMinute: schedule.endMinute, weekday: weekday)
                }
            }
        }
        reconcileScheduledActive()
    }

    private func register(_ name: String,
                          startHour: Int, startMinute: Int,
                          endHour: Int, endMinute: Int, weekday: Int) {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: startHour, minute: startMinute, weekday: weekday),
            intervalEnd: DateComponents(hour: endHour, minute: endMinute, weekday: weekday),
            repeats: true
        )
        do { try center.startMonitoring(DeviceActivityName(name), during: schedule) }
        catch { print("startMonitoring \(name) failed: \(error)") }
    }

    func stopAll() {
        let existing = center.activities.filter { $0.rawValue.hasPrefix("sch.") }
        if !existing.isEmpty { center.stopMonitoring(existing) }
    }

    /// Recompute which blocklists are active by schedule right now, straight from
    /// the schedule windows, and re-apply. Fixes a stale "running" state left
    /// behind when a DeviceActivity end callback didn't fire (the window ended
    /// while the app was closed, or a schedule changed).
    func reconcileScheduledActive() {
        let active = ScheduleStore.all
            .filter { $0.isActiveNow }
            .flatMap { $0.blocklistIDs.map(\.uuidString) }
        SharedState.scheduledActiveIDs = Array(Set(active))
        BlockingManager.shared.recompute()
    }
}
