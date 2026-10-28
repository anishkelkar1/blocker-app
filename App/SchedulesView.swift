import SwiftUI

/// Lists recurring block schedules and lets the user add, edit, enable or
/// delete them. Any change re-registers DeviceActivity monitoring.
struct SchedulesView: View {
    @State private var schedules: [BlockSchedule] = ScheduleStore.all
    @State private var blocklists: [Blocklist] = BlocklistStore.all
    @State private var editing: BlockSchedule?
    @State private var showDeleteBlocked = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(schedules) { schedule in
                    Button { editing = schedule } label: { row(schedule) }
                        .tint(.primary)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                tryDelete(schedule)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }

                if schedules.isEmpty {
                    Text("No schedules yet. Tap + to add one.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Schedules")
            .alert("Can't delete this schedule", isPresented: $showDeleteBlocked) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Turn the schedule off first (open it and switch Enabled off), then delete it.")
            }
            .onAppear {
                // Re-read the stores each time the tab appears, so a blocklist
                // created on another tab is picked up (SwiftUI won't re-run body
                // on its own here — the stores aren't observed objects).
                schedules = ScheduleStore.all
                blocklists = BlocklistStore.all
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addNew() } label: { Image(systemName: "plus") }
                        .disabled(blocklists.isEmpty)
                }
            }
            .sheet(item: $editing, onDismiss: reload) { schedule in
                ScheduleEditorView(schedule: schedule)
            }
            .overlay {
                if blocklists.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "list.bullet")
                            .font(.largeTitle).foregroundStyle(.secondary)
                        Text("Create a blocklist first").font(.headline)
                        Text("Schedules run a blocklist on a timer.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
        }
    }

    private func row(_ s: BlockSchedule) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(s.name).font(.headline)
                Spacer()
                if !s.enabled {
                    Text("off").font(.caption).foregroundStyle(.secondary)
                } else if s.isActiveNow {
                    Text("running").font(.caption).foregroundStyle(.green)
                }
            }
            Text("\(BlocklistStore.get(s.blocklistID)?.name ?? "—") · \(s.weekdaysText) · \(s.windowText)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func addNew() {
        guard let first = blocklists.first else { return }
        editing = BlockSchedule(name: "New schedule", blocklistID: first.id)
    }

    private func reload() {
        schedules = ScheduleStore.all
        blocklists = BlocklistStore.all
        ScheduleManager.shared.refreshAll()
    }

    /// A schedule can only be deleted while it's off. An enabled schedule is a
    /// standing commitment, so deletion is refused until it's disabled — this
    /// also covers a schedule that's currently running.
    private func tryDelete(_ s: BlockSchedule) {
        guard !s.enabled else { showDeleteBlocked = true; return }
        ScheduleStore.remove(s.id)
        reload()
    }
}
