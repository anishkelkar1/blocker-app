import Foundation

/// A recurring block window: run `blocklistID` on the chosen weekdays between a
/// start and end time. Overnight windows (end earlier than start) are allowed
/// and split across midnight by ScheduleManager. Only start == end is invalid.
struct BlockSchedule: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var blocklistID: UUID
    /// Calendar weekdays: 1 = Sunday ... 7 = Saturday.
    var weekdays: Set<Int>
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var enabled: Bool

    init(id: UUID = UUID(), name: String, blocklistID: UUID,
         weekdays: Set<Int> = [2, 3, 4, 5, 6],
         startHour: Int = 9, startMinute: Int = 0,
         endHour: Int = 17, endMinute: Int = 0,
         enabled: Bool = true) {
        self.id = id
        self.name = name
        self.blocklistID = blocklistID
        self.weekdays = weekdays
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.enabled = enabled
    }

    var startText: String { String(format: "%02d:%02d", startHour, startMinute) }
    var endText: String { String(format: "%02d:%02d", endHour, endMinute) }

    var startMinutes: Int { startHour * 60 + startMinute }
    var endMinutes: Int { endHour * 60 + endMinute }

    /// End is earlier than or equal to start, so the window runs past midnight.
    var crossesMidnight: Bool { endMinutes <= startMinutes }

    /// The only invalid case is a zero-length window.
    var isValid: Bool { startMinutes != endMinutes }

    static let weekdaySymbols = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// Calendar weekday after `wd` (1...7, wrapping Sat→Sun).
    static func nextWeekday(_ wd: Int) -> Int { wd == 7 ? 1 : wd + 1 }

    var weekdaysText: String {
        weekdays.sorted().map { BlockSchedule.weekdaySymbols[$0] }.joined(separator: " ")
    }
}

/// CRUD for schedules, persisted in the App Group.
enum ScheduleStore {
    private static var d: UserDefaults { AppGroup.defaults }
    private static let key = "schedules"

    static var all: [BlockSchedule] {
        get {
            guard let data = d.data(forKey: key),
                  let list = try? JSONDecoder().decode([BlockSchedule].self, from: data)
            else { return [] }
            return list
        }
        set { d.set(try? JSONEncoder().encode(newValue), forKey: key) }
    }

    static func get(_ id: UUID) -> BlockSchedule? {
        all.first { $0.id == id }
    }

    static func upsert(_ schedule: BlockSchedule) {
        var list = all
        if let i = list.firstIndex(where: { $0.id == schedule.id }) {
            list[i] = schedule
        } else {
            list.append(schedule)
        }
        all = list
    }

    static func remove(_ id: UUID) {
        all = all.filter { $0.id != id }
    }
}
