import Foundation
import SwiftUI

/// Live-Raum auf dem Cloudflare-Server (server/), gleiches Protokoll wie die Web-App:
/// Warteraum mit Namen, der Gastgeber startet für alle, Countdown auf Serverzeit, Live-Rangliste.
/// Welche Gesichter drankommen, rechnet jedes Gerät selbst aus dem Code aus.
@MainActor
final class LiveRoom: ObservableObject {
    static let server = URL(string: "wss://parteigesicht.wilsker-wiesen.workers.dev")!
    /// Der Server lässt nur bekannte Absender zu (ALLOWED_ORIGINS in server/wrangler.toml)
    static let origin = "app://parteigesicht"

    struct Player: Decodable, Identifiable, Equatable {
        let id: String
        let name: String
        let answered: Int
        let correct: Int
        let bonus: Int
        let points: Int
        let totalMs: Double
        let done: Bool
        let online: Bool
        let host: Bool
    }

    private struct StateMessage: Decodable {
        let t: String
        let phase: String?
        let startAt: Double?
        let round: Int?
        let now: Double?
        let players: [Player]?
        let message: String?
    }

    let config: RoundConfig
    let me: String
    @Published private(set) var players: [Player] = []
    @Published private(set) var connected = false
    @Published private(set) var failed = false
    @Published private(set) var error: String?

    /// Wird aufgerufen, sobald der Gastgeber eine Runde startet: Rundennummer und Startzeitpunkt (Gerätezeit)
    var onStart: ((Int, Date) -> Void)?

    private var task: URLSessionWebSocketTask?
    private var retries = 0
    private var closed = false
    private var playedRound = 0
    private var offset: Double = 0  // Serverzeit − Gerätezeit in ms

    init(config: RoundConfig) {
        self.config = config
        let d = UserDefaults.standard
        if let id = d.string(forKey: "playerId") { me = id } else {
            let id = UUID().uuidString.lowercased()
            d.set(id, forKey: "playerId")
            me = id
        }
    }

    static var name: String {
        get { UserDefaults.standard.string(forKey: "playerName") ?? "" }
        set { UserDefaults.standard.set(String(newValue.prefix(20)), forKey: "playerName") }
    }

    var isHost: Bool { players.first { $0.id == me }?.host ?? false }
    var hostName: String { players.first(where: \.host)?.name ?? "der Gastgeber" }
    var onlineCount: Int { players.filter(\.online).count }

    /// Rangliste: Punkte, dann fertig vor laufend, dann kürzere Zeit
    var ranked: [Player] {
        players.sorted {
            if $0.points != $1.points { return $0.points > $1.points }
            if $0.done != $1.done { return $0.done }
            if $0.totalMs != $1.totalMs { return $0.totalMs < $1.totalMs }
            return $0.answered > $1.answered
        }
    }

    // MARK: Verbindung

    func connect() {
        guard !closed, let code = config.code else { return }
        var req = URLRequest(url: Self.server.appendingPathComponent("room").appendingPathComponent(code))
        req.setValue(Self.origin, forHTTPHeaderField: "Origin")
        let t = URLSession.shared.webSocketTask(with: req)
        task = t
        t.resume()
        send(["t": "hello", "id": me, "name": Self.name.isEmpty ? "Gast" : Self.name])
        receive(on: t)
    }

    private func receive(on t: URLSessionWebSocketTask) {
        t.receive { [weak self] result in
            Task { @MainActor in
                guard let self, self.task === t else { return }
                switch result {
                case .success(let msg):
                    self.connected = true; self.failed = false; self.retries = 0
                    if case .string(let s) = msg { self.handle(s) }
                    self.receive(on: t)
                case .failure:
                    self.connected = false
                    self.reconnect()
                }
            }
        }
    }

    private func reconnect() {
        guard !closed else { return }
        retries += 1
        if retries > 5 { failed = true; return }
        let delay = min(8.0, 0.4 * pow(2, Double(retries)))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.connect() }
    }

    func close() {
        closed = true
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8), let m = try? JSONDecoder().decode(StateMessage.self, from: data) else { return }
        if m.t == "error" { error = m.message; return }
        guard m.t == "state", let ps = m.players else { return }
        if let now = m.now { offset = now - Date().timeIntervalSince1970 * 1000 }
        players = ps
        // neue Runde gestartet: Countdown auf der gemeinsamen Serverzeit
        if m.phase == "playing", let r = m.round, r != playedRound, let startAt = m.startAt {
            playedRound = r
            onStart?(r, Date(timeIntervalSince1970: (startAt - offset) / 1000))
        }
    }

    // MARK: Nachrichten

    func send(_ obj: [String: Any]) {
        guard let task, let data = try? JSONSerialization.data(withJSONObject: obj), let s = String(data: data, encoding: .utf8) else { return }
        task.send(.string(s)) { _ in }
    }

    func rename(_ name: String) {
        Self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        send(["t": "hello", "id": me, "name": Self.name.isEmpty ? "Gast" : Self.name])
    }

    func startForAll() { send(["t": "start"]) }

    func progress(answered: Int, correct: Int, bonus: Int, totalMs: Double, done: Bool) {
        send(["t": "progress", "answered": answered, "correct": correct, "bonus": bonus, "totalMs": Int(totalMs.rounded()), "done": done])
    }

    /// Startwert der n-ten Runde im Raum, bitgenau wie liveSeed() der Web-App
    static func seed(_ base: Int, round n: Int) -> Int {
        Int(UInt32(truncatingIfNeeded: base) &+ (UInt32(truncatingIfNeeded: n) &* 0x9E3779B1))
    }
}
