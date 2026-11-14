import Foundation
import SwiftUI
import UIKit

nonisolated enum AppAppearanceMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "Theo hệ thống"
        case .light:
            return "Sáng"
        case .dark:
            return "Tối"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum ClaudePalette {
    static let canvas = dynamic(
        light: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
        dark: UIColor(red: 0x0F / 255.0, green: 0x0F / 255.0, blue: 0x10 / 255.0, alpha: 1.0)
    )

    static let surface = dynamic(
        light: UIColor(red: 0xF7 / 255.0, green: 0xF7 / 255.0, blue: 0xF7 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x1D / 255.0, green: 0x1D / 255.0, blue: 0x1E / 255.0, alpha: 1.0)
    )

    static let surfaceRaised = dynamic(
        light: UIColor(red: 0xED / 255.0, green: 0xED / 255.0, blue: 0xED / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x29 / 255.0, green: 0x29 / 255.0, blue: 0x2A / 255.0, alpha: 1.0)
    )

    static let ink = dynamic(
        light: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
        dark: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    )

    static let inkPrimary = dynamic(
        light: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.90),
        dark: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92)
    )

    static let textMuted = dynamic(
        light: UIColor(red: 0x59 / 255.0, green: 0x59 / 255.0, blue: 0x59 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xA4 / 255.0, green: 0xA4 / 255.0, blue: 0xA4 / 255.0, alpha: 1.0)
    )

    static let hairline = dynamic(
        light: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.08),
        dark: UIColor(red: 0x35 / 255.0, green: 0x35 / 255.0, blue: 0x36 / 255.0, alpha: 1.0)
    )

    static let borderStrong = dynamic(
        light: UIColor(red: 0xE0 / 255.0, green: 0xE0 / 255.0, blue: 0xE0 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x48 / 255.0, green: 0x48 / 255.0, blue: 0x4A / 255.0, alpha: 1.0)
    )

    static let correct = dynamic(
        light: UIColor(red: 0x1B / 255.0, green: 0x6E / 255.0, blue: 0x44 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x32 / 255.0, green: 0xD7 / 255.0, blue: 0x4B / 255.0, alpha: 1.0)
    )

    static let correctSoft = dynamic(
        light: UIColor(red: 0x1B / 255.0, green: 0x6E / 255.0, blue: 0x44 / 255.0, alpha: 0.10),
        dark: UIColor(red: 0x32 / 255.0, green: 0xD7 / 255.0, blue: 0x4B / 255.0, alpha: 0.16)
    )

    static let wrong = dynamic(
        light: UIColor(red: 0xB4 / 255.0, green: 0x23 / 255.0, blue: 0x18 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xFF / 255.0, green: 0x45 / 255.0, blue: 0x3A / 255.0, alpha: 1.0)
    )

    static let wrongSoft = dynamic(
        light: UIColor(red: 0xB4 / 255.0, green: 0x23 / 255.0, blue: 0x18 / 255.0, alpha: 0.10),
        dark: UIColor(red: 0xFF / 255.0, green: 0x45 / 255.0, blue: 0x3A / 255.0, alpha: 0.16)
    )

    static let critical = dynamic(
        light: UIColor(red: 0x9A / 255.0, green: 0x34 / 255.0, blue: 0x12 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xFF / 255.0, green: 0x9F / 255.0, blue: 0x0A / 255.0, alpha: 1.0)
    )

    static let criticalSoft = dynamic(
        light: UIColor(red: 0x9A / 255.0, green: 0x34 / 255.0, blue: 0x12 / 255.0, alpha: 0.10),
        dark: UIColor(red: 0xFF / 255.0, green: 0x9F / 255.0, blue: 0x0A / 255.0, alpha: 0.16)
    )

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

enum ClaudeSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 28
    static let xxxl: CGFloat = 32
    static let section: CGFloat = 40
    static let band: CGFloat = 44
}

enum ClaudeRadius {
    static let none: CGFloat = 0
    static let xs: CGFloat = 8
    static let sm: CGFloat = 9
    static let md: CGFloat = 10
    static let cardCompact: CGFloat = 20
    static let card: CGFloat = 32
}

enum ClaudeTypography {
    static func display(_ size: CGFloat = 44) -> Font {
        .system(size: size, weight: .light, design: .serif)
    }

    static let headingMD: Font = .system(size: 30, weight: .regular, design: .serif)
    static let headingSerifSM: Font = .system(size: 22, weight: .regular, design: .serif)
    static let bodyLGSerif: Font = .system(size: 18, weight: .regular, design: .serif)

    static let bodyXL: Font = .system(size: 24, weight: .medium, design: .default)
    static let bodyMD: Font = .system(size: 16, weight: .regular, design: .default)
    static let bodySM: Font = .system(size: 14, weight: .regular, design: .default)
    static let nav: Font = .system(size: 14, weight: .medium, design: .default)
    static let buttonStrong: Font = .system(size: 15, weight: .medium, design: .default)
    static let label: Font = .system(size: 15, weight: .regular, design: .default)
    static let bodyXS: Font = .system(size: 13, weight: .regular, design: .default)
    static let captionXS: Font = .system(size: 12, weight: .regular, design: .default)
    static let headingSM: Font = .system(size: 12, weight: .medium, design: .default)
}

private struct ClaudeCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let padding: CGFloat
    let radius: CGFloat
    let useSurfaceFill: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let fillColor: Color = {
            if colorScheme == .dark {
                return useSurfaceFill ? ClaudePalette.surfaceRaised : ClaudePalette.surface
            } else {
                return useSurfaceFill ? ClaudePalette.surface : ClaudePalette.canvas
            }
        }()

        content
            .padding(padding)
            .background(fillColor, in: shape)
            .overlay(
                shape.stroke(ClaudePalette.hairline, lineWidth: 1)
            )
            .shadow(
                color: colorScheme == .light ? Color.black.opacity(0.016) : .clear,
                radius: 12,
                x: 0,
                y: 4
            )
            .shadow(
                color: colorScheme == .light ? Color.black.opacity(0.014) : .clear,
                radius: 24,
                x: 0,
                y: 8
            )
            .shadow(
                color: colorScheme == .light ? Color.black.opacity(0.010) : .clear,
                radius: 32,
                x: 0,
                y: 16
            )
    }
}

private struct ClaudeSurfaceRowModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
        content
            .padding(ClaudeSpacing.md)
            .background(
                isSelected ? ClaudePalette.surfaceRaised : ClaudePalette.surface,
                in: shape
            )
            .overlay(
                shape.stroke(
                    isSelected ? ClaudePalette.inkPrimary : ClaudePalette.hairline,
                    lineWidth: isSelected ? 1.5 : 1
                )
            )
    }
}

extension View {
    func claudeCard(padding: CGFloat = ClaudeSpacing.xl, radius: CGFloat = ClaudeRadius.card) -> some View {
        modifier(ClaudeCardModifier(padding: padding, radius: radius, useSurfaceFill: false))
    }

    func claudeCompactCard(padding: CGFloat = ClaudeSpacing.md) -> some View {
        modifier(ClaudeCardModifier(padding: padding, radius: ClaudeRadius.cardCompact, useSurfaceFill: true))
    }

    func claudeSurfaceRow(isSelected: Bool = false) -> some View {
        modifier(ClaudeSurfaceRowModifier(isSelected: isSelected))
    }
}

struct ClaudePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
        configuration.label
            .font(ClaudeTypography.buttonStrong)
            .foregroundStyle(ClaudePalette.canvas)
            .frame(minHeight: 44)
            .padding(.horizontal, ClaudeSpacing.md)
            .background(ClaudePalette.inkPrimary, in: shape)
            .opacity(isEnabled ? (configuration.isPressed ? 0.84 : 1.0) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct ClaudeSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
        configuration.label
            .font(ClaudeTypography.buttonStrong)
            .foregroundStyle(ClaudePalette.inkPrimary)
            .frame(minHeight: 44)
            .padding(.horizontal, ClaudeSpacing.md)
            .background(ClaudePalette.surface, in: shape)
            .overlay(
                shape.stroke(ClaudePalette.borderStrong, lineWidth: 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1.0) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

nonisolated enum BadgeTone: Sendable {
    case neutral
    case critical
    case correct
    case wrong
    case dark
}

struct ClaudeBadge: View {
    let text: String
    let tone: BadgeTone

    init(text: String, tone: BadgeTone = .neutral) {
        self.text = text
        self.tone = tone
    }

    var body: some View {
        Text(text)
            .font(ClaudeTypography.captionXS)
            .fontWeight(.medium)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, ClaudeSpacing.xs)
            .padding(.vertical, ClaudeSpacing.xxs)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: ClaudeRadius.xs, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ClaudeRadius.xs, style: .continuous)
                    .stroke(borderColor, lineWidth: tone == .neutral ? 1 : 0)
            )
    }

    private var foregroundColor: Color {
        switch tone {
        case .neutral:
            return ClaudePalette.textMuted
        case .critical:
            return ClaudePalette.critical
        case .correct:
            return ClaudePalette.correct
        case .wrong:
            return ClaudePalette.wrong
        case .dark:
            return ClaudePalette.canvas
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .neutral:
            return ClaudePalette.surfaceRaised
        case .critical:
            return ClaudePalette.criticalSoft
        case .correct:
            return ClaudePalette.correctSoft
        case .wrong:
            return ClaudePalette.wrongSoft
        case .dark:
            return ClaudePalette.inkPrimary
        }
    }

    private var borderColor: Color {
        tone == .neutral ? ClaudePalette.hairline : .clear
    }
}

struct ClaudeSectionHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?

    init(eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.xxs) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow.uppercased())
                    .font(ClaudeTypography.captionXS)
                    .fontWeight(.medium)
                    .foregroundStyle(ClaudePalette.textMuted)
            }

            Text(title)
                .font(ClaudeTypography.headingSerifSM)
                .foregroundStyle(ClaudePalette.ink)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(ClaudeTypography.bodySM)
                    .foregroundStyle(ClaudePalette.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
