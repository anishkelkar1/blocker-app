import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

/// Applies the Screen Time shields and the tunnel's domain set for the UNION of
/// all active blocklists. Several blocklists can run at once — started by hand
/// and/or by schedules — and the enforced block is their combination.
///
/// Used by the app (manual runs) and by the DeviceActivityMonitor extension
/// (scheduled runs). Both just change the active-id sets and call `recompute()`.
public final class BlockingManager {
    public static let shared = BlockingManager()

    private let store = ManagedSettingsStore(named: AppGroup.storeName)

    /// DeviceActivity name for a manual timed session (schedules use their own).
    static let manualActivity = DeviceActivityName("focuslock.manual")

    private init() {}

    // MARK: Manual runs

    /// Replace the manually-run set with `ids` and re-apply.
    public func startManual(_ ids: [UUID]) {
        SharedState.manualActiveIDs = ids.map { $0.uuidString }
        recompute()
    }

    /// Clear all manually-run blocklists (schedules stay active).
    public func stopManual() {
        SharedState.manualActiveIDs = []
        recompute()
    }

    // MARK: Scheduled runs

    public func addScheduled(_ id: UUID) {
        var set = Set(SharedState.scheduledActiveIDs)
        set.insert(id.uuidString)
        SharedState.scheduledActiveIDs = Array(set)
        recompute()
    }

    public func removeScheduled(_ id: UUID) {
        SharedState.scheduledActiveIDs = SharedState.scheduledActiveIDs.filter { $0 != id.uuidString }
        recompute()
    }

    // MARK: Recompute

    /// Rebuild the shields and tunnel domain set from every active blocklist.
    public func recompute() {
        let ids = SharedState.activeIDs
        guard !ids.isEmpty else {
            clearAll()
            SharedState.activeDomains = []
            return
        }

        var apps = Set<ApplicationToken>()
        var categories = Set<ActivityCategoryToken>()
        var webs = Set<WebDomainToken>()
        var domains: [String] = []

        for idString in ids {
            guard let id = UUID(uuidString: idString),
                  let blocklist = BlocklistStore.get(id) else { continue }
            if let selection = decodeSelection(blocklist.selectionData) {
                apps.formUnion(selection.applicationTokens)
                categories.formUnion(selection.categoryTokens)
                webs.formUnion(selection.webDomainTokens)
            }
            domains.append(contentsOf: blocklist.domains)
        }

        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomains = webs.isEmpty ? nil : webs
        setAppRemoval(denied: SharedState.strictLevel != .off)
        SharedState.activeDomains = Array(Set(domains))
    }

    // MARK: Raw store helpers

    public func clearAll() {
        store.clearAllSettings()
        setAppRemoval(denied: false)
    }

    /// Toggle the "can't delete this app" restriction. Not guaranteed under
    /// `.individual` authorization — see README "Strict mode honest limits".
    public func setAppRemoval(denied: Bool) {
        store.application.denyAppRemoval = denied ? true : nil
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
