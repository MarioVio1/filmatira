import AVKit
import PhotosUI
import SwiftUI
import UIKit

/// Studio: griglia dei media di Filmatura, import da Fotolibra, player
/// video, condivisione ed eliminazione.
struct StudioScreen: View {

    @EnvironmentObject private var studio: MediaStore
    @State private var pickerItem: PhotosPickerItem?
    @State private var playerURL: URL?
    @State private var editingItem: MediaItem?
    @State private var importResult: String?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    var body: some View {
        NavigationStack {
            Group {
                if studio.items.isEmpty {
                    emptyState
                } else {
                    gridView
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Studio")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onChange(of: pickerItem) { item in importPicked(item) }
            .onAppear { if studio.items.isEmpty { studio.loadAll() } }
            .fullScreenCover(item: $editingItem) { item in
                PhotoEditorScreen(image: UIImage(contentsOfFile: item.url.path) ?? UIImage())
            }
            .fullScreenCover(item: playerBinding) { box in
                PlayerSheet(url: box.url)
            }
            .alert("Import", isPresented: .constant(importResult != nil)) {
                Button("OK", role: .cancel) { importResult = nil }
            } message: {
                Text(importResult ?? "")
            }
        }
    }

    private struct PlayerBox: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    /// Binding esplicito (aiuta il type-checker ed evita timeout di compilazione).
    private var playerBinding: Binding<PlayerBox?> {
        Binding(
            get: { playerURL.map { PlayerBox(url: $0) } },
            set: { playerURL = $0?.url })
    }

    // MARK: - Griglia

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(studio.items) { item in
                    cell(for: item)
                }
            }
            .padding(12)
        }
    }

    private func cell(for item: MediaItem) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(uiImage: studio.thumbnail(for: item))
                .resizable()
                .scaledToFill()
                .frame(height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture {
                    if item.kind == .photo {
                        editingItem = item
                    } else {
                        playerURL = item.url
                    }
                }
                .shadow(color: .black.opacity(0.10), radius: 6, y: 3)

            HStack(spacing: 6) {
                if item.kind == .video {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                }
                Menu {
                    ShareLink(item: item.url,
                              preview: SharePreview(item.url.lastPathComponent)) {
                        Label("Condividi", systemImage: "square.and.arrow.up")
                    }
                    Button("Salva in Fotolibra") {
                        if item.kind == .photo {
                            if let image = UIImage(contentsOfFile: item.url.path) {
                                studio.saveToPhotos(image: image)
                            }
                        } else {
                            studio.saveToPhotos(videoURL: item.url)
                        }
                    }
                    Button("Elimina", role: .destructive) { studio.delete(item) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.55), in: Circle())
                }
            }
            .padding(6)
        }
        .contextMenu {
            ShareLink(item: item.url,
                      preview: SharePreview(item.url.lastPathComponent)) {
                Label("Condividi", systemImage: "square.and.arrow.up")
            }
            Button("Salva in Fotolibra") {
                if item.kind == .photo {
                    if let image = UIImage(contentsOfFile: item.url.path) {
                        studio.saveToPhotos(image: image)
                    }
                } else {
                    studio.saveToPhotos(videoURL: item.url)
                }
            }
            Button("Elimina", role: .destructive) { studio.delete(item) }
        }
    }

    // MARK: - Stato vuoto

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "photo.stack")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accentTeal)
            Text("Il tuo Studio è vuoto")
                .font(Theme.heading)
                .foregroundStyle(Theme.text)
            Text("Scatta con la fotocamera o importa una foto da ritoccare.")
                .font(Theme.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("Importa foto")
                    .font(Theme.heading)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
            }
            Spacer()
        }
        .padding(32)
    }

    // MARK: - Import

    private func importPicked(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                studio.importImage(image)
                importResult = "Foto importata in Studio."
            }
        }
    }
}

/// Player a schermo intero per i video di Studio.
struct PlayerSheet: View {

    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.white.opacity(0.18), in: Circle())
            }
            .padding(16)
        }
    }
}
