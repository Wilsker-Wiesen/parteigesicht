import Foundation

/// Inhalt von data/index.json (von pipeline/build.py erzeugt, identisch zur Web-App).
struct GameIndex: Decodable {
    struct Cell: Decodable { let w: Int; let h: Int; let cols: Int }
    struct Party: Decodable, Identifiable, Hashable {
        let key: String
        let label: String
        let long: String
        let color: String
        let core: Bool
        let textDark: Bool?
        /// Dativ für die Ja/Nein-Frage, z. B. "zu den Grünen"
        let zu: String?
        let counts: [String: Int]
        var id: String { key }
    }
    struct Level: Decodable, Identifiable, Hashable { let key: String; let label: String; var id: String { key } }
    struct Sheet: Decodable { let file: String; let party: String; let level: String; let n: Int }

    let generated: String
    let cell: Cell
    let minFaces: Int
    let parties: [Party]
    let levels: [Level]
    let sheets: [Sheet]
    let people: [Person]
}

/// Eine Person; in der JSON-Datei als kompaktes Array gespeichert (siehe "fields").
struct Person: Decodable, Identifiable, Hashable {
    let name: String
    let party: String
    let sub: String?
    let level: String
    let body: String?
    let sheet: Int
    let cell: Int
    let artist: String
    let license: String
    let file: String
    let wikidata: String
    var id: String { wikidata }

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        name = try c.decode(String.self)
        party = try c.decode(String.self)
        sub = try c.decodeIfPresent(String.self)
        level = try c.decode(String.self)
        body = try c.decodeIfPresent(String.self)
        sheet = try c.decode(Int.self)
        cell = try c.decode(Int.self)
        artist = try c.decode(String.self)
        license = try c.decode(String.self)
        file = try c.decode(String.self)
        wikidata = try c.decode(String.self)
    }

    var commonsURL: URL? {
        let enc = file.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? file
        return URL(string: "https://commons.wikimedia.org/wiki/File:" + enc)
    }

    var whereLabel: String {
        switch level {
        case "bundestag": return "Bundestag"
        case "europa": return "Europaparlament"
        case "landtag": return body.map { "Landtag \($0)" } ?? "Landtag"
        case "regierung": return "Regierungsamt"
        case "kommunal": return body.map { "Kommunal: \($0)" } ?? "Kommunalpolitik"
        default: return "Parteimitglied"
        }
    }
}

extension GameIndex {
    static func loadFromBundle() throws -> GameIndex {
        guard let url = Bundle.main.url(forResource: "index", withExtension: "json", subdirectory: "data") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(GameIndex.self, from: Data(contentsOf: url))
    }

    func party(_ key: String) -> Party { parties.first { $0.key == key }! }

    func partyLabel(_ p: Person) -> String {
        let pt = party(p.party)
        if let sub = p.sub, sub != pt.label { return sub }
        return pt.long
    }

    func count(_ partyKey: String, levels: Set<String>) -> Int {
        levels.reduce(0) { $0 + (party(partyKey).counts[$1] ?? 0) }
    }

    func eligible(levels: Set<String>) -> [String] {
        parties.filter { count($0.key, levels: levels) >= minFaces }.map(\.key)
    }
}
