import Foundation
import FamilyControls
import DeviceActivity

/// The app-side view model that drives blocking. Owns the current selection
/// and start/stop logic, and mirrors state into `SharedState` so extensions
/// stay in sync.
@MainActor
final class BlockController: ObservableObject {
    @Published var selection = FamilyActivitySelection()
    @Published var isBlocking = SharedState.isBlocking
    @Published var strictLevel = SharedState.strictLevel
    @Published var lockedUntil: Date? = SharedState.lockedUntil

    private let center = DeviceActivityCenter()

    init() {
        if let saved = BlockingManager.shared.loadSelection() {
            selection = saved
        }
    }

    var hasSelection: Bool {
        !(selection.applicationTokens.isEmpty
          && selection.categoryTokens.isEmpty
          && selection.webDomainTokens.isEmpty)
    }

    /// Persist the picker result.
    func saveSelection() {
        BlockingManager.shared.saveSelection(selection)
    }

    // MARK: Start

    /// Start blocking. `duration == nil` blocks indefinitely until you stop.
    /// A non-nil duration starts a timed session; with `.hardTimer` strictness
    /// it cannot be stopped early.
    func start(duration: TimeInterval?) {
        saveSelection()

        let until = duration.map { Date().addingTimeInterval($0) }
        SharedState.strictLevel = strictLevel
        SharedState.lockedUntil = until
        SharedState.isBlocking = true
        lockedUntil = until
        isBlocking = true

        BlockingManager.shared.applyShields(from: selection,
                                            denyRemoval: strictLevel != .off)

        // If timed, register a DeviceActivity schedule so the monitor
        // extension re-asserts at the boundaries and clears at the end even if
        // the app is not running.
        if let until {
            scheduleSession(until: until)
        } else {
            center.stopMonitoring([BlockingManager.activityName])
        }
    }

    private func scheduleSession(until: Date) {
        let cal = Calendar.current
        let now = Date()
        let start = cal.dateComponents([.hour, .minute, .second], from: now)
        let end = cal.dateComponents([.hour, .minute, .second], from: until)
        let schedule = DeviceActivitySchedule(intervalStart: start,
                                              intervalEnd: end,
                                              repeats: false)
        do {
            try center.startMonitoring(BlockingManager.activityName, during: schedule)
        } catch {
            print("startMonitoring failed: \(error)")
        }
    }

    // MARK: Stop

    enum StopResult { case stopped, needsPIN, hardLocked }

    /// Attempt to stop. Honors the strict level.
    func requestStop(pin: String? = nil) -> StopResult {
        if SharedState.isHardLocked {
            return .hardLocked
        }
        if strictLevel == .pinGated, SharedState.hasPIN {
            guard let pin, PINCrypto.verify(pin) else { return .needsPIN }
        }
        forceStop()
        return .stopped
    }

    private func forceStop() {
        BlockingManager.shared.clearAll()
        center.stopMonitoring([BlockingManager.activityName])
        SharedState.isBlocking = false
        SharedState.lockedUntil = nil
        isBlocking = false
        lockedUntil = nil
    }

    /// Re-sync published values from shared storage (e.g. after returning to
    /// foreground, in case the monitor extension changed them).
    func refresh() {
        isBlocking = SharedState.isBlocking
        strictLevel = SharedState.strictLevel
        lockedUntil = SharedState.lockedUntil
    }
}
