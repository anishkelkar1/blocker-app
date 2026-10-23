import Foundation

/// Minimal DNS wire-format helpers: read the queried name, and craft an
/// NXDOMAIN reply for a blocked name. Only what the tunnel needs — not a
/// general DNS library.
enum DNSMessage {
    /// Header is 12 bytes; the question follows.
    private static let headerLength = 12

    /// Parse the first question's QNAME, e.g. "ads.example.com".
    /// Returns nil if the payload is malformed or uses name compression
    /// (compression is not valid in a question section).
    static func parseQuestionName(_ data: Data) -> String? {
        guard data.count > headerLength else { return nil }
        var i = headerLength
        var labels: [String] = []
        while i < data.count {
            let len = Int(data[data.startIndex + i])
            if len == 0 { break }                 // end of name
            if len & 0xC0 != 0 { return nil }     // compression pointer: bail
            i += 1
            guard i + len <= data.count else { return nil }
            let start = data.startIndex + i
            let label = data[start..<start + len]
            guard let s = String(bytes: label, encoding: .utf8) else { return nil }
            labels.append(s)
            i += len
        }
        return labels.isEmpty ? nil : labels.joined(separator: ".")
    }

    /// Build an NXDOMAIN response that echoes the original question, so the
    /// client treats the blocked host as non-existent.
    static func makeNXDomainResponse(from query: Data) -> Data? {
        guard query.count >= headerLength else { return nil }
        let q = [UInt8](query)

        // Find the end of the question section (QNAME + QTYPE(2) + QCLASS(2)).
        var i = headerLength
        while i < q.count {
            let len = Int(q[i])
            if len == 0 { i += 1; break }
            if len & 0xC0 != 0 { return nil }
            i += 1 + len
        }
        let questionEnd = i + 4 // QTYPE + QCLASS
        guard questionEnd <= q.count else { return nil }

        var out = [UInt8](q[0..<questionEnd])

        // Flags: QR=1, Opcode=0, AA=0, TC=0, RD=(copied), RA=1, RCODE=3.
        let rd = q[2] & 0x01
        out[2] = 0x80 | rd      // QR + RD
        out[3] = 0x80 | 0x03    // RA + RCODE(NXDOMAIN=3)

        // Counts: one question echoed, no answers/authority/additional.
        out[4] = 0x00; out[5] = 0x01  // QDCOUNT = 1
        out[6] = 0x00; out[7] = 0x00  // ANCOUNT = 0
        out[8] = 0x00; out[9] = 0x00  // NSCOUNT = 0
        out[10] = 0x00; out[11] = 0x00 // ARCOUNT = 0

        return Data(out)
    }
}
