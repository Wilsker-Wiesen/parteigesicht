// Setzt mehrere Porträts zu einem Bildbogen (Sprite-Sheet) zusammen.
// Das spart Dateien und Anfragen: Web-App und iOS-App laden pro Partei einen Bogen
// statt einzelner Fotos.
//
// Aufruf: swiftc -O pipeline/sprites.swift -o pipeline/sprites
//         pipeline/sprites <manifest.json>
// manifest.json: {"cellW": 288, "cellH": 360, "cols": 5, "quality": 0.55,
//                 "sheets": [{"out": "pfad.jpg", "cells": ["a.jpg", "b.jpg", ...]}]}

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Sheet: Decodable { let out: String; let cells: [String] }
struct Manifest: Decodable { let cellW: Int; let cellH: Int; let cols: Int; let quality: Double; let sheets: [Sheet] }

let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let cs = CGColorSpace(name: CGColorSpace.sRGB)!

DispatchQueue.concurrentPerform(iterations: manifest.sheets.count) { i in
    autoreleasepool {
        let sheet = manifest.sheets[i]
        let rows = (sheet.cells.count + manifest.cols - 1) / manifest.cols
        let w = manifest.cellW * manifest.cols, h = manifest.cellH * rows
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return }
        ctx.setFillColor(CGColor(gray: 0.5, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.interpolationQuality = .high
        for (j, path) in sheet.cells.enumerated() {
            guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
                  let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { continue }
            let col = j % manifest.cols, row = j / manifest.cols
            // CoreGraphics zählt von unten; Zeile 0 soll oben liegen
            let rect = CGRect(x: col * manifest.cellW, y: h - (row + 1) * manifest.cellH, width: manifest.cellW, height: manifest.cellH)
            ctx.draw(img, in: rect)
        }
        guard let out = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: sheet.out) as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(dest, out, [kCGImageDestinationLossyCompressionQuality: manifest.quality] as CFDictionary)
        CGImageDestinationFinalize(dest)
    }
}
print("\(manifest.sheets.count) Bögen geschrieben")
