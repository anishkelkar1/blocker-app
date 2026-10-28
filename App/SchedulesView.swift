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
                        .card()
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                tryDelete(schedule)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                }

                if schedules.isEmpty {
                    Text("No schedules yet. Tap + to add one.")
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .focusLockScreen()
            .navigationTitle("Schedules")
            .alert("Can't delete this schedule", isPresented: $showDeleteBlocked) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This schedule is running right now. You can delete it once its window ends.")
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
        HStack {
            Text(s.name).font(.headline)
            Spacer()
            statusBadge(s.isActiveNow)
        }
    }

    /// Green ON while the schedule's window covers now, red OFF otherwise.
    /// ON is a green-outlined pill with green text; OFF is a filled red pill.
    private func statusBadge(_ on: Bool) -> some View {
        Text(on ? "ON" : "OFF")
            .font(.caption.weight(.bold))
            .foregroundStyle(on ? Color.green : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                if on {
                    Capsule().stroke(Color.green, lineWidth: 1.5)
                } else {
                    Capsule().fill(Color.red)
                }
            }
    }

    private func addNew() {
        guard let first = blocklists.first else { return }
        editing = BlockSchedule(name: "New schedule", blocklistIDs: [first.id])
    }

    private func reload() {
        schedules = ScheduleStore.all
        blocklists = BlocklistStore.all
        ScheduleManager.shared.refreshAll()
    }

    /// A schedule can't be deleted while it's running — that would lift a block
    /// in force. It can be deleted once its window ends.
    private func tryDelete(_ s: BlockSchedule) {
        guard !s.isActiveNow else { showDeleteBlocked = true; return }
        ScheduleStore.remove(s.id)
        reload()
    }
}
