import SwiftUI

@available(iOS 17, *)
extension Material {
    /// Zentrales Alias für den neuen iOS-"Liquid Glass" Look.
    /// Bis das echte Material verfügbar ist, mappen wir auf ein passendes Systemmaterial.
    static var liquidGlass: Material {
        if #available(iOS 26, *) {
            // TODO: Ersetze durch das echte Liquid-Glass-Material, sobald verfügbar
            return .thinMaterial
        } else {
            return .thinMaterial
        }
    }
}

@available(iOS 17, *)
private struct LiquidGlassBackgroundModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(overlayGradient)
                    .overlay(highlightStroke)
                    .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 12)
            )
    }

    private var overlayGradient: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [Color.cyan.opacity(0.35), Color.purple.opacity(0.2), Color.mint.opacity(0.35)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var highlightStroke: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.7), Color.cyan.opacity(0.4)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

@available(iOS 17, *)
extension View {
    func liquidGlassBackground(cornerRadius: CGFloat = 20) -> some View {
        modifier(LiquidGlassBackgroundModifier(cornerRadius: cornerRadius))
    }
}
