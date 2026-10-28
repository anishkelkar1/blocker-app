import SwiftUI

@main
struct FocusLockApp: App {
    @StateObject private var auth = AuthorizationManager()
    @StateObject private var controller = BlockController()
    @StateObject private var tunnel = TunnelController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .environmentObject(controller)
                .environmentObject(tunnel)
                .task {
                    // The can't-delete lock was removed (iOS can only block
                    // deleting *every* app, not just this one). Clear it on
                    // launch so any device that still has it on is unlocked.
                    SharedState.denyAppRemoval = false
                    BlockingManager.shared.setAppRemoval(denied: false)
                    auth.refresh()
                    await tunnel.load()
                    ScheduleManager.shared.refreshAll()
                }
                .onChange(of: scenePhase) { phase in
                    // Re-check authorization each time the app comes forward, so
                    // a status restored after launch is picked up.
                    if phase == .active { auth.refresh() }
                }
        }
    }
}
