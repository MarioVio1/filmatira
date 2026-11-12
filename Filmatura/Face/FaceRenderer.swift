import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Sfumature di trucco (colori sRGB 0–1).
enum MakeupShade: String, CaseIterable, Equatable, Identifiable {
    case naturale = "Naturale"
    case caldo = "Caldo"
    case freddo = "Freddo"
    case abbronzzato = "Abbronzzato"
    case rosa = "Rosa"
    case pesca = "Pesca"
    case corallo = "Corallo"
    case malva = "Malva"
    case sabbia = "Sabbia"
    case rame = "Rame"
    case fumo = "Fumo"
    case viola = "Viola"
    case nero = "Nero"
    case marrone = "Marrone"
    case grigioFumo = "Grigio fumo"
    case bluNotte = "Blu notte"
    case nude = "Nude"
    case rosso = "Rosso"

    var id: String { rawValue }

    var rgb: (Double, Double, Double) {
        switch self {
        case .naturale: return (0.93, 0.83, 0.72)
        case .caldo: return (0.91, 0.78, 0.62)
        case .freddo: return (0.90, 0.82, 0.76)
        case .abbronzzato: return (0.80, 0.63, 0.48)
        case .rosa: return (0.94, 0.62, 0.66)
        case .pesca: return (0.96, 0.70, 0.60)
        case .corallo: return (0.95, 0.55, 0.52)
        case .malva: return (0.78, 0.52, 0.62)
        case .sabbia: return (0.82, 0.72, 0.58)
        case .rame: return (0.72, 0.45, 0.30)
        case .fumo: return (0.45, 0.42, 0.45)
        case .viola: return (0.52, 0.42, 0.62)
        case .nero: return (0.08, 0.07, 0.08)
        case .marrone: return (0.32, 0.20, 0.12)
        case .grigioFumo: return (0.25, 0.25, 0.28)
        case .bluNotte: return (0.15, 0.20, 0.35)
        case .nude: return (0.76, 0.50, 0.48)
        case .rosso: return (0.72, 0.15, 0.18)
        }
    }

    static let foundationShades: [MakeupShade] = [.naturale, .caldo, .freddo, .abbronzzato]
    static let blushShades: [MakeupShade] = [.rosa, .pesca, .corallo, .malva]
    static let eyeshadowShades: [MakeupShade] = [.sabbia, .rame, .fumo, .viola]
    static let eyelinerShades: [MakeupShade] = [.nero, .marrone, .grigioFumo, .bluNotte]
    static let lipstickShades: [MakeupShade] = [.nude, .rosso, .corallo, .malva, .rosa]
}

/// Strumenti di editing volto, tutti originali (Vision + CoreImage).
struct FaceEditControls: Equatable {
    var skinSmooth: Double = 0        // pelle liscia
    var underEye: Double = 0          // occhiaie attenuate
    var eyeBrightness: Double = 0     // occhi piu' luminosi
    var eyeEnlarge: Double = 0        // occhi piu' grandi (warp locale)
    var teethWhitening: Double = 0    // denti piu' bianchi
    var cheekSculpt: Double = 0       // pomelli scolpiti (pinch)
    var jawSculpt: Double = 0         // mandibola definita (pinch)
    var faceSlim: Double = 0          // viso snello (pinch laterale)
    var lipVibrance: Double = 0       // labbra piu' vive
    var skinGlow: Double = 0          // glow viso
    var portraitLight: Double = 0     // luce ritratto
    var backgroundBlur: Double = 0    // sfondo sfocato

    // Trucco
    var foundation: Double = 0        // cipria uniformante
    var foundationShade: MakeupShade = .naturale
    var contour: Double = 0           // contouring
    var blush: Double = 0
    var blushShade: MakeupShade = .pesca
    var eyeshadow: Double = 0
    var eyeshadowShade: MakeupShade = .sabbia
    var eyeliner: Double = 0
    var eyelinerShade: MakeupShade = .nero
    var lipstick: Double = 0
    var lipstickShade: MakeupShade = .nude

    var eraLook: EraLook = .none
    var targetFaceID: UUID? = nil     // nil = tutti i volti

    var isNeutral: Bool {
        skinSmooth == 0 && underEye == 0 && eyeBrightness == 0 &&
        eyeEnlarge == 0 && teethWhitening == 0 && cheekSculpt == 0 &&
        jawSculpt == 0 && faceSlim == 0 && lipVibrance == 0 &&
        skinGlow == 0 && portraitLight == 0 && backgroundBlur == 0 &&
        eraLook == .none && foundation == 0 && contour == 0 && blush == 0 &&
        eyeshadow == 0 && eyeliner == 0 && lipstick == 0
    }

    /// Preset «Fai bello»: ritocco completo + trucco leggero.
    static func beautyPreset() -> FaceEditControls {
        var c = FaceEditControls()
        c.skinSmooth = 0.55
        c.underEye = 0.40
        c.eyeBrightness = 0.45
        c.eyeEnlarge = 0.15
        c.teethWhitening = 0.50
        c.cheekSculpt = 0.25
        c.jawSculpt = 0.20
        c.faceSlim = 0.18
        c.lipVibrance = 0.35
        c.skinGlow = 0.30
        c.portraitLight = 0.50
        c.backgroundBlur = 0.35
        c.foundation = 0.40
        c.contour = 0.18
        c.blush = 0.30
        c.eyeshadow = 0.20
        c.eyeliner = 0.35
        c.lipstick = 0.30
        return c
    }

    /// Preset «Naturale»: solo lucido, nessun warp e nessun trucco.
    static func naturalePreset() -> FaceEditControls {
        var c = FaceEditControls()
        c.skinSmooth = 0.35
        c.underEye = 0.40
        c.eyeBrightness = 0.20
        c.teethWhitening = 0.30
        c.skinGlow = 0.25
        c.portraitLight = 0.25
        return c
    }

    /// Preset «Glam»: ritocco forte, occhi grandi, trucco serata.
    static func glamPreset() -> FaceEditControls {
        var c = FaceEditControls()
        c.skinSmooth = 0.60
        c.underEye = 0.45
        c.eyeBrightness = 0.50
        c.eyeEnlarge = 0.20
        c.faceSlim = 0.22
        c.teethWhitening = 0.55
        c.cheekSculpt = 0.25
        c.lipVibrance = 0.40
        c.skinGlow = 0.35
        c.portraitLight = 0.55
        c.backgroundBlur = 0.30
        c.foundation = 0.45
        c.foundationShade = .caldo
        c.contour = 0.30
        c.blush = 0.40
        c.blushShade = .rosa
        c.eyeshadow = 0.45
        c.eyeshadowShade = .malva
        c.eyeliner = 0.50
        c.lipstick = 0.50
        c.lipstickShade = .rosso
        return c
    }

    var isBeautyPreset: Bool { self == FaceEditControls.beautyPreset() }
    var isNaturalePreset: Bool { self == FaceEditControls.naturalePreset() }
    var isGlamPreset: Bool { self == FaceEditControls.glamPreset() }
}

/// Look epoca applicati via LUT + grain della libreria Filmatura.
enum EraLook: String, CaseIterable, Identifiable {
    case none = "Nessuno"
    case seventies = "Anni '70"
    case nineties = "Anni '90"

    var id: String { rawValue }

    var presetID: String? {
        switch self {
        case .none: return nil
        case .seventies: return "super8"
        case .nineties: return "pastello90"
        }
    }
}

/// Renderer delle modifiche volto: maschere disegnate dai landmark,
/// sfocatura selettiva, warp geometrico e luci.
enum FaceRenderer {

    // MARK: - Pipeline principale

    static func render(image: CIImage,
                       faces: [FaceData],
                       controls: FaceEditControls,
                       store: LUTStore = .shared) -> CIImage {
        var result = image
        let selected = faces.filter {
            controls.targetFaceID == nil || $0.id == controls.targetFaceID
        }

        // 1. Pelle liscia (maschera per volto)
        if controls.skinSmooth > 0 {
            let mask = faceMask(for: selected, size: image.extent.size,
                                feather: max(8, image.extent.width * 0.008))
            let radius = 6 + controls.skinSmooth * 10
            let smoothed = result.blurred(radius: radius)
            result = blend(base: result, top: smoothed, mask: mask)
        }

        // 2. Occhi piu' luminosi
        if controls.eyeBrightness > 0 {
            let mask = eyesMask(for: selected, size: image.extent.size,
                                feather: 4)
            let brightened = colorAdjust(result, brightness: 0.08 * controls.eyeBrightness,
                                         saturation: 1.06, contrast: 1.03)
            result = blend(base: result, top: brightened, mask: mask)
        }

        // 3. Denti piu' bianchi
        if controls.teethWhitening > 0 {
            let mask = teethMask(for: selected, size: image.extent.size, feather: 3)
            let whitened = colorAdjust(result, brightness: 0.10 * controls.teethWhitening,
                                       saturation: 1.0 - 0.42 * controls.teethWhitening,
                                       contrast: 1.05)
            result = blend(base: result, top: whitened, mask: mask)
        }

        // 3b. Occhiaie attenuate (area sotto gli occhi)
        if controls.underEye > 0 {
            let mask = underEyeMask(for: selected, size: image.extent.size, feather: 6)
            let corrected = colorAdjust(result,
                                        brightness: 0.09 * controls.underEye,
                                        saturation: 1.0 - 0.25 * controls.underEye,
                                        contrast: 1.02)
            result = blend(base: result, top: corrected, mask: mask)
        }

        // 4. Labbra piu' vive
        if controls.lipVibrance > 0 {
            let mask = lipsMask(for: selected, size: image.extent.size, feather: 4)
            let vibrant = vibrance(result, amount: 0.4 * controls.lipVibrance)
            result = blend(base: result, top: vibrant, mask: mask)
        }

        // 4a. Glow viso: luce calda su tutto il volto
        if controls.skinGlow > 0 {
            let mask = faceMask(for: selected, size: image.extent.size,
                                feather: max(10, image.extent.width * 0.008))
            let warmed = colorAdjust(result,
                                     brightness: 0.045 * controls.skinGlow,
                                     saturation: 1.0 + 0.10 * controls.skinGlow,
                                     contrast: 1.01)
            result = blend(base: result, top: warmed, mask: mask)
        }

        // 4b. Trucco (cipria, contouring, blush, ombretto, eyeliner, rossetto)
        result = applyMakeup(result, faces: selected, controls: controls)

        // 5. Luce ritratto (gradiente radiale soft-light + vignetta)
        if controls.portraitLight > 0 {
            result = applyPortraitLight(result, faces: selected,
                                        amount: controls.portraitLight)
        }

        // 6. Sfondo sfocato
        if controls.backgroundBlur > 0 {
            let mask = backgroundMask(for: selected, size: image.extent.size,
                                      feather: max(12, image.extent.width * 0.02))
            let blurred = result.blurred(radius: 10 + controls.backgroundBlur * 16)
            result = blend(base: result, top: blurred, mask: mask)
        }

        // 7. Warp geometrico: occhi grandi, pomelli, mandibola, viso snello
        // (al termine, per allineare)
        if controls.eyeEnlarge > 0 {
            for face in selected {
                for eye in [face.leftEye, face.rightEye] {
                    result = bump(result, center: eye,
                                  radius: face.eyeWidth * 1.25,
                                  scale: 0.30 * controls.eyeEnlarge)
                }
            }
        }
        if controls.cheekSculpt > 0 {
            for face in selected {
                result = pinch(result, center: face.cheekPointLeft,
                               radius: face.faceWidth * 0.30,
                               scale: 0.55 * controls.cheekSculpt)
                result = pinch(result, center: face.cheekPointRight,
                               radius: face.faceWidth * 0.30,
                               scale: 0.55 * controls.cheekSculpt)
            }
        }
        if controls.jawSculpt > 0 {
            for face in selected {
                result = pinch(result, center: face.jawPointLeft,
                               radius: face.faceWidth * 0.24,
                               scale: 0.45 * controls.jawSculpt)
                result = pinch(result, center: face.jawPointRight,
                               radius: face.faceWidth * 0.24,
                               scale: 0.45 * controls.jawSculpt)
            }
        }
        if controls.faceSlim > 0 {
            for face in selected {
                let left = CGPoint(x: face.box.minX + face.faceWidth * 0.18,
                                   y: face.box.minY + face.faceHeight * 0.55)
                let right = CGPoint(x: face.box.maxX - face.faceWidth * 0.18,
                                    y: face.box.minY + face.faceHeight * 0.55)
                result = pinch(result, center: left,
                               radius: face.faceWidth * 0.26,
                               scale: 0.50 * controls.faceSlim)
                result = pinch(result, center: right,
                               radius: face.faceWidth * 0.26,
                               scale: 0.50 * controls.faceSlim)
            }
        }

        // 8. Look epoca (LUT della libreria + grain)
        if let presetID = controls.eraLook.presetID {
            let preset = LUTCatalog.preset(withID: presetID)
            let intensity: Double = controls.eraLook == .seventies ? 0.6 : 0.5
            result = store.apply(preset, intensity: intensity, to: result)
            result = result.addingGrain(amount: controls.eraLook == .seventies ? 0.35 : 0.2)
        }

        return result
    }

    // MARK: - Filtri di base

    private static func colorAdjust(_ image: CIImage,
                                    brightness: CGFloat,
                                    saturation: CGFloat,
                                    contrast: CGFloat) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.brightness = Float(brightness)
        filter.saturation = Float(saturation)
        filter.contrast = Float(contrast)
        return filter.outputImage ?? image
    }

    private static func vibrance(_ image: CIImage, amount: CGFloat) -> CIImage {
        let filter = CIFilter.vibrance()
        filter.inputImage = image
        filter.amount = Float(amount)
        return filter.outputImage ?? image
    }

    /// Fusione mascherata: top dove la maschera e' bianca, base altrove.
    private static func blend(base: CIImage, top: CIImage, mask: CIImage) -> CIImage {
        let filter = CIFilter.blendWithMask()
        filter.inputImage = top
        filter.backgroundImage = base
        filter.setValue(mask, forKey: "inputMaskImage")
        return filter.outputImage ?? base
    }

    private static func pinch(_ image: CIImage,
                              center: CGPoint,
                              radius: CGFloat,
                              scale: CGFloat) -> CIImage {
        guard scale > 0.01, radius > 2 else { return image }
        let filter = CIFilter(name: "CIPinchDistortion")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(x: center.x, y: center.y), forKey: kCIInputCenterKey)
        filter?.setValue(radius, forKey: kCIInputRadiusKey)
        filter?.setValue(scale, forKey: kCIInputScaleKey)
        return filter?.outputImage?.cropped(to: image.extent) ?? image
    }

    /// Rigonfiamento locale (CIBumpDistortion): ingrandisce occhi e dettagli
    /// senza deformare il resto dell'immagine.
    private static func bump(_ image: CIImage,
                             center: CGPoint,
                             radius: CGFloat,
                             scale: CGFloat) -> CIImage {
        guard scale > 0.01, radius > 2 else { return image }
        let filter = CIFilter(name: "CIBumpDistortion")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(x: center.x, y: center.y), forKey: kCIInputCenterKey)
        filter?.setValue(radius, forKey: kCIInputRadiusKey)
        filter?.setValue(scale, forKey: kCIInputScaleKey)
        return filter?.outputImage?.cropped(to: image.extent) ?? image
    }

    private static func applyPortraitLight(_ image: CIImage,
                                           faces: [FaceData],
                                           amount: Double) -> CIImage {
        guard let first = faces.first else { return image }
        let center = CGPoint(x: first.box.midX,
                             y: first.box.minY + first.faceHeight * 0.35)
        let radius = max(first.faceWidth, first.faceHeight) * 0.9

        guard let gradient = CIFilter(name: "CIRadialGradient") else { return image }
        gradient.setValue(CIVector(x: center.x, y: center.y), forKey: "inputCenter")
        // CIRadialGradient non ha "inputRadius" (crash KVC): usa inputRadius0
        // (nocciolo pieno) e inputRadius1 (fine della sfumatura).
        gradient.setValue(radius * 0.55, forKey: "inputRadius0")
        gradient.setValue(radius * 1.35, forKey: "inputRadius1")
        gradient.setValue(CIColor(red: 1, green: 0.98, blue: 0.92, alpha: 1), forKey: "inputColor0")
        gradient.setValue(CIColor(red: 1, green: 0.98, blue: 0.92, alpha: 0), forKey: "inputColor1")

        // CISoftLightBlendMode non ha "inputIntensity" (crash KVC): si regola
        // l'intensita' miscelando il risultato verso l'immagine originale.
        let soft = CIFilter.softLightBlendMode()
        soft.inputImage = gradient.outputImage!.cropped(to: image.extent)
        soft.backgroundImage = image
        let lit = soft.outputImage ?? image
        return image.blending(image: lit, amount: CGFloat(amount * 0.45))
    }

    // MARK: - Maschere (render CoreGraphics, bianco su nero)

    private static func maskImage(size: CGSize, draw: (CGContext) -> Void) -> CIImage {
        let width = max(1, Int(size.width))
        let height = max(1, Int(size.height))
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
            return CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: size))
        }
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(origin: .zero, size: size))
        draw(context)
        guard let cgImage = context.makeImage() else {
            return CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: size))
        }
        // CoreImage (coordinate basse a sinistra) vs CGContext (alte a sinistra):
        // le maschere sono simmetriche per area, ribaltiamo per precisione.
        return CIImage(cgImage: cgImage).oriented(.downMirrored)
            .cropped(to: CGRect(origin: .zero, size: size))
    }

    private static func feathered(_ mask: CIImage, radius: CGFloat) -> CIImage {
        guard radius > 0.5 else { return mask }
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = mask.clampedToExtent()
        blur.radius = Float(radius)
        return blur.outputImage!.cropped(to: mask.extent)
    }

    private static func fillPolygons(_ context: CGContext,
                                     polygons: [[CGPoint]],
                                     alpha: CGFloat) {
        context.setFillColor(gray: 1, alpha: alpha)
        for polygon in polygons where polygon.count > 2 {
            let path = CGMutablePath()
            path.move(to: polygon[0])
            for point in polygon.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
        }
    }

    /// Maschera di pelle: contorno volto pieno.
    private static func faceMask(for faces: [FaceData],
                                 size: CGSize,
                                 feather: CGFloat) -> CIImage {
        let mask = maskImage(size: size) { context in
            fillPolygons(context, polygons: faces.map { $0.contour }, alpha: 1)
        }
        return feathered(mask, radius: feather)
    }

    /// Maschera occhi: ellissi morbide sui due occhi.
    private static func eyesMask(for faces: [FaceData],
                                 size: CGSize,
                                 feather: CGFloat) -> CIImage {
        let mask = maskImage(size: size) { context in
            context.setFillColor(gray: 1, alpha: 1)
            for face in faces {
                for center in [face.leftEye, face.rightEye] {
                    let radius = face.eyeWidth * 0.85
                    let rect = CGRect(x: center.x - radius,
                                      y: center.y - radius * 0.7,
                                      width: radius * 2,
                                      height: radius * 1.4)
                    context.fillEllipse(in: rect)
                }
            }
        }
        return feathered(mask, radius: feather)
    }

    /// Maschera occhiaie: ellissi morbide sotto i due occhi.
    private static func underEyeMask(for faces: [FaceData],
                                     size: CGSize,
                                     feather: CGFloat) -> CIImage {
        let mask = maskImage(size: size) { context in
            context.setFillColor(gray: 1, alpha: 1)
            for face in faces {
                for center in [face.leftEye, face.rightEye] {
                    let rx = face.eyeWidth * 0.85
                    let ry = face.eyeWidth * 0.55
                    let cy = center.y + face.eyeWidth * 0.75
                    context.fillEllipse(in: CGRect(x: center.x - rx,
                                                   y: cy - ry,
                                                   width: rx * 2,
                                                   height: ry * 2))
                }
            }
        }
        return feathered(mask, radius: feather)
    }

    /// Maschera denti: poligono labbra ristretto verso il centro bocca.
    private static func teethMask(for faces: [FaceData],
                                  size: CGSize,
                                  feather: CGFloat) -> CIImage {
        let polygons = faces.map { face -> [CGPoint] in
            let center = face.mouthCenter
            return face.lips.map { point in
                CGPoint(x: center.x + (point.x - center.x) * 0.42,
                        y: center.y + (point.y - center.y) * 0.42)
            }
        }
        let mask = maskImage(size: size) { context in
            fillPolygons(context, polygons: polygons, alpha: 1)
        }
        return feathered(mask, radius: feather)
    }

    /// Maschera labbra: poligono esterno leggermente contratto.
    private static func lipsMask(for faces: [FaceData],
                                 size: CGSize,
                                 feather: CGFloat) -> CIImage {
        let polygons = faces.map { face -> [CGPoint] in
            let center = face.mouthCenter
            return face.lips.map { point in
                CGPoint(x: center.x + (point.x - center.x) * 0.86,
                        y: center.y + (point.y - center.y) * 0.86)
            }
        }
        let mask = maskImage(size: size) { context in
            fillPolygons(context, polygons: polygons, alpha: 1)
        }
        return feathered(mask, radius: feather)
    }

    // MARK: - Trucco

    private static func applyMakeup(_ image: CIImage,
                                    faces: [FaceData],
                                    controls: FaceEditControls) -> CIImage {
        var result = image
        let size = image.extent.size

        if controls.foundation > 0 {
            let mask = foundationMask(for: faces, size: size,
                                      feather: max(8, size.width * 0.006))
            let top = tinted(result, shade: controls.foundationShade,
                             alpha: 0.16 * controls.foundation)
            result = blend(base: result, top: top, mask: mask)
        }

        if controls.contour > 0 {
            let mask = contourMask(for: faces, size: size,
                                   feather: max(6, size.width * 0.004))
            let top = tinted(result, shade: .marrone,
                             alpha: 0.13 * controls.contour)
            result = blend(base: result, top: top, mask: mask)
        }

        if controls.blush > 0 {
            let mask = blushMask(for: faces, size: size,
                                 feather: max(10, size.width * 0.008))
            let top = tinted(result, shade: controls.blushShade,
                             alpha: 0.26 * controls.blush)
            result = blend(base: result, top: top, mask: mask)
        }

        if controls.eyeshadow > 0 {
            let mask = eyeshadowMask(for: faces, size: size,
                                     feather: max(3, size.width * 0.0035))
            let top = tinted(result, shade: controls.eyeshadowShade,
                             alpha: 0.24 * controls.eyeshadow)
            result = blend(base: result, top: top, mask: mask)
        }

        if controls.eyeliner > 0 {
            let mask = eyelinerMask(for: faces, size: size)
            let top = tinted(result, shade: controls.eyelinerShade,
                             alpha: 0.65 * controls.eyeliner)
            result = blend(base: result, top: top, mask: mask)
        }

        if controls.lipstick > 0 {
            let mask = lipstickMask(for: faces, size: size,
                                    feather: max(2, size.width * 0.0008))
            let top = tinted(result, shade: controls.lipstickShade,
                             alpha: 0.55 * controls.lipstick)
            result = blend(base: result, top: top, mask: mask)
        }

        return result
    }

    /// Velatura di un colore sull'immagine (base del trucco).
    private static func tinted(_ image: CIImage,
                               shade: MakeupShade,
                               alpha: CGFloat) -> CIImage {
        guard alpha > 0.003 else { return image }
        let (r, g, b) = shade.rgb
        let solid = CIImage(color: CIColor(red: r, green: g, blue: b))
            .cropped(to: image.extent)
        let transparent = solid.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha)
        ])
        let over = CIFilter.sourceOverCompositing()
        over.inputImage = transparent
        over.backgroundImage = image
        return over.outputImage ?? image
    }

    /// Cipria: contorno del volto, con occhi e bocca esclusi.
    private static func foundationMask(for faces: [FaceData],
                                       size: CGSize,
                                       feather: CGFloat) -> CIImage {
        let mask = maskImage(size: size) { context in
            fillPolygons(context, polygons: faces.map { $0.contour }, alpha: 1)
            context.setFillColor(gray: 0, alpha: 1)
            for face in faces {
                for center in [face.leftEye, face.rightEye] {
                    let r = face.eyeWidth * 0.85
                    context.fillEllipse(in: CGRect(x: center.x - r,
                                                   y: center.y - r * 0.7,
                                                   width: r * 2,
                                                   height: r * 1.4))
                }
                if !face.lips.isEmpty {
                    let path = CGMutablePath()
                    path.move(to: face.lips[0])
                    for point in face.lips.dropFirst() { path.addLine(to: point) }
                    path.closeSubpath()
                    context.addPath(path)
                    context.fillPath()
                }
            }
        }
        return feathered(mask, radius: feather)
    }

    /// Contouring: tratti scuri sotto gli zigomi e lungo la mandibola.
    private static func contourMask(for faces: [FaceData],
                                    size: CGSize,
                                    feather: CGFloat) -> CIImage {
        let mask = maskImage(size: size) { context in
            context.setStrokeColor(gray: 1, alpha: 1)
            context.setLineJoin(.round)
            context.setLineCap(.round)
            for face in faces {
                let b = face.box
                let w = b.width
                let h = b.height
                context.setLineWidth(w * 0.07)
                let strokes: [[CGPoint]] = [
                    [CGPoint(x: b.minX + w * 0.06, y: b.minY + h * 0.52),
                     CGPoint(x: b.minX + w * 0.32, y: b.minY + h * 0.62)],
                    [CGPoint(x: b.maxX - w * 0.06, y: b.minY + h * 0.52),
                     CGPoint(x: b.maxX - w * 0.32, y: b.minY + h * 0.62)],
                    [CGPoint(x: b.minX + w * 0.14, y: b.minY + h * 0.78),
                     CGPoint(x: b.minX + w * 0.34, y: b.minY + h * 0.88)],
                    [CGPoint(x: b.maxX - w * 0.14, y: b.minY + h * 0.78),
                     CGPoint(x: b.maxX - w * 0.34, y: b.minY + h * 0.88)]
                ]
                for stroke in strokes {
                    context.move(to: stroke[0])
                    context.addLine(to: stroke[1])
                    context.strokePath()
                }
            }
        }
        return feathered(mask, radius: feather)
    }

    /// Blush: due chiazze morbide sugli zigomi.
    private static func blushMask(for faces: [FaceData],
                                  size: CGSize,
                                  feather: CGFloat) -> CIImage {
        let mask = maskImage(size: size) { context in
            context.setFillColor(gray: 1, alpha: 1)
            for face in faces {
                for center in [face.cheekPointLeft, face.cheekPointRight] {
                    let rx = face.faceWidth * 0.15
                    let ry = face.faceWidth * 0.10
                    context.fillEllipse(in: CGRect(x: center.x - rx,
                                                   y: center.y - ry,
                                                   width: rx * 2,
                                                   height: ry * 2))
                }
            }
        }
        return feathered(mask, radius: feather)
    }

    /// Ombretto: area tra la palpebra e il sopracciglio.
    private static func eyeshadowMask(for faces: [FaceData],
                                      size: CGSize,
                                      feather: CGFloat) -> CIImage {
        let mask = maskImage(size: size) { context in
            context.setFillColor(gray: 1, alpha: 1)
            for face in faces {
                let pairs = [(face.leftEyePolygon, face.leftEyebrowPolygon),
                             (face.rightEyePolygon, face.rightEyebrowPolygon)]
                for (eye, brow) in pairs {
                    guard !eye.isEmpty else { continue }
                    let xs = eye.map { $0.x }
                    let ys = eye.map { $0.y }
                    let cx = (xs.min()! + xs.max()!) / 2
                    let eyeTop = ys.min()!
                    let browBottom = brow.map { $0.y }.max() ?? (eyeTop - face.eyeWidth * 0.8)
                    let top = min(browBottom + face.eyeWidth * 0.08, eyeTop - 1)
                    let height = max(face.eyeWidth * 0.5, eyeTop - top)
                    let cy = top + height * 0.5
                    let rx = face.eyeWidth * 0.95
                    let ry = height * 0.55
                    context.fillEllipse(in: CGRect(x: cx - rx, y: cy - ry,
                                                   width: rx * 2, height: ry * 2))
                }
            }
        }
        return feathered(mask, radius: feather)
    }

    /// Eyeliner: tratto lungo il bordo superiore dell'occhio.
    private static func eyelinerMask(for faces: [FaceData], size: CGSize) -> CIImage {
        let mask = maskImage(size: size) { context in
            context.setStrokeColor(gray: 1, alpha: 1)
            context.setLineJoin(.round)
            context.setLineCap(.round)
            for face in faces {
                context.setLineWidth(max(1.2, face.eyeWidth * 0.055))
                for polygon in [face.leftEyePolygon, face.rightEyePolygon] {
                    guard polygon.count > 3 else { continue }
                    let sum = polygon.map { $0.y }.reduce(0, +)
                    let cy = sum / CGFloat(polygon.count)
                    let upper = polygon.filter { $0.y <= cy }.sorted { $0.x < $1.x }
                    guard upper.count > 1 else { continue }
                    let path = CGMutablePath()
                    path.move(to: upper[0])
                    for point in upper.dropFirst() { path.addLine(to: point) }
                    context.addPath(path)
                    context.strokePath()
                }
            }
        }
        return feathered(mask, radius: 1)
    }

    /// Rossetto: poligono labbra pieno.
    private static func lipstickMask(for faces: [FaceData],
                                     size: CGSize,
                                     feather: CGFloat) -> CIImage {
        let mask = maskImage(size: size) { context in
            fillPolygons(context, polygons: faces.map { $0.lips }, alpha: 1)
        }
        return feathered(mask, radius: feather)
    }

    /// Maschera sfondo: bianco ovunque tranne ellissi dei volti.
    private static func backgroundMask(for faces: [FaceData],
                                       size: CGSize,
                                       feather: CGFloat) -> CIImage {
        let mask = maskImage(size: size) { context in
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(origin: .zero, size: size))
            context.setFillColor(gray: 0, alpha: 1)
            for face in faces {
                let rect = face.box.insetBy(dx: -face.faceWidth * 0.18,
                                            dy: -face.faceHeight * 0.18)
                context.fillEllipse(in: rect)
            }
        }
        return feathered(mask, radius: feather)
    }
}
