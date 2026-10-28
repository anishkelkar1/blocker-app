import SwiftUI

/// Create or edit one recurring schedule: which blocklist, which weekdays, and
/// the daily start/end time.
struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var blocklistID: UUID
    @State private var weekdays: Set<Int>
    @State private var start: Date
    @State private var end: Date
    @State private var enabled: Bool
    @State private var allDay: Bool

    private let id: UUID
    private let blocklists = BlocklistStore.all

    init(schedule: BlockSchedule) {
        id = schedule.id
        _name = State(initialValue: schedule.name)
        _blocklistID = State(initialValue: schedule.blocklistID)
        _weekdays = State(initialValue: schedule.weekdays)
        _enabled = State(initialValue: schedule.enabled)
        _allDay = State(initialValue: schedule.allDay)
        _start = State(initialValue: Self.date(schedule.startHour, schedule.startMinute))
        _end = State(initialValue: Self.date(schedule.endHour, schedule.endMinute))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("Schedule name", text: $name) }

                Section("Blocklist") {
                    Picker("Run", selection: $blocklistID) {
                        ForEach(blocklists) { Text($0.name).tag($0.id) }
                    }
                }

                Section("Days") {
                    HStack {
                        ForEach(1...7, id: \.self) { wd in
                            let on = weekdays.contains(wd)
                            Button {
                                if on { weekdays.remove(wd) } else { weekdays.insert(wd) }
                            } label: {
                                Text(BlockSchedule.weekdaySymbols[wd].prefix(1))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(on ? Color.accentColor : Color.gray.opacity(0.15),
                                                in: RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(on ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Time") {
                    Toggle("All day (24 hours)", isOn: $allDay)
                    if allDay {
                        Label("Blocks all day on each selected day. Pick every day for a permanent block.",
                              systemImage: "clock.badge.checkmark")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute)
                        DatePicker("End", selection: $end, displayedComponents: .hourAndMinute)
                        if startEqualsEnd {
                            Label("Start and end can't be the same.",
                                  systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        } else if crossesMidnight {
                            Label("Overnight — runs past midnight into the next day.",
                                  systemImage: "moon.stars")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section { Toggle("Enabled", isOn: $enabled) }
            }
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
        }
    }

    private func minutes(_ d: Date) -> Int {
        let c = comps(d); return c.hour! * 60 + c.minute!
    }
    private var startEqualsEnd: Bool { minutes(start) == minutes(end) }
    private var crossesMidnight: Bool { minutes(end) <= minutes(start) }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !weekdays.isEmpty
            && (allDay || !startEqualsEnd)
    }

    private func save() {
        let s = comps(start), e = comps(end)
        let schedule = BlockSchedule(id: id, name: name, blocklistID: blocklistID,
                                     weekdays: weekdays,
                                     startHour: s.hour!, startMinute: s.minute!,
                                     endHour: e.hour!, endMinute: e.minute!,
                                     enabled: enabled, allDay: allDay)
        ScheduleStore.upsert(schedule)
        dismiss()
    }

    private func comps(_ d: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: d)
    }

    private static func date(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}
