import CoreGraphics
import Foundation
import ImageIO
import SwiftUI

/// Lädt Bildbögen aus dem App-Bundle und schneidet einzelne Gesichter heraus.
final class SheetCache: @unchecked Sendable {
    static let shared = SheetCache()
    private var sheets: [Int: CGImage] = [:]
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "sheets", qos: .userInitiated)

    private func sheet(_ i: Int, index: GameIndex) -> CGImage? {
        lock.lock(); defer { lock.unlock() }
        if let s = sheets[i] { return s }
        let name = index.sheets[i].file  // "sheets/xyz.jpg"
        guard let url = Bundle.main.url(forResource: "data/" + name, withExtension: nil),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { return nil }
        if sheets.count > 24 { sheets.removeAll() }  // Speicher begrenzen
        sheets[i] = img
        return img
    }

    func face(_ p: Person, index: GameIndex) -> CGImage? {
        guard let s = sheet(p.sheet, index: index) else { return nil }
        let c = index.cell
        let rect = CGRect(x: (p.cell % c.cols) * c.w, y: (p.cell / c.cols) * c.h, width: c.w, height: c.h)
        return s.cropping(to: rect)
    }

    func preload(_ ids: [Int], index: GameIndex) {
        queue.async { for i in Set(ids) { _ = self.sheet(i, index: index) } }
    }
}

/// Zeigt das Gesicht einer Person (füllt den verfügbaren Platz im Format 4:5).
struct FaceView: View {
    let person: Person
    let index: GameIndex
    @State private var image: CGImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color.gray.opacity(0.25))
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ProgressView()
            }
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        .clipped()
        .task(id: person.id) {
            let p = person, ix = index
            image = await Task.detached { SheetCache.shared.face(p, index: ix) }.value
        }
        .accessibilityLabel("Porträtfoto")
    }
}
