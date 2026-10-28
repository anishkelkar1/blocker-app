import SwiftUI
import FamilyControls

/// Create or edit one blocklist: its name, the apps/categories it blocks
/// (system picker), and its website domain rules.
struct BlocklistEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selection: FamilyActivitySelection
    @State private var domains: [String]
    @State private var blockAdult: Bool
    @State private var blockFoodDelivery: Bool
    @State private var newDomain = ""
    @State private var pickerPresented = false

    private let id: UUID
    private let originalBlockAdult: Bool
    private let originalBlockFoodDelivery: Bool

    /// True while this blocklist is currently being enforced (manually or by a
    /// schedule). While active, edits may only ADD blocks, never remove them.
    private var isActive: Bool { SharedState.activeIDs.contains(id.uuidString) }

    init(blocklist: Blocklist) {
        id = blocklist.id
        originalBlockAdult = blocklist.blockAdult
        originalBlockFoodDelivery = blocklist.blockFoodDelivery
        _name = State(initialValue: blocklist.name)
        _domains = State(initialValue: blocklist.domains)
        _blockAdult = State(initialValue: blocklist.blockAdult)
        _blockFoodDelivery = State(initialValue: blocklist.blockFoodDelivery)
        _selection = State(initialValue:
            BlockingManager.shared.decodeSelection(blocklist.selectionData) ?? FamilyActivitySelection())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Blocklist name", text: $name)
                }

                if isActive {
                    Section {
                        Label("Running — you can add blocks, but can't remove ones already active.",
                              systemImage: "lock.fill")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }

                Section {
                    Button {
                        pickerPresented = true
                    } label: {
                        Label("Choose apps & categories", systemImage: "square.grid.2x2")
                    }
                    .disabled(isActive)
                    LabeledContent("Apps", value: "\(selection.applicationTokens.count)")
                    LabeledContent("Categories", value: "\(selection.categoryTokens.count)")
                    LabeledContent("Safari sites", value: "\(selection.webDomainTokens.count)")
                } header: {
                    Text("Apps & categories")
                } footer: {
                    if isActive {
                        Text("Apps are locked while this blocklist is running. Stop it to change them.")
                    }
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
                        .onDelete(perform: isActive ? nil : removeDomains)
                } header: {
                    Text("Website rules (all browsers)")
                } footer: {
                    Text("Enforced by the DNS filter in every browser. Host level only — a bare word matches any host containing it.")
                }

                Section {
                    Toggle("Block adult sites", isOn: $blockAdult)
                        .disabled(isActive && originalBlockAdult)
                    Toggle("Block food delivery", isOn: $blockFoodDelivery)
                        .disabled(isActive && originalBlockFoodDelivery)
                } header: {
                    Text("Extra categories")
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

    private func removeDomains(at offsets: IndexSet) {
        domains.remove(atOffsets: offsets)
    }

    private func save() {
        var finalDomains = domains
        var finalAdult = blockAdult
        var finalFood = blockFoodDelivery
        var finalSelectionData = BlockingManager.shared.encodeSelection(selection)

        // Ratchet: while this blocklist is running, edits may only ADD blocks.
        // Union domains with what's stored so removals are ignored, keep the
        // category toggles on if they were on, and keep the enforced app
        // selection unchanged (the picker is locked while active, since Screen
        // Time selections can't be safely merged).
        if isActive, let current = BlocklistStore.get(id) {
            finalDomains = Array(Set(current.domains).union(finalDomains))
            finalAdult = current.blockAdult || finalAdult
            finalFood = current.blockFoodDelivery || finalFood
            finalSelectionData = current.selectionData
        }

        let list = Blocklist(id: id, name: name,
                             selectionData: finalSelectionData,
                             domains: finalDomains, blockAdult: finalAdult,
                             blockFoodDelivery: finalFood)
        BlocklistStore.upsert(list)

        // Live apply: if this blocklist is currently enforced, re-run the
        // shields and domain set so the additions take effect immediately.
        if isActive { BlockingManager.shared.recompute() }

        dismiss()
    }
}
