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
                } footer: {
                    Text("While on, FocusLock sets ManagedSettings denyAppRemoval so the app can't be removed from the Home Screen. Honest limit: with personal (individual) Screen Time authorization you can still revoke access in Settings → Screen Time and then delete. For a hard lock, set a Screen Time passcode you don't hold. A factory reset always removes everything.")
                }
            }
            .navigationTitle("Strict mode")
            .onAppear { denyRemoval = SharedState.denyAppRemoval }
        }
    }
}
