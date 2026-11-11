import SwiftUI
import UIKit
import PhotosUI

/// Schermata Volto: rileva i volti e applica gli strumenti con Vision +
/// CoreImage. Confronto per pressione, target per singolo volto, esporta.
struct FaceEditScreen: View {

    @EnvironmentObject private var studio: MediaStore
    @State private var sourceImage: UIImage?
    @State private var faces: [FaceData] = []
    @State private var controls = FaceEditControls()
    @State private var preview: UIImage?
    @State private var isDetecting = false
    @State private var isProcessing = false
    @State private var showingOriginal = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var saveResult: String?
    @State private var renderTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let sourceImage {
                    imageArea(for: sourceImage)
                    toolPanel
                } else {
                    emptyState
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Volto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Image(systemName: "photo.badge.plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let sourceImage {
                        Button("Esporta") { export(sourceImage) }
                            .font(Theme.heading)
                            .tint(Theme.accent)
                            .disabled(isProcessing)
                    }
                }
            }
            .onChange(of: pickerItem) { item in loadPicked(item) }
            .alert("Esportazione", isPresented: .constant(saveResult != nil)) {
                Button("OK", role: .cancel) { saveResult = nil }
            } message: {
                Text(saveResult ?? "")
            }
        }
    }

    // MARK: - Stato vuoto

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "face.smiling.inverse")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accentTeal)
            Text("Scegli un ritratto da ritoccare")
                .font(Theme.heading)
                .foregroundStyle(Theme.text)
            Text("Pelle, occhi, denti, pomelli, labbra e luce: tutto elaborato on-device.")
                .font(Theme.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("Scegli foto")
                    .font(Theme.heading)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(32)
    }

    // MARK: - Immagine

    private func imageArea(for image: UIImage) -> some View {
        ZStack {
            Image(uiImage: showingOriginal ? image : (preview ?? image))
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .padding(.horizontal, 12)

            if isDetecting || isProcessing {
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

    // MARK: - Pannello strumenti

    private var toolPanel: some View {
        ScrollView {
            VStack(spacing: 16) {
                faceTargets
                beautyRow
                eraChips
                toolSliders
                makeupSection
                resetRow
            }
            .padding(16)
        }
        .frame(height: 300)
        .background(Theme.surface)
    }

    private var faceTargets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Voli rilevati: \(faces.count)")
                .font(Theme.caption)
                .foregroundStyle(Theme.textSecondary)

            if faces.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button("Tutti") {
                            controls.targetFaceID = nil
                            scheduleRender()
                        }
                            .chipStyle(isSelected: controls.targetFaceID == nil)

                        ForEach(Array(faces.enumerated()), id: \.element.id) { index, face in
                            Button("Volto \(index + 1)") {
                                controls.targetFaceID = face.id
                                scheduleRender()
                            }
                            .chipStyle(isSelected: controls.targetFaceID == face.id)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var beautyRow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                controls = controls.isBeautyPreset ? FaceEditControls() : FaceEditControls.beautyPreset()
            }
            scheduleRender()
        } label: {
            Label("Fai bello", systemImage: "wand.and.stars")
                .font(Theme.heading)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(controls.isBeautyPreset ? Theme.accent : Theme.surfaceElevated, in: Capsule())
                .foregroundStyle(controls.isBeautyPreset ? Color.white : Theme.text)
        }
    }

    private var eraChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Look epoca")
                .font(Theme.caption)
                .foregroundStyle(Theme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EraLook.allCases) { look in
                        Button(look.rawValue) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                controls.eraLook = look
                            }
                            scheduleRender()
                        }
                        .chipStyle(isSelected: controls.eraLook == look)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var toolSliders: some View {
        VStack(spacing: 14) {
            sliderRow("Pelle liscia", $controls.skinSmooth)
            sliderRow("Occhi", $controls.eyeBrightness)
            sliderRow("Denti", $controls.teethWhitening)
            sliderRow("Pomelli", $controls.cheekSculpt)
            sliderRow("Mandibola", $controls.jawSculpt)
            sliderRow("Labbra", $controls.lipVibrance)
            sliderRow("Luce ritratto", $controls.portraitLight)
            sliderRow("Sfondo sfocato", $controls.backgroundBlur)
        }
    }

    @ViewBuilder
    private func sliderRow(_ title: String, _ value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(Theme.body)
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))")
                    .font(Theme.caption)
                    .monospacedDigit()
                    .foregroundStyle(value.wrappedValue > 0 ? Theme.accent : Theme.textSecondary)
            }
            Slider(value: value, in: 0...1)
                .tint(Theme.accent)
                .onChange(of: value.wrappedValue) { _ in scheduleRender() }
        }
    }

    private var makeupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Trucco")
                .font(Theme.caption)
                .foregroundStyle(Theme.textSecondary)
            makeupRow("Cipria", value: $controls.foundation,
                      shades: MakeupShade.foundationShades, shade: $controls.foundationShade)
            makeupRow("Contouring", value: $controls.contour, shades: nil, shade: nil)
            makeupRow("Blush", value: $controls.blush,
                      shades: MakeupShade.blushShades, shade: $controls.blushShade)
            makeupRow("Ombretto", value: $controls.eyeshadow,
                      shades: MakeupShade.eyeshadowShades, shade: $controls.eyeshadowShade)
            makeupRow("Eyeliner", value: $controls.eyeliner,
                      shades: MakeupShade.eyelinerShades, shade: $controls.eyelinerShade)
            makeupRow("Rossetto", value: $controls.lipstick,
                      shades: MakeupShade.lipstickShades, shade: $controls.lipstickShade)
        }
    }

    private func makeupRow(_ title: String,
                           value: Binding<Double>,
                           shades: [MakeupShade]?,
                           shade: Binding<MakeupShade>?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(Theme.body)
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))")
                    .font(Theme.caption)
                    .monospacedDigit()
                    .foregroundStyle(value.wrappedValue > 0 ? Theme.accent : Theme.textSecondary)
            }
            if let shades, let shade {
                HStack(spacing: 8) {
                    ForEach(shades) { s in
                        Button {
                            shade.wrappedValue = s
                            scheduleRender()
                        } label: {
                            Circle()
                                .fill(Color(red: s.rgb.0, green: s.rgb.1, blue: s.rgb.2))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle().strokeBorder(
                                        shade.wrappedValue == s ? Theme.accent : Color.white.opacity(0.3),
                                        lineWidth: shade.wrappedValue == s ? 2 : 1)
                                )
                        }
                        .accessibilityLabel("\(title) \(s.rawValue)")
                    }
                    Spacer()
                }
            }
            Slider(value: value, in: 0...1)
                .tint(Theme.accent)
                .onChange(of: value.wrappedValue) { _ in scheduleRender() }
        }
    }

    private var resetRow: some View {
        Button("Ripristina") {
            withAnimation { controls = FaceEditControls() }
            scheduleRender()
        }
        .font(Theme.caption)
        .foregroundStyle(Theme.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.surfaceElevated, in: Capsule())
    }

    // MARK: - Caricamento e rendering

    private func loadPicked(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isDetecting = true
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            guard let data, let loaded = UIImage(data: data) else {
                isDetecting = false
                return
            }
            sourceImage = loaded
            preview = loaded
            let detected = await detect(in: loaded)
            faces = detected
            isDetecting = false
            if detected.isEmpty {
                saveResult = "Nessun volto rilevato in questa foto."
            }
            scheduleRender()
        }
    }

    private func detect(in image: UIImage) async -> [FaceData] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: FaceAnalyzer.detectFaces(in: image))
            }
        }
    }

    private func scheduleRender() {
        guard sourceImage != nil else { return }
        renderTask?.cancel()
        isProcessing = true
        renderTask = Task {
            try? await Task.sleep(nanoseconds: 130_000_000)
            guard !Task.isCancelled else { return }
            let result = await renderPreview()
            if !Task.isCancelled {
                preview = result
                isProcessing = false
            }
        }
    }

    private func renderPreview() async -> UIImage? {
        guard let sourceImage, let cg = sourceImage.normalizedCGImage() else { return nil }
        let ci = CIImage(cgImage: cg)
        let snapshot = controls
        let snapshotFaces = faces
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInteractive).async {
                let processed = FaceRenderer.render(
                    image: ci, faces: snapshotFaces, controls: snapshot)
                continuation.resume(returning: processed.rendered(maxDimension: 1400))
            }
        }
    }

    private func export(_ image: UIImage) {
        isProcessing = true
        guard let cg = image.normalizedCGImage() else {
            isProcessing = false
            return
        }
        let ci = CIImage(cgImage: cg)
        let snapshot = controls
        let snapshotFaces = faces

        DispatchQueue.global(qos: .userInitiated).async {
            let processed = FaceRenderer.render(image: ci, faces: snapshotFaces, controls: snapshot)
            let full = processed.rendered(maxDimension: 4096)
            DispatchQueue.main.async {
                isProcessing = false
                let item = studio.saveImage(full, presetName: snapshot.eraLook.rawValue)
                studio.saveToPhotos(image: full) { ok in
                    saveResult = ok
                        ? "Ritratto salvato in Studio e in Fotolibra."
                        : "Ritratto salvato in Studio."
                    _ = item
                }
            }
        }
    }
}
