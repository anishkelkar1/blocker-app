import NetworkExtension
import Network
import Foundation

/// A DNS-filtering packet tunnel. Runs in standard routing mode (no MDM, no
/// supervision needed). It captures only DNS traffic by advertising itself as
/// the system DNS server, then:
///   • blocked host  → replies NXDOMAIN locally (host fails to resolve in every
///     browser and app),
///   • allowed host  → forwards the query to an upstream resolver and relays
///     the answer back.
///
/// No TLS interception, no root CA: this sees the queried hostname only, never
/// the encrypted URL. Known gaps: apps using hardcoded IPs or their own DoH/DoT
/// can bypass DNS filtering. IPv6 and TCP/53 are TODO.
final class PacketTunnelProvider: NEPacketTunnelProvider {

    /// Virtual addresses used only inside the tunnel.
    private let tunnelAddress = "10.96.0.2"
    private let dnsServerAddress = "10.96.0.1"
    private let upstreamResolver = "1.1.1.1"

    override func startTunnel(options: [String: NSObject]?,
                              completionHandler: @escaping (Error?) -> Void) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        let ipv4 = NEIPv4Settings(addresses: [tunnelAddress],
                                  subnetMasks: ["255.255.255.255"])
        // Route only the virtual DNS server through the tunnel; all other
        // traffic uses the normal interface untouched.
        ipv4.includedRoutes = [NEIPv4Route(destinationAddress: dnsServerAddress,
                                           subnetMask: "255.255.255.255")]
        settings.ipv4Settings = ipv4

        let dns = NEDNSSettings(servers: [dnsServerAddress])
        dns.matchDomains = [""] // intercept all DNS queries
        settings.dnsSettings = dns

        setTunnelNetworkSettings(settings) { [weak self] error in
            if let error { completionHandler(error); return }
            self?.readPackets()
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason,
                             completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    // MARK: Packet loop

    private func readPackets() {
        packetFlow.readPackets { [weak self] packets, _ in
            guard let self else { return }
            for packet in packets {
                self.handle(packet)
            }
            self.readPackets() // keep reading
        }
    }

    private func handle(_ packet: Data) {
        guard let parsed = IPv4UDPPacket.parse(packet),
              parsed.destinationPort == 53,
              let name = DNSMessage.parseQuestionName(parsed.payload) else {
            return
        }

        if BlockedDomains.isBlocked(host: name) {
            if let nx = DNSMessage.makeNXDomainResponse(from: parsed.payload) {
                let reply = parsed.makeReply(responsePayload: nx)
                packetFlow.writePackets([reply], withProtocols: [AF_INET as NSNumber])
            }
            return
        }

        forwardUpstream(parsed)
    }

    /// Forward an allowed DNS query to the upstream resolver and relay the
    /// answer back into the tunnel. One short-lived connection per query —
    /// simple and correct; batch/caching is a future optimization.
    private func forwardUpstream(_ request: IPv4UDPPacket) {
        let conn = NWConnection(
            host: NWEndpoint.Host(upstreamResolver),
            port: 53,
            using: .udp
        )
        conn.start(queue: .global())
        conn.send(content: request.payload, completion: .contentProcessed { _ in
            conn.receiveMessage { [weak self] data, _, _, _ in
                if let data, let self {
                    let reply = request.makeReply(responsePayload: data)
                    self.packetFlow.writePackets([reply], withProtocols: [AF_INET as NSNumber])
                }
                conn.cancel()
            }
        })
    }
}
