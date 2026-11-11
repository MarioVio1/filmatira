import AVFoundation
import CoreImage
import UIKit

/// Controller della fotocamera: sessione AVFoundation, preview con grading
/// live, scatto foto a piena risoluzione e registrazione video con LUT
/// applicato in tempo reale sui buffer (H.264 + audio AAC).
///
/// Disciplina di thread: le proprieta' @Published vengono toccate solo dal
/// main thread (i callback AVFoundation reinviano con Task { @MainActor });
/// lo stato di grading condiviso col thread di elaborazione e' protetto da
/// NSLock. La classe resta senza annotazioni di attore per interoperare con
/// i callback sincroni di AVFoundation.
final class CameraController: NSObject, ObservableObject {

    enum Status: Equatable {
        case idle
        case running
        case unauthorized
    }

    // MARK: - Stato osservabile (main thread)

    @Published var status: Status = .idle
    @Published var currentPreset: LUTPreset? = LUTCatalog.preset(withID: "proiezione")
    @Published var intensity: Double = 1.0
    @Published var isRecording = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var torchOn = false
    @Published var showingGrid = false
    @Published var position: AVCaptureDevice.Position = .back
    @Published var zoomFactor: CGFloat = 1.0
    @Published var errorMessage: String?

    /// Chiamato sul main thread quando una foto elaborata e' pronta.
    var onPhotoCaptured: ((MediaItem) -> Void)?

    // MARK: - Interni

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "filmatura.session")
    private let processingQueue = DispatchQueue(label: "filmatura.processing", qos: .userInteractive)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var recorder: VideoRecorder?
    private var isConfigured = false

    /// Renderer della preview Metal (collegato dalla CameraScreen).
    var previewRenderer: PreviewRenderer?

    /// Stato di grading condiviso col thread di elaborazione (protetto).
    private let gradingLock = NSLock()
    private var gradingPresetID: String?
    private var gradingIntensity: Double = 1.0

    private var recorderRef: VideoRecorder? {
        get { recorderQueue.sync { recorderStorage } }
        set { recorderQueue.async { self.recorderStorage = newValue } }
    }
    private let recorderQueue = DispatchQueue(label: "filmatura.recorder")
    private var recorderStorage: VideoRecorder?
    /// Vero mentre l'utente sta registrando (accesso thread-safe).
    private let recordingLock = NSLock()
    private var recordingFlag = false

    private let mediaStore = MediaStore.shared

    // MARK: - Avvio / arresto

    func start() {
        checkAuthorization { [weak self] granted in
            guard let self else { return }
            guard granted else {
                DispatchQueue.main.async { self.status = .unauthorized }
                return
            }
            self.configureSessionIfNeeded()
            self.sessionQueue.async {
                if !self.session.isRunning {
                    self.session.startRunning()
                }
            }
            DispatchQueue.main.async { self.status = .running }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func checkAuthorization(_ completion: @escaping (Bool) -> Void) {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        switch cameraStatus {
        case .authorized:
            if micStatus == .notDetermined {
                AVCaptureDevice.requestAccess(for: .audio) { _ in completion(true) }
            } else {
                completion(true)
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        default:
            completion(false)
        }
    }

    private func configureSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self, !self.isConfigured else { return }
            self.isConfigured = true
            let session = self.session

            session.beginConfiguration()
            session.sessionPreset = .photo

            // ingresso video (posteriore di default)
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                if let input = try? AVCaptureDeviceInput(device: device),
                   session.canAddInput(input) {
                    session.addInput(input)
                    self.videoDeviceInput = input
                }
            }

            // foto
            if session.canAddOutput(self.photoOutput) {
                session.addOutput(self.photoOutput)
                self.photoOutput.maxPhotoQualityPrioritization = .quality
                self.updateConnectionOrientation(for: self.photoOutput.connections)
            }

            // video (buffer per il grading live)
            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.setSampleBufferDelegate(self, queue: self.processingQueue)
            if session.canAddOutput(self.videoOutput) {
                session.addOutput(self.videoOutput)
            }

            // audio
            self.audioOutput.setSampleBufferDelegate(self, queue: self.processingQueue)
            if session.canAddOutput(self.audioOutput) {
                session.addOutput(self.audioOutput)
            }
            if let mic = AVCaptureDevice.default(for: .audio),
               let input = try? AVCaptureDeviceInput(device: mic),
               session.canAddInput(input) {
                session.addInput(input)
            }

            session.commitConfiguration()
            self.updateConnectionOrientation(for: self.videoOutput.connections)
        }
    }

    private func updateConnectionOrientation(for connections: [AVCaptureConnection]) {
        let mirrored = position == .front
        for connection in connections {
            if connection.isVideoOrientationSupported {
                if #available(iOS 17.0, *) {
                    connection.videoRotationAngle = 90
                } else {
                    connection.videoOrientation = .portrait
                }
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = mirrored
            }
        }
    }

    // MARK: - Controlli

    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let newPosition: AVCaptureDevice.Position = self.position == .back ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video, position: newPosition),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }

            let session = self.session
            session.beginConfiguration()
            if let old = self.videoDeviceInput {
                session.removeInput(old)
            }
            if session.canAddInput(input) {
                session.addInput(input)
                self.videoDeviceInput = input
            } else if let old = self.videoDeviceInput {
                session.addInput(old)
            }
            session.commitConfiguration()

            DispatchQueue.main.async {
                self.position = newPosition
                self.zoomFactor = 1.0
                if self.torchOn { self.toggleTorch() }
            }
            self.updateConnectionOrientation(for: self.videoOutput.connections)
            self.updateConnectionOrientation(for: self.photoOutput.connections)
        }
    }

    func setZoom(_ factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                let clamped = max(1.0, min(factor, device.activeFormat.videoMaxZoomFactor))
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
                DispatchQueue.main.async { self.zoomFactor = clamped }
            } catch {
                DispatchQueue.main.async { self.errorMessage = "Zoom non disponibile." }
            }
        }
    }

    func focus(at point: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func toggleTorch() {
        let on = !torchOn
        guard position == .back, let device = videoDeviceInput?.device, device.hasTorch else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.torchMode = on ? .on : .off
                device.unlockForConfiguration()
                DispatchQueue.main.async { self.torchOn = on }
            } catch {}
        }
    }

    // MARK: - Foto

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }
        settings.photoQualityPrioritization = .quality
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Video

    func startRecording() {
        let url = mediaStore.newVideoURL()
        do {
            let recorder = try VideoRecorder(url: url)
            recorderRef = recorder
            recordingLock.lock()
            recordingFlag = true
            recordingLock.unlock()
            DispatchQueue.main.async { self.isRecording = true }
        } catch {
            DispatchQueue.main.async { self.errorMessage = "Impossibile avviare la registrazione." }
        }
    }

    func stopRecording() {
        recordingLock.lock()
        recordingFlag = false
        recordingLock.unlock()
        DispatchQueue.main.async { self.isRecording = false }

        guard let recorder = recorderRef else { return }
        recorderRef = nil
        let presetName = gradingPresetID.flatMap { LUTCatalog.preset(withID: $0)?.name }
        recorder.finish { [weak self] url in
            guard let self else { return }
            DispatchQueue.main.async {
                self.mediaStore.saveVideo(at: url, presetName: presetName)
            }
        }
    }

    // MARK: - Stato di grading condiviso

    /// Sincronizza le impostazioni correnti col thread di elaborazione.
    /// Da chiamare sul main thread quando cambiano preset o intensita'.
    func syncGradingState() {
        gradingLock.lock()
        gradingPresetID = currentPreset?.id
        gradingIntensity = intensity
        gradingLock.unlock()
    }

    private func snapshotGrading() -> (LUTPreset?, Double) {
        gradingLock.lock()
        defer { gradingLock.unlock() }
        let preset = gradingPresetID.flatMap(LUTCatalog.preset(withID:))
        return (preset, gradingIntensity)
    }

    private func isRecordingNow() -> Bool {
        recordingLock.lock()
        defer { recordingLock.unlock() }
        return recordingFlag
    }
}

// MARK: - Foto delegate

extension CameraController: AVCapturePhotoCaptureDelegate {

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
            return
        }
        guard let cgImage = photo.cgImageRepresentation() else { return }
        let (preset, intensity) = snapshotGrading()

        processingQueue.async { [weak self] in
            let ciImage = CIImage(cgImage: cgImage)
            let graded = ImagePipeline.graded(image: ciImage, preset: preset, intensity: intensity)
            let image = graded.rendered(maxDimension: 4096)
            guard let data = image.jpegData(compressionQuality: 0.95) else { return }
            DispatchQueue.main.async {
                if let item = self?.mediaStore.savePhotoData(data, presetName: preset?.name) {
                    self?.onPhotoCaptured?(item)
                }
            }
        }
    }
}

// MARK: - Buffer video e audio

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate,
                            AVCaptureAudioDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        if output is AVCaptureAudioDataOutput {
            recorderRef?.appendAudio(sampleBuffer)
            return
        }

        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let (preset, intensity) = snapshotGrading()
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let graded = ImagePipeline.graded(image: image, preset: preset, intensity: intensity)

        if isRecordingNow(), let recorder = recorderRef {
            recorder.renderAndAppend(graded, at: time)
        }
        previewRenderer?.enqueue(graded)
    }
}
