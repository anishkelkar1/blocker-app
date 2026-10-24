import Foundation
import ManagedSettings

/// Identifiers shared between the app and its extensions.
///
/// IMPORTANT: change `id` to match the App Group you create in your Apple
/// Developer account, and keep it identical in every target's entitlements
/// file. The app, the DeviceActivityMonitor extension and the Shield
/// extension must all belong to this same App Group so they can read the
/// same saved selection and the same ManagedSettings store.
enum AppGroup {
    /// App Group container id. Must match all `.entitlements` files.
    static let id = "group.com.anishkelkar.focuslock"

    /// Named ManagedSettings store. App and extensions target the same name
    /// so shields applied in one process are visible to the others.
    static let storeName = ManagedSettingsStore.Name("focuslock")

    /// Shared defaults living in the App Group container.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }
}
