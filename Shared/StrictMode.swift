import Foundation

/// How hard it is to stop an active block.
enum StrictLevel: String, Codable, CaseIterable, Identifiable {
    /// Stop anytime with one tap.
    case off
    /// Stopping requires the PIN.
    case pinGated
    /// Cannot stop until the timer expires. The PIN does NOT override this.
    case hardTimer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off — stop anytime"
        case .pinGated: return "PIN required to stop"
        case .hardTimer: return "Locked until timer ends"
        }
    }
}

/// Persistent block + strict-mode state, shared across app and extensions
/// through the App Group defaults.
///
/// Everything here is deliberately small and `Codable`/primitive so the
/// extensions (which run in a separate process) can read the exact same
/// values the app wrote.
enum SharedState {
    private static var d: UserDefaults { AppGroup.defaults }

    private enum Key {
        static let lockedUntil = "lockedUntil"
        static let strict = "strictLevel"
        static let pinHash = "pinHash"
        static let pinSalt = "pinSalt"
        static let activeDomains = "activeDomains"
        static let manualActiveIDs = "manualActiveIDs"
        static let scheduledActiveIDs = "scheduledActiveIDs"
        static let denyAppRemoval = "denyAppRemoval"
    }

    // MARK: Active blocklists (several can run at once)

    /// Domains the tunnel should block right now — the union across every
    /// active blocklist. Empty = block nothing. Recomputed by BlockingManager.
    static var activeDomains: [String] {
        get { (d.array(forKey: Key.activeDomains) as? [String]) ?? [] }
        set { d.set(newValue, forKey: Key.activeDomains) }
    }

    /// Blocklist ids the user started by hand.
    static var manualActiveIDs: [String] {
        get { (d.array(forKey: Key.manualActiveIDs) as? [String]) ?? [] }
        set { d.set(newValue, forKey: Key.manualActiveIDs) }
    }

    /// Blocklist ids currently activated by a running schedule.
    static var scheduledActiveIDs: [String] {
        get { (d.array(forKey: Key.scheduledActiveIDs) as? [String]) ?? [] }
        set { d.set(newValue, forKey: Key.scheduledActiveIDs) }
    }

    /// The union of manual + scheduled active blocklist ids (de-duplicated).
    static var activeIDs: [String] {
        Array(Set(manualActiveIDs + scheduledActiveIDs))
    }

    /// True if anything at all is being blocked right now.
    static var anyActive: Bool { !activeIDs.isEmpty }

    // MARK: Block state

    /// When the current hard-timer / session ends. `nil` = indefinite.
    static var lockedUntil: Date? {
        get { d.object(forKey: Key.lockedUntil) as? Date }
        set { d.set(newValue, forKey: Key.lockedUntil) }
    }

    static var strictLevel: StrictLevel {
        get { StrictLevel(rawValue: d.string(forKey: Key.strict) ?? "") ?? .off }
        set { d.set(newValue.rawValue, forKey: Key.strict) }
    }

    /// Whether FocusLock should keep itself from being deleted (ManagedSettings
    /// `denyAppRemoval`). Set by the "Can't-delete lock" toggle and re-applied
    /// whenever the managed store is reconfigured, independent of any session.
    static var denyAppRemoval: Bool {
        get { d.bool(forKey: Key.denyAppRemoval) }
        set { d.set(newValue, forKey: Key.denyAppRemoval) }
    }

    // MARK: PIN (salted SHA-256; the plain PIN is never stored)

    static var pinHash: String? {
        get { d.string(forKey: Key.pinHash) }
        set { d.set(newValue, forKey: Key.pinHash) }
    }

    static var pinSalt: String? {
        get { d.string(forKey: Key.pinSalt) }
        set { d.set(newValue, forKey: Key.pinSalt) }
    }

    static var hasPIN: Bool { pinHash != nil }

    // MARK: Derived

    /// True while a hard timer is still running — early stop must be refused.
    static var isHardLocked: Bool {
        guard strictLevel == .hardTimer, let until = lockedUntil else { return false }
        return Date() < until
    }
}
