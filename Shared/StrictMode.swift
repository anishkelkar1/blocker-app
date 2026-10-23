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
        static let isBlocking = "isBlocking"
        static let lockedUntil = "lockedUntil"
        static let strict = "strictLevel"
        static let pinHash = "pinHash"
        static let pinSalt = "pinSalt"
        static let activeDomains = "activeDomains"
        static let activeBlocklistID = "activeBlocklistID"
        static let manualRunning = "manualRunning"
    }

    // MARK: Active blocklist (set by a manual run OR by a schedule)

    /// Domains the tunnel should block right now. Empty = block nothing.
    static var activeDomains: [String] {
        get { (d.array(forKey: Key.activeDomains) as? [String]) ?? [] }
        set { d.set(newValue, forKey: Key.activeDomains) }
    }

    /// The blocklist currently enforced, if any.
    static var activeBlocklistID: String? {
        get { d.string(forKey: Key.activeBlocklistID) }
        set { d.set(newValue, forKey: Key.activeBlocklistID) }
    }

    /// True when the user started a block by hand (vs. a schedule). Lets a
    /// schedule's interval-end avoid tearing down a manual session.
    static var manualRunning: Bool {
        get { d.bool(forKey: Key.manualRunning) }
        set { d.set(newValue, forKey: Key.manualRunning) }
    }

    // MARK: Block state

    static var isBlocking: Bool {
        get { d.bool(forKey: Key.isBlocking) }
        set { d.set(newValue, forKey: Key.isBlocking) }
    }

    /// When the current hard-timer / session ends. `nil` = indefinite.
    static var lockedUntil: Date? {
        get { d.object(forKey: Key.lockedUntil) as? Date }
        set { d.set(newValue, forKey: Key.lockedUntil) }
    }

    static var strictLevel: StrictLevel {
        get { StrictLevel(rawValue: d.string(forKey: Key.strict) ?? "") ?? .off }
        set { d.set(newValue.rawValue, forKey: Key.strict) }
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
