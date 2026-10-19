import CoreImage.CIFilterBuiltins
import ImageIO
import SwiftUI

struct RootView: View {
    @StateObject var game: Game

    var body: some View {
        NavigationStack {
            Group {
                switch game.phase {
                case .menu: MenuView()
                case .playing:
                    if game.swipes { SwipeView() } else { ChoiceView() }
                case .result: ResultView()
                case .share(let cfg): CodeShareView(config: cfg)
                case .join(let prefill): JoinView(prefill: prefill ?? "")
                case .lobby(let cfg): LobbyView(config: cfg)
                case .countdown(let n, let at): CountdownView(round: n, at: at)
                }
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .background(Theme.paper.ignoresSafeArea())
        }
        .environmentObject(game)
    }
}

// MARK: - Menü

struct MenuView: View {
    @EnvironmentObject var game: Game

    var body: some View {
        let ix = game.index
        let elig = ix.eligible(levels: game.levels)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Kopf: Wortmarke mit Zeile darunter, rechts das App-Symbol in derselben Höhe
                VStack(alignment: .leading, spacing: 18) {
                    Wordmark(index: ix, size: 30)
                    Text("\(ix.people.count) Gesichter · Stand \(ix.generated)")
                        .font(Theme.body(14, .semibold)).foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .trailing) {
                    GeometryReader { g in
                        Image("Logo").resizable().interpolation(.high)
                            .frame(width: g.size.height, height: g.size.height)
                            .clipShape(RoundedRectangle(cornerRadius: g.size.height * 0.225, style: .continuous))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .accessibilityHidden(true)
                }

                Text("Ebene").font(Theme.display(15))
                FlowLayout(spacing: 8) {
                    Chip(label: "Alle", detail: nil, color: nil, on: game.levels == game.allLevels, enabled: true) { game.toggleLevel(nil) }
                    ForEach(ix.levels) { l in
                        Chip(label: l.label, detail: "\(ix.parties.reduce(0) { $0 + ($1.counts[l.key] ?? 0) })", color: nil,
                             on: game.levels != game.allLevels && game.levels.contains(l.key), enabled: true) { game.toggleLevel(l.key) }
                    }
                }

                Text("Parteien").font(Theme.display(15))
                VStack(spacing: 6) {
                    ForEach(ix.parties.filter { ix.count($0.key, levels: game.allLevels) > 0 }) { p in
                        let enabled = elig.contains(p.key)
                        Toggle(isOn: Binding(get: { game.chosen.contains(p.key) }, set: { _ in game.toggleParty(p.key) })) {
                            HStack(spacing: 10) {
                                Circle().fill(Color(hex: p.color)).frame(width: 14, height: 14)
                                Text(p.label).font(Theme.body(16, .semibold))
                                Spacer()
                                Text(enabled ? "\(ix.count(p.key, levels: game.levels))" : "zu wenige")
                                    .font(Theme.body(13, .semibold)).foregroundStyle(Theme.muted).monospacedDigit()
                            }
                        }
                        .tint(Theme.yes)
                        .disabled(!enabled)
                        .opacity(enabled ? 1 : 0.4)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                    }
                }
                Text("Parteien mit weniger als \(ix.minFaces) Gesichtern in der gewählten Ebene sind ausgegraut, damit jede Partei gleich oft vorkommt.")
                    .font(.footnote).foregroundStyle(.secondary)

                Text("Zeit pro Gesicht").font(Theme.display(15))
                FlowLayout(spacing: 8) {
                    ForEach(SharedCode.timerSteps, id: \.self) { t in
                        Chip(label: t == 0 ? "Ohne Limit" : "\(t) s", detail: nil, color: nil, on: game.timer == t, enabled: true) { game.setTimer(t) }
                    }
                }

                Group {
                    let fast = game.timer > 0 ? "unter \(Int((Double(game.timer) * 0.4).rounded())) s" : "unter 3 s"
                    let timerNote = game.timer > 0 ? " Nach \(game.timer) Sekunden ohne Antwort zählt das Gesicht als falsch." : ""
                    if let t = game.menuTarget {
                        Text("**Ja/Nein-Modus:** Gehört die Person **\(ix.party(t).zu ?? "zu " + ix.party(t).label)**? Nach rechts wischen = Ja, nach links = Nein.\(timerNote) Schnelle richtige Antworten (\(fast)) bringen je einen Bonuspunkt.")
                    } else if game.chosen.count == 2 {
                        let lr = Game.sortedLeftRight(game.chosen).map { ix.party($0).label }
                        Text("**Entweder-oder:** Nach links wischen = **\(lr[0])**, nach rechts = **\(lr[1])**. Je die Hälfte der Gesichter gehört zu einer der beiden Parteien.\(timerNote) Schnelle richtige Antworten (\(fast)) bringen je einen Bonuspunkt.")
                    } else if game.chosen.count >= 2 {
                        Text("**Zuordnen:** \(game.chosen.count) Parteien, je \(max(2, Int((Double(Game.roundSize) / Double(game.chosen.count)).rounded()))) Gesichter pro Runde.\(timerNote) Schnelle richtige Antworten (\(fast)) bringen je einen Bonuspunkt.")
                    } else {
                        Text("Wähle mindestens eine Partei.")
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))

                PrimaryButton(title: "Runde starten") { game.start() }
                    .disabled(game.chosen.isEmpty)
                    .opacity(game.chosen.isEmpty ? 0.35 : 1)

                Text("Gemeinsam spielen").font(Theme.display(15))
                Text("Alle geben denselben Code ein und bekommen dieselben Gesichter in derselben Reihenfolge, auch ohne gemeinsames Netz. Wer den Code erzeugt, legt Parteien, Ebene und Zeitlimit fest.")
                    .font(Theme.body(14)).foregroundStyle(Theme.muted)
                HStack(spacing: 10) {
                    PrimaryButton(title: "Code erzeugen", secondary: true) { game.makeCode() }
                        .disabled(game.chosen.isEmpty)
                        .opacity(game.chosen.isEmpty ? 0.35 : 1)
                    PrimaryButton(title: "Code eingeben", secondary: true) { game.joinCode() }
                }

                Text("Fotos: Wikimedia Commons (freie Lizenzen, Urheber unter jedem Bild). Personen und Ämter: Wikidata und abgeordnetenwatch.de. Hintergründe sind weichgezeichnet.")
                    .font(Theme.body(12)).foregroundStyle(Theme.muted)
            }
            .padding()
        }
        .toolbar(.hidden)
    }
}

struct Chip: View {
    let label: String
    let detail: String?
    let color: Color?
    let on: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let color { Circle().fill(color).frame(width: 10, height: 10).overlay(Circle().stroke(.gray.opacity(0.5))) }
                Text(label).fontWeight(.semibold)
                if let detail { Text(detail).font(.caption.monospaced()).opacity(0.7) }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundStyle(on ? Color(white: 0.97) : .primary)
            .background(Capsule().fill(on ? Color.primary : Color.clear))
            .overlay(Capsule().stroke(on ? Color.primary : Color.gray.opacity(0.4), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Einfaches Umbruch-Layout für die Auswahl-Chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > width && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
        return CGSize(width: width, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX && x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
    }
}

// MARK: - Gemeinsame Teile

struct RoundHeader: View {
    @EnvironmentObject var game: Game
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button { game.backToMenu() } label: {
                    Text("Menü").font(Theme.body(14, .bold)).padding(.horizontal, 13).padding(.vertical, 7)
                        .background(Capsule().fill(Theme.card))
                }
                .buttonStyle(.plain)
                Spacer()
                Text("parteigesicht").font(Theme.display(15, .heavy)).kerning(-0.5)
                Spacer()
                Text("\(min(game.position + 1, game.items.count))/\(game.items.count) · \(game.correctCount) ✓")
                    .font(Theme.body(13, .bold)).foregroundStyle(Theme.muted).monospacedDigit()
            }
            ProgressView(value: Double(game.position), total: Double(max(1, game.items.count))).tint(Theme.ink)
            if game.round.timer > 0 { TimerBar() }
            if game.round.live, let room = game.live { LiveBar(room: room) }
        }
    }
}

/// Zeitlimit: Balken läuft ab, in den letzten drei Sekunden rot, Restsekunden rechts.
struct TimerBar: View {
    @EnvironmentObject var game: Game
    var body: some View {
        let total = Double(max(1, game.round.timer))
        let left = game.currentAnswer == nil ? game.timeLeft : 0
        let low = left <= 3
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.rule)
                    Capsule().fill(low ? Theme.no : Theme.yes)
                        .frame(width: max(0, geo.size.width * left / total))
                        .animation(.linear(duration: 0.1), value: left)
                }
            }
            .frame(height: 8)
            Text("\(Int(left.rounded(.up))) s")
                .font(Theme.body(13, .bold)).foregroundStyle(low ? Theme.no : Theme.muted).monospacedDigit()
                .frame(width: 34, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Noch \(Int(left.rounded(.up))) Sekunden")
    }
}

struct Credit: View {
    let person: Person
    /// Logo-Urheber nach der Auflösung, nur bei CC-lizenzierten Logos nötig
    var logo: GameIndex.Logo? = nil
    /// Urheber erst nach der Antwort (bei allen Fotos): Namen wie „CDU“ oder „Fraktion DIE LINKE“ verraten sonst die Partei
    var revealed = false
    var body: some View {
        HStack(spacing: 4) {
            Text("Foto: \(revealed ? person.artist : "Urheber nach der Antwort") · \(person.license) ·")
            if let url = person.commonsURL { Link("Commons", destination: url) }
            if let logo, logo.license.hasPrefix("CC") { Text("· Logo: \(logo.artist ?? "unbekannt") · \(logo.license)") }
        }
        .font(Theme.body(11)).foregroundStyle(Theme.muted).lineLimit(2)
    }
}

struct RevealOverlay: View {
    @EnvironmentObject var game: Game
    let person: Person
    let answer: Game.Answer
    var body: some View {
        let correct = answer.correct
        VStack(alignment: .leading, spacing: 3) {
            Text(game.verdictText(answer))
                .font(Theme.display(11)).foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(correct ? Theme.yes : Theme.no))
            Spacer()
            Text(person.name).font(Theme.display(20, .heavy))
            HStack(spacing: 6) {
                Circle().fill(Color(hex: game.index.party(person.party).color)).frame(width: 10, height: 10)
                Text(game.index.partyLabel(person)).fontWeight(.semibold)
            }
            Text(person.whereLabel).font(.footnote).opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [.clear, .clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .topTrailing) { PartyLogo(person: person, index: game.index).padding(12) }
    }
}

// MARK: - Zuordnen (mehrere Parteien)

struct ChoiceView: View {
    @EnvironmentObject var game: Game
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let ix = game.index
        if let p = game.current {
            let a = game.currentAnswer
            let done = a != nil
            let answered = a?.guess
            VStack(spacing: 12) {
                RoundHeader()
                FaceView(person: p, index: ix)
                    .overlay { if let a { RevealOverlay(person: p, answer: a) } }
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .frame(maxHeight: 440)
                Text("Zu welcher Partei gehört diese Person?").font(Theme.display(15, .semibold)).multilineTextAlignment(.center)
                // Telefon: höchstens drei Kacheln pro Zeile, damit alle sichtbar bleiben; iPad: alle in einer Zeile
                let n = game.round.parties.count
                let cols = sizeClass == .regular ? min(n, 6) : (n <= 3 ? n : (n == 4 ? 2 : 3))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: max(1, cols)), spacing: 8) {
                    ForEach(game.round.parties, id: \.self) { key in
                        let pt = ix.party(key)
                        Button {
                            guard !done else { return }
                            game.answer(party: key)
                            Haptics.tap(key == p.party)
                        } label: {
                            HStack(spacing: 4) {
                                Text(pt.label).font(Theme.display(14)).lineLimit(2).minimumScaleFactor(0.6)
                                if done && key == p.party { Text("✓").font(Theme.display(14)) }
                                else if answered == key { Text("✕").font(Theme.display(14)) }
                            }
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .foregroundStyle(pt.textDark == true ? Color.black : .white)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: pt.color)))
                            .overlay(RoundedRectangle(cornerRadius: 17).stroke(borderColor(key, p, answered, done), lineWidth: 3).padding(-5))
                            .opacity(!done || key == answered || key == p.party ? 1 : 0.3)
                        }
                        .buttonStyle(.plain)
                    }
                }
                // Platz für den Knopf immer freihalten, damit das Foto nach dem Tipp nicht springt
                PrimaryButton(title: game.position + 1 >= game.items.count ? "Auswertung ansehen" : "Nächstes Gesicht") {
                    game.advance()
                }
                .opacity(done ? 1 : 0)
                .disabled(!done)
                .accessibilityHidden(!done)
                Credit(person: p, logo: done ? ix.logo(for: p) : nil, revealed: done)
                Spacer(minLength: 0)
            }
            .padding()
        }
    }

    private func borderColor(_ key: String, _ p: Person, _ answered: String?, _ done: Bool) -> Color {
        guard done else { return .clear }
        if key == p.party { return Theme.yes }
        if key == answered { return Theme.no }
        return .clear
    }
}

// MARK: - Wischen (eine Partei, wie bei Tinder: rechts = Ja, links = Nein)

struct SwipeView: View {
    @EnvironmentObject var game: Game
    @State private var offset: CGSize = .zero

    var body: some View {
        let ix = game.index
        let target = ix.party(game.targetParty ?? game.pair?[0] ?? "")
        // Zwei Parteien: links die linkere, rechts die rechtere
        let pair = game.pair.map { (ix.party($0[0]), ix.party($0[1])) }
        let feedback = game.currentAnswer
        let locked = feedback != nil
        VStack(spacing: 14) {
            RoundHeader()
            Group {
                if let (l, r) = pair {
                    Text(l.label).foregroundColor(Self.ink(l)) + Text(" oder ") + Text(r.label).foregroundColor(Self.ink(r)) + Text("?")
                } else {
                    Text("Gehört diese Person ") + Text(target.zu ?? "zu \(target.label)").foregroundColor(Self.ink(target)) + Text("?")
                }
            }
            .font(Theme.display(16, .semibold)).multilineTextAlignment(.center)
            ZStack {
                if game.position + 1 < game.items.count {
                    FaceView(person: game.items[game.position + 1], index: ix)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .scaleEffect(0.95).offset(y: 10).brightness(-0.08)
                }
                if let p = game.current {
                    FaceView(person: p, index: ix)
                        // Ja/Nein-Stempel nur im Ein-Partei-Modus; bei zwei Parteien sähe ein Parteistempel
                        // beim Ziehen schon wie die Auflösung aus
                        .overlay(alignment: .topLeading) {
                            if pair == nil { Stamp(text: "JA", color: Theme.yes, angle: -14).opacity(Double(offset.width / 90)).padding(20) }
                        }
                        .overlay(alignment: .topTrailing) {
                            if pair == nil { Stamp(text: "NEIN", color: Theme.no, angle: 14).opacity(Double(-offset.width / 90)).padding(20) }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        // Zeit um: Karte bleibt liegen und wird grau
                        .grayscale(feedback?.timedOut == true ? 1 : 0)
                        .brightness(feedback?.timedOut == true ? -0.3 : 0)
                        .animation(.easeOut(duration: 0.3), value: feedback?.timedOut == true)
                        .shadow(color: .black.opacity(0.22), radius: 14, y: 8)
                        .offset(x: offset.width, y: offset.height * 0.4)
                        .rotationEffect(.degrees(Double(offset.width / 18)))
                        .gesture(
                            DragGesture()
                                .onChanged { if !locked { offset = $0.translation } }
                                .onEnded { v in
                                    guard !locked else { return }
                                    if abs(v.translation.width) > 110 || abs(v.predictedEndTranslation.width) > 260 {
                                        decide(v.translation.width > 0)
                                    } else {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { offset = .zero }
                                    }
                                }
                        )
                        .id(p.id)
                        .accessibilityAction(named: pair?.1.label ?? "Ja") { decide(true) }
                        .accessibilityAction(named: pair?.0.label ?? "Nein") { decide(false) }
                }
            }
            .overlay {
                // Erst nach der Entscheidung: welche Partei es war, grün oder rot umrandet
                if let a = feedback {
                    RevealPopup(person: a.person, index: ix, correct: a.correct)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.22), value: feedback != nil)
            .frame(maxHeight: 480)
            if let p = game.current { Credit(person: p, logo: feedback.map { game.index.logo(for: $0.person) } ?? nil, revealed: feedback != nil) }
            HStack(spacing: 36) {
                if let (l, r) = pair {
                    PartyButton(party: l, arrow: "←", leading: true) { decide(false) }
                    PartyButton(party: r, arrow: "→", leading: false) { decide(true) }
                } else {
                    RoundButton(symbol: "xmark", color: Theme.no) { decide(false) }.accessibilityLabel("Nein, gehört nicht zu \(target.label)")
                    RoundButton(symbol: "checkmark", color: Theme.yes) { decide(true) }.accessibilityLabel("Ja, gehört zu \(target.label)")
                }
            }
            Group {
                if let a = feedback {
                    let p = a.person
                    PartyLogo(person: p, index: ix, width: 56, height: 34)
                    (Text(game.verdictText(a) + ": ").foregroundColor(a.correct ? Theme.yes : Theme.no).bold()
                     + Text(p.name).bold() + Text(", \(ix.partyLabel(p)) · \(p.whereLabel)"))
                } else {
                    Text(pair.map { "Nach links wischen = \($0.0.label) · nach rechts = \($0.1.label)" } ?? "Nach rechts wischen = Ja · nach links = Nein").foregroundStyle(Theme.muted)
                }
            }
            .font(.subheadline).multilineTextAlignment(.center).frame(minHeight: 44)
            Spacer(minLength: 0)
        }
        .padding()
        .onChange(of: game.position) { _, _ in offset = .zero }
    }

    static func ink(_ p: GameIndex.Party) -> Color { p.key == "UNION" || p.textDark == true ? Theme.ink : Color(hex: p.color) }

    /// yes = nach rechts; bei zwei Parteien heißt das: die rechtere Partei
    private func decide(_ yes: Bool) {
        guard game.currentAnswer == nil, let p = game.current else { return }
        let ok: Bool
        if let pair = game.pair {
            let guess = yes ? pair[1] : pair[0]
            ok = p.party == guess
            game.answer(party: guess)
        } else {
            ok = (p.party == game.targetParty) == yes
            game.answer(yes: yes)
        }
        Haptics.tap(ok)
        withAnimation(.easeOut(duration: 0.28)) { offset = CGSize(width: yes ? 700 : -700, height: offset.height + 60) }
    }
}

struct RevealPopup: View {
    let person: Person; let index: GameIndex; let correct: Bool
    var body: some View {
        VStack(spacing: 8) {
            PartyLogo(person: person, index: index, width: 110, height: 66)
            Text(index.party(person.party).label).font(Theme.display(19, .heavy))
        }
        .padding(.horizontal, 18).padding(.vertical, 14).frame(minWidth: 150)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(correct ? Theme.yes : Theme.no, lineWidth: 5))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        .accessibilityHidden(true)
    }
}

struct Stamp: View {
    let text: String; let color: Color; let angle: Double
    var body: some View {
        Text(text).font(Theme.display(30, .black)).foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 4))
            .rotationEffect(.degrees(angle))
    }
}

/// Knopf in Parteifarbe für das Wischen zwischen zwei Parteien
struct PartyButton: View {
    let party: GameIndex.Party; let arrow: String; let leading: Bool; let action: () -> Void
    var body: some View {
        let dark = party.textDark == true || party.key == "FDP"
        Button(action: action) {
            Text(leading ? "\(arrow) \(party.label)" : "\(party.label) \(arrow)")
                .font(Theme.display(16, .heavy)).lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(dark ? Theme.ink : .white)
                .padding(.horizontal, 20).frame(minWidth: 110, minHeight: 64)
                .background(Capsule().fill(Color(hex: party.color)).shadow(color: .black.opacity(0.15), radius: 8, y: 3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(party.label)
    }
}

struct RoundButton: View {
    let symbol: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 28, weight: .heavy)).foregroundStyle(color)
                .frame(width: 68, height: 68)
                .background(Circle().fill(Theme.card).shadow(color: .black.opacity(0.15), radius: 8, y: 3))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Auswertung

struct ResultView: View {
    @EnvironmentObject var game: Game

    var body: some View {
        let ix = game.index
        let a = game.answers
        let n = a.count, ok = game.correctCount, bonus = game.bonus
        let chance = game.targetParty != nil ? Double(n) / 2 : Double(n) / Double(max(1, game.round.parties.count))
        let share = Double(ok) / Double(max(1, n))
        let verdict = share >= 0.8 ? "Du kennst dich aus." : Double(ok) > chance * 1.5 ? "Besser als Zufall, aber oft daneben." : Double(ok) >= chance * 0.8 ? "Ungefähr so gut wie Raten." : "Deine Eindrücke lagen meist falsch."
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(game.points) Punkte").font(Theme.display(44, .heavy)).kerning(-1.5)
                (Text("\(ok) von \(n)").bold() + Text(" richtig")
                 + (bonus > 0 ? Text(" + ") + Text("\(bonus)").bold() + Text(" Schnell-Bonus") : Text(""))
                 + Text(" · Gesamtzeit ") + Text(Game.formatTime(game.totalMs)).bold())
                Text("\(verdict) Reiner Zufall läge bei etwa \(Int(chance.rounded())) von \(n).")
                if game.round.timer > 0 {
                    let answered = a.filter { !$0.timedOut }
                    let avg = answered.reduce(0) { $0 + $1.ms } / Double(max(1, answered.count)) / 1000
                    Text("Durchschnittlich \(String(format: "%.1f", avg)) s pro Antwort bei \(game.round.timer) s Limit.")
                }
                if let code = game.round.code {
                    (Text("Gemeinsame Runde ") + Text(SharedCode.format(code)).font(Theme.display(15)).kerning(1)
                     + Text(": Die meisten Punkte gewinnen, bei Gleichstand die kürzere Gesamtzeit."))
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                }
                Text("Gesamt bisher: \(game.totalCorrect) von \(game.totalAnswered)").foregroundStyle(Theme.muted)
                if game.round.live, let room = game.live { LiveRanking(room: room) }
                ForEach(insights()) { t in InsightCard(insight: t, index: ix, target: game.targetParty) }
                if game.targetParty == nil { matrix }
                let wrong = a.filter { !$0.correct }
                if !wrong.isEmpty {
                    DisclosureGroup("Alle falsch eingeordneten (\(wrong.count))") {
                        MistakeList(answers: wrong, index: ix, target: game.targetParty).padding(.top, 8)
                    }
                    .font(Theme.body(14)).tint(Theme.muted)
                }
                if game.round.live {
                    PrimaryButton(title: "Raum verlassen", secondary: true) { game.backToMenu() }
                } else {
                    HStack {
                        PrimaryButton(title: "Neue Runde") { var cfg = game.round; cfg.seed = nil; cfg.code = nil; game.start(cfg) }
                        PrimaryButton(title: "Menü", secondary: true) { game.backToMenu() }
                    }
                }
                if game.round.code != nil && !game.round.live {
                    PrimaryButton(title: "Neuen gemeinsamen Code erzeugen", secondary: true) { game.makeCodeFromRound() }
                }
                Text("Schnell-Bonus: ein Punkt je richtige Antwort \(game.round.timer > 0 ? "unter \(Int((Double(game.round.timer) * 0.4).rounded())) s" : "unter 3 s"). Pro Runde kommen alle gewählten Parteien gleich oft vor.")
                    .font(Theme.body(12)).foregroundStyle(Theme.muted)
            }
            .padding()
        }
        .toolbar(.hidden)
    }

    /// Aussagen zur Runde; die mit Gesichtern lassen sich aufklappen
    private func insights() -> [Insight] {
        let ix = game.index, a = game.answers
        let timeouts = a.filter(\.timedOut)
        if let t = game.targetParty {
            let label = ix.party(t).label
            let members = a.filter { $0.person.party == t }, others = a.filter { $0.person.party != t }
            let hit = members.filter { $0.saidYes == true }.count
            let fa = others.filter { $0.saidYes == true }
            var out = [Insight(text: "Von \(members.count) Personen aus der Partei \(label) hast du \(hit) erkannt.",
                               list: members.filter { $0.saidYes == false })]
            if fa.isEmpty {
                out.append(Insight(text: "Niemanden aus einer anderen Partei hast du fälschlich \(label) zugeordnet."))
            } else {
                let by = Dictionary(grouping: fa, by: { $0.person.party }).map { "\($0.value.count)× \(ix.party($0.key).label)" }
                out.append(Insight(text: "\(fa.count) von \(others.count) Personen aus anderen Parteien hast du für \(label) gehalten: \(by.joined(separator: ", ")).", list: fa))
            }
            if !timeouts.isEmpty { out.append(Insight(text: "\(timeouts.count)-mal war die Zeit um, bevor du gewischt hast.", list: timeouts)) }
            return out
        }
        // die drei häufigsten Verwechslungen; alle übrigen stehen unter „Alle falsch eingeordneten“
        let typed = a.filter { !$0.timedOut && $0.guess != nil && !$0.correct }
        var out = Dictionary(grouping: typed, by: { "\($0.person.party)>\($0.guess ?? "")" })
            .sorted { $0.value.count != $1.value.count ? $0.value.count > $1.value.count : $0.key < $1.key }.prefix(3)
            .map { k, v -> Insight in
                let parts = k.split(separator: ">").map(String.init)
                return Insight(text: "\(v.count) \(v.count == 1 ? "Person" : "Personen") aus der Partei \(ix.party(parts[0]).label) hast du für \(ix.party(parts[1]).label) gehalten.", list: v)
            }
        if out.isEmpty { out.append(Insight(text: "Keine Verwechslungen in dieser Runde.")) }
        if !timeouts.isEmpty { out.append(Insight(text: "\(timeouts.count)-mal war die Zeit um, bevor du getippt hast.", list: timeouts)) }
        return out
    }

    private var matrix: some View {
        let ix = game.index, keys = game.pair ?? game.round.parties
        let cnt = Dictionary(grouping: game.answers, by: { "\($0.person.party)>\($0.guess ?? "")" }).mapValues(\.count)
        return VStack(alignment: .leading, spacing: 4) {
            Text("Zeilen: tatsächliche Partei · Spalten: dein Tipp").font(.caption).foregroundStyle(.secondary)
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    Text("")
                    ForEach(keys, id: \.self) { Text(ix.party($0).label).font(.caption2.bold()).lineLimit(1).minimumScaleFactor(0.6) }
                }
                ForEach(keys, id: \.self) { r in
                    GridRow {
                        Text(ix.party(r).label).font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.6)
                        ForEach(keys, id: \.self) { c in
                            let v = cnt["\(r)>\(c)"] ?? 0
                            Text(v == 0 ? "·" : "\(v)").font(.footnote.monospaced())
                                .frame(maxWidth: .infinity, minHeight: 28)
                                .background(RoundedRectangle(cornerRadius: 3)
                                    .fill(v == 0 ? Color.clear : (r == c ? Color.green : Color.red).opacity(0.15 + 0.12 * Double(v))))
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
    }
}

struct Insight: Identifiable {
    let text: String
    var list: [Game.Answer] = []
    var id: String { text }
}

/// Aussage der Auswertung; mit Gesichtern lässt sie sich aufklappen
struct InsightCard: View {
    let insight: Insight; let index: GameIndex; let target: String?
    @State private var open = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(insight.text).frame(maxWidth: .infinity, alignment: .leading)
            if !insight.list.isEmpty {
                Button { withAnimation(.easeOut(duration: 0.25)) { open.toggle() } } label: {
                    HStack(spacing: 4) {
                        Text(open ? "Gesichter ausblenden" : "Gesichter ansehen")
                        Image(systemName: "chevron.right").rotationEffect(.degrees(open ? 90 : 0))
                    }
                    .font(Theme.body(13, .bold)).foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                if open { MistakeList(answers: insight.list, index: index, target: target).transition(.opacity) }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
    }
}

/// Gesichter mit deinem Tipp (rot) → was es gewesen wäre (grün)
struct MistakeList: View {
    let answers: [Game.Answer]; let index: GameIndex; let target: String?
    @State private var shown = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(answers.enumerated()), id: \.element.person.id) { i, a in
                HStack(spacing: 12) {
                    FaceView(person: a.person, index: index)
                        .frame(width: 64, height: 80).clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.person.name).font(Theme.body(15, .bold))
                        Text(a.person.whereLabel).font(Theme.body(12)).foregroundStyle(Theme.muted)
                        HStack(spacing: 8) {
                            guessChip(a)
                            Image(systemName: "arrow.right").font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.muted)
                                .opacity(shown ? 1 : 0).offset(x: shown ? 0 : -8)
                                .accessibilityLabel("richtig wäre")
                            LogoChip(logo: index.logo(for: a.person), party: index.party(a.person.party), label: index.partyLabel(a.person), correct: true)
                        }
                        .padding(.top, 4)
                    }
                }
                .opacity(shown ? 1 : 0).offset(y: shown ? 0 : 6)
                .animation(.easeOut(duration: 0.35).delay(Double(i) * 0.07), value: shown)
            }
        }
        .onAppear { shown = true }
    }

    @ViewBuilder private func guessChip(_ a: Game.Answer) -> some View {
        if a.timedOut {
            LogoChip(logo: nil, party: nil, label: "Zeit um", correct: false)
        } else if let g = a.guess ?? (a.saidYes == true ? target : nil) {
            let party = index.party(g)
            LogoChip(logo: index.logos?[g == "UNION" ? "CDU" : g], party: party, label: party.label, correct: false)
        } else {
            LogoChip(logo: nil, party: nil, label: "Nein", correct: false)
        }
    }
}

/// Parteilogo (oder Name) mit grünem oder rotem Rahmen
struct LogoChip: View {
    let logo: GameIndex.Logo?; let party: GameIndex.Party?; let label: String; let correct: Bool
    var body: some View {
        Group {
            if let logo, let url = Bundle.main.url(forResource: "data/" + logo.path, withExtension: nil),
               let src = CGImageSourceCreateWithURL(url as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                let fills = party?.key == "GRUENE"
                Image(decorative: img, scale: 1).resizable().aspectRatio(contentMode: fills ? .fill : .fit)
                    .padding(fills ? 0 : 4).frame(width: 74, height: 36).clipped()
                    .accessibilityLabel(label)
            } else {
                HStack(spacing: 6) {
                    if let party { Circle().fill(Color(hex: party.color)).frame(width: 12, height: 12) }
                    Text(label).font(Theme.body(13, .bold))
                }
                .padding(.horizontal, 8).frame(height: 36)
            }
        }
        .foregroundStyle(Color(hex: "#111318"))
        .background(Color.white, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(correct ? Theme.yes : Theme.no, lineWidth: 2.5))
        .opacity(correct ? 1 : 0.85)
    }
}

// MARK: - Gemeinsam spielen

struct CodeShareView: View {
    @EnvironmentObject var game: Game
    let config: RoundConfig
    @State private var copied = false

    var body: some View {
        let code = config.code ?? ""
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SmallHeader(meta: "Gemeinsam")
                Text("Euer Code").font(Theme.display(17))
                Text(SharedCode.format(code))
                    .font(Theme.display(32, .heavy)).kerning(2).monospacedDigit()
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
                    .textSelection(.enabled)
                    .accessibilityLabel("Code " + code.map(String.init).joined(separator: " "))
                Text(game.settingsSummary(config)).font(Theme.body(14)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    PrimaryButton(title: copied ? "Kopiert ✓" : "Code kopieren", secondary: true) {
                        UIPasteboard.general.string = SharedCode.format(code)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    }
                    ShareLink(item: SharedCode.link(code), subject: Text("Parteigesicht"), message: Text("Spiel mit: Code " + SharedCode.format(code))) {
                        Text("Teilen").font(Theme.display(15))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundStyle(Theme.ink)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                    }
                    .buttonStyle(.plain)
                }
                Text("Alle Mitspielenden geben den Code unter „Gemeinsam spielen“ ein oder öffnen den Link. Dann bekommt jedes Gerät dieselben \(Game.roundSize) Gesichter in derselben Reihenfolge. Am Ende vergleicht ihr eure Ergebnisse.")
                    .font(Theme.body(14)).foregroundStyle(Theme.muted)
                PrimaryButton(title: "Runde starten") { game.start(config) }
            }
            .padding()
        }
        .toolbar(.hidden)
    }
}

struct JoinView: View {
    @EnvironmentObject var game: Game
    let prefill: String
    @State private var input = ""
    @State private var error: String?
    @State private var decoded: SharedCode.Decoded?
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SmallHeader(meta: "Gemeinsam")
                Text("Code eingeben").font(Theme.display(17))
                TextField("XXXXX-XXXXX", text: $input)
                    .font(Theme.display(26, .heavy)).kerning(2)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.go)
                    .focused($focused)
                    .onSubmit(tryJoin)
                    .onChange(of: input) { _, _ in decoded = nil; error = nil }
                    .padding(.vertical, 14).padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(error == nil ? Theme.rule : Theme.no, lineWidth: 1.5))
                    .accessibilityLabel("Code")
                if let error {
                    Text(error).font(Theme.body(14, .semibold)).foregroundStyle(Theme.no)
                }
                if let d = decoded {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Gemeinsame Runde \(SharedCode.format(d.config.code ?? ""))").bold()
                        Text(game.settingsSummary(d.config))
                        if !d.sameData {
                            Text("Achtung: Dieses Gerät hat einen anderen Datenstand als das Gerät, das den Code erzeugt hat. Die Gesichter können abweichen. Am besten aktualisieren alle die App.")
                                .foregroundStyle(Theme.no).fontWeight(.semibold)
                        }
                    }
                    .font(Theme.body(15))
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                    PrimaryButton(title: "In den Warteraum") { game.enterLobby(d.config) }
                } else {
                    PrimaryButton(title: "Beitreten", action: tryJoin)
                }
            }
            .padding()
        }
        .toolbar(.hidden)
        .onAppear {
            if !prefill.isEmpty { input = SharedCode.format(prefill); tryJoin() } else { focused = true }
        }
    }

    private func tryJoin() {
        guard let d = SharedCode.decode(input, index: game.index) else {
            decoded = nil
            error = "Dieser Code ist ungültig. Er hat 10 Zeichen, ohne 0, O, 1 und I."
            return
        }
        error = nil
        decoded = d
        focused = false
    }
}

/// Kopfzeile der Nebenansichten: Menü-Knopf, Schriftzug, Hinweis rechts
struct SmallHeader: View {
    @EnvironmentObject var game: Game
    let meta: String
    var body: some View {
        HStack {
            Button { game.backToMenu() } label: {
                Text("Menü").font(Theme.body(14, .bold)).padding(.horizontal, 13).padding(.vertical, 7)
                    .background(Capsule().fill(Theme.card))
            }
            .buttonStyle(.plain)
            Spacer()
            Text("parteigesicht").font(Theme.display(15, .heavy)).kerning(-0.5)
            Spacer()
            Text(meta).font(Theme.body(13, .bold)).foregroundStyle(Theme.muted)
        }
    }
}

enum Haptics {
    static func tap(_ ok: Bool) {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(ok ? .success : .error)
        #endif
    }
}

struct PrimaryButton: View {
    let title: String
    var secondary = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(Theme.display(15))
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(secondary ? Theme.ink : Theme.paper)
                .background(RoundedRectangle(cornerRadius: 14).fill(secondary ? Theme.card : Theme.ink))
        }
        .buttonStyle(.plain)
    }
}

/// Kleines Parteilogo, das erst nach dem Tipp erscheint (Design-Variante C).
struct PartyLogo: View {
    let person: Person
    let index: GameIndex
    var width: CGFloat = 72
    var height: CGFloat = 44

    var body: some View {
        if let lg = index.logo(for: person),
           let url = Bundle.main.url(forResource: "data/" + lg.path, withExtension: nil),
           let src = CGImageSourceCreateWithURL(url as CFURL, nil),
           let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
            // Das Grünen-Logo hat einen eigenen dunkelgrünen Grund und füllt das Feld
            let fills = person.party == "GRUENE"
            Image(decorative: img, scale: 1)
                .resizable()
                .aspectRatio(contentMode: fills ? .fill : .fit)
                .padding(fills ? 0 : 5)
                .frame(width: width, height: height)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
                .accessibilityLabel("Logo \(index.party(person.party).long)")
        }
    }
}

// MARK: - Live-Raum

struct LobbyView: View {
    @EnvironmentObject var game: Game
    let config: RoundConfig
    var body: some View {
        if let room = game.live { LobbyContent(room: room, config: config) }
    }
}

/// Warteraum: Code, QR-Code, Name, Mitspielende; der Gastgeber startet für alle
struct LobbyContent: View {
    @EnvironmentObject var game: Game
    @ObservedObject var room: LiveRoom
    let config: RoundConfig
    @State private var name = LiveRoom.name
    @State private var copied = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        let code = config.code ?? ""
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SmallHeader(meta: "Live")
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Code").font(Theme.body(13)).foregroundStyle(Theme.muted)
                        Text(SharedCode.format(code)).font(Theme.display(26, .heavy)).kerning(1.5)
                            .minimumScaleFactor(0.6).lineLimit(1)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                            .textSelection(.enabled)
                        Text(game.settingsSummary(config)).font(Theme.body(12)).foregroundStyle(Theme.muted)
                    }
                    if let qr = QRCode.image(SharedCode.link(code).absoluteString) {
                        Image(decorative: qr, scale: 1).interpolation(.none).resizable()
                            .frame(width: 112, height: 112).padding(8)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                            .accessibilityLabel("QR-Code zum Mitspielen")
                    }
                }
                HStack(spacing: 10) {
                    PrimaryButton(title: copied ? "Kopiert ✓" : "Code kopieren", secondary: true) {
                        UIPasteboard.general.string = SharedCode.format(code)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    }
                    ShareLink(item: SharedCode.link(code), subject: Text("Parteigesicht"), message: Text("Spiel mit! Code " + SharedCode.format(code))) {
                        Text("Einladen").font(Theme.display(15))
                            .frame(maxWidth: .infinity, minHeight: 50).foregroundStyle(Theme.ink)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                    }
                    .buttonStyle(.plain)
                }
                Text("Dein Name").font(Theme.display(15))
                TextField("z. B. Jan", text: $name)
                    .font(Theme.body(17, .semibold)).textContentType(.nickname).submitLabel(.done)
                    .focused($nameFocused)
                    .onSubmit { room.rename(name) }
                    .onChange(of: nameFocused) { _, f in if !f { room.rename(name) } }
                    .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                Text("Im Raum").font(Theme.display(15))
                VStack(spacing: 6) {
                    if room.players.isEmpty {
                        playerRow(name: room.failed ? "Keine Verbindung" : "Verbinde …", online: false, host: false, me: false)
                    }
                    ForEach(room.players) { p in playerRow(name: p.name, online: p.online, host: p.host, me: p.id == room.me) }
                }
                if room.failed || room.error != nil {
                    Text("\(room.error ?? "Keine Verbindung zum Live-Server.") Ihr könnt trotzdem dieselbe Runde spielen und am Ende die Punkte vergleichen.")
                        .font(Theme.body(15)).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                    PrimaryButton(title: "Ohne Verbindung starten") { game.startOffline(config) }
                } else if room.isHost {
                    PrimaryButton(title: "Alle starten (\(room.onlineCount) \(room.onlineCount == 1 ? "Gerät" : "Geräte"))") { room.startForAll() }
                    Text("Nach dem Start zählt ein Countdown auf allen Geräten gleichzeitig herunter.")
                        .font(Theme.body(12)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity).multilineTextAlignment(.center)
                } else if !room.players.isEmpty {
                    (Text("Warte, bis ") + Text(room.hostName).bold() + Text(" die Runde startet …"))
                        .font(Theme.body(15)).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                }
            }
            .padding()
        }
        .toolbar(.hidden)
        .onAppear { if name.isEmpty { nameFocused = true } }
    }

    private func playerRow(name: String, online: Bool, host: Bool, me: Bool) -> some View {
        HStack(spacing: 10) {
            Circle().fill(online ? Theme.yes : Theme.rule).frame(width: 10, height: 10)
            Text(name + (me ? " (du)" : "")).font(Theme.body(16, .semibold)).lineLimit(1)
                .foregroundStyle(online ? Theme.ink : Theme.muted)
            Spacer()
            if host {
                Text("Gastgeber").font(Theme.display(10)).foregroundStyle(Theme.paper)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Theme.ink))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
    }
}

/// Countdown bis zum gemeinsamen Start (Serverzeit, auf allen Geräten gleich)
struct CountdownView: View {
    @EnvironmentObject var game: Game
    let round: Int
    let at: Date
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { ctx in
            let left = at.timeIntervalSince(ctx.date)
            VStack(spacing: 12) {
                Spacer()
                Text("Runde \(round)").font(Theme.body(14)).foregroundStyle(Theme.muted)
                Text("\(max(1, Int(left.rounded(.up))))").font(Theme.display(120, .black)).monospacedDigit()
                Text("Gleich geht es los").font(Theme.display(17))
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .toolbar(.hidden)
        .task(id: round) {
            let wait = at.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
            if case .countdown(let n, _) = game.phase, n == round { game.startLiveRound(round) }
        }
    }
}

/// Live-Rangliste im Spiel: kompakte Leiste unter der Fortschrittsanzeige
struct LiveBar: View {
    @ObservedObject var room: LiveRoom
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(room.ranked.enumerated()), id: \.element.id) { i, p in
                    let me = p.id == room.me
                    Text("\(i + 1). \(me ? "Du" : p.name) \(p.points)")
                        .font(Theme.body(12, .bold)).monospacedDigit()
                        .foregroundStyle(me ? Theme.paper : Theme.ink)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().fill(me ? Theme.ink : Theme.card))
                }
            }
        }
        .accessibilityLabel("Live-Rangliste")
    }
}

/// Live-Rangliste in der Auswertung, mit „Nächste Runde für alle“ für den Gastgeber
struct LiveRanking: View {
    @ObservedObject var room: LiveRoom
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Live-Rangliste").font(Theme.display(17))
            ForEach(Array(room.ranked.enumerated()), id: \.element.id) { i, p in
                let me = p.id == room.me
                HStack(spacing: 10) {
                    Text("\(i + 1)").font(Theme.display(16, .heavy)).frame(width: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name + (me ? " (du)" : "")).font(Theme.body(15, .bold)).lineLimit(1)
                        Text("\(p.correct) richtig + \(p.bonus) Bonus\(p.online ? "" : " · offline")").font(Theme.body(12)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(p.points)").font(Theme.display(17, .heavy)).monospacedDigit()
                        Text(p.done ? Game.formatTime(p.totalMs) : "läuft \(p.answered)/\(Game.roundSize)").font(Theme.body(12)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(me ? Theme.yes.opacity(0.18) : Theme.card))
            }
            if room.isHost {
                PrimaryButton(title: "Nächste Runde für alle") { room.startForAll() }
            } else {
                (Text("Die nächste Runde startet ") + Text(room.hostName).bold() + Text("."))
                    .font(Theme.body(14)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
            }
        }
    }
}

enum QRCode {
    static func image(_ text: String) -> CGImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8)
        f.correctionLevel = "M"
        guard let out = f.outputImage else { return nil }
        return CIContext().createCGImage(out.transformed(by: CGAffineTransform(scaleX: 8, y: 8)), from: out.extent.applying(CGAffineTransform(scaleX: 8, y: 8)))
    }
}
