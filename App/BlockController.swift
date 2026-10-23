import Foundation
import DeviceActivity

/// Drives *manual* block runs. The user can select one or more blocklists and
/// start them now (optionally for a fixed duration). Schedules add their own
/// blocklists on top; the enforced block is always the union.
@MainActor
final class BlockController: ObservableObject {
    /// Blocklists the user has ticked to run in a manual session.
    @Published var selectedBlocklistIDs: Set<UUID> = Set(
        SharedState.manualActiveIDs.compactMap(UUID.init)
    )
    @Published var isManualRunning = !SharedState.manualActiveIDs.isEmpty
    @Published var strictLevel = SharedState.strictLevel
    @Published var lockedUntil: Date? = SharedState.lockedUntil

    private let center = DeviceActivityCenter()

    // MARK: Start

    /// Start the selected blocklists now. `duration == nil` runs until stopped.
    func start(duration: TimeInterval?) {
        guard !selectedBlocklistIDs.isEmpty else { return }

        let until = duration.map { Date().addingTimeInterval($0) }
        SharedState.strictLevel = strictLevel
        SharedState.lockedUntil = until
        lockedUntil = until

        BlockingManager.shared.startManual(Array(selectedBlocklistIDs))
        isManualRunning = true

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
        BlockingManager.shared.stopManual()
        SharedState.lockedUntil = nil
        isManualRunning = false
        lockedUntil = nil
    }

    func refresh() {
        isManualRunning = !SharedState.manualActiveIDs.isEmpty
        strictLevel = SharedState.strictLevel
        lockedUntil = SharedState.lockedUntil
        selectedBlocklistIDs.formUnion(SharedState.manualActiveIDs.compactMap(UUID.init))
    }
}
