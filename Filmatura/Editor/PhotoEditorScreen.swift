import SwiftUI
import UIKit

/// Editor foto: pack cinematografici, intensita', grain, vignetta,
/// confronto prima/dopo e salvataggio.
struct PhotoEditorScreen: View {

    let image: UIImage

    @EnvironmentObject private var studio: MediaStore
    @Environment(\.dismiss) private var dismiss

    @State private var preset: LUTPreset?
    @State private var intensity: Double = 1.0
    @State private var grain: Double = 0
    @State private var vignette: Double = 0
    @State private var preview: UIImage?
    @State private var isProcessing = false
    @State private var showingOriginal = false
    @State private var saveResult: String?
    @State private var renderTask: Task<Void, Never>?

    private var originalImage: UIImage {
        showingOriginal ? image : (preview ?? image)
    }

    var body: some View {
        VStack(spacing: 0) {
            imageArea
            packCarousel
            controls
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Editor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Chiudi") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Salva") { export() }
                    .font(Theme.heading)
                    .tint(Theme.accent)
                    .disabled(isProcessing)
            }
        }
        .onAppear { scheduleRender() }
        .onChange(of: preset) { _ in scheduleRender() }
        .onChange(of: intensity) { _ in scheduleRender() }
        .onChange(of: grain) { _ in scheduleRender() }
        .onChange(of: vignette) { _ in scheduleRender() }
        .alert("Salvataggio", isPresented: .constant(saveResult != nil)) {
            Button("OK", role: .cancel) { saveResult = nil }
        } message: {
            Text(saveResult ?? "")
        }
    }

    // MARK: - Immagine

    private var imageArea: some View {
        ZStack {
            Image(uiImage: originalImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .padding(.horizontal, 12)

            if isProcessing {
                ProgressView()
                    .tint(Theme.text)
            }
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in showingOriginal = true }
                .onEnded { _ in showingOriginal = false }
        )
        .overlay(alignment: .bottom) {
            if showingOriginal {
                Text("Originale")
                    .font(Theme.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Pack

    private var packCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                packCard(id: nil, name: "Originale") {
                    Image(systemName: "minus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
                .overlay {
                    if preset == nil {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Theme.accent, lineWidth: 2)
                    }
                }

                ForEach(LUTCatalog.packs) { pack in
                    Text(pack.name.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 68, height: 64)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    ForEach(pack.presets) { item in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { preset = item }
                        } label: {
                            packCard(id: item.id, name: item.name) {
                                Image(uiImage: LUTStore.shared.thumbnail(for: item))
                                    .resizable()
                                    .scaledToFill()
                            }
                        }
                        .overlay {
                            if preset?.id == item.id {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Theme.accent, lineWidth: 2)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(height: 96)
    }

    private func packCard<Content: View>(id: String?,
                                         name: String,
                                         @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 4) {
            content()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 68)
    }

    // MARK: - Controlli

    private var controls: some View {
        VStack(spacing: 14) {
            controlRow(title: "Intensità", value: $intensity,
                       hint: preset == nil ? "Scegli un preset" : nil)
            controlRow(title: "Grain", value: $grain)
            controlRow(title: "Vignetta", value: $vignette)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func controlRow(title: String, value: Binding<Double>, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if let hint {
                    Text(hint)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.accent)
                } else {
                    Text("\(Int(value.wrappedValue * 100))%")
                        .font(Theme.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.text)
                }
            }
            Slider(value: value, in: 0...1)
                .tint(Theme.accent)
        }
    }

    // MARK: - Render ed export

    private func scheduleRender() {
        renderTask?.cancel()
        isProcessing = true
        renderTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            let result = await renderPreview()
            if !Task.isCancelled {
                preview = result
                isProcessing = false
            }
        }
    }

    private func renderPreview() async -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let snapshotPreset = preset
        let snapshotIntensity = intensity
        let snapshotGrain = grain
        let snapshotVignette = vignette
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInteractive).async {
                let processed = ImagePipeline.process(
                    image: ciImage,
                    preset: snapshotPreset,
                    intensity: snapshotIntensity,
                    grain: snapshotGrain,
                    vignette: snapshotVignette)
                continuation.resume(returning: processed.rendered(maxDimension: 1600))
            }
        }
    }

    private func export() {
        isProcessing = true
        guard let cgImage = image.cgImage else {
            isProcessing = false
            return
        }
        let ciImage = CIImage(cgImage: cgImage)
        let snapshotPreset = preset
        let snapshotIntensity = intensity
        let snapshotGrain = grain
        let snapshotVignette = vignette

        DispatchQueue.global(qos: .userInitiated).async {
            let processed = ImagePipeline.process(
                image: ciImage,
                preset: snapshotPreset,
                intensity: snapshotIntensity,
                grain: snapshotGrain,
                vignette: snapshotVignette)
            let full = processed.rendered(maxDimension: 4096)
            let item = studio.saveImage(full, presetName: snapshotPreset?.name)
            DispatchQueue.main.async {
                isProcessing = false
                if let item {
                    studio.saveToPhotos(image: full) { ok in
                        saveResult = ok
                            ? "Salvato in Studio e in Fotolibra."
                            : "Salvato in Studio (permesso Fotolibra negato)."
                        _ = item
                    }
                } else {
                    saveResult = "Errore durante il salvataggio."
                }
            }
        }
    }
}
