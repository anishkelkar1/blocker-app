import DeviceActivity
import Foundation

/// Runs in its own process. iOS wakes it at the start and end of the scheduled
/// session so shields are re-asserted and then cleared, even if the main app
/// is not running.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // Re-apply shields from the shared selection.
        BlockingManager.shared.reapplyFromSharedState()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // The timed session is over. If it was a hard timer, the lock has now
        // expired, so it is safe to clear everything.
        BlockingManager.shared.clearAll()
        SharedState.isBlocking = false
        SharedState.lockedUntil = nil
    }
}
