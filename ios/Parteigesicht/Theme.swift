import CoreText
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Design „Spektrum“: ruhiger Grund, Unbounded für Überschriften, Figtree für Text.
/// Farbe kommt nur von den Parteien.
enum Theme {
    static let paper = Color.adaptive(light: 0xEEF0F4, dark: 0x111318)
    static let card = Color.adaptive(light: 0xFFFFFF, dark: 0x1D2028)
    static let ink = Color.adaptive(light: 0x111318, dark: 0xF2F3F5)
    static let muted = Color.adaptive(light: 0x5B606B, dark: 0x9EA4B0)
    static let rule = Color.adaptive(light: 0xD5D9E1, dark: 0x333844)
    static let yes = Color(hex: "#1fb85c")
    static let no = Color(hex: "#ff4d5e")

    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .custom("Unbounded", size: size).weight(weight)
    }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Figtree", size: size).weight(weight)
    }

    /// Schriften aus dem App-Bundle registrieren (beim Start einmal aufrufen).
    static func registerFonts() {
        for name in ["Unbounded", "Figtree"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}

extension Color {
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        #if os(iOS)
        return Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light) })
        #else
        return Color(rgb: light)
        #endif
    }

    init(rgb: UInt32) {
        self.init(red: Double((rgb >> 16) & 0xff) / 255, green: Double((rgb >> 8) & 0xff) / 255, blue: Double(rgb & 0xff) / 255)
    }
}

#if os(iOS)
extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255, green: CGFloat((rgb >> 8) & 0xff) / 255, blue: CGFloat(rgb & 0xff) / 255, alpha: 1)
    }
}
#endif

/// Schriftzug „parteigesicht“ mit dem Balken aus gleich breiten Parteifarben.
struct Wordmark: View {
    let index: GameIndex
    var size: CGFloat = 26
    var body: some View {
        VStack(alignment: .leading, spacing: size * 0.3) {
            Text("parteigesicht").font(Theme.display(size, .heavy)).kerning(-size * 0.035)
            SpectrumBar(index: index).frame(height: max(4, size * 0.22))
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Parteigesicht")
    }
}

struct SpectrumBar: View {
    let index: GameIndex
    var body: some View {
        HStack(spacing: 4) {
            ForEach(["GRUENE", "SPD", "UNION", "AFD", "LINKE", "FDP"], id: \.self) { k in
                if let p = index.parties.first(where: { $0.key == k }) {
                    Capsule().fill(Color(hex: p.color))
                }
            }
        }
    }
}
