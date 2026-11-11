import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Estensioni Core Image condivise da fotocamera, editor e modulo volto.
extension CIImage {

    /// Applica i dati RGBA Float32 di una LUT 3D via CIColorCube.
    /// Nota: il parser genera i dati nello stesso ordine dei file .cube
    /// (rosso piu' veloce). Se su un dispositivo futuro i colori risultassero
    /// invertiti, vedi README (troubleshooting).
    func applyingCube(_ data: Data, dimension: Int) -> CIImage {
        let filter = CIFilter.colorCube()
        filter.inputImage = self
        filter.cubeDimension = Float(dimension)
        filter.cubeData = data
        return filter.outputImage ?? self
    }

    /// Fusione controllata tra questa immagine (base) e una versione lavorata:
    /// amount 0 -> base, 1 -> versione lavorata.
    func blending(image: CIImage, amount: CGFloat) -> CIImage {
        guard amount < 0.999 else { return image }

        let fade = CIFilter.colorMatrix()
        fade.inputImage = image
        fade.aVector = CIVector(x: 0, y: 0, z: 0, w: amount)
        let faded = fade.outputImage ?? image

        let over = CIFilter.sourceOverCompositing()
        over.inputImage = faded
        over.backgroundImage = self
        return over.outputImage ?? self
    }

    /// Grain pellicola (rumore in soft-light).
    func addingGrain(amount: Double) -> CIImage {
        guard amount > 0.01 else { return self }
        let scaledAmount = CGFloat(amount * 0.45)

        let random = CIFilter.randomGenerator()
        let noise = random.outputImage!.transformed(
            by: CGAffineTransform(translationX: extent.origin.x,
                                  y: extent.origin.y))

        let mono = CIFilter.colorControls()
        mono.inputImage = noise
        mono.saturation = 0.0
        mono.contrast = 0.6
        mono.brightness = 0.0

        let soft = CIFilter.softLightBlendMode()
        soft.inputImage = mono.outputImage!.cropped(to: extent)
        soft.backgroundImage = self
        soft.setValue(Float(scaledAmount), forKey: "inputIntensity")
        return soft.outputImage ?? self
    }

    /// Vignetta cinematografica.
    func addingVignette(amount: Double) -> CIImage {
        guard amount > 0.01 else { return self }
        let radius = CGFloat(max(extent.width, extent.height) * 0.75)
        let vignette = CIFilter.vignette()
        vignette.inputImage = self
        vignette.radius = Float(radius)
        vignette.intensity = Float(amount * 1.6)
        return vignette.outputImage ?? self
    }

    /// Sfocatura gaussiana protetta dai bordi (evita bordi trasparenti).
    func blurred(radius: Double) -> CIImage {
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = self.clampedToExtent()
        blur.radius = Float(radius)
        let result = blur.outputImage!
        return result.cropped(to: extent)
    }

    /// Render in UIImage con dimensione massima.
    func rendered(maxDimension: CGFloat = 2048,
                  context: CIContext = ImagePipeline.sharedContext) -> UIImage {
        let scale = min(1, maxDimension / max(extent.width, extent.height))
        let target = scale < 1
            ? transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            : self
        guard let cg = context.createCGImage(target, from: target.extent) else {
            return UIImage()
        }
        return UIImage(cgImage: cg)
    }
}

/// Contesto e utility per l'elaborazione delle foto a piena risoluzione.
enum ImagePipeline {

    static let sharedContext: CIContext = {
        CIContext(options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any,
            .cacheIntermediates: false,
        ])
    }()

    /// Pipeline editor completo: LUT + intensita', grain, vignetta.
    static func process(image: CIImage,
                        preset: LUTPreset?,
                        intensity: Double,
                        grain: Double,
                        vignette: Double,
                        store: LUTStore = .shared) -> CIImage {
        var result = store.apply(preset, intensity: intensity, to: image)
        result = result.addingGrain(amount: grain)
        result = result.addingVignette(amount: vignette)
        return result
    }

    /// Applica solo LUT + intensita' (pipeline video/foto scattate).
    static func graded(image: CIImage,
                       preset: LUTPreset?,
                       intensity: Double,
                       store: LUTStore = .shared) -> CIImage {
        store.apply(preset, intensity: intensity, to: image)
    }
}
