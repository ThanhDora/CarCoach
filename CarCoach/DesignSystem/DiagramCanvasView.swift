import Foundation
import SwiftUI
import UIKit

struct DiagramCanvasView: View {
    let spec: DiagramSpec
    let size: CGFloat

    init(spec: DiagramSpec, size: CGFloat = 140) {
        self.spec = spec
        self.size = size
    }

    var body: some View {
        VStack(spacing: 6) {
            graphicContent
                .frame(width: size, height: size)
                .accessibilityLabel(accessibilityText)

            if let caption = spec.caption, !caption.isEmpty, spec.kind.lowercased() == "sahinh" {
                Text(caption)
                    .font(.system(size: max(10, min(12, size * 0.08)), weight: .regular))
                    .foregroundStyle(ClaudePalette.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: size * 1.3)
            }
        }
    }

    @ViewBuilder
    private var graphicContent: some View {
        switch spec.kind.lowercased() {
        case "prohibition":
            ProhibitionSignView(spec: spec, size: size)
        case "warning":
            WarningSignView(spec: spec, size: size)
        case "mandatory":
            MandatorySignView(spec: spec, size: size)
        case "guide":
            GuideSignView(spec: spec, size: size)
        case "auxiliary":
            AuxiliarySignView(spec: spec, size: size)
        case "marking":
            RoadMarkingView(spec: spec, size: size)
        case "sahinh":
            SaHinhDiagramView(spec: spec, size: size)
        default:
            FallbackSignView(spec: spec, size: size)
        }
    }

    private var accessibilityText: String {
        if let caption = spec.caption, !caption.isEmpty {
            return "\(spec.code): \(caption)"
        }
        return "\(spec.kind) \(spec.code)"
    }

    static func renderSignUIImage(spec: DiagramSpec, dimension: CGFloat = 320) -> UIImage? {
        let view = DiagramCanvasView(spec: spec, size: dimension)
            .padding(20)
            .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        return renderer.uiImage
    }
}

// MARK: - Sign Palette Helpers

private enum SignColor {
    static let red = Color(red: 0.84, green: 0.14, blue: 0.12)
    static let yellow = Color(red: 0.98, green: 0.80, blue: 0.08)
    static let blue = Color(red: 0.04, green: 0.36, blue: 0.76)
    static let green = Color(red: 0.08, green: 0.48, blue: 0.24)
    static let asphalt = Color(red: 0.22, green: 0.24, blue: 0.27)
    static let roadShoulder = Color(red: 0.88, green: 0.89, blue: 0.90)
    static let darkInk = Color(red: 0.08, green: 0.08, blue: 0.09)
}

private enum SignParser {
    static func normalized(_ value: String) -> String {
        value.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractedNumber(from spec: DiagramSpec) -> String? {
        let sources = [spec.symbol, spec.code]
        for source in sources {
            let digits = source.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let value = Int(digits), value >= 5, value <= 150, source.uppercased().contains("SPEED") || source.uppercased().contains("LIMIT") || source.uppercased().contains("127") || source.uppercased().contains("134") || source.uppercased().contains("306") {
                return "\(value)"
            }
        }
        if let range = spec.symbol.range(of: #"\d+"#, options: .regularExpression) {
            return String(spec.symbol[range])
        }
        return nil
    }

    static func sfSymbolForVehicle(_ sym: String, code: String) -> String? {
        if sym.contains("CAR") || code.hasPrefix("P.103") {
            return "car.fill"
        }
        if sym.contains("TRUCK") || code.hasPrefix("P.106") || code.hasPrefix("P.107") {
            return "box.truck.fill"
        }
        if sym.contains("BUS") || sym.contains("PASSENGER") {
            return "bus.fill"
        }
        if sym.contains("MOTO") || sym.contains("MOTOR") || code.hasPrefix("P.104") {
            return "motorcycle.fill"
        }
        if sym.contains("BICYCLE") || sym.contains("BIKE") || code.hasPrefix("P.110") {
            return "bicycle"
        }
        if sym.contains("PEDESTRIAN") || sym.contains("WALK") || code.hasPrefix("P.112") {
            return "figure.walk"
        }
        if sym.contains("HORN") || code.hasPrefix("P.121") {
            return "speaker.wave.2.fill"
        }
        if sym.contains("TRACTOR") || code.hasPrefix("P.108") {
            return "tractor.fill"
        }
        return nil
    }
}

// MARK: - Basic Geometric Shapes

private struct TriangleShape: Shape {
    var inverted: Bool = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if inverted {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

private struct OctagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cut: CGFloat = 0.2929
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + w * cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - w * cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - h * cut))
        path.addLine(to: CGPoint(x: rect.maxX - w * cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + w * cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - h * cut))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * cut))
        path.closeSubpath()
        return path
    }
}

private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct DiagonalSlash: View {
    let size: CGFloat
    let color: Color
    let lineWidthRatio: CGFloat

    init(size: CGFloat, color: Color = SignColor.red, lineWidthRatio: CGFloat = 0.085) {
        self.size = size
        self.color = color
        self.lineWidthRatio = lineWidthRatio
    }

    var body: some View {
        Path { path in
            let inset = size * 0.16
            path.move(to: CGPoint(x: inset, y: inset))
            path.addLine(to: CGPoint(x: size - inset, y: size - inset))
        }
        .stroke(color, style: StrokeStyle(lineWidth: size * lineWidthRatio, lineCap: .butt))
    }
}

private struct StopOctagonSignView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            OctagonShape()
                .fill(SignColor.red)
            OctagonShape()
                .stroke(Color.white, lineWidth: size * 0.045)
                .padding(size * 0.05)
            Text("STOP")
                .font(.system(size: size * 0.25, weight: .black, design: .rounded))
                .foregroundStyle(Color.white)
        }
    }
}

// MARK: - Prohibition Signs (Biển báo cấm)

private struct ProhibitionSignView: View {
    let spec: DiagramSpec
    let size: CGFloat

    private var sym: String { SignParser.normalized(spec.symbol) }
    private var code: String { SignParser.normalized(spec.code) }

    var body: some View {
        if code == "P.122" || sym == "STOP" {
            StopOctagonSignView(size: size)
        } else if code == "P.102" || sym == "ONE_WAY_PROHIBITED" || sym == "DO_NOT_ENTER" {
            oneWayProhibitedSign
        } else if code == "P.130" || sym == "NO_STOPPING" {
            noStoppingSign
        } else if code.hasPrefix("P.131") || sym == "NO_PARKING" {
            noParkingSign
        } else if code.hasPrefix("DP.") || sym.contains("END_") {
            endRestrictionSign
        } else {
            standardProhibitionSign
        }
    }

    private var oneWayProhibitedSign: some View {
        ZStack {
            Circle()
                .fill(SignColor.red)
            Circle()
                .stroke(Color.white, lineWidth: size * 0.025)
                .padding(size * 0.02)
            RoundedRectangle(cornerRadius: size * 0.02)
                .fill(Color.white)
                .frame(width: size * 0.62, height: size * 0.16)
        }
    }

    private var noStoppingSign: some View {
        ZStack {
            Circle()
                .fill(SignColor.blue)
            Circle()
                .stroke(SignColor.red, lineWidth: size * 0.11)
                .padding(size * 0.055)
            DiagonalSlash(size: size)
            DiagonalSlash(size: size)
                .rotationEffect(.degrees(90))
        }
    }

    private var noParkingSign: some View {
        ZStack {
            Circle()
                .fill(SignColor.blue)
            Circle()
                .stroke(SignColor.red, lineWidth: size * 0.11)
                .padding(size * 0.055)
            if code.hasSuffix("B") {
                Text("I")
                    .font(.system(size: size * 0.34, weight: .bold, design: .serif))
                    .foregroundStyle(Color.white)
            } else if code.hasSuffix("C") {
                Text("II")
                    .font(.system(size: size * 0.32, weight: .bold, design: .serif))
                    .foregroundStyle(Color.white)
            }
            DiagonalSlash(size: size)
        }
    }

    private var endRestrictionSign: some View {
        ZStack {
            Circle()
                .fill(Color.white)
            Circle()
                .stroke(SignColor.darkInk, lineWidth: size * 0.06)
                .padding(size * 0.03)
            if let num = SignParser.extractedNumber(from: spec), !code.contains("135") {
                Text(num)
                    .font(.system(size: size * 0.36, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.gray)
            }
            ForEach([-0.11, 0.0, 0.11], id: \.self) { offset in
                DiagonalSlash(size: size, color: SignColor.darkInk.opacity(0.85), lineWidthRatio: 0.035)
                    .offset(x: size * offset, y: -size * offset)
            }
            .clipShape(Circle().inset(by: size * 0.06))
        }
    }

    private var standardProhibitionSign: some View {
        ZStack {
            Circle()
                .fill(Color.white)
            Circle()
                .stroke(SignColor.red, lineWidth: size * 0.115)
                .padding(size * 0.058)

            prohibitionInnerGlyph

            if spec.hasSlash {
                DiagonalSlash(size: size, lineWidthRatio: 0.075)
            }
        }
    }

    @ViewBuilder
    private var prohibitionInnerGlyph: some View {
        if code == "P.101" || sym == "NO_ENTRY" {
            EmptyView()
        } else if sym.contains("SPEED") || code.hasPrefix("P.127") {
            Text(SignParser.extractedNumber(from: spec) ?? "50")
                .font(.system(size: size * 0.36, weight: .black, design: .rounded))
                .foregroundStyle(SignColor.darkInk)
        } else if sym.contains("LEFT") && sym.contains("TURN") || code.hasPrefix("P.123A") {
            turnArrowGlyph(direction: .left)
        } else if sym.contains("RIGHT") && sym.contains("TURN") || code.hasPrefix("P.123B") {
            turnArrowGlyph(direction: .right)
        } else if sym.contains("UTURN") || sym.contains("U_TURN") || code.hasPrefix("P.124") {
            uTurnGlyph
        } else if sym.contains("OVERTAK") || code.hasPrefix("P.125") || code.hasPrefix("P.126") {
            HStack(spacing: size * 0.06) {
                Image(systemName: sym.contains("TRUCK") ? "box.truck.fill" : "car.fill")
                    .font(.system(size: size * 0.24))
                    .foregroundStyle(SignColor.red)
                Image(systemName: "car.fill")
                    .font(.system(size: size * 0.24))
                    .foregroundStyle(SignColor.darkInk)
            }
        } else if sym.contains("HEIGHT") || code.hasPrefix("P.117") {
            clearanceGlyph(vertical: true, text: SignParser.extractedNumber(from: spec).map { "\($0)m" } ?? "3.5m")
        } else if sym.contains("WIDTH") || code.hasPrefix("P.116") {
            clearanceGlyph(vertical: false, text: SignParser.extractedNumber(from: spec).map { "\($0)m" } ?? "2.5m")
        } else if sym.contains("WEIGHT") || code.hasPrefix("P.115") {
            Text(SignParser.extractedNumber(from: spec).map { "\($0)t" } ?? "10t")
                .font(.system(size: size * 0.28, weight: .black, design: .rounded))
                .foregroundStyle(SignColor.darkInk)
        } else if sym.contains("DISTANCE") || code.hasPrefix("P.128") {
            Text("50m")
                .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                .foregroundStyle(SignColor.darkInk)
        } else if let sfName = SignParser.sfSymbolForVehicle(sym, code: code) {
            Image(systemName: sfName)
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(SignColor.darkInk)
        } else {
            Text(spec.code)
                .font(.system(size: size * 0.20, weight: .bold, design: .rounded))
                .foregroundStyle(SignColor.darkInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, size * 0.14)
        }
    }

    private enum TurnDirection { case left, right }

    private func turnArrowGlyph(direction: TurnDirection) -> some View {
        Image(systemName: direction == .left ? "arrow.turn.up.left" : "arrow.turn.up.right")
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundStyle(SignColor.darkInk)
    }

    private var uTurnGlyph: some View {
        Image(systemName: "arrow.uturn.down")
            .font(.system(size: size * 0.36, weight: .bold))
            .foregroundStyle(SignColor.darkInk)
    }

    private func clearanceGlyph(vertical: Bool, text: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: vertical ? "arrowtriangle.down.fill" : "arrowtriangle.right.fill")
                .font(.system(size: size * 0.12))
                .foregroundStyle(SignColor.darkInk)
            Text(text)
                .font(.system(size: size * 0.22, weight: .black, design: .rounded))
                .foregroundStyle(SignColor.darkInk)
            Image(systemName: vertical ? "arrowtriangle.up.fill" : "arrowtriangle.left.fill")
                .font(.system(size: size * 0.12))
                .foregroundStyle(SignColor.darkInk)
        }
    }
}

// MARK: - Warning Signs (Biển cảnh báo nguy hiểm)

private struct WarningSignView: View {
    let spec: DiagramSpec
    let size: CGFloat

    private var sym: String { SignParser.normalized(spec.symbol) }
    private var code: String { SignParser.normalized(spec.code) }

    private var isGiveWay: Bool {
        code == "W.208" || sym == "GIVE_WAY" || sym == "YIELD"
    }

    var body: some View {
        ZStack {
            TriangleShape(inverted: isGiveWay)
                .fill(isGiveWay ? Color.white : SignColor.yellow)
                .padding(size * 0.08)

            TriangleShape(inverted: isGiveWay)
                .stroke(
                    SignColor.red,
                    style: StrokeStyle(lineWidth: size * 0.095, lineCap: .round, lineJoin: .round)
                )
                .padding(size * 0.08)

            if !isGiveWay {
                warningGlyph
                    .offset(y: size * 0.10)
            }
        }
    }

    @ViewBuilder
    private var warningGlyph: some View {
        if sym.contains("ROUNDABOUT") || code.hasPrefix("W.206") {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: size * 0.28, weight: .bold))
                .foregroundStyle(SignColor.darkInk)
        } else if sym.contains("PEDESTRIAN") || code.hasPrefix("W.224") {
            Image(systemName: "figure.walk")
                .font(.system(size: size * 0.30, weight: .bold))
                .foregroundStyle(SignColor.darkInk)
        } else if sym.contains("CHILDREN") || code.hasPrefix("W.225") {
            Image(systemName: "figure.2")
                .font(.system(size: size * 0.28, weight: .bold))
                .foregroundStyle(SignColor.darkInk)
        } else if sym.contains("RAILWAY") || code.hasPrefix("W.210") || code.hasPrefix("W.211") {
            Image(systemName: code.contains("210") ? "tram.fill" : "road.lanes")
                .font(.system(size: size * 0.28, weight: .bold))
                .foregroundStyle(SignColor.darkInk)
        } else if sym.contains("TRAFFIC_LIGHT") || code.hasPrefix("W.209") {
            VStack(spacing: size * 0.025) {
                Circle().fill(SignColor.red).frame(width: size * 0.09, height: size * 0.09)
                Circle().fill(SignColor.yellow).frame(width: size * 0.09, height: size * 0.09)
                Circle().fill(SignColor.green).frame(width: size * 0.09, height: size * 0.09)
            }
            .padding(size * 0.035)
            .background(SignColor.darkInk, in: RoundedRectangle(cornerRadius: size * 0.04))
        } else if sym.contains("SLIPPERY") || code.hasPrefix("W.222") {
            VStack(spacing: 2) {
                Image(systemName: "car.fill")
                    .font(.system(size: size * 0.22))
                    .foregroundStyle(SignColor.darkInk)
                Image(systemName: "water.waves")
                    .font(.system(size: size * 0.18, weight: .bold))
                    .foregroundStyle(SignColor.darkInk)
            }
        } else if sym.contains("INTERSECTION") || code.hasPrefix("W.205") || code.hasPrefix("W.207") {
            Image(systemName: "plus")
                .font(.system(size: size * 0.30, weight: .black))
                .foregroundStyle(SignColor.darkInk)
        } else if sym.contains("CURVE") || code.hasPrefix("W.201") || code.hasPrefix("W.202") {
            Image(systemName: sym.contains("RIGHT") ? "arrow.turn.up.right" : "arrow.turn.up.left")
                .font(.system(size: size * 0.28, weight: .bold))
                .foregroundStyle(SignColor.darkInk)
        } else if sym.contains("TWO_WAY") || code.hasPrefix("W.204") {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: size * 0.26, weight: .bold))
                .foregroundStyle(SignColor.darkInk)
        } else if sym.contains("NARROW") || code.hasPrefix("W.203") {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .font(.system(size: size * 0.25, weight: .bold))
                .foregroundStyle(SignColor.darkInk)
        } else if sym.contains("WORK") || code.hasPrefix("W.227") {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: size * 0.24))
                .foregroundStyle(SignColor.darkInk)
        } else if sym.contains("STEEP") || code.hasPrefix("W.219") || code.hasPrefix("W.220") {
            Text("10%")
                .font(.system(size: size * 0.22, weight: .black, design: .rounded))
                .foregroundStyle(SignColor.darkInk)
        } else {
            Image(systemName: "exclamationmark")
                .font(.system(size: size * 0.32, weight: .black))
                .foregroundStyle(SignColor.darkInk)
        }
    }
}

// MARK: - Mandatory Signs (Biển hiệu lệnh)

private struct MandatorySignView: View {
    let spec: DiagramSpec
    let size: CGFloat

    private var sym: String { SignParser.normalized(spec.symbol) }
    private var code: String { SignParser.normalized(spec.code) }

    var body: some View {
        if code == "R.122" || sym == "STOP" {
            StopOctagonSignView(size: size)
        } else if code.hasPrefix("R.420") || code.hasPrefix("R.421") || sym.contains("RESIDENTIAL") {
            residentialZoneSign
        } else if code.hasPrefix("R.411") || code.hasPrefix("R.412") || sym.contains("LANE") {
            laneDirectiveSign
        } else {
            circularMandatorySign
        }
    }

    private var residentialZoneSign: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.07, style: .continuous)
                .fill(Color.white)
                .frame(width: size * 0.90, height: size * 0.62)
            RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                .stroke(SignColor.darkInk, lineWidth: size * 0.035)
                .frame(width: size * 0.86, height: size * 0.58)
            Image(systemName: "building.2.fill")
                .font(.system(size: size * 0.34))
                .foregroundStyle(SignColor.darkInk)
            if spec.hasSlash || code.hasPrefix("R.421") {
                DiagonalSlash(size: size, lineWidthRatio: 0.07)
                    .frame(width: size * 0.86, height: size * 0.58)
                    .clipped()
            }
        }
    }

    private var circularMandatorySign: some View {
        ZStack {
            Circle()
                .fill(SignColor.blue)
            Circle()
                .stroke(Color.white, lineWidth: size * 0.035)
                .padding(size * 0.04)

            mandatoryGlyph

            if spec.hasSlash {
                DiagonalSlash(size: size)
            }
        }
    }

    private var laneDirectiveSign: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .fill(SignColor.blue)
                .padding(size * 0.04)
            RoundedRectangle(cornerRadius: size * 0.07, style: .continuous)
                .stroke(Color.white, lineWidth: size * 0.03)
                .padding(size * 0.07)

            HStack(spacing: size * 0.12) {
                Image(systemName: "arrow.turn.up.left")
                Rectangle()
                    .fill(Color.white.opacity(0.65))
                    .frame(width: 2, height: size * 0.45)
                Image(systemName: "arrow.up")
                Rectangle()
                    .fill(Color.white.opacity(0.65))
                    .frame(width: 2, height: size * 0.45)
                Image(systemName: "arrow.turn.up.right")
            }
            .font(.system(size: size * 0.18, weight: .bold))
            .foregroundStyle(Color.white)
        }
    }

    @ViewBuilder
    private var mandatoryGlyph: some View {
        if sym.contains("MIN_SPEED") || code.hasPrefix("R.306") {
            Text(SignParser.extractedNumber(from: spec) ?? "50")
                .font(.system(size: size * 0.36, weight: .black, design: .rounded))
                .foregroundStyle(Color.white)
        } else if sym.contains("ROUNDABOUT") || code.hasPrefix("R.303") {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(Color.white)
        } else if sym.contains("STRAIGHT") || code.hasPrefix("R.301A") {
            Image(systemName: "arrow.up")
                .font(.system(size: size * 0.40, weight: .bold))
                .foregroundStyle(Color.white)
        } else if sym.contains("RIGHT") && sym.contains("AHEAD") || code.hasPrefix("R.301F") {
            HStack(spacing: size * 0.05) {
                Image(systemName: "arrow.up")
                Image(systemName: "arrow.turn.up.right")
            }
            .font(.system(size: size * 0.28, weight: .bold))
            .foregroundStyle(Color.white)
        } else if sym.contains("LEFT") && sym.contains("AHEAD") || code.hasPrefix("R.301G") {
            HStack(spacing: size * 0.05) {
                Image(systemName: "arrow.up")
                Image(systemName: "arrow.turn.up.left")
            }
            .font(.system(size: size * 0.28, weight: .bold))
            .foregroundStyle(Color.white)
        } else if sym.contains("TURN_RIGHT") || sym.contains("KEEP_RIGHT") || code.hasPrefix("R.301B") || code.hasPrefix("R.302B") {
            Image(systemName: sym.contains("KEEP") ? "arrow.down.right" : "arrow.turn.up.right")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(Color.white)
        } else if sym.contains("TURN_LEFT") || sym.contains("KEEP_LEFT") || code.hasPrefix("R.301C") || code.hasPrefix("R.302A") {
            Image(systemName: sym.contains("KEEP") ? "arrow.down.left" : "arrow.turn.up.left")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(Color.white)
        } else if sym.contains("PEDESTRIAN") || code.hasPrefix("R.305") {
            Image(systemName: "figure.walk")
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(Color.white)
        } else if sym.contains("BICYCLE") || code.hasPrefix("R.304") {
            Image(systemName: "bicycle")
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(Color.white)
        } else if sym.contains("HORN") || code.hasPrefix("R.309") {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(Color.white)
        } else {
            Image(systemName: "arrow.up")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(Color.white)
        }
    }
}

// MARK: - Guide Signs (Biển chỉ dẫn)

private struct GuideSignView: View {
    let spec: DiagramSpec
    let size: CGFloat

    private var sym: String { SignParser.normalized(spec.symbol) }
    private var code: String { SignParser.normalized(spec.code) }

    var body: some View {
        if code == "I.401" || code == "I.402" || sym.contains("PRIORITY") {
            priorityDiamondSign
        } else {
            rectangularGuideSign
        }
    }

    private var priorityDiamondSign: some View {
        ZStack {
            DiamondShape()
                .fill(Color.white)
                .padding(size * 0.06)
            DiamondShape()
                .stroke(SignColor.darkInk, lineWidth: size * 0.03)
                .padding(size * 0.06)
            DiamondShape()
                .fill(SignColor.yellow)
                .padding(size * 0.21)
            if spec.hasSlash || code == "I.402" {
                DiagonalSlash(size: size, color: SignColor.darkInk, lineWidthRatio: 0.065)
            }
        }
    }

    private var rectangularGuideSign: some View {
        let baseColor = (sym.contains("HIGHWAY") || code.hasPrefix("I.437") || code.hasPrefix("IE.")) ? SignColor.green : SignColor.blue
        return ZStack {
            RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                .fill(baseColor)
                .padding(size * 0.05)

            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .stroke(Color.white, lineWidth: size * 0.03)
                .padding(size * 0.09)

            guideInnerGlyph

            if spec.hasSlash {
                DiagonalSlash(size: size)
            }
        }
    }

    @ViewBuilder
    private var guideInnerGlyph: some View {
        if sym.contains("PARKING") || code.hasPrefix("I.408") {
            Text("P")
                .font(.system(size: size * 0.46, weight: .black, design: .rounded))
                .foregroundStyle(Color.white)
        } else if sym.contains("HOSPITAL") || code.hasPrefix("I.426") {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.06)
                    .fill(Color.white)
                    .frame(width: size * 0.56, height: size * 0.56)
                Image(systemName: "cross.fill")
                    .font(.system(size: size * 0.30, weight: .bold))
                    .foregroundStyle(SignColor.red)
            }
        } else if sym.contains("HIGHWAY") || code.hasPrefix("I.437") {
            VStack(spacing: size * 0.04) {
                Image(systemName: "road.lanes")
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(Color.white)
                Text("CT")
                    .font(.system(size: size * 0.15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
            }
        } else if sym.contains("ONE_WAY") || code.hasPrefix("I.407") {
            Image(systemName: "arrow.up")
                .font(.system(size: size * 0.42, weight: .black))
                .foregroundStyle(Color.white)
        } else if sym.contains("U_TURN") || code.hasPrefix("I.409") {
            Image(systemName: "arrow.uturn.down")
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(Color.white)
        } else if sym.contains("PEDESTRIAN") || code.hasPrefix("I.423") {
            ZStack {
                TriangleShape()
                    .fill(Color.white)
                    .frame(width: size * 0.56, height: size * 0.48)
                Image(systemName: "figure.walk")
                    .font(.system(size: size * 0.22, weight: .bold))
                    .foregroundStyle(SignColor.darkInk)
                    .offset(y: size * 0.06)
            }
        } else if sym.contains("RESIDENTIAL") || code.hasPrefix("I.420") || code.hasPrefix("I.421") {
            Image(systemName: "building.2.fill")
                .font(.system(size: size * 0.34))
                .foregroundStyle(Color.white)
        } else if sym.contains("GAS") || code.hasPrefix("I.428") {
            Image(systemName: "fuelpump.fill")
                .font(.system(size: size * 0.32))
                .foregroundStyle(Color.white)
        } else if sym.contains("DEAD_END") || code.hasPrefix("I.430") {
            VStack(spacing: 0) {
                Rectangle().fill(SignColor.red).frame(width: size * 0.28, height: size * 0.09)
                Rectangle().fill(Color.white).frame(width: size * 0.11, height: size * 0.34)
            }
        } else {
            VStack(spacing: 4) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: size * 0.28))
                    .foregroundStyle(Color.white)
                Text(spec.code)
                    .font(.system(size: size * 0.14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
            }
        }
    }
}

// MARK: - Auxiliary Signs (Biển phụ)

private struct AuxiliarySignView: View {
    let spec: DiagramSpec
    let size: CGFloat

    private var sym: String { SignParser.normalized(spec.symbol) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.07, style: .continuous)
                .fill(Color.white)
                .frame(width: size * 0.90, height: size * 0.56)
            RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                .stroke(SignColor.darkInk, lineWidth: size * 0.035)
                .frame(width: size * 0.86, height: size * 0.52)

            if sym.contains("PRIORITY") {
                auxiliaryPriorityDiagram
            } else if sym.contains("LENGTH") {
                HStack(spacing: size * 0.05) {
                    Image(systemName: "arrow.up")
                    Text("500 m")
                        .font(.system(size: size * 0.16, weight: .bold, design: .rounded))
                    Image(systemName: "arrow.up")
                }
                .foregroundStyle(SignColor.darkInk)
            } else if sym.contains("DIRECTION") {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: size * 0.22, weight: .bold))
                    .foregroundStyle(SignColor.darkInk)
            } else if sym.contains("VEHICLE") {
                Image(systemName: "box.truck.fill")
                    .font(.system(size: size * 0.24))
                    .foregroundStyle(SignColor.darkInk)
            } else {
                Text(SignParser.extractedNumber(from: spec).map { "\($0) m" } ?? "200 m")
                    .font(.system(size: size * 0.19, weight: .bold, design: .rounded))
                    .foregroundStyle(SignColor.darkInk)
            }
        }
    }

    private var auxiliaryPriorityDiagram: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.45))
                .frame(width: size * 0.42, height: size * 0.04)
            Rectangle()
                .fill(Color.gray.opacity(0.45))
                .frame(width: size * 0.04, height: size * 0.34)
            Path { path in
                path.move(to: CGPoint(x: size * 0.5, y: size * 0.66))
                path.addLine(to: CGPoint(x: size * 0.5, y: size * 0.5))
                path.addLine(to: CGPoint(x: size * 0.68, y: size * 0.5))
            }
            .stroke(SignColor.darkInk, style: StrokeStyle(lineWidth: size * 0.065, lineCap: .square, lineJoin: .miter))
        }
    }
}

// MARK: - Road Markings (Vạch kẻ đường)

private struct RoadMarkingView: View {
    let spec: DiagramSpec
    let size: CGFloat

    private var sym: String { SignParser.normalized(spec.symbol) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                .fill(SignColor.asphalt)
                .padding(size * 0.06)

            markingPattern
        }
    }

    @ViewBuilder
    private var markingPattern: some View {
        if sym.contains("ZEBRA") || sym.contains("CROSSWALK") {
            HStack(spacing: size * 0.06) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: size * 0.10, height: size * 0.56)
                }
            }
        } else if sym.contains("DOUBLE") {
            HStack(spacing: size * 0.05) {
                Rectangle().fill(SignColor.yellow).frame(width: size * 0.045, height: size * 0.68)
                Rectangle().fill(SignColor.yellow).frame(width: size * 0.045, height: size * 0.68)
            }
        } else if sym.contains("SOLID_DASHED") {
            HStack(spacing: size * 0.05) {
                Rectangle().fill(SignColor.yellow).frame(width: size * 0.045, height: size * 0.68)
                VStack(spacing: size * 0.08) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle().fill(SignColor.yellow).frame(width: size * 0.045, height: size * 0.14)
                    }
                }
            }
        } else if sym.contains("DASHED") {
            VStack(spacing: size * 0.09) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(sym.contains("YELLOW") ? SignColor.yellow : Color.white)
                        .frame(width: size * 0.055, height: size * 0.15)
                }
            }
        } else if sym.contains("STOP_LINE") {
            Rectangle()
                .fill(Color.white)
                .frame(width: size * 0.66, height: size * 0.08)
        } else if sym.contains("ARROW") {
            Image(systemName: "arrow.up")
                .font(.system(size: size * 0.38, weight: .black))
                .foregroundStyle(Color.white)
        } else if sym.contains("DIAMOND") {
            DiamondShape()
                .stroke(Color.white, lineWidth: size * 0.04)
                .frame(width: size * 0.30, height: size * 0.46)
        } else if sym.contains("BOX_JUNCTION") || sym.contains("MAT_VONG") {
            ZStack {
                Rectangle()
                    .stroke(SignColor.yellow, lineWidth: size * 0.045)
                Path { path in
                    let w = size * 0.56
                    let h = size * 0.56
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.move(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.move(to: CGPoint(x: w * 0.5, y: 0))
                    path.addLine(to: CGPoint(x: w, y: h * 0.5))
                    path.move(to: CGPoint(x: 0, y: h * 0.5))
                    path.addLine(to: CGPoint(x: w * 0.5, y: h))
                    path.move(to: CGPoint(x: w * 0.5, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: h * 0.5))
                    path.move(to: CGPoint(x: w, y: h * 0.5))
                    path.addLine(to: CGPoint(x: w * 0.5, y: h))
                }
                .stroke(SignColor.yellow, lineWidth: size * 0.03)
            }
            .frame(width: size * 0.56, height: size * 0.56)
        } else if sym.contains("CHEVRON") {
            VStack(spacing: size * 0.06) {
                ForEach(0..<3, id: \.self) { _ in
                    Image(systemName: "chevron.up")
                        .font(.system(size: size * 0.18, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
        } else {
            Rectangle()
                .fill(sym.contains("YELLOW") ? SignColor.yellow : Color.white)
                .frame(width: size * 0.06, height: size * 0.68)
        }
    }
}

// MARK: - Sa Hình Intersection Diagram (Chương 6)

private struct SaHinhDiagramView: View {
    let spec: DiagramSpec
    let size: CGFloat

    private var contextText: String {
        "\(spec.code) \(spec.symbol) \(spec.caption ?? "")".uppercased()
    }

    private var isRoundabout: Bool {
        contextText.contains("ROUNDABOUT") || contextText.contains("VONG_XUYEN") || contextText.contains("XUYẾN")
    }

    private var isTJunction: Bool {
        contextText.contains("T_JUNCTION") || contextText.contains("NGA_BA") || contextText.contains("NGÃ BA")
    }

    private var hasPoliceOfficer: Bool {
        contextText.contains("CSGT") || contextText.contains("POLICE_OFFICER") || contextText.contains("CẢNH SÁT")
    }

    private var hasTrafficLight: Bool {
        contextText.contains("LIGHT") || contextText.contains("DEN_") || contextText.contains("ĐÈN")
    }

    private var vehicles: [SaHinhVehicle] {
        var result: [SaHinhVehicle] = []

        if contextText.contains("FIRE") || contextText.contains("CHUA_CHAY") || contextText.contains("CHỮA CHÁY") {
            result.append(SaHinhVehicle(label: "PCCC", color: SignColor.red, arm: .left, turn: .straight, isPriority: true))
        } else if contextText.contains("MILITARY") || contextText.contains("QUAN_SU") || contextText.contains("QUÂN SỰ") {
            result.append(SaHinhVehicle(label: "QS", color: SignColor.green, arm: .top, turn: .straight, isPriority: true))
        } else if contextText.contains("AMBULANCE") || contextText.contains("CUU_THUONG") || contextText.contains("CỨU THƯƠNG") {
            result.append(SaHinhVehicle(label: "115", color: Color.white, arm: .right, turn: .straight, isPriority: true))
        } else if contextText.contains("POLICE_CAR") || contextText.contains("CONG_AN") || contextText.contains("CÔNG AN") {
            result.append(SaHinhVehicle(label: "CA", color: SignColor.blue, arm: .bottom, turn: .straight, isPriority: true))
        }

        let usedArms = Set(result.map(\.arm))
        let candidateSlots: [(String, SaHinhArm, SaHinhTurn, Color)] = [
            ("A", .bottom, contextText.contains("A_LEFT") ? .left : .straight, Color(red: 0.16, green: 0.45, blue: 0.85)),
            ("B", .right, contextText.contains("B_RIGHT") ? .right : .left, Color(red: 0.88, green: 0.45, blue: 0.12)),
            ("C", .top, contextText.contains("C_RIGHT") ? .right : .straight, Color(red: 0.16, green: 0.62, blue: 0.36)),
            ("D", .left, .right, Color(red: 0.46, green: 0.36, blue: 0.72))
        ]

        for (label, arm, turn, color) in candidateSlots where !usedArms.contains(arm) {
            let matchesLetter = contextText.contains("XE_\(label)") || contextText.contains(" \(label)") || result.count < 3
            if matchesLetter && result.count < 3 {
                result.append(SaHinhVehicle(label: label, color: color, arm: arm, turn: turn, isPriority: false))
            }
        }

        return result
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                .fill(SignColor.roadShoulder)

            intersectionRoads

            if isRoundabout {
                Circle()
                    .fill(SignColor.green.opacity(0.75))
                    .frame(width: size * 0.20, height: size * 0.20)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }

            if hasPoliceOfficer {
                policeOfficerGlyph
            }

            if hasTrafficLight {
                trafficLightCorner
            }

            ForEach(vehicles) { vehicle in
                vehicleMarker(vehicle)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: size * 0.10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                .stroke(ClaudePalette.hairline, lineWidth: 1)
        )
    }

    private var intersectionRoads: some View {
        let roadWidth = size * 0.38
        return ZStack {
            // Vertical road
            Rectangle()
                .fill(SignColor.asphalt)
                .frame(width: roadWidth, height: isTJunction ? size * 0.69 : size)
                .offset(y: isTJunction ? size * 0.155 : 0)

            // Horizontal road
            Rectangle()
                .fill(SignColor.asphalt)
                .frame(width: size, height: roadWidth)

            // Dashed centerlines
            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                .foregroundStyle(Color.white.opacity(0.65))
                .frame(width: 1, height: size * 0.25)
                .offset(y: size * 0.36)

            if !isTJunction {
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .frame(width: 1, height: size * 0.25)
                    .offset(y: -size * 0.36)
            }

            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                .foregroundStyle(Color.white.opacity(0.65))
                .frame(width: size * 0.25, height: 1)
                .offset(x: -size * 0.36)

            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                .foregroundStyle(Color.white.opacity(0.65))
                .frame(width: size * 0.25, height: 1)
                .offset(x: size * 0.36)
        }
    }

    private var policeOfficerGlyph: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.80, green: 0.65, blue: 0.22))
                .frame(width: size * 0.14, height: size * 0.14)
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            Capsule()
                .fill(Color.white)
                .frame(width: size * 0.22, height: size * 0.03)
        }
    }

    private var trafficLightCorner: some View {
        HStack(spacing: 2) {
            Circle().fill(SignColor.red).frame(width: size * 0.045, height: size * 0.045)
            Circle().fill(SignColor.yellow).frame(width: size * 0.045, height: size * 0.045)
            Circle().fill(SignColor.green).frame(width: size * 0.045, height: size * 0.045)
        }
        .padding(3)
        .background(SignColor.darkInk, in: Capsule())
        .offset(x: size * 0.27, y: -size * 0.27)
    }

    private func vehicleMarker(_ vehicle: SaHinhVehicle) -> some View {
        let boxWidth = size * 0.13
        let boxHeight = size * 0.18
        let offset = vehicleOffset(for: vehicle.arm)

        return ZStack {
            Image(systemName: vehicle.turn.arrowSymbol)
                .font(.system(size: size * 0.11, weight: .bold))
                .foregroundStyle(Color.white)
                .offset(y: -boxHeight * 0.85)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(vehicle.color)
                .frame(width: boxWidth, height: boxHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(vehicle.isPriority ? SignColor.yellow : Color.white, lineWidth: vehicle.isPriority ? 2 : 1)
                )
                .overlay(
                    Text(vehicle.label)
                        .font(.system(size: max(8, size * 0.075), weight: .black, design: .rounded))
                        .foregroundStyle(vehicle.color == .white ? SignColor.red : Color.white)
                )
        }
        .rotationEffect(vehicle.arm.rotation)
        .offset(x: offset.width, y: offset.height)
    }

    private func vehicleOffset(for arm: SaHinhArm) -> CGSize {
        let d = size * 0.34
        let lane = size * 0.095
        switch arm {
        case .bottom:
            return CGSize(width: lane, height: d)
        case .top:
            return CGSize(width: -lane, height: -d)
        case .right:
            return CGSize(width: d, height: -lane)
        case .left:
            return CGSize(width: -d, height: lane)
        }
    }
}

private enum SaHinhArm: Hashable {
    case bottom, right, top, left

    var rotation: Angle {
        switch self {
        case .bottom: return .degrees(0)
        case .left: return .degrees(90)
        case .top: return .degrees(180)
        case .right: return .degrees(270)
        }
    }
}

private enum SaHinhTurn {
    case straight, left, right

    var arrowSymbol: String {
        switch self {
        case .straight: return "arrow.up"
        case .left: return "arrow.turn.up.left"
        case .right: return "arrow.turn.up.right"
        }
    }
}

private struct SaHinhVehicle: Identifiable {
    let id = UUID()
    let label: String
    let color: Color
    let arm: SaHinhArm
    let turn: SaHinhTurn
    let isPriority: Bool
}

// MARK: - Fallback Sign

private struct FallbackSignView: View {
    let spec: DiagramSpec
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .fill(ClaudePalette.surfaceRaised)
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .stroke(ClaudePalette.borderStrong, lineWidth: 1.5)
            VStack(spacing: 4) {
                Image(systemName: "signpost.right")
                    .font(.system(size: size * 0.28))
                    .foregroundStyle(ClaudePalette.inkPrimary)
                Text(spec.code)
                    .font(.system(size: size * 0.14, weight: .bold, design: .rounded))
                    .foregroundStyle(ClaudePalette.inkPrimary)
            }
        }
    }
}
