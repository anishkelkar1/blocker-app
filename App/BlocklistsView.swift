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
                    }
                    .tint(.primary)
                }
                .onDelete(perform: delete)

                if blocklists.isEmpty {
                    Text("No blocklists yet. Tap + to create one.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Blocklists")
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
        "\(list.domains.count) site rule(s)"
    }

    private func reload() { blocklists = BlocklistStore.all }

    private func delete(at offsets: IndexSet) {
        for i in offsets { BlocklistStore.remove(blocklists[i].id) }
        reload()
    }
}
