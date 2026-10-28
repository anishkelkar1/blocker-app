import SwiftUI

/// Lists the user's saved blocklists and lets them add, edit or delete.
struct BlocklistsView: View {
    @State private var blocklists: [Blocklist] = BlocklistStore.all
    @State private var editing: Blocklist?
    @State private var showDeleteBlocked = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(blocklists) { list in
                    Button {
                        editing = list
                    } label: {
                        HStack {
                            Text(list.name).font(.headline)
                            Spacer()
                            statusBadge(SharedState.activeIDs.contains(list.id.uuidString))
                        }
                    }
                    .tint(.primary)
                    .card()
                    .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            tryDelete(list)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }

                if blocklists.isEmpty {
                    Text("No blocklists yet. Tap + to create one.")
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .focusLockScreen()
            .navigationTitle("Blocklists")
            .alert("Can't delete this blocklist", isPresented: $showDeleteBlocked) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This blocklist is active right now. You can delete it once it stops running.")
            }
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

    /// Green outlined "Active" while the blocklist is being enforced (manually or
    /// by a schedule), red filled "Not Active" otherwise.
    private func statusBadge(_ active: Bool) -> some View {
        Text(active ? "Active" : "Not Active")
            .font(.caption.weight(.bold))
            .foregroundStyle(active ? Color.green : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                if active {
                    Capsule().stroke(Color.green, lineWidth: 1.5)
                } else {
                    Capsule().fill(Color.red)
                }
            }
    }

    private func reload() { blocklists = BlocklistStore.all }

    /// A blocklist can't be deleted while it's active (running manually or by a
    /// schedule) — that would lift a block in force. Stop it first.
    private func tryDelete(_ list: Blocklist) {
        guard !SharedState.activeIDs.contains(list.id.uuidString) else {
            showDeleteBlocked = true
            return
        }
        BlocklistStore.remove(list.id)
        reload()
    }
}
