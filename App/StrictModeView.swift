import SwiftUI

/// A single commitment control: keep FocusLock from being deleted. Turning it on
/// asks for confirmation, and it can't be switched back off while any block is
/// running — so you can't remove the app mid-session.
struct StrictModeView: View {
    @State private var denyRemoval = SharedState.denyAppRemoval
    @State private var showConfirm = false
    @State private var showCantUndo = false

    /// Intercepts the toggle so turning on confirms first, and turning off is
    /// refused while a block is active. Visual state follows `denyRemoval`, which
    /// only changes once an action is actually committed.
    private var toggle: Binding<Bool> {
        Binding(
            get: { denyRemoval },
            set: { wantOn in
                if wantOn {
                    showConfirm = true
                } else if SharedState.anyActive {
                    showCantUndo = true
                } else {
                    apply(false)
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Prevent deleting this app", isOn: toggle)
                } header: {
                    Text("Can't-delete lock")
                }
            }
            .navigationTitle("Strict mode")
            .focusLockScreen()
            .onAppear { denyRemoval = SharedState.denyAppRemoval }
            .alert("Prevent deleting FocusLock?", isPresented: $showConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Turn on", role: .destructive) { apply(true) }
            } message: {
                Text("FocusLock will hide its Delete option. While any block is running you won't be able to turn this back off, so you can't remove the app mid-session. Only turn it off when nothing is blocking.")
            }
            .alert("Can't turn off", isPresented: $showCantUndo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("A block is currently active. Stop all blocking first, then you can turn this off.")
            }
        }
    }

    private func apply(_ on: Bool) {
        denyRemoval = on
        SharedState.denyAppRemoval = on
        BlockingManager.shared.setAppRemoval(denied: on)
    }
}
