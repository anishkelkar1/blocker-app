import SwiftUI

@main
struct FocusLockApp: App {
    @StateObject private var auth = AuthorizationManager()
    @StateObject private var controller = BlockController()
    @StateObject private var tunnel = TunnelController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .environmentObject(controller)
                .environmentObject(tunnel)
                .task {
                    auth.refresh()
                    await tunnel.load()
                    ScheduleManager.shared.refreshAll()
                }
        }
    }
}
