import Foundation
import Combine
import FamilyControls

/// Wraps FamilyControls authorization. The app is largely inert until the
/// user grants Screen Time access. On your own device this uses `.individual`
/// authorization (no Family Sharing required).
@MainActor
final class AuthorizationManager: ObservableObject {
    @Published var status: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus

    private var cancellable: AnyCancellable?

    init() {
        // At cold launch `authorizationStatus` can read `.notDetermined` before
        // FamilyControls restores the real value, which flashed the "access
        // needed" banner on every open. Mirror the center's published status so
        // the banner clears as soon as the restored value ( .approved ) lands.
        cancellable = AuthorizationCenter.shared.$authorizationStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.status = $0 }
    }

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
