import Foundation

/// A parsed IPv4 + UDP datagram, enough to read a DNS query and craft a reply.
/// IPv4/UDP only; IPv6 is a TODO (see PacketTunnelProvider).
struct IPv4UDPPacket {
    var sourceAddress: (UInt8, UInt8, UInt8, UInt8)
    var destinationAddress: (UInt8, UInt8, UInt8, UInt8)
    var sourcePort: UInt16
    var destinationPort: UInt16
    var payload: Data // UDP payload (the DNS message)

    static let protocolUDP: UInt8 = 17

    /// Parse a raw IPv4 packet; returns nil unless it is a well-formed IPv4 UDP
    /// datagram.
    static func parse(_ packet: Data) -> IPv4UDPPacket? {
        let b = [UInt8](packet)
        guard b.count >= 28 else { return nil }          // 20 IP + 8 UDP min
        guard (b[0] >> 4) == 4 else { return nil }        // IPv4
        let ihl = Int(b[0] & 0x0F) * 4
        guard ihl >= 20, b.count >= ihl + 8 else { return nil }
        guard b[9] == protocolUDP else { return nil }     // UDP

        let src = (b[12], b[13], b[14], b[15])
        let dst = (b[16], b[17], b[18], b[19])
        let srcPort = UInt16(b[ihl]) << 8 | UInt16(b[ihl + 1])
        let dstPort = UInt16(b[ihl + 2]) << 8 | UInt16(b[ihl + 3])
        let udpLen = Int(UInt16(b[ihl + 4]) << 8 | UInt16(b[ihl + 5]))
        guard udpLen >= 8, ihl + udpLen <= b.count else { return nil }

        let payloadStart = ihl + 8
        let payload = Data(b[payloadStart..<(ihl + udpLen)])
        return IPv4UDPPacket(sourceAddress: src, destinationAddress: dst,
                             sourcePort: srcPort, destinationPort: dstPort,
                             payload: payload)
    }

    /// Build a reply IPv4/UDP packet addressed back to the original sender,
    /// swapping src/dst and carrying `responsePayload` (a DNS answer).
    /// UDP checksum is left 0 (legal for IPv4).
    func makeReply(responsePayload: Data) -> Data {
        var out = [UInt8]()
        let udpLength = 8 + responsePayload.count
        let totalLength = 20 + udpLength

        // ---- IPv4 header (20 bytes) ----
        out.append(0x45)                                   // version 4, IHL 5
        out.append(0x00)                                   // DSCP/ECN
        out.append(UInt8(totalLength >> 8)); out.append(UInt8(totalLength & 0xFF))
        out.append(0x00); out.append(0x00)                 // identification
        out.append(0x40); out.append(0x00)                 // flags: don't fragment
        out.append(64)                                     // TTL
        out.append(IPv4UDPPacket.protocolUDP)              // protocol
        out.append(0x00); out.append(0x00)                 // checksum (filled below)
        // src = original destination, dst = original source (swap)
        out.append(destinationAddress.0); out.append(destinationAddress.1)
        out.append(destinationAddress.2); out.append(destinationAddress.3)
        out.append(sourceAddress.0); out.append(sourceAddress.1)
        out.append(sourceAddress.2); out.append(sourceAddress.3)

        let checksum = IPv4UDPPacket.checksum(out[0..<20])
        out[10] = UInt8(checksum >> 8); out[11] = UInt8(checksum & 0xFF)

        // ---- UDP header (8 bytes) ----
        out.append(UInt8(destinationPort >> 8)); out.append(UInt8(destinationPort & 0xFF))
        out.append(UInt8(sourcePort >> 8)); out.append(UInt8(sourcePort & 0xFF))
        out.append(UInt8(udpLength >> 8)); out.append(UInt8(udpLength & 0xFF))
        out.append(0x00); out.append(0x00)                 // UDP checksum = 0

        out.append(contentsOf: responsePayload)
        return Data(out)
    }

    /// 16-bit one's-complement checksum (IPv4 header).
    static func checksum(_ bytes: ArraySlice<UInt8>) -> UInt16 {
        var sum: UInt32 = 0
        var it = bytes.startIndex
        while it < bytes.endIndex {
            let hi = UInt32(bytes[it]) << 8
            let lo = it + 1 < bytes.endIndex ? UInt32(bytes[it + 1]) : 0
            sum += hi | lo
            it += 2
        }
        while (sum >> 16) != 0 { sum = (sum & 0xFFFF) + (sum >> 16) }
        return UInt16(~sum & 0xFFFF)
    }
}
