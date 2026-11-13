import SwiftUI
import UIKit

/// Editor foto professionale: pack cinematografici con intensita',
/// regolazioni manuali (esposizione, contrasto, saturazione, temperatura,
/// tinta, nitidezza), grain e vignetta, confronto prima/dopo e salvataggio.
struct PhotoEditorScreen: View {

    let image: UIImage

    @EnvironmentObject private var studio: MediaStore
    @Environment(\.dismiss) private var dismiss

    private enum EditorTab: String, CaseIterable, Identifiable {
        case filtri = "Filtri"
        case regolazioni = "Regolazioni"
        case effetti = "Effetti"
        var id: String { rawValue }
    }

    @State private var preset: LUTPreset?
    @State private var intensity: Double = 1.0
    @State private var grain: Double = 0
    @State private var vignette: Double = 0
    @State private var bloom: Double = 0
    @State private var adjustments = PhotoAdjustments()
    @State private var tab: EditorTab = .filtri
    @State private var preview: UIImage?
    @State private var isProcessing = false
    @State private var showingOriginal = false
    @State private var saveResult: String?
    @State private var renderTask: Task<Void, Never>?

    private var originalImage: UIImage {
        showingOriginal ? image : (preview ?? image)
    }

    var body: some View {
        VStack(spacing: 8) {
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
        .onChange(of: bloom) { _ in scheduleRender() }
        .onChange(of: adjustments) { _ in scheduleRender() }
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
            // Schede stile FaceTune: Filtri / Regolazioni / Effetti.
            Picker("Sezione", selection: $tab) {
                ForEach(EditorTab.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .tint(Theme.accent)

            switch tab {
            case .filtri:
                controlRow(title: "Intensità", value: $intensity,
                           hint: preset == nil ? "Scegli un preset" : nil)
            case .regolazioni:
                bipolarRow(title: "Esposizione", value: $adjustments.exposure)
                bipolarRow(title: "Contrasto", value: $adjustments.contrast)
                bipolarRow(title: "Saturazione", value: $adjustments.saturation)
                bipolarRow(title: "Temperatura", value: $adjustments.temperature)
                bipolarRow(title: "Tinta", value: $adjustments.tint)
                bipolarRow(title: "Nitidezza", value: $adjustments.sharpness)
                if !adjustments.isNeutral {
                    Button("Azzera regolazioni") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            adjustments = PhotoAdjustments()
                        }
                    }
                    .font(Theme.caption)
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            case .effetti:
                controlRow(title: "Bloom", value: $bloom)
                controlRow(title: "Grain", value: $grain)
                controlRow(title: "Vignetta", value: $vignette)
            }
        }
        .padding(16)
        .liquidPanel()
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
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

    /// Slider bipolare (-100...100) per le regolazioni manuali.
    @ViewBuilder
    private func bipolarRow(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(value.wrappedValue == 0 ? "0"
                        : String(format: "%+d", Int(value.wrappedValue * 100)))
                    .font(Theme.caption)
                    .monospacedDigit()
                    .foregroundStyle(value.wrappedValue != 0 ? Theme.accent : Theme.text)
            }
            Slider(value: value, in: -1...1)
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
        guard let cgImage = image.normalizedCGImage() else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let snapshotPreset = preset
        let snapshotIntensity = intensity
        let snapshotGrain = grain
        let snapshotVignette = vignette
        let snapshotBloom = bloom
        let snapshotAdjustments = adjustments
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInteractive).async {
                let processed = ImagePipeline.process(
                    image: ciImage,
                    preset: snapshotPreset,
                    intensity: snapshotIntensity,
                    grain: snapshotGrain,
                    vignette: snapshotVignette,
                    bloom: snapshotBloom,
                    adjustments: snapshotAdjustments)
                continuation.resume(returning: processed.rendered(maxDimension: 1600))
            }
        }
    }

    private func export() {
        isProcessing = true
        guard let cgImage = image.normalizedCGImage() else {
            isProcessing = false
            return
        }
        let ciImage = CIImage(cgImage: cgImage)
        let snapshotPreset = preset
        let snapshotIntensity = intensity
        let snapshotGrain = grain
        let snapshotVignette = vignette
        let snapshotBloom = bloom
        let snapshotAdjustments = adjustments

        DispatchQueue.global(qos: .userInitiated).async {
            let processed = ImagePipeline.process(
                image: ciImage,
                preset: snapshotPreset,
                intensity: snapshotIntensity,
                grain: snapshotGrain,
                vignette: snapshotVignette,
                bloom: snapshotBloom,
                adjustments: snapshotAdjustments)
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
