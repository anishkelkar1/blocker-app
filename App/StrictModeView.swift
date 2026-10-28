import SwiftUI

/// A single commitment control: keep FocusLock from being deleted while the
/// lock is on. (The strictness levels and PIN were removed.)
struct StrictModeView: View {
    @State private var denyRemoval = SharedState.denyAppRemoval

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Prevent deleting this app", isOn: $denyRemoval)
                        .onChange(of: denyRemoval) { on in
                            SharedState.denyAppRemoval = on
                            BlockingManager.shared.setAppRemoval(denied: on)
                        }
                } header: {
                    Text("Can't-delete lock")
                }
            }
            .navigationTitle("Strict mode")
            .onAppear { denyRemoval = SharedState.denyAppRemoval }
        }
    }
}
