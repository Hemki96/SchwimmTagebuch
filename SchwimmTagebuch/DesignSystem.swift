import SwiftUI

enum AppTheme {
    static let accent = Color.teal
    static let gradientTop = Color(red: 0.08, green: 0.17, blue: 0.36)
    static let gradientCenter = Color(red: 0.05, green: 0.41, blue: 0.55)
    static let gradientBottom = Color(red: 0.02, green: 0.62, blue: 0.57)
    static let glassStroke = Color.white.opacity(0.35)
    static let glassFill = Color.white.opacity(0.08)
    static let cardCornerRadius: CGFloat = 24
    static let elementSpacing: CGFloat = 18

    static var barMaterial: Material { Material.liquidGlass }
    static var cardMaterial: Material { Material.liquidGlass }
}

struct AppGradientBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Color(.systemBackground)
                LinearGradient(
                    colors: [
                        AppTheme.gradientTop.opacity(0.95),
                        AppTheme.gradientCenter.opacity(0.85),
                        AppTheme.gradientBottom.opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    RadialGradient(
                        colors: [Color.white.opacity(0.35), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: max(size.width, size.height) * 0.8
                    )
                    .blendMode(.softLight)
                    .offset(x: -size.width * 0.15, y: -size.height * 0.25)
                )
                .overlay(
                    AngularGradient(
                        colors: [Color.white.opacity(0.12), .clear, Color.white.opacity(0.1)],
                        center: .center
                    )
                    .blendMode(.overlay)
                    .opacity(0.6)
                )
            }
            .ignoresSafeArea()
        }
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var contentPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(contentPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.cardMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(AppTheme.glassFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(AppTheme.glassStroke, lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.12), radius: 18, y: 12)
    }
}

extension View {
    func appSurfaceBackground() -> some View {
        modifier(AppSurfaceModifier())
    }

    func glassCard(cornerRadius: CGFloat = AppTheme.cardCornerRadius,
                   contentPadding: CGFloat = AppTheme.elementSpacing) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, contentPadding: contentPadding))
    }

    func glassListRow() -> some View {
        self
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 12, leading: 0, bottom: 12, trailing: 0))
            .listRowBackground(Color.clear)
    }

    func sectionHeaderStyle() -> some View {
        self
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
    }
}

private struct AppSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            AppGradientBackground()
            content
        }
    }
}

struct SectionHeaderLabel: View {
    let title: String
    let systemImage: String?

    init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, 4)
        .foregroundStyle(.primary)
    }
}

struct ContentUnavailableHint: View {
    let title: String
    let subtitle: String
    let systemImage: String

    init(title: String, subtitle: String, systemImage: String) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    var body: some View {
        ContentUnavailableView(
            label: {
                Label(title, systemImage: systemImage)
            },
            description: {
                Text(subtitle)
            }
        )
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .glassCard(contentPadding: 20)
    }
}
