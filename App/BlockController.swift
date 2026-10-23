import Foundation
import DeviceActivity

/// Drives a *manual* block run of a chosen blocklist (start now, optionally for
/// a fixed duration). Recurring blocks are handled by schedules + the monitor
/// extension, not here.
@MainActor
final class BlockController: ObservableObject {
    @Published var selectedBlocklistID: UUID?
    @Published var isBlocking = SharedState.manualRunning
    @Published var strictLevel = SharedState.strictLevel
    @Published var lockedUntil: Date? = SharedState.lockedUntil

    private let center = DeviceActivityCenter()

    init() {
        selectedBlocklistID = SharedState.activeBlocklistID.flatMap(UUID.init)
            ?? BlocklistStore.all.first?.id
    }

    var selectedBlocklist: Blocklist? {
        guard let id = selectedBlocklistID else { return nil }
        return BlocklistStore.get(id)
    }

    // MARK: Start

    /// Start blocking the selected blocklist now. `duration == nil` blocks until
    /// stopped; a duration starts a timed session that ends on its own.
    func start(duration: TimeInterval?) {
        guard let blocklist = selectedBlocklist else { return }

        let until = duration.map { Date().addingTimeInterval($0) }
        SharedState.strictLevel = strictLevel
        SharedState.lockedUntil = until
        SharedState.manualRunning = true
        SharedState.isBlocking = true
        lockedUntil = until
        isBlocking = true

        BlockingManager.shared.activate(blocklist, denyRemoval: strictLevel != .off)

        if let until {
            scheduleManualEnd(until: until)
        } else {
            center.stopMonitoring([BlockingManager.manualActivity])
        }
    }

    private func scheduleManualEnd(until: Date) {
        let cal = Calendar.current
        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents([.hour, .minute, .second], from: Date()),
            intervalEnd: cal.dateComponents([.hour, .minute, .second], from: until),
            repeats: false
        )
        do { try center.startMonitoring(BlockingManager.manualActivity, during: schedule) }
        catch { print("manual startMonitoring failed: \(error)") }
    }

    // MARK: Stop

    enum StopResult { case stopped, needsPIN, hardLocked }

    func requestStop(pin: String? = nil) -> StopResult {
        if SharedState.isHardLocked { return .hardLocked }
        if strictLevel == .pinGated, SharedState.hasPIN {
            guard let pin, PINCrypto.verify(pin) else { return .needsPIN }
        }
        forceStop()
        return .stopped
    }

    private func forceStop() {
        center.stopMonitoring([BlockingManager.manualActivity])
        BlockingManager.shared.deactivate()
        SharedState.manualRunning = false
        SharedState.lockedUntil = nil
        SharedState.isBlocking = false
        isBlocking = false
        lockedUntil = nil
    }

    func refresh() {
        isBlocking = SharedState.manualRunning
        strictLevel = SharedState.strictLevel
        lockedUntil = SharedState.lockedUntil
    }
}
