import SwiftUI
import AppKit

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32) { self.init(nsColor: NSColor(hex: hex)) }
    /// A colour that follows the system appearance (light/dark).
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        })
    }
}

/// Design tokens shared with the website (apps/web/styles.css). Light values are the brand values;
/// dark values for paper, panel and ink are the website's dark theme.
enum Theme {
    static let paper = Color.dynamic(light: 0xF6F4FC, dark: 0x1D1930)
    static let panel = Color.dynamic(light: 0xFFFFFF, dark: 0x272140)
    static let ink = Color.dynamic(light: 0x2B2541, dark: 0xEEEAF8)
    static let muted = Color.dynamic(light: 0x5E5878, dark: 0xB7B0D0)
    static let sakura = Color(hex: 0xE8779E)
    static let sakuraLight = Color(hex: 0xF4A9C2)
    static let sakuraInk = Color.dynamic(light: 0xB3365F, dark: 0xF4A9C2)
    static let matcha = Color(hex: 0x7CC49A)
    static let matchaInk = Color.dynamic(light: 0x2D7550, dark: 0x9FD8B5)
    static let sky = Color(hex: 0x8DBDEB)
    static let skyInk = Color.dynamic(light: 0x2C64A0, dark: 0xA9CDF2)
    static let yolk = Color(hex: 0xF5CF6B)
    static let yolkInk = Color.dynamic(light: 0x7A5A00, dark: 0xF5CF6B)
    static let alert = Color.dynamic(light: 0xC8323F, dark: 0xFF7A85)
    /// Fixed brand colours for the drawn mark and mascot; the cat is never recoloured (brand/README.md).
    enum Brand {
        static let ink = Color(hex: 0x2B2541)
        static let white = Color.white
        static let sakura = Color(hex: 0xE8779E)
        static let sakuraLight = Color(hex: 0xF4A9C2)
        static let sky = Color(hex: 0x8DBDEB)
        static let skyInk = Color(hex: 0x2C64A0)
        static let yolk = Color(hex: 0xF5CF6B)
        static let matcha = Color(hex: 0x7CC49A)
        /// Tiger-stripe orange and skewer wood, used by the cat icons.
        static let tiger = Color(hex: 0xF4B36A)
        static let wood = Color(hex: 0xB58A5A)
    }
}

/// Primary panels: 2 pt ink stroke, 16 pt corners, hard offset shadow.
struct StickerCard: ViewModifier {
    var fill: Color = Theme.panel
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(fill).shadow(color: Theme.ink.opacity(0.18), radius: 0, x: 3, y: 3))
            .overlay(shape.strokeBorder(Theme.ink, lineWidth: 2))
    }
}

/// Plain panels for warnings and veterinary referrals: no sticker styling, no mascot.
struct PlainPanel: ViewModifier {
    var tint: Color = Theme.alert
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(tint.opacity(0.08)))
            .overlay(shape.strokeBorder(tint, lineWidth: 1))
    }
}

extension View {
    func stickerCard(fill: Color = Theme.panel, padding: CGFloat = 16) -> some View {
        modifier(StickerCard(fill: fill, padding: padding))
    }
    func plainPanel(tint: Color = Theme.alert) -> some View { modifier(PlainPanel(tint: tint)) }
    /// Rounded headings with tabular digits.
    func roundedHeading(_ font: Font = .title3) -> some View {
        self.font(font.weight(.bold)).fontDesign(.rounded).monospacedDigit()
    }
    /// Large rounded numbers with tabular digits.
    func bigNumber(size: CGFloat = 34) -> some View {
        self.font(.system(size: size, weight: .bold, design: .rounded)).monospacedDigit()
    }
}

enum ChipTone { case neutral, sakura, matcha, sky, yolk, alert }

/// A small rounded label (status, stage, equation).
struct Chip: View {
    let text: String
    var tone: ChipTone = .neutral
    private var colors: (fill: Color, ink: Color) {
        switch tone {
        case .neutral: (Theme.muted.opacity(0.15), Theme.ink)
        case .sakura: (Theme.sakura.opacity(0.22), Theme.sakuraInk)
        case .matcha: (Theme.matcha.opacity(0.25), Theme.matchaInk)
        case .sky: (Theme.sky.opacity(0.25), Theme.skyInk)
        case .yolk: (Theme.yolk.opacity(0.30), Theme.yolkInk)
        case .alert: (Theme.alert.opacity(0.12), Theme.alert)
        }
    }
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold)).fontDesign(.rounded)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .foregroundStyle(colors.ink)
            .background(Capsule().fill(colors.fill))
            .overlay(Capsule().strokeBorder(colors.ink.opacity(0.35), lineWidth: 1))
    }
}
