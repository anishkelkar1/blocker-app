import Foundation
import FamilyControls

/// Wraps FamilyControls authorization. The app is largely inert until the
/// user grants Screen Time access. On your own device this uses `.individual`
/// authorization (no Family Sharing required).
@MainActor
final class AuthorizationManager: ObservableObject {
    @Published var status: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus

    func refresh() {
        status = AuthorizationCenter.shared.authorizationStatus
    }

    /// Prompts for Screen Time authorization. Must run on a real device; the
    /// Simulator cannot grant this.
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            // The user declined, or the entitlement is missing (e.g. free
            // provisioning). The UI reads `status` to show guidance.
            print("FamilyControls authorization failed: \(error)")
        }
        refresh()
    }

    var isAuthorized: Bool { status == .approved }
}
