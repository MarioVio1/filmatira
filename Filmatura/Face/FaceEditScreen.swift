import SwiftUI
import UIKit
import PhotosUI

/// Schermata Volto stile AirBrush: anteprima grande con confronto a
/// pressione, preset «Fai bello» sempre a portata di tocco e barra
/// strumenti per categoria con la PELLE come primo strumento (leviga,
/// macchie, illumina, tono uniforme). Tutto su pannelli Liquid Glass.
struct FaceEditScreen: View {

    @EnvironmentObject private var studio: MediaStore
    @State private var sourceImage: UIImage?
    @State private var faces: [FaceData] = []
    @State private var bodyData: BodyData?
    @State private var controls = FaceEditControls()
    @State private var bodyControls = BodyEditControls()
    @State private var category: FaceCategory = .pelle
    @State private var preview: UIImage?
    @State private var isDetecting = false
    @State private var isProcessing = false
    @State private var showingOriginal = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var saveResult: String?
    @State private var renderTask: Task<Void, Never>?
    @State private var healMode = false
    @State private var healPoints: [CGPoint] = []

    var body: some View {
        NavigationStack {
            Group {
                if let sourceImage {
                    VStack(spacing: 8) {
                        imageArea(for: sourceImage)
                        toolPanel
                    }
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

    // MARK: - Categorie (pelle prima di tutto, come AirBrush)

    private enum FaceCategory: String, CaseIterable, Identifiable {
        case pelle = "Pelle"
        case occhi = "Occhi"
        case sorriso = "Sorriso"
        case viso = "Viso"
        case corpo = "Corpo"
        case trucco = "Trucco"
        case luce = "Luce"
        case sfondo = "Sfondo"
        case look = "Look"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .pelle: return "drop.degreesign"
            case .occhi: return "eye"
            case .sorriso: return "face.smiling"
            case .viso: return "face.dashed"
            case .corpo: return "figure.stand"
            case .trucco: return "lipstick"
            case .luce: return "lightbulb"
            case .sfondo: return "photo.on.rectangle.angled"
            case .look: return "camera.filters"
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
            Text("Ritocco pelle in stile AirBrush")
                .font(Theme.title)
                .foregroundStyle(Theme.text)
            Text("Leviga, rimuovi le macchie, illumina il viso e uniforma il tono: tutto elaborato on-device, nessun server.")
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
        GeometryReader { geo in
            ZStack {
                Image(uiImage: showingOriginal ? image : (preview ?? image))
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                    .padding(.horizontal, 10)

                if isDetecting || isProcessing {
                    ProgressView()
                        .tint(Theme.text)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !healMode { showingOriginal = true }
                    }
                    .onEnded { value in
                        showingOriginal = false
                        // In modalità rimozione un tap netto aggiunge
                        // un punto di guarigione (spostamento minimo).
                        let moved = hypot(value.translation.width,
                                          value.translation.height)
                        if healMode, moved < 10 {
                            addHealPoint(at: value.startLocation,
                                         container: geo.size)
                        }
                    }
            )
            .overlay(alignment: .bottom) {
                if showingOriginal {
                    Text("Originale")
                        .font(Theme.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6), in: Capsule())
                        .padding(.bottom, 10)
                } else if healMode {
                    Text(healPoints.isEmpty
                         ? "Tocca le imperfezioni da rimuovere"
                         : "\(healPoints.count) tocchi — tocca per aggiungerne altri")
                        .font(Theme.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6), in: Capsule())
                        .padding(.bottom, 10)
                }
            }
        }
    }

    // MARK: - Pannello strumenti (stile AirBrush, Liquid Glass)

    private var toolPanel: some View {
        VStack(spacing: 0) {
            presetGrid
            Divider().opacity(0.18)
            toolStrip
            Divider().opacity(0.18)
            categoryContentArea
        }
        .frame(height: 348)
        .liquidPanel()
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
    }

    /// Preset sempre visibili: «Fai bello» per il ritocco completo,
    /// poi le varianti piu' leggere.
    private var presetGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                presetChip("Fai bello", icon: "wand.and.stars",
                           preset: FaceEditControls.beautyPreset(),
                           isSelected: controls.isBeautyPreset)
                presetChip("Naturale", icon: "leaf.fill",
                           preset: FaceEditControls.naturalePreset(),
                           isSelected: controls.isNaturalePreset)
                presetChip("Glam", icon: "sparkles",
                           preset: FaceEditControls.glamPreset(),
                           isSelected: controls.isGlamPreset)
                presetChip("Dolce", icon: "cloud.fill",
                           preset: FaceEditControls.dolcePreset(),
                           isSelected: controls.isDolcePreset)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func presetChip(_ title: String,
                            icon: String,
                            preset: FaceEditControls,
                            isSelected: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                controls = isSelected ? FaceEditControls() : preset
            }
            scheduleRender()
        } label: {
            Label(title, systemImage: icon)
                .font(Theme.caption.weight(.semibold))
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .glassButton(isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    /// Barra strumenti: icone con etichetta, come le strip di AirBrush.
    private var toolStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FaceCategory.allCases) { item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            category = item
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: item.icon)
                                .font(.system(size: 17, weight: .semibold))
                            Text(item.rawValue)
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .frame(width: 78, height: 52)
                        .toolGlass(isSelected: category == item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Strumenti \(item.rawValue)")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var categoryContentArea: some View {
        ScrollView {
            VStack(spacing: 12) {
                if faces.count > 1 {
                    faceTargets
                }
                categoryContent
                resetRow
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
        .frame(height: 206)
    }

    @ViewBuilder
    private var categoryContent: some View {
        switch category {
        case .pelle:
            VStack(spacing: 12) {
                healToggleRow
                if !healPoints.isEmpty {
                    healUndoRow
                }
                sliderRow("Leviga", $controls.skinSmooth)
                sliderRow("Macchie", $controls.blemish)
                sliderRow("Illumina", $controls.skinBrighten)
                sliderRow("Tono uniforme", $controls.skinTone)
                sliderRow("Abbronzatura", $controls.tan)
                sliderRow("Glow viso", $controls.skinGlow)
            }
        case .occhi:
            VStack(spacing: 12) {
                sliderRow("Occhi grandi", $controls.eyeEnlarge)
                sliderRow("Occhi luminosi", $controls.eyeBrightness)
                sliderRow("Occhiaie", $controls.underEye)
                eyeColorSection
            }
        case .sorriso:
            VStack(spacing: 12) {
                sliderRow("Sorriso", $controls.smile)
                sliderRow("Denti", $controls.teethWhitening)
            }
        case .viso:
            VStack(spacing: 12) {
                sliderRow("Viso snello", $controls.slimFace)
                sliderRow("Guance", $controls.cheeks)
                sliderRow("Pomelli", $controls.cheekbones)
                sliderRow("Mandibola", $controls.jaw)
                sliderRow("Mento", $controls.chin)
                sliderRow("Naso", $controls.nose)
            }
        case .corpo:
            bodyContent
        case .trucco:
            makeupSection
        case .luce:
            VStack(spacing: 12) {
                sliderRow("Luce ritratto", $controls.portraitLight)
            }
        case .sfondo:
            VStack(spacing: 12) {
                sliderRow("Sfocatura", $controls.backgroundBlur)
                sliderRow("Bianco e nero", $controls.backgroundMono)
            }
        case .look:
            eraChips
        }
    }

    // MARK: - Corpo (reshape stile FaceLab/FaceTune)

    @ViewBuilder
    private var bodyContent: some View {
        VStack(spacing: 12) {
            if let bodyData, bodyData.hasFullBody {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.accent)
                    Text("Corpo rilevato: strumenti guidati dall'anatomia")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Theme.textSecondary)
                    Text("Per il reshape del corpo usa una foto di corpo intero o 3/4.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
            }
            sliderRow("Vita", $bodyControls.waist)
            sliderRow("Corpo", $bodyControls.slimBody)
            sliderRow("Gambe", $bodyControls.legsLength)
            sliderRow("Braccia", $bodyControls.armsSlim)
            sliderRow("Spalle larghe", $bodyControls.shouldersWiden)
        }
    }

    // MARK: - Volti multipli

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

    // MARK: - Rimozione a tocco (pennello AirBrush «Rimuovi»)

    private var healToggleRow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { healMode.toggle() }
        } label: {
            Label(healMode ? "Rimozione a tocco attiva" : "Rimozione a tocco",
                  systemImage: healMode ? "checkmark.circle.fill" : "wand.and.rays")
                .font(Theme.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .glassButton(isSelected: healMode)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Attiva o disattiva la rimozione a tocco")
    }

    private var healUndoRow: some View {
        HStack(spacing: 10) {
            Button("Annulla ultimo") {
                if !healPoints.isEmpty {
                    healPoints.removeLast()
                    scheduleRender()
                }
            }
            .font(Theme.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .glassButton(isSelected: false)

            Button("Azzera tocchi") {
                healPoints.removeAll()
                scheduleRender()
            }
            .font(Theme.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .glassButton(isSelected: false)

            Spacer()
        }
    }

    /// Converte il punto toccato (coordinate schermo del contenitore) in
    /// coordinate immagine normalizzate 0-1, affinché il renderer le
    /// mappi su qualsiasi risoluzione.
    private func addHealPoint(at location: CGPoint, container: CGSize) {
        guard let sourceImage else { return }
        let inner = CGSize(width: max(1, container.width - 20),
                           height: max(1, container.height))
        let imgSize = sourceImage.size
        guard imgSize.width > 0, imgSize.height > 0 else { return }
        let scale = min(inner.width / imgSize.width, inner.height / imgSize.height)
        let displayW = imgSize.width * scale
        let displayH = imgSize.height * scale
        let originX = 10 + (inner.width - displayW) / 2
        let originY = (inner.height - displayH) / 2
        let nx = (location.x - originX) / max(1, displayW)
        let ny = (location.y - originY) / max(1, displayH)
        guard nx >= 0, nx <= 1, ny >= 0, ny <= 1 else { return }
        healPoints.append(CGPoint(x: nx, y: ny))
        scheduleRender()
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
            bodyControls = BodyEditControls()
            healPoints.removeAll()
            healMode = false
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
            async let detectedFaces = detect(in: loaded)
            let detectedBody = await detectBody(loaded)
            let detected = await detectedFaces
            faces = detected
            bodyData = detectedBody
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

    private func detectBody(_ image: UIImage) async -> BodyData? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: FaceAnalyzer.detectBody(in: image))
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
        let snapshotHeal = healPoints
        let snapshotBody = bodyData
        let snapshotBodyControls = bodyControls
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInteractive).async {
                let processed = FaceRenderer.render(
                    image: ci, faces: snapshotFaces, controls: snapshot,
                    healPoints: snapshotHeal,
                    body: snapshotBody, bodyControls: snapshotBodyControls)
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
        let snapshotHeal = healPoints
        let snapshotBody = bodyData
        let snapshotBodyControls = bodyControls

        DispatchQueue.global(qos: .userInitiated).async {
            let processed = FaceRenderer.render(image: ci, faces: snapshotFaces,
                                                controls: snapshot,
                                                healPoints: snapshotHeal,
                                                body: snapshotBody,
                                                bodyControls: snapshotBodyControls)
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
