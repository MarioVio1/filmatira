import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Sfumature di trucco (colori sRGB 0-1).
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

/// Tonalita' per il colore degli occhi (gradiente iride via maschera).
enum EyeColorShade: String, CaseIterable, Equatable, Identifiable {
    case miele = "Miele"
    case ambra = "Ambra"
    case verde = "Verde"
    case smeraldo = "Smeraldo"
    case azzurro = "Azzurro"
    case grigio = "Grigio"
    case nocciola = "Nocciola"
    case viola = "Viola"

    var id: String { rawValue }

    var rgb: (Double, Double, Double) {
        switch self {
        case .miele: return (0.72, 0.52, 0.24)
        case .ambra: return (0.62, 0.38, 0.14)
        case .verde: return (0.34, 0.48, 0.26)
        case .smeraldo: return (0.16, 0.42, 0.30)
        case .azzurro: return (0.28, 0.50, 0.62)
        case .grigio: return (0.42, 0.46, 0.50)
        case .nocciola: return (0.55, 0.42, 0.26)
        case .viola: return (0.38, 0.32, 0.50)
        }
    }
}

/// Strumenti di editing volto stile FaceLab, tutti originali
/// (Vision + CoreImage), con categorie a schede nell'interfaccia.
struct FaceEditControls: Equatable {
    // Viso (warp guidato dai contorni reali)
    var slimFace: Double = 0          // viso snello (pinch largo sugli zigomi)
    var cheeks: Double = 0            // guance (pinch sulle guance)
    var cheekbones: Double = 0        // pomelli in rilievo (bump sugli zigomi)
    var jaw: Double = 0               // mandibola definita
    var chin: Double = 0              // mento
    var nose: Double = 0              // naso sottile

    // Occhi
    var eyeEnlarge: Double = 0        // occhi piu' grandi
    var eyeBrightness: Double = 0     // occhi piu' luminosi
    var underEye: Double = 0          // occhiaie attenuate
    var eyeColor: Double = 0          // colore occhi
    var eyeColorShade: EyeColorShade = .miele

    // Sorriso
    var smile: Double = 0             // sorriso (warp angoli bocca)
    var teethWhitening: Double = 0    // denti piu' bianchi

    // Pelle
    var skinSmooth: Double = 0        // leviga con separazione di frequenze
    var blemish: Double = 0           // anti-imperfezioni (mediana)
    var tan: Double = 0               // abbronzatura calda
    var skinGlow: Double = 0          // glow viso

    // Luce
    var portraitLight: Double = 0     // luce ritratto

    // Sfondo (segmentazione persona)
    var backgroundBlur: Double = 0    // sfondo sfocato
    var backgroundMono: Double = 0    // sfondo bianco e nero

    // Trucco
    var foundation: Double = 0
    var foundationShade: MakeupShade = .naturale
    var contour: Double = 0
    var blush: Double = 0
    var blushShade: MakeupShade = .pesca
    var eyeshadow: Double = 0
    var eyeshadowShade: MakeupShade = .sabbia
    var eyeliner: Double = 0
    var eyelinerShade: MakeupShade = .nero
    var lipstick: Double = 0
    var lipstickShade: MakeupShade = .nude
    var lipVibrance: Double = 0       // labbra piu' vive

    var eraLook: EraLook = .none
    var targetFaceID: UUID? = nil     // nil = tutti i volti

    var isNeutral: Bool {
        slimFace == 0 && cheeks == 0 && cheekbones == 0 && jaw == 0 &&
        chin == 0 && nose == 0 && eyeEnlarge == 0 && eyeBrightness == 0 &&
        underEye == 0 && eyeColor == 0 && smile == 0 && teethWhitening == 0 &&
        skinSmooth == 0 && blemish == 0 && tan == 0 && skinGlow == 0 &&
        portraitLight == 0 && backgroundBlur == 0 && backgroundMono == 0 &&
        foundation == 0 && contour == 0 && blush == 0 && eyeshadow == 0 &&
        eyeliner == 0 && lipstick == 0 && lipVibrance == 0 && eraLook == .none
    }

    /// Preset «Fai bello»: pelle pulita, occhi freschi, sorriso leggero,
    /// viso scolpito con moderazione, luce e sfondo ritratto.
    static func beautyPreset() -> FaceEditControls {
        var c = FaceEditControls()
        c.skinSmooth = 0.50
        c.blemish = 0.50
        c.underEye = 0.40
        c.teethWhitening = 0.45
        c.eyeBrightness = 0.40
        c.eyeEnlarge = 0.15
        c.smile = 0.20
        c.slimFace = 0.18
        c.cheekbones = 0.28
        c.cheeks = 0.15
        c.tan = 0.10
        c.skinGlow = 0.25
        c.portraitLight = 0.45
        c.backgroundBlur = 0.30
        c.foundation = 0.35
        c.contour = 0.18
        c.blush = 0.28
        c.lipstick = 0.25
        c.lipVibrance = 0.30
        return c
    }

    /// Preset «Naturale»: solo pelle e luce, nessun warp e nessun trucco.
    static func naturalePreset() -> FaceEditControls {
        var c = FaceEditControls()
        c.skinSmooth = 0.35
        c.blemish = 0.45
        c.underEye = 0.35
        c.teethWhitening = 0.30
        c.eyeBrightness = 0.20
        c.skinGlow = 0.15
        c.portraitLight = 0.20
        return c
    }

    /// Preset «Glam»: scultura decisa, occhi grandi, trucco da serata.
    static func glamPreset() -> FaceEditControls {
        var c = FaceEditControls()
        c.skinSmooth = 0.55
        c.blemish = 0.55
        c.underEye = 0.45
        c.eyeBrightness = 0.50
        c.eyeEnlarge = 0.20
        c.smile = 0.25
        c.slimFace = 0.25
        c.cheekbones = 0.35
        c.cheeks = 0.20
        c.jaw = 0.20
        c.teethWhitening = 0.55
        c.skinGlow = 0.35
        c.tan = 0.15
        c.portraitLight = 0.55
        c.backgroundBlur = 0.35
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
        c.lipVibrance = 0.40
        return c
    }

    /// Preset «Dolce»: glow soffuso, guance rosate, sorriso delicato.
    static func dolcePreset() -> FaceEditControls {
        var c = FaceEditControls()
        c.skinSmooth = 0.40
        c.blemish = 0.40
        c.underEye = 0.35
        c.eyeBrightness = 0.30
        c.smile = 0.30
        c.teethWhitening = 0.35
        c.skinGlow = 0.40
        c.portraitLight = 0.35
        c.backgroundBlur = 0.25
        c.blush = 0.40
        c.blushShade = .rosa
        c.eyeshadow = 0.25
        c.eyeshadowShade = .sabbia
        c.lipstick = 0.20
        c.lipVibrance = 0.25
        return c
    }

    var isBeautyPreset: Bool { self == FaceEditControls.beautyPreset() }
    var isNaturalePreset: Bool { self == FaceEditControls.naturalePreset() }
    var isGlamPreset: Bool { self == FaceEditControls.glamPreset() }
    var isDolcePreset: Bool { self == FaceEditControls.dolcePreset() }
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

/// Renderer FaceLab: maschere disegnate dai landmark, separazione di
/// frequenze per la pelle, soglia di luminosita' per i denti, warp guidato
/// dal contorno reale e sfondo ritratto con segmentazione persona.
enum FaceRenderer {

    /// Kernel di warp per il sorriso: alza gli angoli della bocca con una
    /// finestra gaussiana. Se il kernel non si compila il tool e' ignorato.
    private static let smileKernelSource = """
        kernel vec2 filmaturaSmile(sampler src, vec2 cornerL, vec2 cornerR,
                                   float radius, float lift) {
            vec2 p = destCoord();
            float dL = distance(p, cornerL);
            float dR = distance(p, cornerR);
            float r2 = max(radius * radius, 1.0);
            float fL = exp(-(dL * dL) / r2);
            float fR = exp(-(dR * dR) / r2);
            return samplerCoord(src) + vec2(0.0, -lift) * (fL + fR);
        }
        """
    private static let smileWarpKernel: CIWarpKernel? = CIWarpKernel(source: smileKernelSource)

    // MARK: - Pipeline principale

    static func render(image: CIImage,
                       faces: [FaceData],
                       controls: FaceEditControls,
                       store: LUTStore = .shared) -> CIImage {
        var result = image
        let selected = faces.filter {
            controls.targetFaceID == nil || $0.id == controls.targetFaceID
        }
        let size = image.extent.size

        // 1. Pelle: imperfezioni, levigatura a separazione di frequenze,
        //    abbronzatura, glow.
        if controls.blemish > 0 {
            result = applyBlemish(result, faces: selected, amount: controls.blemish)
        }
        if controls.skinSmooth > 0 {
            result = applySkinSmoothing(result, faces: selected,
                                        amount: controls.skinSmooth)
        }
        if controls.tan > 0 {
            result = applyTan(result, faces: selected, amount: controls.tan)
        }
        if controls.skinGlow > 0 {
            let mask = skinMask(for: selected, size: size,
                                feather: max(10, size.width * 0.008))
            let warmed = colorAdjust(result,
                                     brightness: 0.045 * controls.skinGlow,
                                     saturation: 1.0 + 0.10 * controls.skinGlow,
                                     contrast: 1.01)
            let top = result.blending(image: warmed, amount: CGFloat(controls.skinGlow))
            result = blend(base: result, top: top, mask: mask)
        }

        // 2. Occhi: occhiaie, luminosita', colore iridi.
        if controls.underEye > 0 {
            let mask = underEyeMask(for: selected, size: size, feather: 6)
            let corrected = colorAdjust(result,
                                        brightness: 0.09 * controls.underEye,
                                        saturation: 1.0 - 0.25 * controls.underEye,
                                        contrast: 1.02)
            let top = result.blending(image: corrected,
                                      amount: CGFloat(0.9 * controls.underEye))
            result = blend(base: result, top: top, mask: mask)
        }
        if controls.eyeBrightness > 0 {
            let mask = eyesMask(for: selected, size: size, feather: 4)
            let brightened = colorAdjust(result,
                                         brightness: 0.08 * controls.eyeBrightness,
                                         saturation: 1.06, contrast: 1.03)
            let top = result.blending(image: brightened,
                                      amount: CGFloat(0.9 * controls.eyeBrightness))
            result = blend(base: result, top: top, mask: mask)
        }
        if controls.eyeColor > 0 {
            result = applyEyeColor(result, faces: selected,
                                   amount: controls.eyeColor,
                                   shade: controls.eyeColorShade)
        }

        // 3. Denti: schiariti solo dove la luminosita' indica i denti.
        if controls.teethWhitening > 0 {
            result = applyTeeth(result, faces: selected,
                                amount: controls.teethWhitening)
        }

        // 4. Trucco + labbra vive.
        result = applyMakeup(result, faces: selected, controls: controls)
        if controls.lipVibrance > 0 {
            let mask = lipsMask(for: selected, size: size, feather: 4)
            let vibrant = vibrance(result, amount: 0.4 * controls.lipVibrance)
            let top = result.blending(image: vibrant,
                                      amount: CGFloat(0.85 * controls.lipVibrance))
            result = blend(base: result, top: top, mask: mask)
        }

        // 5. Luce ritratto (gradiente radiale sul volto principale).
        if controls.portraitLight > 0 {
            result = applyPortraitLight(result, faces: selected,
                                        amount: controls.portraitLight)
        }

        // 6. Warp geometrico guidato dal contorno reale (punti convertiti
        //    nello spazio CoreImage: origine in basso a sinistra).
        result = applyWarp(result, faces: selected, controls: controls)

        // 7. Sfondo ritratto: sfocatura e bianco e nero fuori dalla persona.
        if controls.backgroundBlur > 0 || controls.backgroundMono > 0 {
            result = applyBackground(result, faces: selected,
                                     blur: controls.backgroundBlur,
                                     mono: controls.backgroundMono)
        }

        // 8. Look epoca (LUT della libreria + grain).
        if let presetID = controls.eraLook.presetID {
            let preset = LUTCatalog.preset(withID: presetID)
            let intensity: Double = controls.eraLook == .seventies ? 0.6 : 0.5
            result = store.apply(preset, intensity: intensity, to: result)
            result = result.addingGrain(amount: controls.eraLook == .seventies ? 0.35 : 0.2)
        }

        return result
    }

    // MARK: - Pelle

    /// Anti-imperfezioni: doppia mediana (smorza brufoli e pori) miscelata
    /// solo sulla pelle, preservando occhi e labbra.
    private static func applyBlemish(_ image: CIImage,
                                     faces: [FaceData],
                                     amount: Double) -> CIImage {
        let size = image.extent.size
        let mask = skinMask(for: faces, size: size,
                            feather: max(8, size.width * 0.008))
        let once = median(image)
        let twice = median(once)
        let top = image.blending(image: twice, amount: CGFloat(0.85 * amount))
        return blend(base: image, top: top, mask: mask)
    }

    private static func median(_ image: CIImage) -> CIImage {
        let filter = CIFilter(name: "CIMedianFilter")
        filter?.setValue(image, forKey: kCIInputImageKey)
        return filter?.outputImage?.cropped(to: image.extent) ?? image
    }

    /// Levigatura con separazione di frequenze: bassa frequenza (sfocata)
    /// piu' una parte dei dettagli originali, cosi' la pelle resta naturale
    /// senza effetto plastica.
    private static func applySkinSmoothing(_ image: CIImage,
                                           faces: [FaceData],
                                           amount: Double) -> CIImage {
        let size = image.extent.size
        let mask = skinMask(for: faces, size: size,
                            feather: max(8, size.width * 0.008))
        let faceScale = faces.map { $0.faceWidth }.max() ?? size.width * 0.4
        let radius = max(3, faceScale * (0.012 + 0.030 * amount))
        let low = image.blurred(radius: radius)

        let difference = CIFilter.differenceBlendMode()
        difference.inputImage = image
        difference.backgroundImage = low
        let detailLayer = difference.outputImage ?? low
        let retention = 0.85 - 0.55 * amount
        let detail = detailLayer.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: retention, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: retention, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: retention, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        ])

        let addition = CIFilter.additionCompositing()
        addition.inputImage = detail.cropped(to: image.extent)
        addition.backgroundImage = low
        let smoothed = addition.outputImage ?? low

        return blend(base: image, top: smoothed.cropped(to: image.extent), mask: mask)
    }

    /// Abbronzatura: moltiplicazione calda limitata alla pelle.
    private static func applyTan(_ image: CIImage,
                                 faces: [FaceData],
                                 amount: Double) -> CIImage {
        let size = image.extent.size
        let mask = skinMask(for: faces, size: size,
                            feather: max(12, size.width * 0.010))
        let solid = CIImage(color: CIColor(red: 1.0, green: 0.85, blue: 0.68))
            .cropped(to: image.extent)
        let multiply = CIFilter.multiplyBlendMode()
        multiply.inputImage = solid
        multiply.backgroundImage = image
        let warm = multiply.outputImage ?? image
        let top = image.blending(image: warm, amount: CGFloat(0.45 * amount))
        return blend(base: image, top: top, mask: mask)
    }

    // MARK: - Occhi e denti

    /// Colore occhi: velo colorato sugli iridi (morbidato da soft-light e
    /// moltiplicazione) limitato alle ellissi degli occhi.
    private static func applyEyeColor(_ image: CIImage,
                                      faces: [FaceData],
                                      amount: Double,
                                      shade: EyeColorShade) -> CIImage {
        let size = image.extent.size
        let mask = irisMask(for: faces, size: size, feather: 1.5)
        let (r, g, b) = shade.rgb
        let solid = CIImage(color: CIColor(red: r, green: g, blue: b))
            .cropped(to: image.extent)
        let soft = blendNamed("CISoftLightBlendMode", top: solid, base: image)
        let deep = blendNamed("CIMultiplyBlendMode", top: solid, base: soft)
        let top = image.blending(image: deep, amount: CGFloat(0.80 * amount))
        return blend(base: image, top: top, mask: mask)
    }

    /// Denti bianchi: dentro la bocca si schiarisce solo dove la luminosita'
    /// supera la soglia (i denti), cosi' labbra e ombre restano invariate.
    private static func applyTeeth(_ image: CIImage,
                                   faces: [FaceData],
                                   amount: Double) -> CIImage {
        let size = image.extent.size
        let mouth = teethMask(for: faces, size: size, feather: 2)
        let gray = colorAdjust(image, brightness: 0, saturation: 0, contrast: 1.0)
        let threshold = CIFilter.colorThreshold()
        threshold.inputImage = gray
        threshold.threshold = Float(max(0.40, 0.58 - 0.12 * amount))
        let white = (threshold.outputImage ?? gray).cropped(to: image.extent)

        let combined = CIFilter.multiplyBlendMode()
        combined.inputImage = mouth
        combined.backgroundImage = white
        let teeth = (combined.outputImage ?? mouth).cropped(to: image.extent)

        let whitened = colorAdjust(image,
                                   brightness: 0.10 * amount,
                                   saturation: 1.0 - 0.50 * amount,
                                   contrast: 1.06)
        let top = image.blending(image: whitened, amount: CGFloat(0.90 * amount))
        return blend(base: image, top: top, mask: teeth)
    }

    // MARK: - Warp (tutti i punti sono in spazio alto-sinistra e vengono
    // convertiti nello spazio CoreImage dei filtri di distorsione)

    private static func applyWarp(_ image: CIImage,
                                  faces: [FaceData],
                                  controls: FaceEditControls) -> CIImage {
        var result = image

        for face in faces {
            // Occhi grandi: bump morbido sui centri occhio.
            if controls.eyeEnlarge > 0 {
                for eye in [face.leftEye, face.rightEye] {
                    result = bump(result, at: eye,
                                  radius: face.eyeWidth * 1.35,
                                  scale: CGFloat(0.26 * controls.eyeEnlarge))
                }
            }

            // Pomelli in rilievo: bump sugli zigomi reali.
            if controls.cheekbones > 0 {
                result = bump(result, at: face.cheekboneLeftOrFallback,
                              radius: face.faceWidth * 0.24,
                              scale: CGFloat(0.20 * controls.cheekbones))
                result = bump(result, at: face.cheekboneRightOrFallback,
                              radius: face.faceWidth * 0.24,
                              scale: CGFloat(0.20 * controls.cheekbones))
            }

            // Guance: pinch sulle guance (quota centrale).
            if controls.cheeks > 0 {
                result = pinch(result, at: face.cheekSlimLeftOrFallback,
                               radius: face.faceWidth * 0.28,
                               scale: CGFloat(0.50 * controls.cheeks))
                result = pinch(result, at: face.cheekSlimRightOrFallback,
                               radius: face.faceWidth * 0.28,
                               scale: CGFloat(0.50 * controls.cheeks))
            }

            // Viso snello: pinch largo e morbido alla quota zigomi.
            if controls.slimFace > 0 {
                result = pinch(result, at: face.cheekboneLeftOrFallback,
                               radius: face.faceWidth * 0.45,
                               scale: CGFloat(0.34 * controls.slimFace))
                result = pinch(result, at: face.cheekboneRightOrFallback,
                               radius: face.faceWidth * 0.45,
                               scale: CGFloat(0.34 * controls.slimFace))
            }

            // Mandibola.
            if controls.jaw > 0, let left = face.jawLeft, let right = face.jawRight {
                result = pinch(result, at: left,
                               radius: face.faceWidth * 0.22,
                               scale: CGFloat(0.40 * controls.jaw))
                result = pinch(result, at: right,
                               radius: face.faceWidth * 0.22,
                               scale: CGFloat(0.40 * controls.jaw))
            }

            // Mento.
            if controls.chin > 0 {
                result = pinch(result, at: face.chinPoint,
                               radius: face.faceWidth * 0.18,
                               scale: CGFloat(0.30 * controls.chin))
            }

            // Naso sottile: pinch sulle ali del naso.
            if controls.nose > 0 {
                result = pinch(result, at: face.noseAlaeLeft,
                               radius: face.faceWidth * 0.12,
                               scale: CGFloat(0.42 * controls.nose))
                result = pinch(result, at: face.noseAlaeRight,
                               radius: face.faceWidth * 0.12,
                               scale: CGFloat(0.42 * controls.nose))
            }

            // Sorriso: kernel di warp sugli angoli della bocca.
            if controls.smile > 0, let kernel = smileWarpKernel {
                let height = result.extent.height
                let cornerL = CIVector(x: face.mouthCornerLeft.x,
                                       y: height - face.mouthCornerLeft.y)
                let cornerR = CIVector(x: face.mouthCornerRight.x,
                                       y: height - face.mouthCornerRight.y)
                let radius = Float(face.faceWidth * 0.30)
                let lift = Float(face.faceWidth * 0.055 * controls.smile)
                let warped = kernel.apply(extent: result.extent,
                                          roiCallback: { _ in result.extent },
                                          arguments: [cornerL, cornerR, radius, lift])
                if let warped {
                    result = warped.cropped(to: image.extent)
                }
            }
        }

        return result
    }

    private static func pinch(_ image: CIImage,
                              at point: CGPoint,
                              radius: CGFloat,
                              scale: CGFloat) -> CIImage {
        guard scale > 0.01, radius > 2 else { return image }
        let filter = CIFilter(name: "CIPinchDistortion")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(x: point.x, y: image.extent.height - point.y),
                         forKey: kCIInputCenterKey)
        filter?.setValue(radius, forKey: kCIInputRadiusKey)
        filter?.setValue(scale, forKey: kCIInputScaleKey)
        return filter?.outputImage?.cropped(to: image.extent) ?? image
    }

    private static func bump(_ image: CIImage,
                             at point: CGPoint,
                             radius: CGFloat,
                             scale: CGFloat) -> CIImage {
        guard scale > 0.01, radius > 2 else { return image }
        let filter = CIFilter(name: "CIBumpDistortion")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(x: point.x, y: image.extent.height - point.y),
                         forKey: kCIInputCenterKey)
        filter?.setValue(radius, forKey: kCIInputRadiusKey)
        filter?.setValue(scale, forKey: kCIInputScaleKey)
        return filter?.outputImage?.cropped(to: image.extent) ?? image
    }

    // MARK: - Sfondo

    /// Sfondo ritratto: la maschera di segmentazione persona separa il
    /// soggetto dallo sfondo (sfocato e/o in bianco e nero).
    private static func applyBackground(_ image: CIImage,
                                        faces: [FaceData],
                                        blur: Double,
                                        mono: Double) -> CIImage {
        let size = image.extent.size
        let person = faces.compactMap { $0.personMask }.first
            ?? backgroundMask(for: faces, size: size,
                              feather: max(12, size.width * 0.02))
        let subject = feathered(person, radius: 2)
        var result = image

        if blur > 0 {
            let radius = (8.0 + 26.0 * blur) * max(1.0, size.width / 1400)
            let blurred = result.blurred(radius: radius)
            result = blend(base: blurred, top: result, mask: subject)
        }

        if mono > 0 {
            let invert = CIFilter.colorInvert()
            invert.inputImage = subject
            let outside = invert.outputImage ?? subject
            let desat = colorAdjust(result, brightness: 0,
                                    saturation: 0, contrast: 1.02)
            let top = result.blending(image: desat, amount: CGFloat(0.95 * mono))
            result = blend(base: result, top: top, mask: outside)
        }

        return result
    }

    // MARK: - Luce

    private static func applyPortraitLight(_ image: CIImage,
                                           faces: [FaceData],
                                           amount: Double) -> CIImage {
        guard let first = faces.first else { return image }
        // Il gradiente vive nello spazio CoreImage (origine basso-sinistra):
        // la quota del volto va convertita.
        let centerY = image.extent.height -
            (first.box.minY + first.faceHeight * 0.35)
        let center = CGPoint(x: first.box.midX, y: centerY)
        let radius = max(first.faceWidth, first.faceHeight) * 0.9

        let gradient = CIFilter.radialGradient()
        gradient.center = center
        // CIRadialGradient non ha "inputRadius": usa radius0 (nocciolo) e
        // radius1 (fine sfumatura).
        gradient.radius0 = Float(radius * 0.55)
        gradient.radius1 = Float(radius * 1.35)
        gradient.color0 = CIColor(red: 1, green: 0.98, blue: 0.92, alpha: 1)
        gradient.color1 = CIColor(red: 1, green: 0.98, blue: 0.92, alpha: 0)

        let soft = CIFilter.softLightBlendMode()
        soft.inputImage = gradient.outputImage!.cropped(to: image.extent)
        soft.backgroundImage = image
        let lit = soft.outputImage ?? image
        return image.blending(image: lit, amount: CGFloat(amount * 0.45))
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

    /// Fusione con un blend mode nominato (chiavi legali: inputImage,
    /// inputBackgroundImage).
    private static func blendNamed(_ mode: String,
                                   top: CIImage,
                                   base: CIImage) -> CIImage {
        let filter = CIFilter(name: mode)
        filter?.setValue(top, forKey: kCIInputImageKey)
        filter?.setValue(base, forKey: kCIInputBackgroundImageKey)
        return filter?.outputImage?.cropped(to: base.extent) ?? base
    }

    // MARK: - Maschere (render CoreGraphics, bianco su nero, spazio alto-sinistra)

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
        // CoreImage (origine basso-sinistra) vs CGContext (origine alto-sinistra):
        // ribaltiamo la maschera per allinearla ai landmark.
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

    /// Maschera di pelle: contorno pieno meno occhi, sopracciglia, labbra e
    /// narici (levigatura e trucco rispettano i tratti del volto).
    private static func skinMask(for faces: [FaceData],
                                 size: CGSize,
                                 feather: CGFloat) -> CIImage {
        let mask = maskImage(size: size) { context in
            fillPolygons(context, polygons: faces.map { $0.contour }, alpha: 1)
            context.setFillColor(gray: 0, alpha: 1)
            for face in faces {
                for center in [face.leftEye, face.rightEye] {
                    let r = face.eyeWidth * 0.80
                    context.fillEllipse(in: CGRect(x: center.x - r,
                                                   y: center.y - r * 0.7,
                                                   width: r * 2,
                                                   height: r * 1.4))
                }
                fillPolygons(context,
                             polygons: [face.leftEyebrowPolygon,
                                        face.rightEyebrowPolygon],
                             alpha: 1)
                fillPolygons(context, polygons: [face.lips], alpha: 1)
                let nr = max(2, face.eyeWidth * 0.30)
                context.fillEllipse(in: CGRect(x: face.noseTip.x - nr,
                                               y: face.noseTip.y - nr * 0.55,
                                               width: nr * 2,
                                               height: nr * 1.1))
            }
        }
        return feathered(mask, radius: feather)
    }

    /// Maschera iridi: ellissi centrare sugli occhi.
    private static func irisMask(for faces: [FaceData],
                                 size: CGSize,
                                 feather: CGFloat) -> CIImage {
        let mask = maskImage(size: size) { context in
            context.setFillColor(gray: 1, alpha: 1)
            for face in faces {
                for center in [face.leftEye, face.rightEye] {
                    let rx = face.eyeWidth * 0.60
                    let ry = face.eyeWidth * 0.45
                    context.fillEllipse(in: CGRect(x: center.x - rx,
                                                   y: center.y - ry,
                                                   width: rx * 2,
                                                   height: ry * 2))
                }
            }
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
                    context.fillEllipse(in: CGRect(x: center.x - radius,
                                                   y: center.y - radius * 0.7,
                                                   width: radius * 2,
                                                   height: radius * 1.4))
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
                CGPoint(x: center.x + (point.x - center.x) * 0.50,
                        y: center.y + (point.y - center.y) * 0.50)
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
            let shade = makeupTone(shade: controls.foundationShade)
            let soft = blendNamed("CISoftLightBlendMode", top: shade, base: result)
            let top = result.blending(image: soft,
                                      amount: CGFloat(0.55 * controls.foundation))
            result = blend(base: result, top: top, mask: mask)
        }

        if controls.contour > 0 {
            let mask = contourMask(for: faces, size: size,
                                   feather: max(6, size.width * 0.004))
            let shade = makeupTone(shade: .marrone)
            let multiply = blendNamed("CIMultiplyBlendMode", top: shade, base: result)
            let top = result.blending(image: multiply,
                                      amount: CGFloat(0.38 * controls.contour))
            result = blend(base: result, top: top, mask: mask)
        }

        if controls.blush > 0 {
            let mask = blushMask(for: faces, size: size,
                                 feather: max(10, size.width * 0.008))
            let shade = makeupTone(shade: controls.blushShade)
            let soft = blendNamed("CISoftLightBlendMode", top: shade, base: result)
            let top = result.blending(image: soft,
                                      amount: CGFloat(0.65 * controls.blush))
            result = blend(base: result, top: top, mask: mask)
        }

        if controls.eyeshadow > 0 {
            let mask = eyeshadowMask(for: faces, size: size,
                                     feather: max(3, size.width * 0.0035))
            let shade = makeupTone(shade: controls.eyeshadowShade)
            let multiply = blendNamed("CIMultiplyBlendMode", top: shade, base: result)
            let soft = blendNamed("CISoftLightBlendMode", top: multiply, base: result)
            let top = result.blending(image: soft,
                                      amount: CGFloat(0.70 * controls.eyeshadow))
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
            let shade = makeupTone(shade: controls.lipstickShade)
            // Moltiplicazione per il colore + soft-light per il velo: le
            // labbra mantengono la texture e prendono la tonalita'.
            let multiply = blendNamed("CIMultiplyBlendMode", top: shade, base: result)
            let soft = blendNamed("CISoftLightBlendMode", top: shade, base: multiply)
            let top = result.blending(image: soft,
                                      amount: CGFloat(0.80 * controls.lipstick))
            result = blend(base: result, top: top, mask: mask)
        }

        return result
    }

    /// Immagine tinta con la sfumatura indicata.
    private static func makeupTone(shade: MakeupShade) -> CIImage {
        let (r, g, b) = shade.rgb
        return CIImage(color: CIColor(red: r, green: g, blue: b))
    }

    /// Velatura di un colore sull'immagine (eyeliner e ritocchi piatti).
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
                for center in [face.cheekboneLeftOrFallback,
                               face.cheekboneRightOrFallback] {
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

    /// Sfondo di riserva: bianco ovunque tranne ellissi dei volti.
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
