import SwiftUI

@main
struct ParteigesichtApp: App {
    private let index: GameIndex? = try? GameIndex.loadFromBundle()

    var body: some Scene {
        WindowGroup {
            if let index {
                RootView(game: Game(index: index))
            } else {
                Text("Spieldaten fehlen. Bitte zuerst `python3 pipeline/build.py` ausführen und das Projekt neu bauen.")
                    .padding()
            }
        }
    }
}
