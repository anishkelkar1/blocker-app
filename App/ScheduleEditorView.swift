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

    private let id: UUID
    private let blocklists = BlocklistStore.all

    init(schedule: BlockSchedule) {
        id = schedule.id
        _name = State(initialValue: schedule.name)
        _blocklistID = State(initialValue: schedule.blocklistID)
        _weekdays = State(initialValue: schedule.weekdays)
        _enabled = State(initialValue: schedule.enabled)
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
                    DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $end, displayedComponents: .hourAndMinute)
                    if !isSameDay {
                        Label("End must be after start (overnight windows aren't supported yet).",
                              systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
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

    private var isSameDay: Bool {
        comps(end).hour! * 60 + comps(end).minute! > comps(start).hour! * 60 + comps(start).minute!
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !weekdays.isEmpty && isSameDay
    }

    private func save() {
        let s = comps(start), e = comps(end)
        let schedule = BlockSchedule(id: id, name: name, blocklistID: blocklistID,
                                     weekdays: weekdays,
                                     startHour: s.hour!, startMinute: s.minute!,
                                     endHour: e.hour!, endMinute: e.minute!,
                                     enabled: enabled)
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
