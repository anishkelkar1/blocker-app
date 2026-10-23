import SwiftUI
import FamilyControls

/// Lets you choose which apps, categories and website domains to block, using
/// Apple's system `FamilyActivityPicker` (the tokens never expose real app
/// identities to your code — that is by design).
struct PickerView: View {
    @EnvironmentObject var controller: BlockController
    @State private var pickerPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        pickerPresented = true
                    } label: {
                        Label("Choose apps & websites", systemImage: "plus.circle")
                    }
                } footer: {
                    Text("Pick apps, whole categories, and Safari website domains. Changes are saved automatically.")
                }

                Section("Current selection") {
                    row("Apps", controller.selection.applicationTokens.count)
                    row("Categories", controller.selection.categoryTokens.count)
                    row("Websites", controller.selection.webDomainTokens.count)
                }
            }
            .navigationTitle("Blocklist")
            .familyActivityPicker(isPresented: $pickerPresented,
                                  selection: $controller.selection)
            .onChange(of: controller.selection) { _, _ in
                controller.saveSelection()
            }
        }
    }

    private func row(_ label: String, _ count: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(count)").foregroundStyle(.secondary)
        }
    }
}
