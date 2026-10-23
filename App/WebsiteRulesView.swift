import SwiftUI

/// Manage the domain blocklist enforced by the DNS tunnel across every browser
/// and app. Host/domain level only — see the note at the bottom.
struct WebsiteRulesView: View {
    @State private var entries: [String] = BlockedDomains.entries
    @State private var newEntry = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("domain or keyword (e.g. reddit.com)", text: $newEntry)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit(add)
                        Button("Add", action: add)
                            .disabled(newEntry.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } footer: {
                    Text("Blocks this host in every browser and app while a session with the network filter is on. A bare word (no dot) matches any host containing it, e.g. \"casino\".")
                }

                Section("Blocked (\(entries.count))") {
                    if entries.isEmpty {
                        Text("Nothing blocked yet.").foregroundStyle(.secondary)
                    }
                    ForEach(entries, id: \.self) { Text($0) }
                        .onDelete(perform: delete)
                }

                Section {
                    Text("Host/domain matching only. iOS does not expose the encrypted URL path to a non-MDM app, so rules can't match keywords inside a full URL (like a search query) — only the site's host.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Websites")
            .toolbar { EditButton() }
        }
    }

    private func add() {
        let value = newEntry
        BlockedDomains.add(value)
        entries = BlockedDomains.entries
        newEntry = ""
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { BlockedDomains.remove(entries[i]) }
        entries = BlockedDomains.entries
    }
}
