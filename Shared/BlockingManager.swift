import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

/// Applies and removes the actual Screen Time shields for a blocklist, and
/// mirrors the active blocklist's domains into shared state for the tunnel.
/// Used by the app (manual run) and by the DeviceActivityMonitor extension
/// (scheduled run).
public final class BlockingManager {
    public static let shared = BlockingManager()

    private let store = ManagedSettingsStore(named: AppGroup.storeName)

    /// DeviceActivity name for a manual timed session (schedules use their own).
    static let manualActivity = DeviceActivityName("focuslock.manual")

    private init() {}

    // MARK: Apply / clear raw shields

    public func applyShields(from selection: FamilyActivitySelection, denyRemoval: Bool) {
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty
            ? nil : selection.webDomainTokens
        setAppRemoval(denied: denyRemoval)
    }

    public func clearAll() {
        store.clearAllSettings()
        setAppRemoval(denied: false)
    }

    /// Toggle the "can't delete this app" restriction. Not guaranteed under
    /// `.individual` authorization — see README "Strict mode honest limits".
    public func setAppRemoval(denied: Bool) {
        store.application.denyAppRemoval = denied ? true : nil
    }

    // MARK: Activate / deactivate a blocklist

    /// Enforce a blocklist: apply its Screen Time shields and publish its
    /// domains for the tunnel.
    public func activate(_ blocklist: Blocklist, denyRemoval: Bool) {
        let selection = decodeSelection(blocklist.selectionData) ?? FamilyActivitySelection()
        applyShields(from: selection, denyRemoval: denyRemoval)
        SharedState.activeDomains = blocklist.domains
        SharedState.activeBlocklistID = blocklist.id.uuidString
    }

    /// Stop enforcing: clear shields and the tunnel's domain set.
    public func deactivate() {
        clearAll()
        SharedState.activeDomains = []
        SharedState.activeBlocklistID = nil
    }

    // MARK: Selection coding

    public func encodeSelection(_ selection: FamilyActivitySelection) -> Data? {
        try? JSONEncoder().encode(selection)
    }

    public func decodeSelection(_ data: Data?) -> FamilyActivitySelection? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }
}
