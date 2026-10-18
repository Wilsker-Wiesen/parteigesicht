import Foundation
import SwiftUI

/// Zufall mit Startwert (Mulberry32), bitgenau wie seeded() in der Web-App:
/// gleicher Startwert → gleiche Gesichter in gleicher Reihenfolge auf jedem Gerät.
struct Mulberry32 {
    private var a: UInt32
    init(seed: UInt32) { a = seed }
    mutating func next() -> Double {
        a = a &+ 0x6D2B79F5
        var t = a
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        return Double(t ^ (t >> 14)) / 4294967296
    }
}

/// Einstellungen einer Runde; mit Startwert und Code bei einer gemeinsamen Runde.
struct RoundConfig: Equatable {
    var seed: Int?
    var parties: [String]
    var levels: [String]
    var timer: Int
    var code: String?
    /// Runde in einem Live-Raum: Fortschritt geht an den Server, Rangliste live
    var live = false
}

/// Gemeinsame Runde per Code, 50 Bit in 10 Zeichen:
/// Startwert (22) · Parteien (16, Reihenfolge wie index.json) · Ebenen (6) · Zeitlimit (3) · Datenstand (3)
enum SharedCode {
    /// ohne 0/O und 1/I, damit nichts verwechselt wird
    static let alphabet = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")
    static let timerSteps = [0, 5, 10, 15, 20, 30]

    static func dataVersion(_ ix: GameIndex) -> UInt64 {
        var h: UInt32 = 0
        for ch in (ix.generated + String(ix.people.count)).utf16 { h = h &* 31 &+ UInt32(ch) }
        return UInt64(h & 7)
    }

    static func encode(_ cfg: RoundConfig, index ix: GameIndex) -> String {
        var pBits: UInt64 = 0
        for (i, p) in ix.parties.enumerated() where cfg.parties.contains(p.key) { pBits |= 1 << UInt64(i) }
        var lBits: UInt64 = 0
        for (i, l) in ix.levels.enumerated() where cfg.levels.contains(l.key) { lBits |= 1 << UInt64(i) }
        var v = UInt64((cfg.seed ?? 0) & 0x3FFFFF)
        v = (v << 16) | pBits
        v = (v << 6) | lBits
        v = (v << 3) | UInt64(max(0, timerSteps.firstIndex(of: cfg.timer) ?? 0))
        v = (v << 3) | dataVersion(ix)
        var out: [Character] = []
        for _ in 0..<10 { out.insert(alphabet[Int(v & 31)], at: 0); v >>= 5 }
        return String(out)
    }

    struct Decoded { let config: RoundConfig; let sameData: Bool }

    static func decode(_ str: String, index ix: GameIndex) -> Decoded? {
        let c = str.uppercased().filter { ("A"..."Z").contains($0) || ("0"..."9").contains($0) }
        guard c.count == 10 else { return nil }
        var v: UInt64 = 0
        for ch in c {
            guard let i = alphabet.firstIndex(of: ch) else { return nil }
            v = (v << 5) | UInt64(i)
        }
        let ver = v & 7; v >>= 3
        let ti = Int(v & 7); v >>= 3
        let lBits = v & 63; v >>= 6
        let pBits = v & 0xFFFF; v >>= 16
        let seed = Int(v)
        let parties = ix.parties.enumerated().filter { pBits & (1 << UInt64($0.offset)) != 0 }.map(\.element.key)
        let levels = ix.levels.enumerated().filter { lBits & (1 << UInt64($0.offset)) != 0 }.map(\.element.key)
        guard !parties.isEmpty, !levels.isEmpty, ti < timerSteps.count else { return nil }
        return Decoded(config: RoundConfig(seed: seed, parties: parties, levels: levels, timer: timerSteps[ti], code: c), sameData: ver == dataVersion(ix))
    }

    static func format(_ c: String) -> String { String(c.prefix(5)) + "-" + String(c.dropFirst(5)) }
    static func link(_ c: String) -> URL { URL(string: "https://wilsker-wiesen.github.io/parteigesicht/#" + c)! }
}

/// Spiellogik: gleiche Regeln und gleiche Zugreihenfolge wie die Web-App (app/index.html).
@MainActor
final class Game: ObservableObject {
    struct Answer {
        let person: Person
        let guess: String?
        let saidYes: Bool?
        let correct: Bool
        let timedOut: Bool
        /// Antwortzeit in Millisekunden
        let ms: Double
    }

    enum Phase { case menu, playing, result, share(RoundConfig), join(String?), lobby(RoundConfig), countdown(Int, Date) }

    static let roundSize = 20

    /// Reihenfolge von links (progressiver) nach rechts wie im Farbbalken, gleich wie LEFT_RIGHT in der Web-App;
    /// bei zwei Parteien liegt die linkere auf der linken Wischseite
    static let leftRight = ["LINKE", "PARTEI", "PIRATEN", "GRUENE", "VOLT", "SPD", "SSW", "OEDP", "FDP", "FW", "UNION", "BSW", "AFD"]
    static func sortedLeftRight(_ keys: [String]) -> [String] {
        keys.sorted { (leftRight.firstIndex(of: $0) ?? 99) < (leftRight.firstIndex(of: $1) ?? 99) }
    }

    let index: GameIndex
    private var bySheet: [[Int]]
    private var rnd: () -> Double = { Double.random(in: 0..<1) }

    @Published var phase: Phase = .menu
    // Menü-Einstellungen
    @Published var levels: Set<String>
    @Published var chosen: [String]
    @Published var timer: Int
    // laufende Runde
    @Published private(set) var round = RoundConfig(seed: nil, parties: [], levels: [], timer: 0, code: nil)
    @Published private(set) var items: [Person] = []
    @Published private(set) var position = 0
    @Published private(set) var answers: [Answer] = []
    /// Restzeit für das aktuelle Gesicht in Sekunden (nur mit Zeitlimit)
    @Published private(set) var timeLeft: Double = 0

    /// Live-Raum, solange man in einer gemeinsamen Runde mit Server ist
    @Published private(set) var live: LiveRoom?

    @AppStorage("totalAnswered") var totalAnswered = 0
    @AppStorage("totalCorrect") var totalCorrect = 0

    private var faceShownAt = Date()
    private var ticker: Timer?
    private var pendingAdvance: DispatchWorkItem?

    init(index: GameIndex) {
        self.index = index
        var map = Array(repeating: [Int](), count: index.sheets.count)
        for (i, p) in index.people.enumerated() { map[p.sheet].append(i) }
        bySheet = map
        let all = Set(index.levels.map(\.key))
        let lv = Set(UserDefaults.standard.stringArray(forKey: "levels") ?? Array(all))
        levels = lv
        let t = UserDefaults.standard.integer(forKey: "timer")
        timer = SharedCode.timerSteps.contains(t) ? t : 0
        let elig = index.eligible(levels: lv)
        chosen = (UserDefaults.standard.stringArray(forKey: "parties") ?? index.parties.filter(\.core).map(\.key)).filter { elig.contains($0) }
    }

    var allLevels: Set<String> { Set(index.levels.map(\.key)) }
    /// Ebenen in der Reihenfolge von index.json (für Code und Rundenaufbau)
    var orderedLevels: [String] { index.levels.map(\.key).filter { levels.contains($0) } }
    /// Modus im Menü
    var menuTarget: String? { chosen.count == 1 ? chosen[0] : nil }
    /// Modus der laufenden Runde
    var targetParty: String? { round.parties.count == 1 ? round.parties[0] : nil }
    /// Zwei Parteien: [links, rechts] zum Wischen
    var pair: [String]? { round.parties.count == 2 ? Game.sortedLeftRight(round.parties) : nil }
    var swipes: Bool { targetParty != nil || pair != nil }
    var current: Person? { position < items.count ? items[position] : nil }
    var currentAnswer: Answer? { position < answers.count ? answers[position] : nil }
    var correctCount: Int { answers.filter(\.correct).count }

    /// Einstellungen des Menüs als Rundenkonfiguration (ohne Startwert)
    var menuConfig: RoundConfig { RoundConfig(seed: nil, parties: chosen, levels: orderedLevels, timer: timer, code: nil) }

    func saveSettings() {
        UserDefaults.standard.set(Array(levels), forKey: "levels")
        UserDefaults.standard.set(chosen, forKey: "parties")
        UserDefaults.standard.set(timer, forKey: "timer")
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

    func setTimer(_ t: Int) { timer = t; saveSettings() }

    // MARK: Gemeinsame Runde

    func makeCode() {
        var cfg = menuConfig
        cfg.seed = Int.random(in: 0..<0x400000)
        cfg.code = SharedCode.encode(cfg, index: index)
        enterLobby(cfg)
    }

    func makeCodeFromRound() {
        var cfg = round
        cfg.seed = Int.random(in: 0..<0x400000)
        cfg.live = false
        cfg.code = SharedCode.encode(cfg, index: index)
        enterLobby(cfg)
    }

    func joinCode(prefill: String? = nil) { phase = .join(prefill) }

    // MARK: Live-Raum

    /// In den Warteraum des Codes wechseln (verbindet mit dem Server)
    func enterLobby(_ cfg: RoundConfig) {
        if live?.config.code != cfg.code {
            live?.close()
            let room = LiveRoom(config: cfg)
            room.onStart = { [weak self] n, at in
                guard let self else { return }
                self.cancelTimers()
                self.phase = .countdown(n, at)
            }
            live = room
            room.connect()
        }
        phase = .lobby(cfg)
    }

    /// Countdown abgelaufen: Runde n im Raum starten, auf allen Geräten mit demselben Startwert
    func startLiveRound(_ n: Int) {
        guard let room = live, let base = room.config.seed else { return }
        var cfg = room.config
        cfg.seed = LiveRoom.seed(base, round: n)
        cfg.live = true
        start(cfg)
    }

    /// Ohne Verbindung: dieselbe Runde, jedes Gerät spielt für sich
    func startOffline(_ cfg: RoundConfig) {
        leaveRoom()
        start(cfg)
    }

    func leaveRoom() { live?.close(); live = nil }

    func settingsSummary(_ cfg: RoundConfig) -> String {
        let lv = cfg.levels.count == index.levels.count ? "alle Ebenen"
            : cfg.levels.compactMap { k in index.levels.first { $0.key == k }?.label }.joined(separator: ", ")
        let pt = cfg.parties.map { index.party($0).label }.joined(separator: ", ")
        return "\(pt) · \(lv) · \(cfg.timer > 0 ? "\(cfg.timer) s pro Gesicht" : "ohne Zeitlimit")"
    }

    // MARK: Rundenaufbau (Zugreihenfolge exakt wie startRound() der Web-App)

    /// Fisher-Yates wie shuffle() der Web-App
    private func shuffle<T>(_ a: [T]) -> [T] {
        var a = a
        var i = a.count - 1
        while i > 0 {
            let j = Int((rnd() * Double(i + 1)).rounded(.down))
            a.swapAt(i, j)
            i -= 1
        }
        return a
    }

    /// Zieht n Personen einer Partei, bevorzugt aus wenigen Bildbögen.
    private func pick(_ party: String, levels: [String], n: Int, used: inout Set<Int>) -> [Int] {
        // nach Größe gewichtete Zufallsreihenfolge (Efraimidis-Spirakis), damit Ebenen anteilig vorkommen;
        // wie in der Web-App wird für jeden Bogen in Dateireihenfolge eine Zufallszahl gezogen, erst danach gefiltert
        let keyed = index.sheets.indices.map { ($0, pow(rnd(), 1 / Double(max(1, index.sheets[$0].n)))) }
        let pool = keyed
            .filter { index.sheets[$0.0].party == party && levels.contains(index.sheets[$0.0].level) }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
            .map(\.0)
        var out: [Int] = []
        for s in pool {
            for pi in shuffle(bySheet[s]) {
                if out.count >= n { break }
                if !used.contains(pi) { out.append(pi); used.insert(pi) }
            }
            if out.count >= n { break }
        }
        return out
    }

    func start() { start(menuConfig) }

    func start(_ cfg: RoundConfig) {
        cancelTimers()
        if let seed = cfg.seed { var g = Mulberry32(seed: UInt32(truncatingIfNeeded: seed)); rnd = { g.next() } }
        else { rnd = { Double.random(in: 0..<1) } }
        let lv = cfg.levels
        var used = Set<Int>()
        var picked: [Int]
        if cfg.parties.count == 1 {
            let target = cfg.parties[0]
            let half = Self.roundSize / 2
            let yes = pick(target, levels: lv, n: half, used: &used)
            let others = shuffle(index.eligible(levels: Set(lv)).filter { $0 != target })
            var no: [Int] = []
            var i = 0
            while no.count < half && !others.isEmpty && i < 200 {
                no += pick(others[i % others.count], levels: lv, n: 1, used: &used); i += 1
            }
            picked = shuffle(yes + no)
        } else {
            let per = max(2, Int((Double(Self.roundSize) / Double(cfg.parties.count)).rounded()))
            picked = shuffle(cfg.parties.flatMap { pick($0, levels: lv, n: per, used: &used) })
        }
        rnd = { Double.random(in: 0..<1) }
        round = cfg
        items = picked.map { index.people[$0] }
        #if DEBUG
        print("Runde\(cfg.code.map { " \(SharedCode.format($0))" } ?? ""): " + items.prefix(5).map(\.name).joined(separator: " · "))
        #endif
        position = 0
        answers = []
        phase = .playing
        SheetCache.shared.preload(items.map(\.sheet), index: index)
        showFace()
    }

    // MARK: Zeitlimit

    /// Ein neues Gesicht ist sichtbar: Stoppuhr und Zeitlimit starten.
    private func showFace() {
        faceShownAt = Date()
        ticker?.invalidate(); ticker = nil
        guard round.timer > 0 else { return }
        timeLeft = Double(round.timer)
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func tick() {
        guard case .playing = phase, currentAnswer == nil else { return }
        let left = max(0, Double(round.timer) - Date().timeIntervalSince(faceShownAt))
        timeLeft = left
        if left <= 0 {
            ticker?.invalidate(); ticker = nil
            guard let p = current else { return }
            record(Answer(person: p, guess: nil, saidYes: nil, correct: false, timedOut: true, ms: elapsedMs))
        }
    }

    private var elapsedMs: Double { Date().timeIntervalSince(faceShownAt) * 1000 }

    private func cancelTimers() {
        ticker?.invalidate(); ticker = nil
        pendingAdvance?.cancel(); pendingAdvance = nil
    }

    // MARK: Antworten und Schnell-Bonus

    /// Schnell-Bonus: richtige Antwort innerhalb von 40 % des Zeitlimits, ohne Limit unter 3 Sekunden
    var fastLimitMs: Double { round.timer > 0 ? Double(round.timer) * 1000 * 0.4 : 3000 }
    func isFast(_ a: Answer) -> Bool { a.correct && a.ms <= fastLimitMs }
    var bonus: Int { answers.filter(isFast).count }
    var points: Int { correctCount + bonus }
    var timeouts: Int { answers.filter(\.timedOut).count }
    /// Gesamtzeit in Millisekunden; „Zeit um“ zählt mit dem vollen Limit
    var totalMs: Double { answers.reduce(0) { $0 + ($1.timedOut ? Double(round.timer) * 1000 : $1.ms) } }

    static func formatTime(_ ms: Double) -> String {
        let s = Int((ms / 1000).rounded())
        return s >= 60 ? String(format: "%d:%02d min", s / 60, s % 60) : "\(s) s"
    }

    func verdictText(_ a: Answer) -> String {
        if a.timedOut { return "Zeit um" }
        if a.correct { return isFast(a) ? "Richtig · schnell +1" : "Richtig" }
        return "Daneben"
    }

    func answer(party guess: String) {
        guard let p = current, currentAnswer == nil else { return }
        record(Answer(person: p, guess: guess, saidYes: nil, correct: guess == p.party, timedOut: false, ms: elapsedMs))
    }

    func answer(yes: Bool) {
        guard let p = current, let target = targetParty, currentAnswer == nil else { return }
        record(Answer(person: p, guess: nil, saidYes: yes, correct: (p.party == target) == yes, timedOut: false, ms: elapsedMs))
    }

    private func record(_ a: Answer) {
        ticker?.invalidate(); ticker = nil
        answers.append(a)
        totalAnswered += 1
        if a.correct { totalCorrect += 1 }
        if round.live {
            live?.progress(answered: answers.count, correct: correctCount, bonus: bonus, totalMs: totalMs, done: answers.count >= items.count)
        }
        // Wischen läuft immer von selbst weiter; Zuordnen nur mit Zeitlimit, damit alle im gleichen Takt bleiben
        let delay: Double? = swipes ? (a.correct ? 0.9 : 1.6) : (round.timer > 0 ? (a.correct ? 1.5 : 2.2) : nil)
        if let delay {
            let work = DispatchWorkItem { [weak self] in self?.advance() }
            pendingAdvance = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    func advance() {
        pendingAdvance?.cancel(); pendingAdvance = nil
        guard case .playing = phase else { return }
        if position + 1 >= items.count { cancelTimers(); phase = .result } else { position += 1; showFace() }
    }

    func backToMenu() { cancelTimers(); leaveRoom(); phase = .menu }
}

extension Color {
    init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }
}
