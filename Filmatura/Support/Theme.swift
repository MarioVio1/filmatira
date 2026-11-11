import SwiftUI

/// Token di design di Filmatura — nessun valore grezzo nelle viste.
enum Theme {
    static let background = Color(red: 0.066, green: 0.075, blue: 0.094)
    static let surface = Color(red: 0.106, green: 0.113, blue: 0.137)
    static let surfaceElevated = Color(red: 0.145, green: 0.153, blue: 0.180)
    static let text = Color(red: 0.949, green: 0.953, blue: 0.965)
    static let textSecondary = Color(red: 0.604, green: 0.627, blue: 0.667)
    static let accent = Color(red: 0.914, green: 0.506, blue: 0.188)
    static let accentTeal = Color(red: 0.055, green: 0.455, blue: 0.529)
    static let recording = Color(red: 0.867, green: 0.239, blue: 0.235)

    static let cornerRadius: CGFloat = 14
    static let chipHeight: CGFloat = 64

    /// Titoli di sezione (Studio, Volto…).
    static let title = Font.system(size: 28, weight: .bold, design: .rounded)
    static let heading = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 15)
    static let caption = Font.system(size: 12, weight: .medium)
}

/// Estensioni comuni di stile.
extension View {
    func filmaturaCard() -> some View {
        self
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    func chipStyle(isSelected: Bool) -> some View {
        self
            .font(Theme.caption)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected ? Theme.accent : Theme.surfaceElevated,
                in: Capsule()
            )
            .foregroundStyle(isSelected ? .white : Theme.text)
    }
}
