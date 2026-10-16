// Bereitet Porträtfotos für das Spiel auf (läuft lokal auf macOS mit Apples Vision-Framework):
//  1. größtes Gesicht finden; Fotos ohne erkennbares Gesicht werden verworfen
//  2. auf ein Hochformat 4:5 um das Gesicht zuschneiden
//  3. Person freistellen und den Hintergrund stark weichzeichnen,
//     damit Parteilogos, Plakate oder Farben im Hintergrund nichts verraten
//
// Aufruf: swiftc -O pipeline/portrait.swift -o pipeline/portrait
//         pipeline/portrait <eingabe-ordner> <ausgabe-ordner> [breite]
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

    // Zuschnitt: Gesicht nimmt ~42 % der Breite ein, Augenhöhe im oberen Drittel
    var cw = face.width / 0.42
    var ch = cw * 5 / 4
    if cw > ext.width { cw = ext.width; ch = cw * 5 / 4 }
    if ch > ext.height { ch = ext.height; cw = ch * 4 / 5 }
    var cx = face.midX - cw / 2
    var cy = face.midY - ch * 0.58   // Gesichtsmitte bei 58 % von unten
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
        // zusätzlich entsättigen und abdunkeln: Parteifarben im Hintergrund verlieren ihre Signalwirkung
        let muted = blurred.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.25, kCIInputBrightnessKey: -0.02, kCIInputContrastKey: 0.9])
        composed = src.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: muted, kCIInputMaskImageKey: mask])
    } else {
        return "keine Freistellung"
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
