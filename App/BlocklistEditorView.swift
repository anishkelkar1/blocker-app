import SwiftUI
import FamilyControls

/// Create or edit one blocklist: its name, the apps/categories it blocks
/// (system picker), and its website domain rules.
struct BlocklistEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selection: FamilyActivitySelection
    @State private var domains: [String]
    @State private var newDomain = ""
    @State private var pickerPresented = false

    private let id: UUID

    init(blocklist: Blocklist) {
        id = blocklist.id
        _name = State(initialValue: blocklist.name)
        _domains = State(initialValue: blocklist.domains)
        _selection = State(initialValue:
            BlockingManager.shared.decodeSelection(blocklist.selectionData) ?? FamilyActivitySelection())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Blocklist name", text: $name)
                }

                Section("Apps & categories") {
                    Button {
                        pickerPresented = true
                    } label: {
                        Label("Choose apps & categories", systemImage: "square.grid.2x2")
                    }
                    LabeledContent("Apps", value: "\(selection.applicationTokens.count)")
                    LabeledContent("Categories", value: "\(selection.categoryTokens.count)")
                    LabeledContent("Safari sites", value: "\(selection.webDomainTokens.count)")
                }

                Section {
                    HStack {
                        TextField("domain or keyword", text: $newDomain)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit(addDomain)
                        Button("Add", action: addDomain)
                            .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    ForEach(domains, id: \.self) { Text($0) }
                        .onDelete { domains.remove(atOffsets: $0) }
                } header: {
                    Text("Website rules (all browsers)")
                } footer: {
                    Text("Enforced by the DNS filter in every browser. Host level only — a bare word matches any host containing it.")
                }
            }
            .navigationTitle("Blocklist")
            .familyActivityPicker(isPresented: $pickerPresented, selection: $selection)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addDomain() {
        let value = BlockedDomains.normalize(newDomain)
        guard !value.isEmpty, !domains.contains(value) else { newDomain = ""; return }
        domains.append(value)
        newDomain = ""
    }

    private func save() {
        let list = Blocklist(id: id, name: name,
                             selectionData: BlockingManager.shared.encodeSelection(selection),
                             domains: domains)
        BlocklistStore.upsert(list)
        dismiss()
    }
}
