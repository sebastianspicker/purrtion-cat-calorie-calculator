import SwiftUI
import PurrtionCore

// The 12 cat profile icons, redrawn from brand/cat-icons.svg (24 x 24, the source of truth) and apps/web/src/cat-icons.ts.
// Coordinates are SVG user units; outlines are 1.6 ink with round joins and caps. Colours are fixed brand colours.

private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
private func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
}
private func shape(_ build: (inout Path) -> Void) -> Path { var path = Path(); build(&path); return path }

private extension Path {
    /// The SVG `A r r 0 large sweep x y` command (circular arcs only), drawn as cubic curves from the current point.
    /// Angles follow SVG's y-down convention, so `sweep` means a positive angle direction.
    mutating func svgArc(to end: CGPoint, radius: CGFloat, large: Bool, sweep: Bool) {
        guard let start = currentPoint else { return }
        let dx = (start.x - end.x) / 2, dy = (start.y - end.y) / 2
        let d2 = dx * dx + dy * dy
        guard d2 > 0 else { return }
        let r = max(radius, d2.squareRoot())
        let k = max(0, (r * r - d2) / d2).squareRoot()
        let sign: CGFloat = large != sweep ? 1 : -1
        let cx = sign * k * dy + (start.x + end.x) / 2
        let cy = -sign * k * dx + (start.y + end.y) / 2
        let a0 = atan2(start.y - cy, start.x - cx), a1 = atan2(end.y - cy, end.x - cx)
        var delta = a1 - a0
        if sweep && delta < 0 { delta += 2 * .pi }
        if !sweep && delta > 0 { delta -= 2 * .pi }
        let count = max(1, Int((abs(delta) / (.pi / 2)).rounded(.up)))
        let step = delta / CGFloat(count), handle = 4 / 3 * tan(step / 4) * r
        for i in 0..<count {
            let t0 = a0 + step * CGFloat(i), t1 = t0 + step
            let from = pt(cx + r * cos(t0), cy + r * sin(t0)), to = i == count - 1 ? end : pt(cx + r * cos(t1), cy + r * sin(t1))
            addCurve(to: to,
                     control1: pt(from.x - handle * sin(t0), from.y + handle * cos(t0)),
                     control2: pt(cx + r * cos(t1) + handle * sin(t1), cy + r * sin(t1) - handle * cos(t1)))
        }
    }
}

/// Fills and outlines a shape the way the sprite does.
private func solid(_ context: GraphicsContext, _ path: Path, _ fill: Color, width: CGFloat = 1.6) {
    context.fill(path, with: .color(fill))
    context.stroke(path, with: .color(Theme.Brand.ink), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
}
/// An unfilled ink stroke.
private func line(_ context: GraphicsContext, _ path: Path, width: CGFloat = 1.6) {
    context.stroke(path, with: .color(Theme.Brand.ink), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
}
private func dot(_ context: GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
    context.fill(circle(cx, cy, r), with: .color(Theme.Brand.ink))
}

private func draw(_ icon: CatIcon, in context: GraphicsContext) {
    let B = Theme.Brand.self
    switch icon {
    case .moon:
        solid(context, shape {
            $0.move(to: pt(14.6, 3.8))
            $0.svgArc(to: pt(20.2, 15.6), radius: 8.4, large: true, sweep: false)
            $0.svgArc(to: pt(14.6, 3.8), radius: 6.6, large: false, sweep: true)
            $0.closeSubpath()
        }, B.yolk)
        dot(context, 18.6, 5.4, 1)
    case .scale:
        solid(context, shape {
            $0.move(to: pt(5.4, 9.2)); $0.addLine(to: pt(18.6, 9.2))
            $0.addCurve(to: pt(12, 13.6), control1: pt(18.1, 12.4), control2: pt(15.4, 13.6))
            $0.addCurve(to: pt(5.4, 9.2), control1: pt(8.6, 13.6), control2: pt(5.9, 12.4))
            $0.closeSubpath()
        }, B.sakuraLight)
        solid(context, Path(roundedRect: CGRect(x: 4.6, y: 14.2, width: 14.8, height: 6.4), cornerRadius: 2.2), B.sky)
        solid(context, circle(12, 17.4, 1.7), B.white, width: 1.3)
    case .dango:
        context.stroke(shape { $0.move(to: pt(5.5, 21)); $0.addLine(to: pt(19, 3.5)) }, with: .color(B.wood),
                       style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        solid(context, circle(8.6, 17, 3.3), B.matcha)
        solid(context, circle(12.25, 12.25, 3.3), B.white)
        solid(context, circle(15.9, 7.5, 3.3), B.sakuraLight)
        dot(context, 11.2, 12.2, 0.55); dot(context, 13.3, 12.2, 0.55)
    case .stripes:
        solid(context, shape {
            $0.move(to: pt(5.2, 9.6)); $0.addLine(to: pt(5.6, 4.4)); $0.addLine(to: pt(9.6, 6.9)); $0.closeSubpath()
            $0.move(to: pt(18.8, 9.6)); $0.addLine(to: pt(18.4, 4.4)); $0.addLine(to: pt(14.4, 6.9)); $0.closeSubpath()
        }, B.tiger)
        solid(context, circle(12, 13, 7.6), B.tiger)
        line(context, shape {
            $0.move(to: pt(10.6, 6.2)); $0.addLine(to: pt(11, 8.4))
            $0.move(to: pt(12, 5.6)); $0.addLine(to: pt(12, 8.4))
            $0.move(to: pt(13.4, 6.2)); $0.addLine(to: pt(13, 8.4))
            $0.move(to: pt(4.8, 13)); $0.addLine(to: pt(7.2, 13))
            $0.move(to: pt(5, 15.2)); $0.addLine(to: pt(7.4, 15.2))
            $0.move(to: pt(19.2, 13)); $0.addLine(to: pt(16.8, 13))
            $0.move(to: pt(19, 15.2)); $0.addLine(to: pt(16.6, 15.2))
        }, width: 1.3)
        dot(context, 9.6, 12.4, 0.95); dot(context, 14.4, 12.4, 0.95)
        line(context, shape {
            $0.move(to: pt(11, 15.2)); $0.addQuadCurve(to: pt(12, 15.2), control: pt(11.5, 15.9))
            $0.addQuadCurve(to: pt(13, 15.2), control: pt(12.5, 15.9))
        }, width: 1.1)
    case .bolt:
        solid(context, shape {
            $0.move(to: pt(13.6, 2.8)); $0.addLine(to: pt(5.8, 13.4)); $0.addLine(to: pt(11.2, 13.4)); $0.addLine(to: pt(10, 21.2))
            $0.addLine(to: pt(18.2, 9.8)); $0.addLine(to: pt(12.8, 9.8)); $0.closeSubpath()
        }, B.yolk)
    case .paw:
        solid(context, Path(ellipseIn: CGRect(x: 12 - 4.4, y: 15.6 - 3.7, width: 8.8, height: 7.4)), B.sakuraLight)
        for (cx, cy) in [(6.4, 10.6), (9.9, 7.0), (14.1, 7.0), (17.6, 10.6)] { solid(context, circle(cx, cy, 1.9), B.sakuraLight) }
    case .fish:
        solid(context, shape {
            $0.move(to: pt(3.6, 12))
            $0.addCurve(to: pt(16.8, 12), control1: pt(6.6, 6.8), control2: pt(13.6, 6.8))
            $0.addCurve(to: pt(3.6, 12), control1: pt(13.6, 17.2), control2: pt(6.6, 17.2))
            $0.closeSubpath()
        }, B.sky)
        solid(context, shape { $0.move(to: pt(16.8, 12)); $0.addLine(to: pt(20.6, 8.4)); $0.addLine(to: pt(20.6, 15.6)); $0.closeSubpath() }, B.sky)
        dot(context, 7.6, 11.2, 0.9)
        line(context, shape { $0.move(to: pt(11.4, 9.6)); $0.addQuadCurve(to: pt(11.4, 14.4), control: pt(12.8, 12)) }, width: 1.2)
    case .yarn:
        solid(context, circle(11, 11, 7.4), B.sakuraLight)
        line(context, shape {
            $0.move(to: pt(5.4, 7.8)); $0.addQuadCurve(to: pt(15.6, 5.4), control: pt(11, 9.4))
            $0.move(to: pt(4.4, 12.4)); $0.addQuadCurve(to: pt(17.6, 8.8), control: pt(11, 13))
            $0.move(to: pt(6.6, 16.8)); $0.addQuadCurve(to: pt(17.8, 12.6), control: pt(12.4, 15.6))
        }, width: 1.2)
        line(context, shape { $0.move(to: pt(16.2, 16.2)); $0.addQuadCurve(to: pt(19.4, 21), control: pt(19.6, 17.4)) })
    case .star:
        solid(context, shape {
            $0.move(to: pt(12, 3.4)); $0.addLine(to: pt(14.5, 8.6)); $0.addLine(to: pt(20.2, 9.3)); $0.addLine(to: pt(16, 13.2))
            $0.addLine(to: pt(17.1, 18.8)); $0.addLine(to: pt(12, 16)); $0.addLine(to: pt(6.9, 18.8)); $0.addLine(to: pt(8, 13.2))
            $0.addLine(to: pt(3.8, 9.3)); $0.addLine(to: pt(9.5, 8.6)); $0.closeSubpath()
        }, B.yolk)
    case .heart:
        solid(context, shape {
            $0.move(to: pt(12, 20))
            $0.addCurve(to: pt(5.4, 8.2), control1: pt(5.4, 15.4), control2: pt(3.6, 11.4))
            $0.addCurve(to: pt(12, 8.4), control1: pt(7.2, 5.2), control2: pt(10.8, 5.6))
            $0.addCurve(to: pt(18.6, 8.2), control1: pt(13.2, 5.6), control2: pt(16.8, 5.2))
            $0.addCurve(to: pt(12, 20), control1: pt(20.4, 11.4), control2: pt(18.6, 15.4))
            $0.closeSubpath()
        }, B.sakura)
    case .leaf:
        solid(context, shape {
            $0.move(to: pt(4.8, 19.2))
            $0.addCurve(to: pt(19.2, 4.8), control1: pt(4.8, 10.2), control2: pt(9.8, 4.8))
            $0.addCurve(to: pt(4.8, 19.2), control1: pt(19.2, 14.2), control2: pt(13.8, 19.2))
            $0.closeSubpath()
        }, B.matcha)
        line(context, shape { $0.move(to: pt(5.6, 18.4)); $0.addLine(to: pt(14.4, 9.6)) }, width: 1.3)
    case .bow:
        solid(context, shape {
            $0.move(to: pt(12, 12))
            $0.addCurve(to: pt(4.2, 11.6), control1: pt(9, 7), control2: pt(4, 7.2))
            $0.addCurve(to: pt(12, 12), control1: pt(4.4, 16), control2: pt(9, 16.4))
            $0.closeSubpath()
        }, B.sakura)
        solid(context, shape {
            $0.move(to: pt(12, 12))
            $0.addCurve(to: pt(19.8, 11.6), control1: pt(15, 7), control2: pt(20, 7.2))
            $0.addCurve(to: pt(12, 12), control1: pt(19.6, 16), control2: pt(15, 16.4))
            $0.closeSubpath()
        }, B.sakura)
        line(context, shape {
            $0.move(to: pt(10.6, 13.4)); $0.addLine(to: pt(8.6, 19.4))
            $0.move(to: pt(13.4, 13.4)); $0.addLine(to: pt(15.4, 19.4))
        })
        solid(context, circle(12, 12, 2), B.sakuraLight)
    }
}

/// One icon, drawn on its 24 x 24 grid. Decorative: whatever holds it supplies the accessible name.
struct CatIconView: View {
    let icon: CatIcon
    var size: CGFloat = 24
    var body: some View {
        Canvas { context, canvasSize in
            fit(&context, size: canvasSize, viewBox: CGRect(x: 0, y: 0, width: 24, height: 24))
            draw(icon, in: context)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The round badge at the corner of an avatar: white disc, 1.5 pt ink ring, the icon inset inside it (about 40 % of the avatar).
struct CatIconBadge: View {
    let icon: CatIcon
    let avatarSize: CGFloat
    var body: some View {
        let diameter = max(10, (avatarSize * 0.4).rounded())
        ZStack {
            Circle().fill(Theme.Brand.white)
            Circle().strokeBorder(Theme.Brand.ink, lineWidth: 1.5)
            CatIconView(icon: icon, size: diameter * 0.72)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

/// Choose a cat's picture: the 12 icons or none. Each button is named from `icon.*` in shared/messages.json.
struct CatIconPicker: View {
    @Binding var selection: CatIcon?
    @Environment(\.l10n) private var l

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 52), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(CatIcon.allCases, id: \.self) { icon in
                choice(isSelected: selection == icon, label: l.msg("icon.\(icon.rawValue)")) { selection = icon } content: {
                    CatIconView(icon: icon, size: 28)
                }
            }
            choice(isSelected: selection == nil, label: l.t("icon.none")) { selection = nil } content: {
                Text(l.t("icon.none")).font(.caption.weight(.semibold)).foregroundStyle(Theme.ink)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l.t("icon.legend"))
    }

    private func choice<Content: View>(isSelected: Bool, label: String, action: @escaping () -> Void,
                                       @ViewBuilder content: () -> Content) -> some View {
        let frame = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return Button(action: action) {
            content()
                .frame(minWidth: 44, minHeight: 44)
                .background(frame.fill(isSelected ? Theme.sakura.opacity(0.22) : Theme.panel))
                .overlay(frame.strokeBorder(isSelected ? Theme.sakuraInk : Theme.ink.opacity(0.35), lineWidth: isSelected ? 3 : 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
