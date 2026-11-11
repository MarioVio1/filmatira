import AVFoundation
import Photos
import SwiftUI
import UIKit

/// Alias comodo per il tipo annidato MediaStore.MediaItem.
typealias MediaItem = MediaStore.MediaItem

/// Archivio locale dei media di Filmatura (Documents/Media).
/// Nessuna sincronizzazione con servizi esterni: tutto resta sul device.
final class MediaStore: ObservableObject {

    struct MediaItem: Identifiable, Hashable {
        enum Kind { case photo, video }

        let id: UUID
        let url: URL
        let kind: Kind
        let date: Date
        let presetName: String?
        var thumbnail: UIImage?

        // Hashable manuale: la thumbnail (UIImage, non Hashable) non entra
        // nell'identita' del media; serve a navigationDestination(item:).
        static func == (lhs: MediaItem, rhs: MediaItem) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    static let shared = MediaStore()

    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var isLoading = false

    private let directory: URL
    private let thumbnailCache = NSCache<NSString, UIImage>()

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = docs.appendingPathComponent("Media", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true)
    }

    // MARK: - Percorsi

    func newVideoURL() -> URL {
        directory.appendingPathComponent("\(UUID().uuidString).mov")
    }

    // MARK: - Salvataggio

    @discardableResult
    func savePhotoData(_ data: Data, presetName: String?) -> MediaItem? {
        let id = UUID()
        let url = directory.appendingPathComponent("\(id.uuidString).jpg")
        do {
            try data.write(to: url, options: .atomic)
            let item = MediaItem(id: id, url: url, kind: .photo, date: Date(),
                                 presetName: presetName, thumbnail: nil)
            DispatchQueue.main.async {
                self.items.insert(item, at: 0)
            }
            return item
        } catch {
            return nil
        }
    }

    @discardableResult
    func saveImage(_ image: UIImage, presetName: String?) -> MediaItem? {
        guard let data = image.jpegData(compressionQuality: 0.95) else { return nil }
        return savePhotoData(data, presetName: presetName)
    }

    @discardableResult
    func saveVideo(at url: URL, presetName: String?) -> MediaItem? {
        let id = UUID()
        let destination = directory.appendingPathComponent("\(id.uuidString).mov")
        do {
            try FileManager.default.moveItem(at: url, to: destination)
            let item = MediaItem(id: id, url: destination, kind: .video, date: Date(),
                                 presetName: presetName, thumbnail: nil)
            DispatchQueue.main.async {
                self.items.insert(item, at: 0)
            }
            return item
        } catch {
            return nil
        }
    }

    @discardableResult
    func importImage(_ image: UIImage) -> MediaItem? {
        saveImage(image, presetName: nil)
    }

    // MARK: - Lettura

    func loadAll() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let urls = (try? FileManager.default.contentsOfDirectory(at: self.directory,
                                                                     includingPropertiesForKeys: [.creationDateKey])) ?? []
            let loaded: [MediaItem] = urls.compactMap { url in
                let ext = url.pathExtension.lowercased()
                guard ext == "jpg" || ext == "mov" else { return nil }
                let date = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()
                return MediaItem(id: UUID(),
                                 url: url,
                                 kind: ext == "mov" ? .video : .photo,
                                 date: date,
                                 presetName: nil,
                                 thumbnail: nil)
            }
            .sorted { $0.date > $1.date }

            DispatchQueue.main.async {
                self.items = loaded
                self.isLoading = false
            }
        }
    }

    func delete(_ item: MediaItem) {
        try? FileManager.default.removeItem(at: item.url)
        items.removeAll { $0.id == item.id }
    }

    // MARK: - Miniature

    func thumbnail(for item: MediaItem) -> UIImage {
        let key = item.url.lastPathComponent as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }

        var image = UIImage(systemName: "photo") ?? UIImage()
        switch item.kind {
        case .photo:
            if let source = CGImageSourceCreateWithURL(item.url as CFURL, nil) {
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 400,
                ]
                if let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                    image = UIImage(cgImage: cg)
                }
            }
        case .video:
            let asset = AVURLAsset(url: item.url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 400, height: 400)
            if let cg = try? generator.copyCGImage(at: CMTime(seconds: 0.2, preferredTimescale: 600),
                                                   actualTime: nil) {
                image = UIImage(cgImage: cg)
            }
        }
        thumbnailCache.setObject(image, forKey: key)
        return image
    }

    // MARK: - Salvataggio in Fotolibra

    func saveToPhotos(image: UIImage, completion: ((Bool) -> Void)? = nil) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                completion?(false)
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { ok, _ in
                completion?(ok)
            }
        }
    }

    func saveToPhotos(videoURL: URL, completion: ((Bool) -> Void)? = nil) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                completion?(false)
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            } completionHandler: { ok, _ in
                completion?(ok)
            }
        }
    }
}
