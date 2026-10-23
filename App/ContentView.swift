import SwiftUI
import FamilyControls

struct ContentView: View {
    @EnvironmentObject var auth: AuthorizationManager
    @EnvironmentObject var controller: BlockController

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Focus", systemImage: "lock.shield") }

            PickerView()
                .tabItem { Label("Blocklist", systemImage: "list.bullet") }

            WebsiteRulesView()
                .tabItem { Label("Websites", systemImage: "globe") }

            StrictModeView()
                .tabItem { Label("Strict", systemImage: "exclamationmark.lock") }
        }
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
                VStack(alignment: .leading, spacing: 8) {
                    Label("Screen Time access needed", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                    Text("Blocking does nothing until you grant Screen Time access. This requires a real device and a build signed with the Family Controls entitlement.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Grant access") {
                        Task { await auth.requestAuthorization() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
