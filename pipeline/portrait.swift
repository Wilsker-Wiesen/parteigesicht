// Bereitet Porträtfotos für das Spiel auf (läuft lokal auf macOS mit Apples Vision-Framework):
//  1. größtes Gesicht finden; Fotos ohne erkennbares Gesicht werden verworfen
//  2. auf ein Hochformat 4:5 um das Gesicht zuschneiden
//  3. Person freistellen und den Hintergrund stark weichzeichnen,
//     damit Parteilogos, Plakate oder Farben im Hintergrund nichts verraten
//
// Aufruf: swiftc -O pipeline/portrait.swift -o pipeline/portrait
//         pipeline/portrait <eingabe-ordner> <ausgabe-ordner> [breite] [zuschnitt]
// Zuschnitt: "gesicht" (Standard) zeigt nur den Kopf in einem weichen Oval, Schultern, Kragen,
// Anstecknadeln und Kleidung verschwinden im neutralen Grund; "oval-weit" ist etwas großzügiger,
// "voll" füllt das Bild vom Kinn bis zum Haaransatz; "brustbild" ist der frühere Zuschnitt mit Schultern.
// Ausgabe: <id>.jpg pro Foto und report.json mit Fehlern/Ausschlüssen.

import AppKit
import CoreImage
import Foundation
import Vision

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("Aufruf: portrait <eingabe> <ausgabe> [breite]")
    exit(1)
}
let inDir = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
let outW = args.count > 3 ? Int(args[3]) ?? 360 : 360
let outH = outW * 5 / 4
let mode = args.count > 4 ? args[4] : "gesicht"
// neutraler Grund außerhalb des Ovals (hell, wie die Karten der App)
let neutral = CIImage(color: CIColor(red: 0.86, green: 0.87, blue: 0.89)).cropped(to: CGRect(x: -1e5, y: -1e5, width: 2e5, height: 2e5))
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let ctx = CIContext(options: [.useSoftwareRenderer: false])
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func process(_ url: URL) -> String? {
    guard let src = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else { return "unlesbar" }
    let ext = src.extent
    let handler = VNImageRequestHandler(ciImage: src, options: [:])
    let faceReq = VNDetectFaceRectanglesRequest()
    let segReq = VNGeneratePersonSegmentationRequest()
    segReq.qualityLevel = .accurate
    segReq.outputPixelFormat = kCVPixelFormatType_OneComponent8
    do { try handler.perform([faceReq, segReq]) } catch { return "vision: \(error.localizedDescription)" }

    guard let faces = faceReq.results, !faces.isEmpty else { return "kein Gesicht" }
    // Gruppenfotos sind ungeeignet: zweites Gesicht fast so groß wie das erste
    let sorted = faces.sorted { $0.boundingBox.width > $1.boundingBox.width }
    if sorted.count > 1 && sorted[1].boundingBox.width > sorted[0].boundingBox.width * 0.6 { return "mehrere Gesichter" }
    let fb = sorted[0].boundingBox  // normiert, Ursprung unten links
    let face = CGRect(x: ext.minX + fb.minX * ext.width, y: ext.minY + fb.minY * ext.height,
                      width: fb.width * ext.width, height: fb.height * ext.height)
    if face.width < 48 { return "Gesicht zu klein" }

    // Zuschnitt. Vision umrahmt das Gesicht etwa von den Augenbrauen bis zum Kinn; der Kopf
    // (mit Haaren) reicht vom Kinn bis rund 0,5 Gesichtshöhen über den Rahmen.
    let headMid = face.minY + face.height * 0.72   // Mitte zwischen Kinn und Scheitel
    var cw: CGFloat, centerY: CGFloat
    switch mode {
    case "brustbild": cw = face.width / 0.42; centerY = face.midY - cw * 5 / 4 * 0.08
    case "oval-weit": cw = face.width * 1.85; centerY = headMid
    case "voll":      cw = face.width * 1.22; centerY = face.minY + face.height * 0.66   // Kinn bis Haaransatz, füllt das Bild
    default:          cw = face.width * 1.55; centerY = headMid   // gesicht
    }
    var ch = cw * 5 / 4
    if cw > ext.width { cw = ext.width; ch = cw * 5 / 4 }
    if ch > ext.height { ch = ext.height; cw = ch * 4 / 5 }
    var cx = face.midX - cw / 2
    var cy = centerY - ch / 2
    cx = min(max(cx, ext.minX), ext.maxX - cw)
    cy = min(max(cy, ext.minY), ext.maxY - ch)
    let crop = CGRect(x: cx, y: cy, width: cw, height: ch)

    var composed = src
    if let maskBuf = segReq.results?.first?.pixelBuffer {
        var mask = CIImage(cvPixelBuffer: maskBuf)
        mask = mask.transformed(by: CGAffineTransform(scaleX: ext.width / mask.extent.width,
                                                      y: ext.height / mask.extent.height))
            .transformed(by: CGAffineTransform(translationX: ext.minX, y: ext.minY))
        // weiche Kante, damit Haare nicht ausgefranst wirken
        mask = mask.clampedToExtent().applyingGaussianBlur(sigma: max(2, cw / 220)).cropped(to: ext)
        let radius = max(12, cw / 22)
        let blurred = src.clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: ext)
        // zusätzlich ganz entsättigen: Bühnen- und Parteifarben im Hintergrund verlieren ihre Signalwirkung
        let muted = blurred.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0, kCIInputBrightnessKey: -0.02, kCIInputContrastKey: 0.9])
        composed = src.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: muted, kCIInputMaskImageKey: mask])
    } else {
        return "keine Freistellung"
    }

    // Oval um den Kopf: außerhalb weich in den neutralen Grund überblenden
    if mode == "gesicht" || mode == "oval-weit" {
        let rx = face.width * (mode == "oval-weit" ? 0.76 : 0.67)
        let ry = face.height * (mode == "oval-weit" ? 0.98 : 0.9)
        let center = CGPoint(x: face.midX, y: face.minY + face.height * 0.77)
        // kreisförmiger Verlauf, danach zum Oval gestreckt
        var oval = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(x: 0, y: 0), "inputRadius0": rx * 0.86, "inputRadius1": rx * 1.0,
            "inputColor0": CIColor.white, "inputColor1": CIColor.black])!.outputImage!
        oval = oval.transformed(by: CGAffineTransform(scaleX: 1, y: ry / rx))
            .transformed(by: CGAffineTransform(translationX: center.x, y: center.y))
        composed = composed.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: neutral, kCIInputMaskImageKey: oval])
    }

    let scale = CGFloat(outW) / crop.width
    let out = composed.cropped(to: crop)
        .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
        .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        .cropped(to: CGRect(x: 0, y: 0, width: outW, height: outH))
    let dest = outDir.appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".jpg")
    do {
        try ctx.writeJPEGRepresentation(of: out, to: dest, colorSpace: colorSpace,
                                        options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.62])
    } catch { return "schreiben: \(error.localizedDescription)" }
    if crop.width < CGFloat(outW) * 0.6 { return "ok-unscharf" }
    return nil
}

let files = (try? FileManager.default.contentsOfDirectory(at: inDir, includingPropertiesForKeys: nil)) ?? []
var report: [String: String] = [:]
let lock = NSLock()
let todo = files.filter { f in
    let dest = outDir.appendingPathComponent(f.deletingPathExtension().lastPathComponent + ".jpg")
    return !f.lastPathComponent.hasPrefix(".") && !FileManager.default.fileExists(atPath: dest.path)
}
// Begrenzte Parallelität: Vision nutzt selbst Threads, zu viele gleichzeitige Anfragen blockieren sich.
let queue = OperationQueue()
queue.maxConcurrentOperationCount = 4
for f in todo {
    queue.addOperation {
        autoreleasepool {
            let r = process(f)
            lock.lock()
            report[f.deletingPathExtension().lastPathComponent] = r ?? "ok"
            if report.count % 250 == 0 { print("\(report.count)/\(todo.count)"); fflush(stdout) }
            lock.unlock()
        }
    }
}
queue.waitUntilAllOperationsAreFinished()
// Bestehenden Bericht fortschreiben
let reportURL = outDir.appendingPathComponent("report.json")
var merged: [String: String] = [:]
if let d = try? Data(contentsOf: reportURL), let old = try? JSONSerialization.jsonObject(with: d) as? [String: String] { merged = old }
merged.merge(report) { _, new in new }
let data = try JSONSerialization.data(withJSONObject: merged, options: [.sortedKeys, .prettyPrinted])
try data.write(to: reportURL)
let counts = Dictionary(grouping: report.values, by: { $0 }).mapValues(\.count)
print("Fertig:", counts)
