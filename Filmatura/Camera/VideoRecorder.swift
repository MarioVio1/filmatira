import AVFoundation
import CoreImage
import Foundation

/// Registra video H.264 con i buffer gia' elaborati dal grading live,
/// piu' audio AAC dalla sessione di cattura.
final class VideoRecorder {

    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let audioInput: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let pool: CVPixelBufferPool?
    private let context = CIContext(options: [.cacheIntermediates: false])

    private let lock = NSLock()
    private var sessionStarted = false
    private var startTime: CMTime?
    private var finished = false
    private let url: URL

    private static let width = 1080
    private static let height = 1920

    init(url: URL) throws {
        self.url = url
        try? FileManager.default.removeItem(at: url)

        writer = try AVAssetWriter(outputURL: url, fileType: .mov)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264.rawValue,
            AVVideoWidthKey: Self.width,
            AVVideoHeightKey: Self.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 9_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ]
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true

        let bufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Self.width,
            kCVPixelBufferHeightKey as String: Self.height,
        ]
        adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: bufferAttributes)
        pool = adaptor.pixelBufferPool

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true

        if writer.canAdd(videoInput) { writer.add(videoInput) }
        if writer.canAdd(audioInput) { writer.add(audioInput) }
        writer.startWriting()
    }

    /// Restituisce un buffer dal pool per il rendering del frame elaborato.
    func dequeueBuffer() -> CVPixelBuffer? {
        if let pool {
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            return buffer
        }
        var buffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Self.width,
            kCVPixelBufferHeightKey as String: Self.height,
        ]
        CVPixelBufferCreate(nil, Self.width, Self.height,
                            kCVPixelFormatType_32BGRA, attrs as CFDictionary, &buffer)
        return buffer
    }

    /// Renderizza l'immagine elaborata nel buffer e la aggiunge al registro.
    func renderAndAppend(_ image: CIImage, at time: CMTime) {
        guard let buffer = dequeueBuffer() else { return }
        context.render(image,
                       to: buffer,
                       bounds: CGRect(x: 0, y: 0,
                                      width: Self.width, height: Self.height),
                       colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        appendVideo(buffer, at: time)
    }

    func appendVideo(_ buffer: CVPixelBuffer, at time: CMTime) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }

        if !sessionStarted {
            startTime = time
            writer.startSession(atSourceTime: time)
            sessionStarted = true
        }
        if videoInput.isReadyForMoreMediaData {
            adaptor.append(buffer, withPresentationTime: time)
        }
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished, sessionStarted else { return }
        if audioInput.isReadyForMoreMediaData {
            audioInput.append(sampleBuffer)
        }
    }

    /// Completa la scrittura; completion arriva su una coda arbitraria.
    func finish(_ completion: @escaping (URL) -> Void) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            completion(url)
            return
        }
        finished = true
        lock.unlock()

        videoInput.markAsFinished()
        audioInput.markAsFinished()
        writer.finishWriting {
            completion(self.url)
        }
    }
}
