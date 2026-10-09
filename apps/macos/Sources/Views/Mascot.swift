import SwiftUI
import PurrtionCore

// Vector drawings in SVG viewBox units, matching brand/purrtion-mark.svg and apps/web/src/mascot.ts.
// Never used on warning, error or veterinary-referral panels (brand/README.md).

private func polygon(_ points: [CGPoint]) -> Path {
    var path = Path()
    guard let first = points.first else { return path }
    path.move(to: first)
    for point in points.dropFirst() { path.addLine(to: point) }
    path.closeSubpath()
    return path
}
private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
private func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
}
/// Scales and centres the context so that `viewBox` fits `size` (like SVG's default preserveAspectRatio).
func fit(_ context: inout GraphicsContext, size: CGSize, viewBox: CGRect) {
    let scale = min(size.width / viewBox.width, size.height / viewBox.height)
    context.translateBy(x: (size.width - viewBox.width * scale) / 2, y: (size.height - viewBox.height * scale) / 2)
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: -viewBox.minX, y: -viewBox.minY)
}
private let roundStroke = StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round)

/// The Purrtion mark: a cat peeking out of a graduated food bowl, with a white die-cut sticker edge.
struct BrandMark: View {
    var size: CGFloat = 36
    var body: some View {
        Canvas { context, canvasSize in
            fit(&context, size: canvasSize, viewBox: CGRect(x: 0, y: 4, width: 64, height: 56))
            let B = Theme.Brand.self
            let ears = polygon([p(17, 26), p(18.2, 12), p(29.5, 18)])
            let ears2 = polygon([p(47, 26), p(45.8, 12), p(34.5, 18)])
            let head = ellipse(32, 30.5, 16, 13.5)
            let rim = Path(roundedRect: CGRect(x: 7, y: 33, width: 50, height: 5.5), cornerRadius: 2.75)
            var bowl = Path()
            bowl.move(to: p(9.6, 36)); bowl.addLine(to: p(54.4, 36))
            bowl.addCurve(to: p(32, 54.5), control1: p(53.4, 47), control2: p(46, 54.5))
            bowl.addCurve(to: p(9.6, 36), control1: p(18, 54.5), control2: p(10.6, 47))
            bowl.closeSubpath()
            // Die-cut sticker edge.
            let edge = StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
            for shape in [ears, ears2, head, rim, bowl] { context.fill(shape, with: .color(B.white)); context.stroke(shape, with: .color(B.white), style: edge) }
            // Ears and head.
            for ear in [ears, ears2] { context.fill(ear, with: .color(B.white)); context.stroke(ear, with: .color(B.ink), style: roundStroke) }
            context.fill(polygon([p(20.4, 16.4), p(20.9, 21.6), p(25.8, 18.9)]), with: .color(B.sakuraLight))
            context.fill(polygon([p(43.6, 16.4), p(43.1, 21.6), p(38.2, 18.9)]), with: .color(B.sakuraLight))
            context.fill(head, with: .color(B.white)); context.stroke(head, with: .color(B.ink), style: roundStroke)
            // Bowl and rim.
            context.fill(bowl, with: .color(B.sakura)); context.stroke(bowl, with: .color(B.ink), style: roundStroke)
            context.fill(rim, with: .color(B.sakuraLight)); context.stroke(rim, with: .color(B.ink), style: roundStroke)
            // Face.
            context.fill(ellipse(25.6, 26.8, 2.1, 2.1), with: .color(B.ink))
            context.fill(ellipse(38.4, 26.8, 2.1, 2.1), with: .color(B.ink))
            context.fill(ellipse(21.6, 30.1, 2.4, 1.3), with: .color(B.sakura.opacity(0.6)))
            context.fill(ellipse(42.4, 30.1, 2.4, 1.3), with: .color(B.sakura.opacity(0.6)))
            var mouth = Path()
            mouth.move(to: p(30, 29.4))
            mouth.addQuadCurve(to: p(32, 29.4), control: p(31, 30.6))
            mouth.addQuadCurve(to: p(34, 29.4), control: p(33, 30.6))
            context.stroke(mouth, with: .color(B.ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            // Measuring graduations.
            var marks = Path()
            marks.move(to: p(41, 42)); marks.addLine(to: p(48, 42))
            marks.move(to: p(44, 45.5)); marks.addLine(to: p(48, 45.5))
            marks.move(to: p(41, 49)); marks.addLine(to: p(46, 49))
            context.stroke(marks, with: .color(B.ink.opacity(0.8)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

enum MascotExpression: Sendable { case happy, curious, thinking }

/// The cat face (white face, ink outline, triangular ears with sakura inner ears, dot eyes, "w" mouth, blush),
/// optionally on a pastel disc and with Professor Purr's wizard hat.
struct CatFace: View {
    var size: CGFloat = 40
    var tint: Color? = nil
    var expression: MascotExpression = .happy
    var hat = false
    var body: some View {
        Canvas { context, canvasSize in
            let viewBox = hat ? CGRect(x: 0, y: -4, width: 64, height: 60) : CGRect(x: 0, y: 6, width: 64, height: 50)
            fit(&context, size: canvasSize, viewBox: viewBox)
            let B = Theme.Brand.self
            if let tint { context.fill(ellipse(32, hat ? 26 : 31, hat ? 31 : 26, hat ? 31 : 26), with: .color(tint)) }
            let outline = StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)
            for ear in [polygon([p(15, 33), p(17, 15), p(30, 23)]), polygon([p(49, 33), p(47, 15), p(34, 23)])] {
                context.fill(ear, with: .color(B.white)); context.stroke(ear, with: .color(B.ink), style: outline)
            }
            context.fill(polygon([p(19, 20), p(19.6, 26.5), p(25.4, 23.3)]), with: .color(B.sakuraLight))
            context.fill(polygon([p(45, 20), p(44.4, 26.5), p(38.6, 23.3)]), with: .color(B.sakuraLight))
            let head = ellipse(32, 37, 18, 15)
            context.fill(head, with: .color(B.white)); context.stroke(head, with: .color(B.ink), style: outline)
            context.fill(ellipse(22.5, 40.6, 2.8, 1.5), with: .color(B.sakura.opacity(0.6)))
            context.fill(ellipse(41.5, 40.6, 2.8, 1.5), with: .color(B.sakura.opacity(0.6)))
            let thin = StrokeStyle(lineWidth: 1.6, lineCap: .round)
            switch expression {
            case .curious:
                context.fill(ellipse(25.5, 35.5, 3, 3), with: .color(B.ink)); context.fill(ellipse(38.5, 35.5, 3, 3), with: .color(B.ink))
                context.fill(ellipse(26.5, 34.4, 0.9, 0.9), with: .color(B.white)); context.fill(ellipse(39.5, 34.4, 0.9, 0.9), with: .color(B.white))
                context.stroke(ellipse(32, 42.4, 1.4, 1.7), with: .color(B.ink), style: StrokeStyle(lineWidth: 1.5))
            case .thinking:
                context.fill(ellipse(26.6, 34.6, 2.2, 2.2), with: .color(B.ink)); context.fill(ellipse(39.6, 34.6, 2.2, 2.2), with: .color(B.ink))
                var mouth = Path(); mouth.move(to: p(29.5, 42.5)); mouth.addLine(to: p(34.5, 42.5))
                context.stroke(mouth, with: .color(B.ink), style: thin)
            case .happy:
                context.fill(ellipse(25.5, 36, 2.2, 2.2), with: .color(B.ink)); context.fill(ellipse(38.5, 36, 2.2, 2.2), with: .color(B.ink))
                var mouth = Path()
                mouth.move(to: p(29.8, 40.6))
                mouth.addQuadCurve(to: p(32, 40.6), control: p(30.9, 41.9))
                mouth.addQuadCurve(to: p(34.2, 40.6), control: p(33.1, 41.9))
                context.stroke(mouth, with: .color(B.ink), style: thin)
            }
            if hat { drawHat(&context) }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
    private func drawHat(_ context: inout GraphicsContext) {
        let B = Theme.Brand.self
        var cone = Path()
        cone.move(to: p(20, 22))
        cone.addQuadCurve(to: p(44, 22), control: p(32, 25))
        cone.addLine(to: p(35, 1.5))
        cone.addQuadCurve(to: p(32, 2), control: p(33.5, -0.5))
        cone.closeSubpath()
        context.fill(cone, with: .color(B.sky))
        context.stroke(cone, with: .color(B.ink), style: StrokeStyle(lineWidth: 2.4, lineJoin: .round))
        var band = Path()
        band.move(to: p(21.6, 18.6))
        band.addQuadCurve(to: p(42.4, 18.6), control: p(32, 21.6))
        band.addLine(to: p(43.4, 21))
        band.addQuadCurve(to: p(20.6, 21), control: p(32, 24.4))
        band.closeSubpath()
        context.fill(band, with: .color(B.sakura))
        context.stroke(band, with: .color(B.ink), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
        let star = polygon([p(31, 7.5), p(32.2, 10), p(34.9, 10.3), p(32.9, 12.1), p(33.5, 14.8), p(31, 13.4),
                            p(28.6, 14.8), p(29.2, 12.1), p(27.2, 10.3), p(29.9, 10)])
        context.fill(star, with: .color(B.yolk))
        context.stroke(star, with: .color(B.skyInk), style: StrokeStyle(lineWidth: 0.6))
    }
}

/// A stable pastel for a cat id: FNV-1a hash → hue, `hsl(hue 72% 86%)` like the website.
func pastel(for id: String) -> Color {
    var hash: UInt32 = 0x811c9dc5
    for unit in id.utf16 { hash ^= UInt32(unit); hash = hash &* 0x01000193 }
    let hue = Double(hash % 360) / 360, s = 0.72, l = 0.86
    // HSL → HSB
    let v = l + s * min(l, 1 - l)
    let sv = v == 0 ? 0 : 2 * (1 - l / v)
    return Color(hue: hue, saturation: sv, brightness: v)
}

/// Per-cat avatar: the face on the cat's own pastel, with the cat's icon as a badge at the bottom right.
struct CatAvatar: View {
    let id: String
    var icon: CatIcon? = nil
    var size: CGFloat = 36
    var body: some View {
        CatFace(size: size, tint: pastel(for: id))
            .overlay(alignment: .bottomTrailing) {
                if let icon { CatIconBadge(icon: icon, avatarSize: size).offset(x: 3, y: 2) }
            }
    }
}

/// Professor Purr with a speech bubble.
struct ProfessorPurr: View {
    let text: String
    var expression: MascotExpression = .curious
    @Environment(\.l10n) private var l
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CatFace(size: 64, expression: expression, hat: true)
            VStack(alignment: .leading, spacing: 4) {
                Text(l.t("wizard.guideName")).font(.caption.weight(.bold)).fontDesign(.rounded).foregroundStyle(Theme.sakuraInk)
                Text(text).fixedSize(horizontal: false, vertical: true)
            }
            .stickerCard(padding: 12)
        }
    }
}
