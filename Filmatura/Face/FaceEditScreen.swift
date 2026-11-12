import SwiftUI
import UIKit
import PhotosUI

/// Schermata Volto stile FaceLab: strumenti organizzati in categorie a
/// schede (Preset, Viso, Occhi, Sorriso, Pelle, Trucco, Luce, Sfondo,
/// Look) su pannelli Liquid Glass, anteprima live e confronto a pressione.
struct FaceEditScreen: View {

    @EnvironmentObject private var studio: MediaStore
    @State private var sourceImage: UIImage?
    @State private var faces: [FaceData] = []
    @State private var controls = FaceEditControls()
    @State private var category: FaceCategory = .preset
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

    // MARK: - Categorie

    private enum FaceCategory: String, CaseIterable, Identifiable {
        case preset = "Preset"
        case face = "Viso"
        case eyes = "Occhi"
        case smile = "Sorriso"
        case skin = "Pelle"
        case makeup = "Trucco"
        case light = "Luce"
        case background = "Sfondo"
        case era = "Look"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .preset: return "wand.and.stars"
            case .face: return "face.dashed"
            case .eyes: return "eye"
            case .smile: return "face.smiling"
            case .skin: return "drop.degreesign"
            case .makeup: return "lipstick"
            case .light: return "lightbulb"
            case .background: return "photo.on.rectangle.angled"
            case .era: return "camera.filters"
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
            Text("Pelle, occhi, denti, sorriso, viso, trucco, luce e sfondo: tutto elaborato on-device.")
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

    // MARK: - Pannello strumenti (schede FaceLab)

    private var toolPanel: some View {
        VStack(spacing: 0) {
            categoryBar
            Divider().opacity(0.25)
            ScrollView {
                VStack(spacing: 14) {
                    if faces.count > 1 {
                        faceTargets
                    }
                    categoryContent
                    resetRow
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(height: 336)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(.white.opacity(0.5))
                .frame(height: 1),
            alignment: .top
        )
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FaceCategory.allCases) { item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            category = item
                        }
                    } label: {
                        Label(item.rawValue, systemImage: item.icon)
                            .font(Theme.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassButton(isSelected: category == item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var categoryContent: some View {
        switch category {
        case .preset:
            presetGrid
        case .face:
            VStack(spacing: 12) {
                sliderRow("Viso snello", $controls.slimFace)
                sliderRow("Guance", $controls.cheeks)
                sliderRow("Pomelli", $controls.cheekbones)
                sliderRow("Mandibola", $controls.jaw)
                sliderRow("Mento", $controls.chin)
                sliderRow("Naso", $controls.nose)
            }
        case .eyes:
            VStack(spacing: 12) {
                sliderRow("Occhi grandi", $controls.eyeEnlarge)
                sliderRow("Occhi luminosi", $controls.eyeBrightness)
                sliderRow("Occhiaie", $controls.underEye)
                eyeColorSection
            }
        case .smile:
            VStack(spacing: 12) {
                sliderRow("Sorriso", $controls.smile)
                sliderRow("Denti", $controls.teethWhitening)
            }
        case .skin:
            VStack(spacing: 12) {
                sliderRow("Leviga", $controls.skinSmooth)
                sliderRow("Imperfezioni", $controls.blemish)
                sliderRow("Abbronzatura", $controls.tan)
                sliderRow("Glow viso", $controls.skinGlow)
            }
        case .makeup:
            makeupSection
        case .light:
            VStack(spacing: 12) {
                sliderRow("Luce ritratto", $controls.portraitLight)
            }
        case .background:
            VStack(spacing: 12) {
                sliderRow("Sfocatura", $controls.backgroundBlur)
                sliderRow("Bianco e nero", $controls.backgroundMono)
            }
        case .era:
            eraChips
        }
    }

    // MARK: - Preset

    private var presetGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            presetCard("Fai bello", icon: "wand.and.stars",
                       preset: FaceEditControls.beautyPreset(),
                       isSelected: controls.isBeautyPreset)
            presetCard("Naturale", icon: "leaf.fill",
                       preset: FaceEditControls.naturalePreset(),
                       isSelected: controls.isNaturalePreset)
            presetCard("Glam", icon: "sparkles",
                       preset: FaceEditControls.glamPreset(),
                       isSelected: controls.isGlamPreset)
            presetCard("Dolce", icon: "cloud.fill",
                       preset: FaceEditControls.dolcePreset(),
                       isSelected: controls.isDolcePreset)
        }
    }

    private func presetCard(_ title: String,
                            icon: String,
                            preset: FaceEditControls,
                            isSelected: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                controls = isSelected ? FaceEditControls() : preset
            }
            scheduleRender()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(Theme.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassButton(isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var faceTargets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Voli rilevati: \(faces.count)")
                .font(Theme.caption)
                .foregroundStyle(Theme.textSecondary)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Slider e selettore colore occhi

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

    private var eyeColorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Colore occhi")
                    .font(Theme.body)
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(controls.eyeColorShade.rawValue)
                    .font(Theme.caption)
                    .foregroundStyle(controls.eyeColor > 0 ? Theme.accent : Theme.textSecondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(EyeColorShade.allCases) { shade in
                        Button {
                            controls.eyeColorShade = shade
                            if controls.eyeColor == 0 {
                                controls.eyeColor = 0.5
                            }
                            scheduleRender()
                        } label: {
                            Circle()
                                .fill(Color(red: shade.rgb.0, green: shade.rgb.1, blue: shade.rgb.2))
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Circle().strokeBorder(
                                        controls.eyeColorShade == shade ? Theme.accent : Theme.textSecondary.opacity(0.4),
                                        lineWidth: controls.eyeColorShade == shade ? 2 : 1)
                                )
                        }
                        .accessibilityLabel("Colore occhi \(shade.rawValue)")
                    }
                    Spacer()
                }
            }
            Slider(value: $controls.eyeColor, in: 0...1)
                .tint(Theme.accent)
                .onChange(of: controls.eyeColor) { _ in scheduleRender() }
        }
    }

    // MARK: - Trucco e look epoca

    private var makeupSection: some View {
        VStack(spacing: 12) {
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
            sliderRow("Labbra vive", $controls.lipVibrance)
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
                                        shade.wrappedValue == s ? Theme.accent : Theme.textSecondary.opacity(0.4),
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

    private var resetRow: some View {
        Button("Ripristina") {
            withAnimation { controls = FaceEditControls() }
            scheduleRender()
        }
        .font(Theme.caption)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .glassButton(isSelected: false)
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
