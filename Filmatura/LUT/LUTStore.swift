import Foundation
import CoreImage
import UIKit

/// Carica e applica le LUT 3D del bundle con Core Image (CIColorCube).
/// Gestisce la cache dei dati del cubo e le miniature dei preset.
final class LUTStore {

    static let shared = LUTStore()

    private var dataCache: [String: CUBEParser.ParsedLUT] = [:]
    private var thumbnailCache: [String: UIImage] = [:]
    private let lock = NSLock()

    private init() {}

    // MARK: - Caricamento

    func parsedLUT(for presetID: String) -> CUBEParser.ParsedLUT? {
        lock.lock()
        if let cached = dataCache[presetID] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let url = Bundle.main.url(forResource: "lut_\(presetID)", withExtension: "cube") else {
            return nil
        }
        guard let parsed = try? CUBEParser.parse(contentsOf: url) else { return nil }

        lock.lock()
        dataCache[presetID] = parsed
        lock.unlock()
        return parsed
    }

    // MARK: - Applicazione

    /// Applica il preset con intensita' regolabile.
    /// intensity 0 = immagine originale, 1 = grading pieno.
    func apply(_ preset: LUTPreset?, intensity: Double, to image: CIImage) -> CIImage {
        guard let preset, intensity > 0.001,
              let lut = parsedLUT(for: preset.id) else { return image }

        let graded = image.applyingCube(lut.rgbaData, dimension: lut.dimension)
        let amount = CGFloat(max(0, min(1, intensity)))
        return image.blending(image: graded, amount: amount)
    }

    // MARK: - Miniature

    /// Miniatura del preset renderizzata sull'immagine campione del bundle.
    func thumbnail(for preset: LUTPreset) -> UIImage {
        lock.lock()
        if let cached = thumbnailCache[preset.id] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        var result = UIImage(systemName: "camera.aperture") ?? UIImage()
        if let sampleURL = Bundle.main.url(forResource: "sample", withExtension: "jpg"),
           let sample = CIImage(contentsOf: sampleURL) {
            let scaled = sample.transformed(
                by: CGAffineTransform(scaleX: 150 / sample.extent.width,
                                     y: 150 / sample.extent.width))
            let graded = apply(preset, intensity: 1.0, to: scaled)
            let context = CIContext(options: [.useSoftwareRenderer: false])
            if let cg = context.createCGImage(graded, from: graded.extent) {
                result = UIImage(cgImage: cg)
            }
        }
        lock.lock()
        thumbnailCache[preset.id] = result
        lock.unlock()
        return result
    }
}
