import Foundation

/// Host-level domain matching used by the DNS tunnel. Stateless: the set of
/// blocked domains now lives on each `Blocklist`, and the currently enforced
/// set is mirrored into `SharedState.activeDomains`.
///
/// NOTE: host/domain matching only. iOS gives no personal (non-MDM) app the
/// encrypted URL path, so this cannot match a keyword inside a full URL — only
/// the site's host.
enum BlockedDomains {
    /// Reduce a user-typed value to a bare host (drop scheme/path, `www.`).
    static func normalize(_ raw: String) -> String {
        var s = raw.lowercased().trimmingCharacters(in: .whitespaces)
        if let range = s.range(of: "://") { s = String(s[range.upperBound...]) }
        if let slash = s.firstIndex(of: "/") { s = String(s[..<slash]) }
        if s.hasPrefix("www.") { s = String(s.dropFirst(4)) }
        return s
    }

    /// True if `host` matches any entry (exact, subdomain, or — for a bare
    /// keyword with no dot — substring of the host).
    static func isBlocked(host: String, in entries: [String]) -> Bool {
        let h = normalize(host)
        for raw in entries {
            let e = normalize(raw)
            guard !e.isEmpty else { continue }
            if h == e { return true }
            if h.hasSuffix("." + e) { return true }
            if !e.contains(".") && h.contains(e) { return true }
        }
        return false
    }

    /// Convenience against the currently enforced set.
    static func isBlocked(host: String) -> Bool {
        isBlocked(host: host, in: SharedState.activeDomains)
    }
}
