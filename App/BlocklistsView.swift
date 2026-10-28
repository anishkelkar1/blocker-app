import SwiftUI

/// Lists the user's saved blocklists and lets them add, edit or delete.
struct BlocklistsView: View {
    @State private var blocklists: [Blocklist] = BlocklistStore.all
    @State private var editing: Blocklist?

    var body: some View {
        NavigationStack {
            List {
                ForEach(blocklists) { list in
                    Button {
                        editing = list
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(list.name).font(.headline)
                            Text(summary(list)).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .tint(.primary)
                    .card()
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onDelete(perform: delete)

                if blocklists.isEmpty {
                    Text("No blocklists yet. Tap + to create one.")
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .focusLockScreen()
            .navigationTitle("Blocklists")
            .onAppear {
                // Clear any stale scheduled-active state so the "running" badge
                // reflects only schedules actually in their window right now.
                ScheduleManager.shared.reconcileScheduledActive()
                blocklists = BlocklistStore.all
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editing = Blocklist(name: "New blocklist")
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing, onDismiss: reload) { list in
                BlocklistEditorView(blocklist: list)
            }
        }
    }

    private func summary(_ list: Blocklist) -> String {
        var parts = ["\(list.domains.count) site rule(s)"]
        if list.blockAdult { parts.append("adult") }
        if list.blockFoodDelivery { parts.append("food delivery") }
        if SharedState.activeIDs.contains(list.id.uuidString) { parts.append("running") }
        return parts.joined(separator: " · ")
    }

    private func reload() { blocklists = BlocklistStore.all }

    /// Won't delete a blocklist that's currently running — that would remove
    /// blocks already in force. Stop it first.
    private func delete(at offsets: IndexSet) {
        let active = Set(SharedState.activeIDs)
        for i in offsets where !active.contains(blocklists[i].id.uuidString) {
            BlocklistStore.remove(blocklists[i].id)
        }
        reload()
    }
}
