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
                Text("\(ix.people.count) Gesichter · Stand \(ix.generated)")
                    .font(.footnote.monospaced()).foregroundStyle(.secondary)

                Text("Ebene").font(.headline)
                FlowLayout(spacing: 8) {
                    Chip(label: "Alle", detail: nil, color: nil, on: game.levels == game.allLevels, enabled: true) { game.toggleLevel(nil) }
                    ForEach(ix.levels) { l in
                        Chip(label: l.label, detail: "\(ix.parties.reduce(0) { $0 + ($1.counts[l.key] ?? 0) })", color: nil,
                             on: game.levels != game.allLevels && game.levels.contains(l.key), enabled: true) { game.toggleLevel(l.key) }
                    }
                }

                Text("Parteien").font(.headline)
                FlowLayout(spacing: 8) {
                    ForEach(ix.parties.filter { ix.count($0.key, levels: game.allLevels) > 0 }) { p in
                        Chip(label: p.label, detail: "\(ix.count(p.key, levels: game.levels))", color: Color(hex: p.color),
                             on: game.chosen.contains(p.key), enabled: elig.contains(p.key)) { game.toggleParty(p.key) }
                    }
                }
                Text("Parteien mit weniger als \(ix.minFaces) Gesichtern in der gewählten Ebene sind ausgegraut, damit jede Partei gleich oft vorkommt.")
                    .font(.footnote).foregroundStyle(.secondary)

                Group {
                    if let t = game.targetParty {
                        Text("**Ja/Nein-Modus:** Gehört die Person zu **\(ix.party(t).label)**? Nach rechts wischen = Ja, nach links = Nein.")
                    } else if game.chosen.count >= 2 {
                        Text("**Zuordnen:** \(game.chosen.count) Parteien, je \(max(2, Int((Double(Game.roundSize) / Double(game.chosen.count)).rounded()))) Gesichter pro Runde.")
                    } else {
                        Text("Wähle mindestens eine Partei.")
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.12)))

                Button { game.start() } label: {
                    Text("Runde starten").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent).tint(.primary)
                .disabled(game.chosen.isEmpty)

                Text("Fotos: Wikimedia Commons (freie Lizenzen, Urheber unter jedem Bild). Personen und Ämter: Wikidata und abgeordnetenwatch.de. Hintergründe sind weichgezeichnet.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Parteigesicht")
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
                Button("Menü") { game.backToMenu() }
                Spacer()
                Text("\(min(game.position + 1, game.items.count)) / \(game.items.count) · \(game.correctCount) richtig")
                    .font(.footnote.monospaced()).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(game.position), total: Double(max(1, game.items.count))).tint(.primary)
        }
    }
}

struct Credit: View {
    let person: Person
    var body: some View {
        HStack(spacing: 4) {
            Text("Foto: \(person.artist) · \(person.license) ·")
            if let url = person.commonsURL { Link("Commons", destination: url) }
        }
        .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
    }
}

struct RevealOverlay: View {
    @EnvironmentObject var game: Game
    let person: Person
    let correct: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(correct ? "Richtig" : "Daneben")
                .font(.caption.monospaced().bold()).foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 3).fill(correct ? Color.green.opacity(0.85) : Color.red.opacity(0.85)))
            Spacer()
            Text(person.name).font(.title2.bold())
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
    }
}

// MARK: - Zuordnen (mehrere Parteien)

struct ChoiceView: View {
    @EnvironmentObject var game: Game
    @State private var answered: String?

    var body: some View {
        let ix = game.index
        if let p = game.current {
            VStack(spacing: 12) {
                RoundHeader()
                FaceView(person: p, index: ix)
                    .overlay { if answered != nil { RevealOverlay(person: p, correct: answered == p.party) } }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(maxHeight: 440)
                Credit(person: p)
                Text("Zu welcher Partei gehört diese Person?").font(.headline)
                let cols = game.chosen.count <= 5 ? game.chosen.count : (game.chosen.count + 1) / 2
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: max(1, cols)), spacing: 8) {
                    ForEach(game.chosen, id: \.self) { key in
                        let pt = ix.party(key)
                        Button {
                            guard answered == nil else { return }
                            answered = key
                            game.answer(party: key)
                            Haptics.tap(key == p.party)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: answered == key ? "xmark.circle" : "circle").font(.title3)
                                Text(pt.label).font(.subheadline.bold()).lineLimit(2).minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .foregroundStyle(pt.textDark == true ? Color.black : .white)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: pt.color)))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor(key, p), lineWidth: 3).padding(-4))
                            .opacity(answered == nil || key == answered || key == p.party ? 1 : 0.3)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if answered != nil {
                    Button { answered = nil; game.advance() } label: {
                        Text(game.position + 1 >= game.items.count ? "Auswertung ansehen" : "Nächstes Gesicht")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent).tint(.primary)
                }
                Spacer(minLength: 0)
            }
            .padding()
        }
    }

    private func borderColor(_ key: String, _ p: Person) -> Color {
        guard answered != nil else { return .clear }
        if key == p.party { return .green }
        if key == answered { return .red }
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
            (Text("Gehört diese Person zu ") + Text(target.label).bold() + Text("?")).font(.headline)
            ZStack {
                if game.position + 1 < game.items.count {
                    FaceView(person: game.items[game.position + 1], index: ix)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .scaleEffect(0.95).offset(y: 10).brightness(-0.08)
                }
                if let p = game.current {
                    FaceView(person: p, index: ix)
                        .overlay(alignment: .topLeading) { Stamp(text: "JA", color: .green, angle: -14).opacity(Double(offset.width / 90)).padding(20) }
                        .overlay(alignment: .topTrailing) { Stamp(text: "NEIN", color: .red, angle: 14).opacity(Double(-offset.width / 90)).padding(20) }
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
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
            if let p = game.current { Credit(person: p) }
            HStack(spacing: 36) {
                RoundButton(symbol: "xmark", color: .red) { decide(false) }.accessibilityLabel("Nein, gehört nicht zu \(target.label)")
                RoundButton(symbol: "checkmark", color: .green) { decide(true) }.accessibilityLabel("Ja, gehört zu \(target.label)")
            }
            Group {
                if let (p, ok) = feedback {
                    (Text(ok ? "Richtig: " : "Daneben: ").foregroundColor(ok ? .green : .red).bold()
                     + Text(p.name).bold() + Text(", \(ix.partyLabel(p)) · \(p.whereLabel)"))
                } else {
                    Text("Nach rechts wischen = Ja · nach links = Nein").foregroundStyle(.secondary)
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
        Text(text).font(.system(size: 30, weight: .heavy)).foregroundStyle(color)
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
                .background(Circle().fill(.background).shadow(color: .black.opacity(0.15), radius: 8, y: 3))
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
                Text("\(ok) von \(n)").font(.system(size: 44, weight: .heavy))
                Text("Reiner Zufall läge bei etwa \(Int(chance.rounded())) von \(n).")
                Text("Gesamt bisher: \(game.totalCorrect) von \(game.totalAnswered)").foregroundStyle(.secondary)
                ForEach(insights(), id: \.self) { t in
                    Text(t).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.12)))
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
                    Button { game.start() } label: { Text("Neue Runde").frame(maxWidth: .infinity).padding(.vertical, 6) }
                        .buttonStyle(.borderedProminent).tint(.primary)
                    Button { game.backToMenu() } label: { Text("Menü").frame(maxWidth: .infinity).padding(.vertical, 6) }
                        .buttonStyle(.bordered).tint(.primary)
                }
            }
            .padding()
        }
        .navigationTitle("Auswertung")
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
        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
    }
}

enum Haptics {
    static func tap(_ ok: Bool) {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(ok ? .success : .error)
        #endif
    }
}
