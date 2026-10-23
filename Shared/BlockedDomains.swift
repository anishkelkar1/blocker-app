import Foundation

/// The user's web blocklist, shared with the packet-tunnel extension through
/// the App Group. Matching is host-level (domain + subdomains), with an
/// optional substring match so a bare keyword like "casino" blocks any host
/// that contains it.
///
/// NOTE: this is host/domain matching, NOT full-URL matching. iOS gives no
/// personal (non-MDM) app visibility into the encrypted URL path or query, so
/// a true "keyword anywhere in the URL" rule is out of scope by design.
enum BlockedDomains {
    private static var d: UserDefaults { AppGroup.defaults }
    private static let key = "blockedDomains"

    /// Normalized blocklist entries (lowercased, `www.` stripped).
    static var entries: [String] {
        get { (d.array(forKey: key) as? [String]) ?? [] }
        set { d.set(newValue.map(normalize), forKey: key) }
    }

    static func add(_ raw: String) {
        let e = normalize(raw)
        guard !e.isEmpty else { return }
        var list = entries
        guard !list.contains(e) else { return }
        list.append(e)
        entries = list
    }

    static func remove(_ raw: String) {
        let e = normalize(raw)
        entries = entries.filter { $0 != e }
    }

    static func normalize(_ raw: String) -> String {
        var s = raw.lowercased().trimmingCharacters(in: .whitespaces)
        // Strip scheme and any path — we only keep the host part.
        if let range = s.range(of: "://") { s = String(s[range.upperBound...]) }
        if let slash = s.firstIndex(of: "/") { s = String(s[..<slash]) }
        if s.hasPrefix("www.") { s = String(s.dropFirst(4)) }
        return s
    }

    /// True if `host` should be blocked given the current blocklist.
    static func isBlocked(host: String) -> Bool {
        let h = normalize(host)
        for e in entries where !e.isEmpty {
            if h == e { return true }               // exact
            if h.hasSuffix("." + e) { return true } // subdomain of e
            if !e.contains(".") && h.contains(e) { return true } // keyword in host
        }
        return false
    }
}
