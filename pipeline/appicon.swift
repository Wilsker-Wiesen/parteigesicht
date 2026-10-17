// Zeichnet das App-Symbol „Spektrum-Kopf“ als PNG (ohne abgerundete Ecken, die setzt iOS selbst).
//
// Kopf und Schultern aus sieben gleich breiten Streifen, von links nach rechts:
// Linke, Grüne, SPD, FDP, Union, BSW, AfD. Der Kopf ist so groß, dass Grün noch im Kopf
// zu sehen ist, das AfD-Blau ganz rechts aber nur in den Schultern liegt.
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
// Offizielle Parteifarben (Wikidata P465, FDP: Logo 2026; siehe pipeline/colors.py)
let stripes: [UInt32] = [0xBE3075, 0x409A3C, 0xE3000F, 0x032D67, 0x000000, 0x792351, 0x009EE0]  // Linke, Grüne, SPD, FDP, Union, BSW, AfD

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Koordinaten wie im SVG-Entwurf: Ursprung oben links
ctx.translateBy(x: 0, y: CGFloat(size)); ctx.scaleBy(x: s, y: -s)

ctx.setFillColor(background); ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))

// Kopf und Schultern als Maske
let bust = CGMutablePath()
// Kopf: x 30 bis 70; die Streifen sind je 58/7 ≈ 8,3 breit, Grün reicht bis 37,6, Blau beginnt bei 70,7
bust.addEllipse(in: CGRect(x: 30, y: 17, width: 40, height: 40))
bust.move(to: CGPoint(x: 21, y: 90))
bust.addCurve(to: CGPoint(x: 50, y: 60), control1: CGPoint(x: 21, y: 68), control2: CGPoint(x: 33, y: 60))
bust.addCurve(to: CGPoint(x: 79, y: 90), control1: CGPoint(x: 67, y: 60), control2: CGPoint(x: 79, y: 68))
bust.closeSubpath()
ctx.addPath(bust); ctx.clip()

let x0: CGFloat = 21, w: CGFloat = 58 / CGFloat(stripes.count)
for (i, c) in stripes.enumerated() {
    ctx.setFillColor(rgb(c))
    ctx.fill(CGRect(x: x0 + CGFloat(i) * w, y: 0, width: w + 0.05, height: 100))
}

let img = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("App-Symbol geschrieben: \(out) (\(size) px)")
