// Zeichnet das App-Symbol „Mosaik-Kopf“ als PNG (ohne abgerundete Ecken, die setzt iOS selbst).
//
// Kopf und Schultern aus kleinen Kacheln. Jede Spalte gehört einer Partei, von links nach rechts:
// Linke, Grüne, SPD, FDP, Union, BSW, AfD. Die FDP hat zwei Spalten, alle anderen drei
// (Entscheidung nach der Symbol-Runde vom 17.10.2026). Grün liegt noch im Kopf, das
// AfD-Blau ganz rechts und die Linke ganz links nur in den Schultern.
//
// Aufruf: swiftc -O pipeline/appicon.swift -o pipeline/appicon
//         pipeline/appicon <ausgabe.png> [größe]   (Standard 1024)

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let out = CommandLine.arguments[1]
let size = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2]) ?? 1024 : 1024
let s = CGFloat(size) / 100  // Entwurf im Raster 100 × 100

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
}

let background = rgb(0xEEF0F4)
// Offizielle Parteifarben (Wikidata P465, FDP: Gelb von fdp.de; siehe pipeline/colors.py) und Spaltenzahl je Partei
let parties: [(color: UInt32, columns: Int)] = [
    (0xBE3075, 3),  // Linke
    (0x409A3C, 3),  // Grüne
    (0xE3000F, 3),  // SPD
    (0xFFE000, 2),  // FDP
    (0x000000, 3),  // Union
    (0x792351, 3),  // BSW
    (0x009EE0, 3),  // AfD
]
let columnColors = parties.flatMap { Array(repeating: $0.color, count: $0.columns) }

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Koordinaten wie im SVG-Entwurf: Ursprung oben links
ctx.translateBy(x: 0, y: CGFloat(size)); ctx.scaleBy(x: s, y: -s)
ctx.setFillColor(background); ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))

// Umriss: Kopf und Schultern (wie Entwurf M2)
let bust = CGMutablePath()
bust.addEllipse(in: CGRect(x: 29, y: 15, width: 42, height: 42))
bust.move(to: CGPoint(x: 19, y: 94))
// Schultern beginnen eine Kachelreihe unter dem Kopf, damit kein „Hals“ aus Kacheln entsteht
bust.addCurve(to: CGPoint(x: 50, y: 62.5), control1: CGPoint(x: 19, y: 70), control2: CGPoint(x: 32, y: 62.5))
bust.addCurve(to: CGPoint(x: 81, y: 94), control1: CGPoint(x: 68, y: 62.5), control2: CGPoint(x: 81, y: 70))
bust.closeSubpath()

// Kachelraster: eine Kachel wird gesetzt, wenn ihr Mittelpunkt im Umriss liegt
let x0: CGFloat = 14, x1: CGFloat = 86, y0: CGFloat = 8, y1: CGFloat = 96
let cell = (x1 - x0) / CGFloat(columnColors.count)
let gap = cell * 0.1, tile = cell - 2 * gap
let rows = Int((y1 - y0) / cell)
for r in 0..<rows {
    for (c, color) in columnColors.enumerated() {
        let x = x0 + CGFloat(c) * cell, y = y0 + CGFloat(r) * cell
        guard bust.contains(CGPoint(x: x + cell / 2, y: y + cell / 2)) else { continue }
        ctx.setFillColor(rgb(color))
        ctx.addPath(CGPath(roundedRect: CGRect(x: x + gap, y: y + gap, width: tile, height: tile),
                           cornerWidth: tile * 0.12, cornerHeight: tile * 0.12, transform: nil))
        ctx.fillPath()
    }
}

let img = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("App-Symbol geschrieben: \(out) (\(size) px)")
