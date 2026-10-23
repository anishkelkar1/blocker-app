import SwiftUI

struct StrictModeView: View {
    @EnvironmentObject var controller: BlockController

    @State private var level: StrictLevel = SharedState.strictLevel
    @State private var newPIN = ""
    @State private var confirmPIN = ""
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("When blocking is on", selection: $level) {
                        ForEach(StrictLevel.allCases) { lvl in
                            Text(lvl.title).tag(lvl)
                        }
                    }
                    .pickerStyle(.inline)
                    .onChange(of: level) { _, new in
                        SharedState.strictLevel = new
                        controller.strictLevel = new
                    }
                } header: {
                    Text("Strictness")
                } footer: {
                    Text("PIN required: stopping a block needs the PIN.\nLocked until timer: a timed session can't be stopped early — not even with the PIN.")
                }

                Section("PIN") {
                    SecureField("New PIN", text: $newPIN)
                        .keyboardType(.numberPad)
                    SecureField("Confirm PIN", text: $confirmPIN)
                        .keyboardType(.numberPad)
                    Button("Save PIN") { savePIN() }
                        .disabled(newPIN.count < 4)
                    if SharedState.hasPIN {
                        Label("A PIN is set", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                }

                Section {
                    Label("Prevent deleting this app", systemImage: "trash.slash")
                    Text("While strict mode is active, the app sets ManagedSettings `denyAppRemoval`. Honest limit: on your own device you can still revoke Screen Time access in Settings and then delete. For a hard lock, set a Screen Time passcode you don't hold, or supervise the device. A factory reset always removes everything.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Can't-delete lock")
                }
            }
            .navigationTitle("Strict mode")
            .onAppear { level = SharedState.strictLevel }
            .alert("PIN", isPresented: .constant(message != nil)) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }

    private func savePIN() {
        guard newPIN == confirmPIN else {
            message = "PINs don't match."
            return
        }
        PINCrypto.setPIN(newPIN)
        newPIN = ""; confirmPIN = ""
        message = "PIN saved."
    }
}
