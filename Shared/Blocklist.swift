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
    /// When true, also block a built-in list of popular adult sites
    /// (`AdultDomains.list`) through the website filter.
    var blockAdult: Bool

    init(id: UUID = UUID(), name: String, selectionData: Data? = nil,
         domains: [String] = [], blockAdult: Bool = false) {
        self.id = id
        self.name = name
        self.selectionData = selectionData
        self.domains = domains
        self.blockAdult = blockAdult
    }

    enum CodingKeys: String, CodingKey {
        case id, name, selectionData, domains, blockAdult
    }

    /// Custom decoder so blocklists saved before `blockAdult` existed still load
    /// (the flag defaults to false when the key is missing).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        selectionData = try c.decodeIfPresent(Data.self, forKey: .selectionData)
        domains = try c.decode([String].self, forKey: .domains)
        blockAdult = try c.decodeIfPresent(Bool.self, forKey: .blockAdult) ?? false
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
