import SwiftUI

/// Create or edit one recurring schedule: which blocklists, which weekdays, and
/// the daily start/end time.
struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var blocklistIDs: Set<UUID>
    @State private var weekdays: Set<Int>
    @State private var start: Date
    @State private var end: Date
    @State private var allDay: Bool

    private let id: UUID
    private let blocklists = BlocklistStore.all
    /// Blocklists the schedule already had — while it's running these can't be
    /// removed, only added to.
    private let originalIDs: Set<UUID>

    /// True when editing a schedule that already exists. Its timings (days,
    /// times, all-day) are then locked — set once, can't be changed.
    private let isExisting: Bool

    /// True while the schedule's window currently covers now.
    private var isRunning: Bool { ScheduleStore.get(id)?.isActiveNow ?? false }

    init(schedule: BlockSchedule) {
        id = schedule.id
        isExisting = ScheduleStore.get(schedule.id) != nil
        originalIDs = Set(schedule.blocklistIDs)
        _name = State(initialValue: schedule.name)
        _blocklistIDs = State(initialValue: Set(schedule.blocklistIDs))
        _weekdays = State(initialValue: schedule.weekdays)
        _allDay = State(initialValue: schedule.allDay)
        _start = State(initialValue: Self.date(schedule.startHour, schedule.startMinute))
        _end = State(initialValue: Self.date(schedule.endHour, schedule.endMinute))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("Schedule name", text: $name) }

                if isExisting {
                    Section {
                        Label("Timings are locked once a schedule is created. Delete it and make a new one to change the days or times.",
                              systemImage: "lock.fill")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }

                Section {
                    ForEach(blocklists) { list in
                        let on = blocklistIDs.contains(list.id)
                        let locked = isRunning && originalIDs.contains(list.id)
                        Button {
                            if on {
                                if locked { return }   // ratchet: can't remove while running
                                blocklistIDs.remove(list.id)
                            } else {
                                blocklistIDs.insert(list.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(on ? Color.accentColor : .secondary)
                                Text(list.name)
                                Spacer()
                                if locked {
                                    Image(systemName: "lock.fill")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                } header: {
                    Text("Blocklists")
                } footer: {
                    if isRunning {
                        Text("This schedule is running. You can add blocklists but can't remove ones already active.")
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
                    .disabled(isExisting)
                }

                Section("Time") {
                    Toggle("All day (24 hours)", isOn: $allDay)
                        .disabled(isExisting)
                    if allDay {
                        Label("Blocks all day on each selected day. Pick every day for a permanent block.",
                              systemImage: "clock.badge.checkmark")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute)
                            .disabled(isExisting)
                        DatePicker("End", selection: $end, displayedComponents: .hourAndMinute)
                            .disabled(isExisting)
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

                    if allDay || !startEqualsEnd {
                        Text("Schedule runs \(durationText)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.navy)
                    }
                }

            }
            .focusLockScreen()
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

    /// How long one run of the schedule lasts, in minutes. All-day is 24 hours;
    /// an overnight window wraps past midnight into the next day.
    private var runMinutes: Int {
        if allDay { return 24 * 60 }
        let diff = minutes(end) - minutes(start)
        return diff > 0 ? diff : diff + 24 * 60
    }

    /// The run length as words, e.g. "1 hour", "1 hour 30 minutes", "45 minutes".
    private var durationText: String {
        let hours = runMinutes / 60, mins = runMinutes % 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hour\(hours == 1 ? "" : "s")") }
        if mins > 0 { parts.append("\(mins) minute\(mins == 1 ? "" : "s")") }
        return parts.isEmpty ? "0 minutes" : parts.joined(separator: " ")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !weekdays.isEmpty
            && !blocklistIDs.isEmpty && (allDay || !startEqualsEnd)
    }

    private func save() {
        let s = comps(start), e = comps(end)
        // Ratchet: while running, never drop a blocklist already in force.
        var finalIDs = blocklistIDs
        if isRunning { finalIDs.formUnion(originalIDs) }

        let schedule = BlockSchedule(id: id, name: name, blocklistIDs: Array(finalIDs),
                                     weekdays: weekdays,
                                     startHour: s.hour!, startMinute: s.minute!,
                                     endHour: e.hour!, endMinute: e.minute!,
                                     allDay: allDay)
        ScheduleStore.upsert(schedule)

        // If the schedule is running now, enforce any newly added blocklists
        // immediately — the monitor only fires at the window edges.
        if isRunning {
            for bid in finalIDs { BlockingManager.shared.addScheduled(bid) }
        }
        dismiss()
    }

    private func comps(_ d: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: d)
    }

    private static func date(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}
