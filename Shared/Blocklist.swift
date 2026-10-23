import Foundation

/// A named, reusable set of things to block: apps/categories (an encoded
/// `FamilyActivitySelection`) plus website domains. Stored as `Data` for the
/// selection so this model needs no FamilyControls import; the editor encodes
/// and decodes it.
struct Blocklist: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var selectionData: Data?
    var domains: [String]

    init(id: UUID = UUID(), name: String, selectionData: Data? = nil, domains: [String] = []) {
        self.id = id
        self.name = name
        self.selectionData = selectionData
        self.domains = domains
    }
}

/// CRUD for blocklists, persisted in the App Group so extensions can read them.
enum BlocklistStore {
    private static var d: UserDefaults { AppGroup.defaults }
    private static let key = "blocklists"

    static var all: [Blocklist] {
        get {
            guard let data = d.data(forKey: key),
                  let list = try? JSONDecoder().decode([Blocklist].self, from: data)
            else { return [] }
            return list
        }
        set {
            d.set(try? JSONEncoder().encode(newValue), forKey: key)
        }
    }

    static func get(_ id: UUID) -> Blocklist? {
        all.first { $0.id == id }
    }

    static func upsert(_ blocklist: Blocklist) {
        var list = all
        if let i = list.firstIndex(where: { $0.id == blocklist.id }) {
            list[i] = blocklist
        } else {
            list.append(blocklist)
        }
        all = list
    }

    static func remove(_ id: UUID) {
        all = all.filter { $0.id != id }
    }
}
