import Foundation
import NetworkExtension

/// App-side control of the DNS-filtering packet tunnel. Installs/updates the
/// VPN configuration (the user approves it once in a system prompt) and starts
/// or stops it alongside a focus session.
@MainActor
final class TunnelController: ObservableObject {
    @Published var status: NEVPNStatus = .invalid

    /// Must match the Tunnel extension's bundle identifier.
    private let providerBundleID = "com.example.focuslock.tunnel"
    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?

    // MARK: Loading

    /// Load the existing configuration or create one in memory.
    func load() async {
        let managers = (try? await NETunnelProviderManager.loadAllFromPreferences()) ?? []
        let mgr = managers.first ?? NETunnelProviderManager()
        configure(mgr)
        manager = mgr
        status = mgr.connection.status
        observeStatus()
    }

    private func configure(_ mgr: NETunnelProviderManager) {
        let proto = (mgr.protocolConfiguration as? NETunnelProviderProtocol)
            ?? NETunnelProviderProtocol()
        proto.providerBundleIdentifier = providerBundleID
        proto.serverAddress = "FocusLock DNS filter"
        mgr.protocolConfiguration = proto
        mgr.localizedDescription = "FocusLock"
        mgr.isEnabled = true
    }

    private func observeStatus() {
        guard let connection = manager?.connection else { return }
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: connection, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.status = connection.status }
        }
    }

    // MARK: Start / stop

    /// Save, (re)load and start the tunnel. The first start shows the system
    /// "FocusLock would like to add VPN configurations" prompt.
    func start() async {
        guard let manager else { return }
        configure(manager)
        do {
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences() // required before starting
            try manager.connection.startVPNTunnel()
        } catch {
            print("Tunnel start failed: \(error)")
        }
    }

    func stop() {
        manager?.connection.stopVPNTunnel()
    }

    var isActive: Bool {
        status == .connected || status == .connecting || status == .reasserting
    }
}
