import SwiftUI
import PurrtionCore

/// Values drawn on the energy ruler (kcal/day); any may be nil.
struct RulerData: Equatable {
    var lowKcal: Double?, highKcal: Double?, startKcal: Double?, floorKcal: Double?
    var bandLowKcal: Double?, bandHighKcal: Double?, targetKcal: Double?

    init(lowKcal: Double? = nil, highKcal: Double? = nil, startKcal: Double? = nil, floorKcal: Double? = nil,
         bandLowKcal: Double? = nil, bandHighKcal: Double? = nil, targetKcal: Double? = nil) {
        self.lowKcal = lowKcal; self.highKcal = highKcal; self.startKcal = startKcal; self.floorKcal = floorKcal
        self.bandLowKcal = bandLowKcal; self.bandHighKcal = bandHighKcal; self.targetKcal = targetKcal
    }
    init(estimate e: EnergyEstimate, target: Double?) {
        self.init(lowKcal: e.lowKcal, highKcal: e.highKcal, startKcal: e.startKcal, floorKcal: e.floorKcal,
                  bandLowKcal: e.referenceBand?.lowKcal, bandHighKcal: e.referenceBand?.highKcal, targetKcal: target)
    }
    var values: [Double] {
        [lowKcal, highKcal, startKcal, floorKcal, bandLowKcal, bandHighKcal, targetKcal].compactMap { $0 }.filter(\.isFinite)
    }
}

/// The axis domain: rounded to a "nice" step with some margin (same as apps/web/src/ruler.ts).
struct RulerScale {
    let min: Double, max: Double, step: Double
    init?(_ data: RulerData) {
        let values = data.values
        guard var lo = values.min(), var hi = values.max() else { return nil }
        if hi - lo < 20 { lo -= 10; hi += 10 }
        let raw = (hi - lo) / 5, power = pow(10, floor(log10(raw))), unit = raw / power
        let step = (unit < 1.5 ? 1 : unit < 3 ? 2 : unit < 7 ? 5 : 10) * power
        self.step = step
        min = Swift.max(0, floor((lo - step * 0.4) / step) * step)
        max = ceil((hi + step * 0.4) / step) * step
    }
    var ticks: [Double] {
        var result: [Double] = [], v = min
        while v <= max + 1e-9 { result.append(v); v += step }
        return result
    }
}

/// Diagonal hatch lines filling a rectangle.
private struct Hatch: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(), x = rect.minX - rect.height
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.maxY)); path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += 6
        }
        return path
    }
}
private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
/// A paw print pointing down; drawn in a 20 × 30 box whose bottom centre is the pin point.
private struct PawPin: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 20, sy = rect.height / 30
        func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: rect.minX + (x + 10) * sx, y: rect.minY + (y + 30) * sy) }
        func oval(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> CGRect {
            CGRect(x: rect.minX + (cx - rx + 10) * sx, y: rect.minY + (cy - ry + 30) * sy, width: 2 * rx * sx, height: 2 * ry * sy)
        }
        var path = Path()
        path.move(to: pt(0, 0)); path.addLine(to: pt(-5, -9)); path.addLine(to: pt(5, -9)); path.closeSubpath()
        path.addEllipse(in: oval(0, -16, 6.4, 5.4))
        path.addEllipse(in: oval(-7.4, -24, 2.3, 2.9)); path.addEllipse(in: oval(-2.6, -27.6, 2.3, 2.9))
        path.addEllipse(in: oval(2.6, -27.6, 2.3, 2.9)); path.addEllipse(in: oval(7.4, -24, 2.3, 2.9))
        return path
    }
}

/// The energy ruler: kcal/day scale with the reference band (hatched), the estimate range (sky capsule),
/// the start (ink diamond), the floor (dashed alert line) and the target (sakura paw pin, animated on change).
struct EnergyRuler: View {
    let data: RulerData
    @Environment(\.l10n) private var l
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let height: CGFloat = 104, pad: CGFloat = 18, axisY: CGFloat = 62

    var body: some View {
        if let scale = RulerScale(data) {
            VStack(alignment: .leading, spacing: 10) {
                GeometryReader { geo in
                    canvas(scale: scale, width: geo.size.width)
                }
                .frame(height: height)
                legend
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
        }
    }

    private func x(_ value: Double, _ scale: RulerScale, _ width: CGFloat) -> CGFloat {
        pad + CGFloat((value - scale.min) / (scale.max - scale.min)) * (width - 2 * pad)
    }

    @ViewBuilder private func canvas(scale: RulerScale, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            if let lo = data.bandLowKcal, let hi = data.bandHighKcal {
                let w = max(1, x(hi, scale, width) - x(lo, scale, width))
                Hatch().stroke(Theme.muted.opacity(0.45), lineWidth: 1)
                    .background(Theme.muted.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .frame(width: w, height: 22)
                    .position(x: x(lo, scale, width) + w / 2, y: axisY - 15)
            }
            axisAndTicks(scale: scale, width: width)
            Text(l.t("unit.kcalPerDay")).font(.caption2).foregroundStyle(Theme.muted)
                .position(x: width - pad - 28, y: axisY + 34)
            if let lo = data.lowKcal, let hi = data.highKcal {
                let w = max(8, x(hi, scale, width) - x(lo, scale, width))
                Capsule().fill(Theme.sky).overlay(Capsule().strokeBorder(Theme.skyInk, lineWidth: 1.2))
                    .frame(width: w, height: 10)
                    .position(x: x(lo, scale, width) + w / 2, y: axisY - 15)
            }
            if let start = data.startKcal {
                Diamond().fill(Theme.ink).frame(width: 12, height: 16)
                    .position(x: x(start, scale, width), y: axisY - 15)
            }
            if let floor = data.floorKcal {
                let fx = x(floor, scale, width)
                Path { path in path.move(to: CGPoint(x: fx, y: 8)); path.addLine(to: CGPoint(x: fx, y: axisY + 4)) }
                    .stroke(Theme.alert, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                Text(l.t("ruler.floor")).font(.caption2.weight(.semibold)).foregroundStyle(Theme.alert)
                    .fixedSize().position(x: fx + 22, y: 10)
            }
            if let target = data.targetKcal {
                PawPin().fill(Theme.sakura).overlay(PawPin().stroke(Theme.sakuraInk, lineWidth: 1))
                    .frame(width: 20, height: 30)
                    .position(x: x(target, scale, width), y: axisY - 16)
                    .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7), value: target)
            }
        }
        .frame(width: width, height: height)
    }

    @ViewBuilder private func axisAndTicks(scale: RulerScale, width: CGFloat) -> some View {
        let ticks = scale.ticks
        Path { path in
            path.move(to: CGPoint(x: pad, y: axisY)); path.addLine(to: CGPoint(x: width - pad, y: axisY))
            for v in ticks {
                let tx = x(v, scale, width)
                path.move(to: CGPoint(x: tx, y: axisY)); path.addLine(to: CGPoint(x: tx, y: axisY + 6))
                for minor in 1..<5 {
                    let mv = v + scale.step * Double(minor) / 5
                    if mv < scale.max {
                        let mx = x(mv, scale, width)
                        path.move(to: CGPoint(x: mx, y: axisY)); path.addLine(to: CGPoint(x: mx, y: axisY + 3))
                    }
                }
            }
        }
        .stroke(Theme.ink, lineWidth: 1.5)
        ForEach(ticks, id: \.self) { v in
            Text(l.int(v)).font(.caption2).monospacedDigit().foregroundStyle(Theme.muted)
                .fixedSize().position(x: x(v, scale, width), y: axisY + 17)
        }
    }

    private struct Row: Identifiable { let key: String, label: String, value: String; var id: String { key } }
    private var rows: [Row] {
        var rows: [Row] = []
        if let t = data.targetKcal { rows.append(Row(key: "target", label: l.t("ruler.target"), value: l.kcalPerDay(t))) }
        if let s = data.startKcal { rows.append(Row(key: "start", label: l.t("ruler.start"), value: l.kcalPerDay(s))) }
        if let lo = data.lowKcal, let hi = data.highKcal {
            rows.append(Row(key: "range", label: l.t("ruler.range"), value: l.t("range.kcal", ["low": l.int(lo), "high": l.int(hi)])))
        }
        if let f = data.floorKcal { rows.append(Row(key: "floor", label: l.t("ruler.floorLong"), value: l.kcalPerDay(f))) }
        if let lo = data.bandLowKcal, let hi = data.bandHighKcal {
            rows.append(Row(key: "band", label: l.t("ruler.band"), value: l.t("range.kcal", ["low": l.int(lo), "high": l.int(hi)])))
        }
        return rows
    }
    private var accessibilityText: String {
        "\(l.t("ruler.label")): " + rows.map { "\($0.label) \($0.value)" }.joined(separator: "; ")
    }
    private var legend: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
            ForEach(rows) { row in
                GridRow {
                    swatch(row.key)
                    Text(row.label).foregroundStyle(Theme.muted)
                    Text(row.value).monospacedDigit()
                }
                .font(.caption)
            }
        }
    }
    @ViewBuilder private func swatch(_ key: String) -> some View {
        switch key {
        case "target": PawPin().fill(Theme.sakura).frame(width: 9, height: 13)
        case "start": Diamond().fill(Theme.ink).frame(width: 8, height: 11)
        case "range": Capsule().fill(Theme.sky).frame(width: 14, height: 7)
        case "floor": Rectangle().fill(Theme.alert).frame(width: 2, height: 12)
        default: Hatch().stroke(Theme.muted, lineWidth: 1).frame(width: 14, height: 9).clipped()
        }
    }
}
