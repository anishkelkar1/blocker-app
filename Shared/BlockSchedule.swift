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
    /// When true, the schedule blocks the whole day (00:00–23:59) on each
    /// selected weekday, ignoring the start/end times. Pick every weekday for an
    /// effectively permanent block.
    var allDay: Bool

    init(id: UUID = UUID(), name: String, blocklistID: UUID,
         weekdays: Set<Int> = [2, 3, 4, 5, 6],
         startHour: Int = 9, startMinute: Int = 0,
         endHour: Int = 17, endMinute: Int = 0,
         enabled: Bool = true, allDay: Bool = false) {
        self.id = id
        self.name = name
        self.blocklistID = blocklistID
        self.weekdays = weekdays
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.enabled = enabled
        self.allDay = allDay
    }

    enum CodingKeys: String, CodingKey {
        case id, name, blocklistID, weekdays
        case startHour, startMinute, endHour, endMinute, enabled, allDay
    }

    /// Custom decoder so schedules saved before `allDay` existed still load
    /// (the key defaults to false when missing). Encoding stays synthesized.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        blocklistID = try c.decode(UUID.self, forKey: .blocklistID)
        weekdays = try c.decode(Set<Int>.self, forKey: .weekdays)
        startHour = try c.decode(Int.self, forKey: .startHour)
        startMinute = try c.decode(Int.self, forKey: .startMinute)
        endHour = try c.decode(Int.self, forKey: .endHour)
        endMinute = try c.decode(Int.self, forKey: .endMinute)
        enabled = try c.decode(Bool.self, forKey: .enabled)
        allDay = try c.decodeIfPresent(Bool.self, forKey: .allDay) ?? false
    }

    var startText: String { String(format: "%02d:%02d", startHour, startMinute) }
    var endText: String { String(format: "%02d:%02d", endHour, endMinute) }

    /// Human-readable block window for lists: the time range, or "All day".
    var windowText: String { allDay ? "All day" : "\(startText)–\(endText)" }

    var startMinutes: Int { startHour * 60 + startMinute }
    var endMinutes: Int { endHour * 60 + endMinute }

    /// End is earlier than or equal to start, so the window runs past midnight.
    var crossesMidnight: Bool { endMinutes <= startMinutes }

    /// All-day schedules are always valid; otherwise the only invalid case is a
    /// zero-length window.
    var isValid: Bool { allDay || startMinutes != endMinutes }

    /// True if this (enabled, valid) schedule's window currently covers now — so
    /// its blocklist is being enforced by this schedule right this moment.
    var isActiveNow: Bool {
        guard enabled, isValid else { return false }
        let c = Calendar.current.dateComponents([.weekday, .hour, .minute], from: Date())
        guard let wd = c.weekday, let h = c.hour, let m = c.minute else { return false }
        let minutesNow = h * 60 + m
        if allDay { return weekdays.contains(wd) }
        if crossesMidnight {
            if weekdays.contains(wd) && minutesNow >= startMinutes { return true }
            return weekdays.contains(BlockSchedule.prevWeekday(wd)) && minutesNow < endMinutes
        }
        return weekdays.contains(wd) && minutesNow >= startMinutes && minutesNow < endMinutes
    }

    static let weekdaySymbols = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// Calendar weekday after `wd` (1...7, wrapping Sat→Sun).
    static func nextWeekday(_ wd: Int) -> Int { wd == 7 ? 1 : wd + 1 }

    /// Calendar weekday before `wd` (1...7, wrapping Sun→Sat).
    static func prevWeekday(_ wd: Int) -> Int { wd == 1 ? 7 : wd - 1 }

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
