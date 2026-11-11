import Vision
import CoreGraphics
import UIKit

/// Analisi dei volti con Vision: bounding box e landmark convertiti in
/// coordinate pixel con origine in alto a sinistra (spazio UIKit/CoreImage).
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
    /// Poligoni degli occhi (per ombretto ed eyeliner).
    let leftEyePolygon: [CGPoint]
    let rightEyePolygon: [CGPoint]
    /// Poligoni delle sopracciglia (limite superiore dell'ombretto).
    let leftEyebrowPolygon: [CGPoint]
    let rightEyebrowPolygon: [CGPoint]

    var faceWidth: CGFloat { box.width }
    var faceHeight: CGFloat { box.height }

    /// Centro della mandibola sinistra/destra (frazione del box).
    var jawPointLeft: CGPoint {
        CGPoint(x: box.minX + box.width * 0.12,
                y: box.minY + box.height * 0.80)
    }
    var jawPointRight: CGPoint {
        CGPoint(x: box.minX + box.width * 0.88,
                y: box.minY + box.height * 0.80)
    }
    var cheekPointLeft: CGPoint {
        CGPoint(x: box.minX + box.width * 0.22,
                y: box.minY + box.height * 0.52)
    }
    var cheekPointRight: CGPoint {
        CGPoint(x: box.minX + box.width * 0.78,
                y: box.minY + box.height * 0.52)
    }
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
}

/// Rilevamento volti (VNDetectFaceLandmarksRequest), on-device.
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
        return observations.compactMap { face(from: $0, imageSize: CGSize(width: cgImage.width, height: cgImage.height)) }
    }

    static func detectFaces(in image: UIImage) -> [FaceData] {
        guard let cg = image.normalizedCGImage() else { return [] }
        return detectFaces(in: cg)
    }

    // MARK: - Conversione coordinate

    /// Vision usa coordinate normalizzate con origine in basso a sinistra.
    /// Converte un punto nello spazio pixel alto-sinistra.
    private static func toPixel(_ normalized: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: normalized.x * size.width,
                y: (1 - normalized.y) * size.height)
    }

    private static func face(from observation: VNFaceObservation,
                             imageSize: CGSize) -> FaceData? {
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
                        rightEyebrowPolygon: rightEyebrowPolygon)
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
