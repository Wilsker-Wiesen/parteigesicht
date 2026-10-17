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
                    if game.targetParty != nil { SwipeView() } else { ChoiceView() }
                case .result: ResultView()
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
                Wordmark(index: ix, size: 30)
                Text("\(ix.people.count) Gesichter · Stand \(ix.generated)")
                    .font(Theme.body(14, .semibold)).foregroundStyle(Theme.muted)

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

                Group {
                    if let t = game.targetParty {
                        Text("**Ja/Nein-Modus:** Gehört die Person **\(ix.party(t).zu ?? "zu " + ix.party(t).label)**? Nach rechts wischen = Ja, nach links = Nein.")
                    } else if game.chosen.count >= 2 {
                        Text("**Zuordnen:** \(game.chosen.count) Parteien, je \(max(2, Int((Double(Game.roundSize) / Double(game.chosen.count)).rounded()))) Gesichter pro Runde.")
                    } else {
                        Text("Wähle mindestens eine Partei.")
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))

                PrimaryButton(title: "Runde starten") { game.start() }
                    .disabled(game.chosen.isEmpty)
                    .opacity(game.chosen.isEmpty ? 0.35 : 1)

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
        }
    }
}

struct Credit: View {
    let person: Person
    /// Logo-Urheber nach der Auflösung, nur bei CC-lizenzierten Logos nötig
    var logo: GameIndex.Logo? = nil
    var body: some View {
        HStack(spacing: 4) {
            Text("Foto: \(person.artist) · \(person.license) ·")
            if let url = person.commonsURL { Link("Commons", destination: url) }
            if let logo, logo.license.hasPrefix("CC") { Text("· Logo: \(logo.artist ?? "unbekannt") · \(logo.license)") }
        }
        .font(Theme.body(11)).foregroundStyle(Theme.muted).lineLimit(2)
    }
}

struct RevealOverlay: View {
    @EnvironmentObject var game: Game
    let person: Person
    let correct: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(correct ? "Richtig" : "Daneben")
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
    @State private var answered: String?

    var body: some View {
        let ix = game.index
        if let p = game.current {
            VStack(spacing: 12) {
                RoundHeader()
                FaceView(person: p, index: ix)
                    .overlay { if answered != nil { RevealOverlay(person: p, correct: answered == p.party) } }
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .frame(maxHeight: 440)
                Text("Zu welcher Partei gehört diese Person?").font(Theme.display(15, .semibold)).multilineTextAlignment(.center)
                // Telefon: höchstens drei Kacheln pro Zeile, damit alle sichtbar bleiben; iPad: alle in einer Zeile
                let n = game.chosen.count
                let cols = sizeClass == .regular ? min(n, 6) : (n <= 3 ? n : (n == 4 ? 2 : 3))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: max(1, cols)), spacing: 8) {
                    ForEach(game.chosen, id: \.self) { key in
                        let pt = ix.party(key)
                        Button {
                            guard answered == nil else { return }
                            answered = key
                            game.answer(party: key)
                            Haptics.tap(key == p.party)
                        } label: {
                            HStack(spacing: 4) {
                                Text(pt.label).font(Theme.display(14)).lineLimit(2).minimumScaleFactor(0.6)
                                if answered != nil && key == p.party { Text("✓").font(Theme.display(14)) }
                                else if answered == key { Text("✕").font(Theme.display(14)) }
                            }
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .foregroundStyle(pt.textDark == true ? Color.black : .white)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: pt.color)))
                            .overlay(RoundedRectangle(cornerRadius: 17).stroke(borderColor(key, p), lineWidth: 3).padding(-5))
                            .opacity(answered == nil || key == answered || key == p.party ? 1 : 0.3)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if answered != nil {
                    PrimaryButton(title: game.position + 1 >= game.items.count ? "Auswertung ansehen" : "Nächstes Gesicht") {
                        answered = nil; game.advance()
                    }
                }
                Credit(person: p, logo: answered != nil ? ix.logo(for: p) : nil)
                Spacer(minLength: 0)
            }
            .padding()
        }
    }

    private func borderColor(_ key: String, _ p: Person) -> Color {
        guard answered != nil else { return .clear }
        if key == p.party { return Theme.yes }
        if key == answered { return Theme.no }
        return .clear
    }
}

// MARK: - Wischen (eine Partei, wie bei Tinder: rechts = Ja, links = Nein)

struct SwipeView: View {
    @EnvironmentObject var game: Game
    @State private var offset: CGSize = .zero
    @State private var feedback: (Person, Bool)?
    @State private var locked = false

    var body: some View {
        let ix = game.index
        let target = ix.party(game.targetParty ?? "")
        VStack(spacing: 14) {
            RoundHeader()
            (Text("Gehört diese Person ") + Text(target.zu ?? "zu \(target.label)").foregroundColor(target.key == "UNION" || target.textDark == true ? Theme.ink : Color(hex: target.color)) + Text("?"))
                .font(Theme.display(16, .semibold)).multilineTextAlignment(.center)
            ZStack {
                if game.position + 1 < game.items.count {
                    FaceView(person: game.items[game.position + 1], index: ix)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .scaleEffect(0.95).offset(y: 10).brightness(-0.08)
                }
                if let p = game.current {
                    FaceView(person: p, index: ix)
                        .overlay(alignment: .topLeading) { Stamp(text: "JA", color: Theme.yes, angle: -14).opacity(Double(offset.width / 90)).padding(20) }
                        .overlay(alignment: .topTrailing) { Stamp(text: "NEIN", color: Theme.no, angle: 14).opacity(Double(-offset.width / 90)).padding(20) }
                        .clipShape(RoundedRectangle(cornerRadius: 22))
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
                        .accessibilityAction(named: "Ja") { decide(true) }
                        .accessibilityAction(named: "Nein") { decide(false) }
                }
            }
            .frame(maxHeight: 480)
            if let p = game.current { Credit(person: p, logo: feedback.map { game.index.logo(for: $0.0) } ?? nil) }
            HStack(spacing: 36) {
                RoundButton(symbol: "xmark", color: Theme.no) { decide(false) }.accessibilityLabel("Nein, gehört nicht zu \(target.label)")
                RoundButton(symbol: "checkmark", color: Theme.yes) { decide(true) }.accessibilityLabel("Ja, gehört zu \(target.label)")
            }
            Group {
                if let (p, ok) = feedback {
                    PartyLogo(person: p, index: ix, width: 56, height: 34)
                    (Text(ok ? "Richtig: " : "Daneben: ").foregroundColor(ok ? Theme.yes : Theme.no).bold()
                     + Text(p.name).bold() + Text(", \(ix.partyLabel(p)) · \(p.whereLabel)"))
                } else {
                    Text("Nach rechts wischen = Ja · nach links = Nein").foregroundStyle(Theme.muted)
                }
            }
            .font(.subheadline).multilineTextAlignment(.center).frame(minHeight: 44)
            Spacer(minLength: 0)
        }
        .padding()
    }

    private func decide(_ yes: Bool) {
        guard !locked, let p = game.current else { return }
        locked = true
        let ok = (p.party == game.targetParty) == yes
        game.answer(yes: yes)
        Haptics.tap(ok)
        feedback = (p, ok)
        withAnimation(.easeOut(duration: 0.28)) { offset = CGSize(width: yes ? 700 : -700, height: offset.height + 60) }
        DispatchQueue.main.asyncAfter(deadline: .now() + (ok ? 0.9 : 1.6)) {
            offset = .zero
            feedback = nil
            locked = false
            game.advance()
        }
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
        let n = a.count, ok = game.correctCount
        let chance = game.targetParty != nil ? Double(n) / 2 : Double(n) / Double(max(1, game.chosen.count))
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(ok) von \(n)").font(Theme.display(44, .heavy)).kerning(-1.5)
                Text("Reiner Zufall läge bei etwa \(Int(chance.rounded())) von \(n).")
                Text("Gesamt bisher: \(game.totalCorrect) von \(game.totalAnswered)").foregroundStyle(Theme.muted)
                ForEach(insights(), id: \.self) { t in
                    Text(t).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                }
                if game.targetParty == nil { matrix }
                let wrong = a.filter { !$0.correct }
                if !wrong.isEmpty {
                    DisclosureGroup("Falsch eingeordnet (\(wrong.count))") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(wrong, id: \.person.id) { w in
                                Text("\(w.person.name) (\(ix.partyLabel(w.person)), \(w.person.whereLabel))").font(.footnote)
                            }
                        }
                    }
                }
                HStack {
                    PrimaryButton(title: "Neue Runde") { game.start() }
                    PrimaryButton(title: "Menü", secondary: true) { game.backToMenu() }
                }
            }
            .padding()
        }
        .toolbar(.hidden)
    }

    private func insights() -> [String] {
        let ix = game.index, a = game.answers
        if let t = game.targetParty {
            let label = ix.party(t).label
            let members = a.filter { $0.person.party == t }, others = a.filter { $0.person.party != t }
            let hit = members.filter { $0.saidYes == true }.count
            let fa = others.filter { $0.saidYes == true }
            var out = ["Von \(members.count) Personen aus der Partei \(label) hast du \(hit) erkannt."]
            if fa.isEmpty {
                out.append("Niemanden aus einer anderen Partei hast du fälschlich \(label) zugeordnet.")
            } else {
                let by = Dictionary(grouping: fa, by: { $0.person.party }).map { "\($0.value.count)× \(ix.party($0.key).label)" }
                out.append("\(fa.count) von \(others.count) Personen aus anderen Parteien hast du für \(label) gehalten: \(by.joined(separator: ", ")).")
            }
            return out
        }
        var out: [String] = []
        let per = a.filter { $0.person.party == game.chosen.first }.count
        let guesses = Dictionary(grouping: a, by: { $0.guess ?? "" }).mapValues(\.count)
        if let top = guesses.max(by: { $0.value < $1.value }), top.value > per + 1 {
            out.append("Du hast \(top.value)-mal \(ix.party(top.key).label) getippt, obwohl nur \(per) Personen dabei waren.")
        }
        let conf = Dictionary(grouping: a.filter { !$0.correct }, by: { "\($0.person.party)>\($0.guess ?? "")" })
            .sorted { $0.value.count > $1.value.count }.prefix(2)
        for (k, v) in conf {
            let parts = k.split(separator: ">").map(String.init)
            out.append("\(v.count) aus der Partei \(ix.party(parts[0]).label) hast du für \(ix.party(parts[1]).label) gehalten.")
        }
        return out.isEmpty ? ["Keine klare Schlagseite in dieser Runde."] : out
    }

    private var matrix: some View {
        let ix = game.index, keys = game.chosen
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
