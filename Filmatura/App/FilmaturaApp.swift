import SwiftUI
import UIKit

/// Stato condiviso dell'app (tab selezionato).
@MainActor
final class AppState: ObservableObject {
    enum Tab: Hashable { case camera, studio, face }

    @Published var selection: Tab = .camera

    func openStudio() {
        selection = .studio
    }
}

/// Entry point di Filmatura.
@main
struct FilmaturaApp: App {

    @StateObject private var appState = AppState()
    @StateObject private var camera = CameraController()
    @StateObject private var studio = MediaStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(camera)
                .environmentObject(studio)
                .preferredColorScheme(.light)
        }
    }
}

/// Navigazione a tab: Fotocamera, Studio, Volto.
struct RootView: View {

    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selection) {
            CameraScreen()
                .toolbarBackground(.black, for: .tabBar)
                .tabItem {
                    Label("Fotocamera", systemImage: "camera.fill")
                }
                .tag(AppState.Tab.camera)

            StudioScreen()
                .toolbarBackground(Theme.background, for: .tabBar)
                .tabItem {
                    Label("Studio", systemImage: "photo.stack.fill")
                }
                .tag(AppState.Tab.studio)

            FaceEditScreen()
                .toolbarBackground(Theme.background, for: .tabBar)
                .tabItem {
                    Label("Volto", systemImage: "faceid")
                }
                .tag(AppState.Tab.face)
        }
        .tint(Theme.accent)
    }
}
