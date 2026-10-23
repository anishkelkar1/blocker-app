import SwiftUI

@main
struct FocusLockApp: App {
    @StateObject private var auth = AuthorizationManager()
    @StateObject private var controller = BlockController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .environmentObject(controller)
                .task { auth.refresh() }
        }
    }
}
