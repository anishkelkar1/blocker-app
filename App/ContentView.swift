import SwiftUI
import FamilyControls

struct ContentView: View {
    @EnvironmentObject var auth: AuthorizationManager
    @EnvironmentObject var controller: BlockController

    init() {
        #if canImport(UIKit)
        Theme.configureBars()
        #endif
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Focus", systemImage: "lock.shield") }

            BlocklistsView()
                .tabItem { Label("Blocklists", systemImage: "list.bullet") }

            SchedulesView()
                .tabItem { Label("Schedules", systemImage: "calendar") }
        }
        .tint(Theme.navy)
        .roundedFont()
        .preferredColorScheme(.light)
    }
}

/// Shown at the top of Home when Screen Time access is not yet granted.
struct AuthBanner: View {
    @EnvironmentObject var auth: AuthorizationManager

    var body: some View {
        Group {
            switch auth.status {
            case .approved:
                EmptyView()
            default:
                VStack(alignment: .leading, spacing: 10) {
                    Label("Screen Time access needed", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.navyDeep)
                    Text("Blocking does nothing until you grant Screen Time access. This needs a real device and a build signed with the Family Controls entitlement.")
                        .font(.footnote)
                        .foregroundStyle(Theme.silver)
                    Button("Grant access") {
                        Task { await auth.requestAuthorization() }
                    }
                    .buttonStyle(FilledPill())
                    .padding(.top, 2)
                }
                .card()
            }
        }
    }
}
