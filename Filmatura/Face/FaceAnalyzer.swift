import Vision
import CoreImage
import CoreGraphics
import UIKit

/// Analisi dei volti con Vision: bounding box, landmark, geometria derivata
/// e maschera di segmentazione persona. Le coordinate sono in pixel con
/// origine in alto a sinistra (spazio UIKit/CoreGraphics).
struct FaceData: Identifiable {

    let id: UUID
    /// Bounding box in pixel, origine alto-sinistra.
    let box: CGRect
    /// Contorno del volto (punti pixel).
    let contour: [CGPoint]
    /// Poligono esterno delle labbra (punti pixel).
    let lips: [CGPoint]
    /// Centri degli occhi.
    let leftEye: CGPoint
    let rightEye: CGPoint
    /// Larghezza dell'occhio in pixel (per raggio maschere).
    let eyeWidth: CGFloat
    /// Poligoni degli occhi (per ombretto, eyeliner e colore occhi).
    let leftEyePolygon: [CGPoint]
    let rightEyePolygon: [CGPoint]
    /// Poligoni delle sopracciglia (limite superiore dell'ombretto).
    let leftEyebrowPolygon: [CGPoint]
    let rightEyebrowPolygon: [CGPoint]
    /// Punta del naso, ali del naso (da Vision, con fallback sul box).
    let noseTip: CGPoint
    let noseAlaeLeft: CGPoint
    let noseAlaeRight: CGPoint
    /// Angoli della bocca (punto piu' a sinistra/destra del poligono labbra).
    let mouthCornerLeft: CGPoint
    let mouthCornerRight: CGPoint
    /// Maschera di segmentazione persona (bianco = persona), usata per lo
    /// sfondo ritratto. Calcolata una sola volta per foto.
    let personMask: CIImage?

    var faceWidth: CGFloat { box.width }
    var faceHeight: CGFloat { box.height }

    // MARK: - Geometria derivata (tutte in spazio alto-sinistra)

    var mouthCenter: CGPoint {
        guard !lips.isEmpty else {
            return CGPoint(x: box.midX, y: box.minY + box.height * 0.68)
        }
        let sum = lips.reduce(CGPoint.zero) {
            CGPoint(x: $0.x + $1.x, y: $0.y + $1.y)
        }
        return CGPoint(x: sum.x / CGFloat(lips.count),
                       y: sum.y / CGFloat(lips.count))
    }

    var eyeMidY: CGFloat {
        (leftEye.y + rightEye.y) / 2
    }

    /// Punto piu' basso del contorno (punta del mento).
    var chinPoint: CGPoint {
        if let lowest = contour.max(by: { $0.y < $1.y }) {
            return lowest
        }
        return CGPoint(x: box.midX, y: box.maxY)
    }

    /// Quota y intermedia tra occhi e bocca, usata per zigomi e guance.
    private func faceY(fraction: CGFloat) -> CGFloat {
        eyeMidY + (mouthCenter.y - eyeMidY) * fraction
    }

    /// Cerca sul contorno i punti estremi (sinistra/destra) alla quota y data.
    /// Torna nil se il contorno e' assente o la quota cade fuori dal volto.
    func contourEdge(nearY y: CGFloat) -> (left: CGPoint, right: CGPoint)? {
        guard contour.count > 4 else { return nil }
        let band = max(6, faceHeight * 0.07)
        let inBand = contour.filter { abs($0.y - y) <= band }
        guard inBand.count >= 2,
              let leftmost = inBand.min(by: { $0.x < $1.x }),
              let rightmost = inBand.max(by: { $0.x < $1.x }) else {
            return nil
        }
        return (leftmost, rightmost)
    }

    private func edge(atFraction fraction: CGFloat) -> (left: CGPoint, right: CGPoint)? {
        contourEdge(nearY: faceY(fraction: fraction))
    }

    /// Zigomi: quota tra occhi e bocca, verso l'alto (rilievo pomelli).
    var cheekboneLeft: CGPoint? { edge(atFraction: 0.30)?.left }
    var cheekboneRight: CGPoint? { edge(atFraction: 0.30)?.right }

    /// Guance: quota centrale (pinch per snellire).
    var cheekSlimLeft: CGPoint? { edge(atFraction: 0.52)?.left }
    var cheekSlimRight: CGPoint? { edge(atFraction: 0.52)?.right }

    /// Mandibola: poco sotto gli angoli della bocca.
    var jawLeft: CGPoint? {
        let y = mouthCornerLeft.y + (chinPoint.y - mouthCornerLeft.y) * 0.12
        return contourEdge(nearY: y)?.left
    }
    var jawRight: CGPoint? {
        let y = mouthCornerRight.y + (chinPoint.y - mouthCornerRight.y) * 0.12
        return contourEdge(nearY: y)?.right
    }

    /// Fallback geometrico per gli zigomi quando il contorno manca.
    private var fallbackCheekbone: (left: CGPoint, right: CGPoint) {
        (CGPoint(x: box.minX + box.width * 0.24, y: faceY(fraction: 0.30)),
         CGPoint(x: box.maxX - box.width * 0.24, y: faceY(fraction: 0.30)))
    }
    private var fallbackCheekSlim: (left: CGPoint, right: CGPoint) {
        (CGPoint(x: box.minX + box.width * 0.26, y: faceY(fraction: 0.52)),
         CGPoint(x: box.maxX - box.width * 0.26, y: faceY(fraction: 0.52)))
    }
    var cheekboneLeftOrFallback: CGPoint { cheekboneLeft ?? fallbackCheekbone.left }
    var cheekboneRightOrFallback: CGPoint { cheekboneRight ?? fallbackCheekbone.right }
    var cheekSlimLeftOrFallback: CGPoint { cheekSlimLeft ?? fallbackCheekSlim.left }
    var cheekSlimRightOrFallback: CGPoint { cheekSlimRight ?? fallbackCheekSlim.right }
}

/// Rilevamento volti (VNDetectFaceLandmarksRequest) e segmentazione persona
/// (VNGeneratePersonSegmentationRequest), tutto on-device.
enum FaceAnalyzer {

    static func detectFaces(in cgImage: CGImage) -> [FaceData] {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        var observations: [VNFaceObservation] = []
        do {
            try handler.perform([request])
            observations = (request.results as? [VNFaceObservation]) ?? []
        } catch {
            observations = []
        }
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let mask = personSegmentation(in: cgImage, imageSize: imageSize)
        return observations.compactMap {
            face(from: $0, imageSize: imageSize, personMask: mask)
        }
    }

    static func detectFaces(in image: UIImage) -> [FaceData] {
        guard let cg = image.normalizedCGImage() else { return [] }
        return detectFaces(in: cg)
    }

    // MARK: - Segmentazione persona

    /// Maschera bianco/nero dove bianco = persona. Qualita' bilanciata per
    /// restare rapida in fase di analisi; viene poi riscalata all'immagine.
    private static func personSegmentation(in cgImage: CGImage,
                                           imageSize: CGSize) -> CIImage? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? handler.perform([request])) != nil,
              let buffer = (request.results as? [VNPersonSegmentationObservation])?
                  .first?.mask else {
            return nil
        }
        let maskImage = CIImage(cvPixelBuffer: buffer)
        let maskSize = maskImage.extent.size
        guard maskSize.width > 1, maskSize.height > 1 else { return nil }
        let scaleX = imageSize.width / maskSize.width
        let scaleY = imageSize.height / maskSize.height
        let scaled = maskImage.transformed(
            by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .cropped(to: CGRect(origin: .zero, size: imageSize))
        return scaled
    }

    // MARK: - Conversione coordinate

    /// Vision usa coordinate normalizzate con origine in basso a sinistra.
    /// Converte un punto nello spazio pixel alto-sinistra.
    private static func toPixel(_ normalized: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: normalized.x * size.width,
                y: (1 - normalized.y) * size.height)
    }

    private static func face(from observation: VNFaceObservation,
                             imageSize: CGSize,
                             personMask: CIImage?) -> FaceData? {
        let bb = observation.boundingBox
        let box = CGRect(
            x: bb.origin.x * imageSize.width,
            y: (1 - bb.origin.y - bb.height) * imageSize.height,
            width: bb.width * imageSize.width,
            height: bb.height * imageSize.height)

        guard let landmarks = observation.landmarks else { return nil }
        let id = observation.uuid

        let contour = landmarks.faceContour?.pointsInImage(imageSize: imageSize).map {
            toPixel($0, size: imageSize)
        } ?? []

        let lips = landmarks.outerLips?.pointsInImage(imageSize: imageSize).map {
            toPixel($0, size: imageSize)
        } ?? []

        let leftEyeRegion = landmarks.leftEye
        let rightEyeRegion = landmarks.rightEye
        let leftEye = center(of: leftEyeRegion, imageSize: imageSize)
            ?? CGPoint(x: box.midX, y: box.midY)
        let rightEye = center(of: rightEyeRegion, imageSize: imageSize)
            ?? CGPoint(x: box.midX, y: box.midY)
        let eyeWidth = max(
            max(width(of: leftEyeRegion, imageSize: imageSize),
                width(of: rightEyeRegion, imageSize: imageSize)),
            box.width * 0.15)

        let leftEyePolygon = landmarks.leftEye?.pointsInImage(imageSize: imageSize).map {
            toPixel($0, size: imageSize)
        } ?? []
        let rightEyePolygon = landmarks.rightEye?.pointsInImage(imageSize: imageSize).map {
            toPixel($0, size: imageSize)
        } ?? []
        let leftEyebrowPolygon = landmarks.leftEyebrow?.pointsInImage(imageSize: imageSize).map {
            toPixel($0, size: imageSize)
        } ?? []
        let rightEyebrowPolygon = landmarks.rightEyebrow?.pointsInImage(imageSize: imageSize).map {
            toPixel($0, size: imageSize)
        } ?? []

        // Naso: punta dal crest (ultima quota piu' bassa), ali dal poligono.
        let nose = geometry(of: landmarks.nose, imageSize: imageSize)
        let crest = geometry(of: landmarks.noseCrest, imageSize: imageSize)
        let noseTip = crest.points.map { $0.y }.max().flatMap { maxY in
            crest.points.filter { $0.y >= maxY - 1 }.min(by: { $0.x < $1.x })
        } ?? nose.points.max(by: { $0.y < $1.y })
        ?? CGPoint(x: box.midX, y: box.minY + box.height * 0.60)

        let alaeCandidates = nose.points.filter {
            $0.y > leftEye.y + (noseTip.y - leftEye.y) * 0.55
        }
        let alaeLeft = alaeCandidates.min(by: { $0.x < $1.x })
            ?? CGPoint(x: noseTip.x - box.width * 0.09, y: noseTip.y)
        let alaeRight = alaeCandidates.max(by: { $0.x < $1.x })
            ?? CGPoint(x: noseTip.x + box.width * 0.09, y: noseTip.y)

        // Angoli bocca dal poligono labbra.
        let cornerLeft = lips.min(by: { $0.x < $1.x })
            ?? CGPoint(x: box.midX - box.width * 0.10, y: box.minY + box.height * 0.68)
        let cornerRight = lips.max(by: { $0.x < $1.x })
            ?? CGPoint(x: box.midX + box.width * 0.10, y: box.minY + box.height * 0.68)

        return FaceData(id: id,
                        box: box,
                        contour: contour,
                        lips: lips,
                        leftEye: leftEye,
                        rightEye: rightEye,
                        eyeWidth: eyeWidth,
                        leftEyePolygon: leftEyePolygon,
                        rightEyePolygon: rightEyePolygon,
                        leftEyebrowPolygon: leftEyebrowPolygon,
                        rightEyebrowPolygon: rightEyebrowPolygon,
                        noseTip: noseTip,
                        noseAlaeLeft: alaeLeft,
                        noseAlaeRight: alaeRight,
                        mouthCornerLeft: cornerLeft,
                        mouthCornerRight: cornerRight,
                        personMask: personMask)
    }

    private static func geometry(of region: VNFaceLandmarkRegion2D?,
                                 imageSize: CGSize) -> (points: [CGPoint], center: CGPoint?) {
        guard let region else { return ([], nil) }
        let points = region.pointsInImage(imageSize: imageSize).map {
            toPixel($0, size: imageSize)
        }
        let sum = points.reduce(CGPoint.zero) {
            CGPoint(x: $0.x + $1.x, y: $0.y + $1.y)
        }
        let center = points.isEmpty
            ? nil
            : CGPoint(x: sum.x / CGFloat(points.count),
                      y: sum.y / CGFloat(points.count))
        return (points, center)
    }

    private static func center(of region: VNFaceLandmarkRegion2D?,
                               imageSize: CGSize) -> CGPoint? {
        guard let region else { return nil }
        let points = region.pointsInImage(imageSize: imageSize)
        guard !points.isEmpty else { return nil }
        let sum = points.reduce(CGPoint.zero) {
            CGPoint(x: $0.x + $1.x, y: $0.y + $1.y)
        }
        return toPixel(CGPoint(x: sum.x / CGFloat(points.count),
                               y: sum.y / CGFloat(points.count)),
                       size: imageSize)
    }

    private static func width(of region: VNFaceLandmarkRegion2D?,
                              imageSize: CGSize) -> CGFloat {
        guard let region else { return 0 }
        let points = region.pointsInImage(imageSize: imageSize)
        guard points.count > 1,
              let minX = points.map({ $0.x }).min(),
              let maxX = points.map({ $0.x }).max() else { return 0 }
        return (maxX - minX) * imageSize.width
    }
}

extension CGSize {
    var midPoint: CGPoint {
        CGPoint(x: width / 2, y: height / 2)
    }
}

extension CGPoint {
    func scaled(by factor: CGFloat) -> CGPoint {
        CGPoint(x: x * factor, y: y * factor)
    }
}

extension UIImage {
    /// CGImage orientato correttamente (UIKit ruota le foto EXIF).
    func normalizedCGImage() -> CGImage? {
        if imageOrientation == .up, let cg = cgImage { return cg }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()?.cgImage
    }
}
