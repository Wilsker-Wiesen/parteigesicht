import SwiftUI

@main
struct ParteigesichtApp: App {
    private let index: GameIndex? = try? GameIndex.loadFromBundle()

    init() { Theme.registerFonts() }

    var body: some Scene {
        WindowGroup {
            if let index {
                RootView(game: Game(index: index))
                    .font(Theme.body(17))
                    .tint(Theme.ink)
            } else {
                Text("Spieldaten fehlen. Bitte zuerst `python3 pipeline/build.py` ausführen und das Projekt neu bauen.")
                    .padding()
            }
        }
    }
}
