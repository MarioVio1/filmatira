import AVFoundation
import SwiftUI
import UIKit

/// Schermata fotocamera: preview Metal, carousel dei pack film, slider
/// intensita', scatto foto e registrazione video con grading live.
struct CameraScreen: View {

    @EnvironmentObject private var camera: CameraController
    @EnvironmentObject private var studio: MediaStore
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            previewLayer

            VStack(spacing: 0) {
                topBar
                Spacer()
                controlDeck
            }
        }
        .statusBarHidden()
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.currentPreset) { _ in camera.syncGradingState() }
        .onChange(of: camera.intensity) { _ in camera.syncGradingState() }
        .alert("Attenzione", isPresented: alertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(camera.errorMessage ?? "")
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(get: { camera.errorMessage != nil },
                set: { if !$0 { camera.errorMessage = nil } })
    }

    // MARK: - Preview e griglia

    private var previewLayer: some View {
        ZStack {
            CameraPreviewView(controller: camera)
                .ignoresSafeArea()

            if camera.status == .unauthorized {
                deniedState
            } else if camera.status == .idle {
                ProgressView().tint(.white)
            }
        }
        .overlay { if camera.showingGrid { GridOverlay() } }
    }

    private var deniedState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 44))
                .foregroundStyle(Theme.textSecondary)
            Text("Serve il permesso fotocamera per iniziare")
                .font(Theme.heading)
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            Button("Apri Impostazioni") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .padding(32)
    }

    // MARK: - Barra superiore

    private var topBar: some View {
        HStack(spacing: 12) {
            ToolButton(icon: camera.showingGrid ? "grid.circle.fill" : "grid.circle",
                       label: "Griglia") {
                camera.showingGrid.toggle()
            }

            Spacer()

            ToolButton(icon: torchIcon, label: "Torcia") {
                camera.toggleTorch()
            }
            .disabled(camera.position == .front)

            ToolButton(icon: flashIcon, label: flashLabel) {
                cycleFlash()
            }

            ToolButton(icon: "arrow.triangle.2.circlepath.camera", label: "Gira") {
                camera.switchCamera()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var torchIcon: String {
        camera.torchOn ? "flashlight.on.fill" : "flashlight.off"
    }

    private var flashIcon: String {
        switch camera.flashMode {
        case .on: return "bolt.badge.a.fill"
        case .auto: return "bolt.badge.a"
        default: return "bolt.slash.fill"
        }
    }

    private var flashLabel: String {
        switch camera.flashMode {
        case .on: return "Flash"
        case .auto: return "Auto"
        default: return "No flash"
        }
    }

    private func cycleFlash() {
        switch camera.flashMode {
        case .off: camera.flashMode = .auto
        case .auto: camera.flashMode = .on
        default: camera.flashMode = .off
        }
    }

    // MARK: - Controlli inferiori

    private var controlDeck: some View {
        VStack(spacing: 14) {
            zoomChips
            packCarousel
            intensitySlider
            shutterRow
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(alignment: .bottom) {
            Rectangle()
                .fill(Theme.background.opacity(0.45))
                .background(.thinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var zoomChips: some View {
        HStack(spacing: 8) {
            ForEach([1.0, 2.0, 3.0], id: \.self) { factor in
                Button {
                    camera.setZoom(factor)
                } label: {
                    Text(factor == 1.0 ? "1x" : "\(Int(factor))x")
                        .font(Theme.caption)
                        .frame(width: 40, height: 28)
                        .background(
                            abs(camera.zoomFactor - factor) < 0.05
                                ? Theme.accent : Theme.surfaceElevated,
                            in: Capsule()
                        )
                        .foregroundStyle(abs(camera.zoomFactor - factor) < 0.05 ? .white : Theme.text)
                }
            }
            Spacer()
        }
    }

    private var packCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                packCard(id: nil, name: "Originale") {
                    Image(systemName: "minus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
                .overlay {
                    if camera.currentPreset == nil {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Theme.accent, lineWidth: 2)
                    }
                }

                ForEach(LUTCatalog.packs) { pack in
                    ForEach(pack.presets) { preset in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                camera.currentPreset = preset
                            }
                        } label: {
                            packCard(id: preset.id, name: preset.name) {
                                Image(uiImage: lutStore.thumbnail(for: preset))
                                    .resizable()
                                    .scaledToFill()
                            }
                        }
                        .overlay {
                            if camera.currentPreset?.id == preset.id {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Theme.accent, lineWidth: 2)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(height: 96)
    }

    private let lutStore = LUTStore.shared

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

    private var intensitySlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Intensità")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(Int(camera.intensity * 100))%")
                    .font(Theme.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
            }
            Slider(value: $camera.intensity, in: 0...1)
                .tint(Theme.accent)
                .disabled(camera.currentPreset == nil)
        }
    }

    private var shutterRow: some View {
        HStack {
            Button { appState.openStudio() } label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.text)
                    .frame(width: 56, height: 56)
            }

            Spacer()

            ShutterButton(
                isRecording: camera.isRecording,
                action: { camera.capturePhoto() },
                longPressAction: { toggleRecording() }
            )

            Spacer()

            Button { appState.openStudio() } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.text)
                    .frame(width: 56, height: 56)
            }
        }
        .padding(.top, 6)
    }

    private func toggleRecording() {
        if camera.isRecording {
            camera.stopRecording()
        } else {
            camera.startRecording()
        }
    }
}

// MARK: - Componenti

/// Pulsante circolare di scatto: tap = foto, pressione tenuta = registra
/// finché non viene rilasciato.
struct ShutterButton: View {
    let isRecording: Bool
    let action: () -> Void
    let longPressAction: () -> Void

    @State private var pressing = false
    @State private var pressStart: Date?
    @State private var longPressFired = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isRecording ? Theme.recording : .white, lineWidth: 4)
                .frame(width: 78, height: 78)

            Circle()
                .fill(isRecording ? Theme.recording : .white)
                .frame(width: pressing ? 62 : 68, height: pressing ? 62 : 68)
                .animation(.easeInOut(duration: 0.15), value: pressing)
        }
        .contentShape(Circle().size(width: 96, height: 96))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressing {
                        pressing = true
                        pressStart = Date()
                        longPressFired = false
                    }
                    if !longPressFired,
                       let start = pressStart,
                       Date().timeIntervalSince(start) >= 0.45 {
                        longPressFired = true
                        longPressAction()      // avvia la registrazione
                    }
                }
                .onEnded { _ in
                    let fired = longPressFired
                    pressing = false
                    pressStart = nil
                    longPressFired = false
                    if fired {
                        longPressAction()      // ferma la registrazione
                    } else {
                        action()               // scatta la foto
                    }
                }
        )
    }
}

/// Icona con etichetta della barra superiore.
struct ToolButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(Theme.text)
            .frame(width: 52, height: 46)
            .background(Theme.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

/// Griglia dei terzi sulla preview.
struct GridOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width / 3
            let h = geo.size.height / 3
            Path { path in
                for i in 1...2 {
                    path.move(to: CGPoint(x: w * CGFloat(i), y: 0))
                    path.addLine(to: CGPoint(x: w * CGFloat(i), y: geo.size.height))
                    path.move(to: CGPoint(x: 0, y: h * CGFloat(i)))
                    path.addLine(to: CGPoint(x: geo.size.width, y: h * CGFloat(i)))
                }
            }
            .stroke(.white.opacity(0.35), lineWidth: 0.6)
        }
        .allowsHitTesting(false)
    }
}
