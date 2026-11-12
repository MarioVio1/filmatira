import SwiftUI

/// Token di design di Filmatura — stile «Liquid Glass»: palette chiara,
/// superfici translucide, bordi luminosi, angoli generosi e ombre soffuse.
enum Theme {
    // Palette chiara
    static let background = Color(red: 0.945, green: 0.953, blue: 0.969)
    static let backgroundDeep = Color(red: 0.898, green: 0.910, blue: 0.937)
    static let surface = Color.white.opacity(0.62)
    static let surfaceElevated = Color.white.opacity(0.85)
    static let text = Color(red: 0.118, green: 0.125, blue: 0.149)
    static let textSecondary = Color(red: 0.42, green: 0.44, blue: 0.49)
    static let accent = Color(red: 0.925, green: 0.475, blue: 0.161)
    static let accentTeal = Color(red: 0.075, green: 0.478, blue: 0.549)
    static let recording = Color(red: 0.898, green: 0.235, blue: 0.235)

    static let cornerRadius: CGFloat = 20
    static let chipHeight: CGFloat = 64

    /// Titoli di sezione (Studio, Volto…).
    static let title = Font.system(size: 28, weight: .bold, design: .rounded)
    static let heading = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 15)
    static let caption = Font.system(size: 12, weight: .medium)
}

/// Estensioni comuni di stile.
extension View {

    /// Scheda «Liquid Glass»: materiale translucido, bordo luminoso interno
    /// e ombra morbida.
    func filmaturaCard() -> some View {
        self
            .padding(16)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 6)
    }

    /// Chip translucida: vetro quando non selezionata, gradiente d'accento
    /// con riflesso quando selezionata.
    func chipStyle(isSelected: Bool) -> some View {
        self
            .font(Theme.caption)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? AnyShapeStyle(
                        LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0.82)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(.ultraThinMaterial),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(.white.opacity(0.45), lineWidth: 1))
            .foregroundStyle(isSelected ? Color.white : Theme.text)
            .shadow(color: .black.opacity(isSelected ? 0.16 : 0.05), radius: 5, x: 0, y: 2)
    }

    /// Bottone pilastro «Liquid Glass» (presets, azioni principali).
    func glassButton(isSelected: Bool) -> some View {
        self
            .background(
                isSelected
                    ? AnyShapeStyle(
                        LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0.82)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(.ultraThinMaterial),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 1))
            .foregroundStyle(isSelected ? Color.white : Theme.text)
            .shadow(color: .black.opacity(isSelected ? 0.16 : 0.06), radius: 6, x: 0, y: 3)
    }

    /// Pannello flottante «Liquid Glass»: vetro piu' leggero (thin), bordo
    /// luminoso e angoli generosi — la scheda strumenti si stacca dal fondo.
    func liquidPanel() -> some View {
        self
            .background(
                .thinMaterial,
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(.white.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
    }

    /// Bottone strumento della barra AirBrush: piastrella di vetro con
    /// icona ed etichetta, gradiente d'accento quando selezionata.
    func toolGlass(isSelected: Bool) -> some View {
        self
            .background(
                isSelected
                    ? AnyShapeStyle(
                        LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0.85)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(.thinMaterial),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(isSelected ? 0.7 : 0.45), lineWidth: 1)
            )
            .foregroundStyle(isSelected ? Color.white : Theme.text)
            .shadow(color: .black.opacity(isSelected ? 0.14 : 0.06), radius: 5, x: 0, y: 3)
    }
}
