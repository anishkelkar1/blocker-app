import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

/// Applies and removes the actual Screen Time shields. Used by both the app
/// (when you tap Start/Stop) and the DeviceActivityMonitor extension (which
/// re-asserts shields at the scheduled interval boundaries).
public final class BlockingManager {
    public static let shared = BlockingManager()

    /// Named store, shared by name with the extensions.
    private let store = ManagedSettingsStore(named: AppGroup.storeName)

    /// A fixed DeviceActivity name for the single session this app runs.
    static let activityName = DeviceActivityName("focuslock.session")

    private init() {}

    // MARK: Shields

    /// Apply shields for the given selection and (optionally) forbid removing
    /// this app while the block is active.
    public func applyShields(from selection: FamilyActivitySelection, denyRemoval: Bool) {
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil : selection.applicationTokens

        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)

        store.shield.webDomains = selection.webDomainTokens.isEmpty
            ? nil : selection.webDomainTokens

        setAppRemoval(denied: denyRemoval)
    }

    /// Re-read the saved selection from shared storage and apply it. Called by
    /// the monitor extension, which has no in-memory model of its own.
    public func reapplyFromSharedState() {
        guard let selection = loadSelection() else { return }
        applyShields(from: selection, denyRemoval: SharedState.strictLevel != .off)
    }

    /// Remove every shield and lift the removal lock.
    public func clearAll() {
        store.clearAllSettings()
        setAppRemoval(denied: false)
    }

    /// Toggle the "can't delete this app" restriction.
    ///
    /// NOTE: with `.individual` FamilyControls authorization (what a personal
    /// app uses) this is NOT guaranteed — the user can revoke authorization in
    /// Settings and then delete. See README "Strict mode honest limits".
    public func setAppRemoval(denied: Bool) {
        store.application.denyAppRemoval = denied ? true : nil
    }

    // MARK: Selection persistence helpers

    public func saveSelection(_ selection: FamilyActivitySelection) {
        SharedState.selectionData = try? JSONEncoder().encode(selection)
    }

    public func loadSelection() -> FamilyActivitySelection? {
        guard let data = SharedState.selectionData else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }
}
