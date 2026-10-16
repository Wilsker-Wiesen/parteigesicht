import Foundation
import SwiftUI

/// Spiellogik: gleiche Regeln wie die Web-App (app/index.html).
@MainActor
final class Game: ObservableObject {
    struct Answer { let person: Person; let guess: String?; let saidYes: Bool?; let correct: Bool }

    enum Phase { case menu, playing, result }

    static let roundSize = 20

    let index: GameIndex
    private var bySheet: [[Int]]

    @Published var phase: Phase = .menu
    @Published var levels: Set<String>
    @Published var chosen: [String]
    @Published private(set) var items: [Person] = []
    @Published private(set) var position = 0
    @Published private(set) var answers: [Answer] = []

    @AppStorage("totalAnswered") var totalAnswered = 0
    @AppStorage("totalCorrect") var totalCorrect = 0

    init(index: GameIndex) {
        self.index = index
        var map = Array(repeating: [Int](), count: index.sheets.count)
        for (i, p) in index.people.enumerated() { map[p.sheet].append(i) }
        bySheet = map
        let all = Set(index.levels.map(\.key))
        levels = Set(UserDefaults.standard.stringArray(forKey: "levels") ?? Array(all))
        chosen = UserDefaults.standard.stringArray(forKey: "parties") ?? index.parties.filter(\.core).map(\.key)
        chosen = chosen.filter { index.eligible(levels: levels).contains($0) }
    }

    var allLevels: Set<String> { Set(index.levels.map(\.key)) }
    var targetParty: String? { chosen.count == 1 ? chosen[0] : nil }
    var current: Person? { position < items.count ? items[position] : nil }
    var correctCount: Int { answers.filter(\.correct).count }

    func saveSettings() {
        UserDefaults.standard.set(Array(levels), forKey: "levels")
        UserDefaults.standard.set(chosen, forKey: "parties")
    }

    func toggleLevel(_ key: String?) {
        if let key {
            if levels == allLevels { levels = [key] }
            else if levels.contains(key) { levels.remove(key); if levels.isEmpty { levels = allLevels } }
            else { levels.insert(key) }
        } else {
            levels = allLevels
        }
        let elig = index.eligible(levels: levels)
        chosen = chosen.filter { elig.contains($0) }
        saveSettings()
    }

    func toggleParty(_ key: String) {
        if let i = chosen.firstIndex(of: key) { chosen.remove(at: i) } else { chosen.append(key) }
        saveSettings()
    }

    /// Zieht n Personen einer Partei, bevorzugt aus wenigen Bildbögen.
    private func pick(_ party: String, n: Int, used: inout Set<Int>) -> [Int] {
        // nach Größe gewichtete Zufallsreihenfolge (Efraimidis-Spirakis), damit Ebenen anteilig vorkommen
        let pool = index.sheets.indices
            .filter { index.sheets[$0].party == party && levels.contains(index.sheets[$0].level) }
            .map { ($0, pow(Double.random(in: 0..<1), 1 / Double(max(1, index.sheets[$0].n)))) }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
        var out: [Int] = []
        for s in pool {
            for pi in bySheet[s].shuffled() where out.count < n && !used.contains(pi) {
                out.append(pi); used.insert(pi)
            }
            if out.count >= n { break }
        }
        return out
    }

    func start() {
        var used = Set<Int>()
        var picked: [Int] = []
        if let target = targetParty {
            let half = Self.roundSize / 2
            picked += pick(target, n: half, used: &used)
            let others = index.eligible(levels: levels).filter { $0 != target }.shuffled()
            var no: [Int] = []
            var i = 0
            while no.count < half && !others.isEmpty && i < 200 {
                no += pick(others[i % others.count], n: 1, used: &used); i += 1
            }
            picked += no
        } else {
            let per = max(2, Int((Double(Self.roundSize) / Double(chosen.count)).rounded()))
            for k in chosen { picked += pick(k, n: per, used: &used) }
        }
        items = picked.shuffled().map { index.people[$0] }
        position = 0
        answers = []
        phase = .playing
        SheetCache.shared.preload(items.map(\.sheet), index: index)
    }

    func answer(party guess: String) {
        guard let p = current else { return }
        answers.append(Answer(person: p, guess: guess, saidYes: nil, correct: guess == p.party))
        record(answers.last!.correct)
    }

    func answer(yes: Bool) {
        guard let p = current, let target = targetParty else { return }
        let correct = (p.party == target) == yes
        answers.append(Answer(person: p, guess: nil, saidYes: yes, correct: correct))
        record(correct)
    }

    private func record(_ correct: Bool) {
        totalAnswered += 1
        if correct { totalCorrect += 1 }
    }

    func advance() {
        if position + 1 >= items.count { phase = .result } else { position += 1 }
    }

    func backToMenu() { phase = .menu }
}

extension Color {
    init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }
}
