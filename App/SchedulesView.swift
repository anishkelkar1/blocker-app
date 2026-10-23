import SwiftUI

/// Lists recurring block schedules and lets the user add, edit, enable or
/// delete them. Any change re-registers DeviceActivity monitoring.
struct SchedulesView: View {
    @State private var schedules: [BlockSchedule] = ScheduleStore.all
    @State private var editing: BlockSchedule?

    var body: some View {
        NavigationStack {
            List {
                ForEach(schedules) { schedule in
                    Button { editing = schedule } label: { row(schedule) }
                        .tint(.primary)
                }
                .onDelete(perform: delete)

                if schedules.isEmpty {
                    Text("No schedules yet. Tap + to add one.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Schedules")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addNew() } label: { Image(systemName: "plus") }
                        .disabled(BlocklistStore.all.isEmpty)
                }
            }
            .sheet(item: $editing, onDismiss: reload) { schedule in
                ScheduleEditorView(schedule: schedule)
            }
            .overlay {
                if BlocklistStore.all.isEmpty {
                    ContentUnavailableView("Create a blocklist first",
                                           systemImage: "list.bullet",
                                           description: Text("Schedules run a blocklist on a timer."))
                }
            }
        }
    }

    private func row(_ s: BlockSchedule) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(s.name).font(.headline)
                Spacer()
                if !s.enabled { Text("off").font(.caption).foregroundStyle(.secondary) }
            }
            Text("\(BlocklistStore.get(s.blocklistID)?.name ?? "—") · \(s.weekdaysText) · \(s.startText)–\(s.endText)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func addNew() {
        guard let first = BlocklistStore.all.first else { return }
        editing = BlockSchedule(name: "New schedule", blocklistID: first.id)
    }

    private func reload() {
        schedules = ScheduleStore.all
        ScheduleManager.shared.refreshAll()
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { ScheduleStore.remove(schedules[i].id) }
        reload()
    }
}
