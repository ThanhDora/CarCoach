//
//  VisionSignRecognizer.swift
//  CarCoach
//

import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Observation
import UIKit
import Vision

nonisolated enum DetectedSignShape: String, Sendable {
    case circle
    case uprightTriangle
    case invertedTriangle
    case diamond
    case rectangle
    case square
    case unknown

    var vietnameseLabel: String {
        switch self {
        case .circle: return "Hình tròn"
        case .uprightTriangle: return "Tam giác đều"
        case .invertedTriangle: return "Tam giác ngược"
        case .diamond: return "Hình thoi"
        case .rectangle: return "Chữ nhật"
        case .square: return "Hình vuông"
        case .unknown: return "Chưa rõ hình khối"
        }
    }
}

nonisolated struct SignColorMetrics: Sendable {
    let redRatio: Double
    let yellowRatio: Double
    let greenRatio: Double
    let blueRatio: Double
    let whiteRatio: Double
    let darkRatio: Double
    let centerRedRatio: Double
    let centerBlueRatio: Double
    let centerDarkInkRatio: Double
    let cornerFillRatio: Double
    let hasDiagonalRedSlash: Bool
    let dominantDescription: String
}

nonisolated struct VisionRawFeatures: Sendable {
    let recognizedTexts: [String]
    let detectedRectanglesCount: Int
    let shape: DetectedSignShape
    let colorMetrics: SignColorMetrics
    let processingTimeMs: Double
}

struct VisionSignMatch: Identifiable, Equatable {
    let sign: TrafficSign
    let confidence: Double
    let matchReasons: [String]

    var id: String { sign.id }

    var confidencePercent: Int {
        Int((confidence * 100).rounded())
    }
}

struct VisionAnalysisSummary: Equatable {
    let inferredCategory: TrafficSignCategory?
    let shapeLabel: String
    let dominantColorText: String
    let recognizedTexts: [String]
    let detectedRectanglesCount: Int
    let processingTimeMs: Int
}

nonisolated enum VisionImageAnalyzer {
    static func analyze(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) throws -> VisionRawFeatures {
        let startTime = CFAbsoluteTimeGetCurrent()
        let workingImage = normalizeImage(cgImage, orientation: orientation, maxDimension: 640) ?? cgImage

        let textObservations = recognizeText(in: workingImage)
        let rectanglesCount = detectRectangles(in: workingImage)
        let (shape, colorMetrics) = extractShapeAndColorMetrics(from: workingImage)

        let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        return VisionRawFeatures(
            recognizedTexts: textObservations,
            detectedRectanglesCount: rectanglesCount,
            shape: shape,
            colorMetrics: colorMetrics,
            processingTimeMs: elapsedMs
        )
    }

    private static func normalizeImage(
        _ cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        maxDimension: CGFloat
    ) -> CGImage? {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        guard width > 0, height > 0 else { return nil }

        if orientation == .up && max(width, height) <= maxDimension {
            return cgImage
        }

        var ciImage = CIImage(cgImage: cgImage).oriented(orientation)
        let extent = ciImage.extent
        let currentMax = max(extent.width, extent.height)
        if currentMax > maxDimension, currentMax > 0 {
            let scale = maxDimension / currentMax
            ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }

        let context = CIContext(options: [.useSoftwareRenderer: false])
        return context.createCGImage(ciImage, from: ciImage.extent)
    }

    private static func recognizeText(in cgImage: CGImage) -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["vi-VN", "en-US"]
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.04

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        guard let results = request.results else { return [] }
        var texts: [String] = []
        for observation in results {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let trimmed = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !texts.contains(trimmed) {
                texts.append(trimmed)
            }
        }
        return texts
    }

    private static func detectRectangles(in cgImage: CGImage) -> Int {
        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = 0.5
        request.minimumAspectRatio = 0.35
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.15
        request.maximumObservations = 4

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return 0
        }
        return request.results?.count ?? 0
    }

    private static func extractShapeAndColorMetrics(from cgImage: CGImage) -> (DetectedSignShape, SignColorMetrics) {
        let gridSize = 128
        let bytesPerPixel = 4
        let bytesPerRow = gridSize * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: gridSize * gridSize * bytesPerPixel)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixels,
                width: gridSize,
                height: gridSize,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
              ) else {
            return (
                .unknown,
                SignColorMetrics(
                    redRatio: 0,
                    yellowRatio: 0,
                    greenRatio: 0,
                    blueRatio: 0,
                    whiteRatio: 0,
                    darkRatio: 0,
                    centerRedRatio: 0,
                    centerBlueRatio: 0,
                    centerDarkInkRatio: 0,
                    cornerFillRatio: 0,
                    hasDiagonalRedSlash: false,
                    dominantDescription: "Không đọc được dữ liệu điểm ảnh"
                )
            )
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: gridSize, height: gridSize))

        enum PixelClass {
            case transparent
            case red
            case yellow
            case green
            case blue
            case white
            case dark
            case neutral
        }

        var classes = [PixelClass](repeating: .transparent, count: gridSize * gridSize)
        var opaqueCount = 0
        var redCount = 0
        var yellowCount = 0
        var greenCount = 0
        var blueCount = 0
        var whiteCount = 0
        var darkCount = 0

        var minChromaX = gridSize
        var maxChromaX = -1
        var minChromaY = gridSize
        var maxChromaY = -1

        var minFgX = gridSize
        var maxFgX = -1
        var minFgY = gridSize
        var maxFgY = -1

        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let idx = (y * gridSize + x) * bytesPerPixel
                let a = Int(pixels[idx + 3])
                if a < 32 {
                    classes[y * gridSize + x] = .transparent
                    continue
                }

                let alphaFactor = 255.0 / Double(a)
                let r = min(255.0, Double(pixels[idx]) * alphaFactor) / 255.0
                let g = min(255.0, Double(pixels[idx + 1]) * alphaFactor) / 255.0
                let b = min(255.0, Double(pixels[idx + 2]) * alphaFactor) / 255.0

                let (h, s, v) = rgbToHSV(r: r, g: g, b: b)
                opaqueCount += 1

                let pixelClass: PixelClass
                if s >= 0.30 && v >= 0.18 {
                    if h >= 332 || h <= 22 {
                        pixelClass = .red
                        redCount += 1
                    } else if h >= 28 && h <= 68 && v >= 0.28 {
                        pixelClass = .yellow
                        yellowCount += 1
                    } else if h >= 95 && h <= 165 {
                        pixelClass = .green
                        greenCount += 1
                    } else if h >= 190 && h <= 258 {
                        pixelClass = .blue
                        blueCount += 1
                    } else {
                        pixelClass = .neutral
                    }
                } else if v < 0.26 && s < 0.42 {
                    pixelClass = .dark
                    darkCount += 1
                } else if s < 0.18 && v >= 0.80 {
                    pixelClass = .white
                    whiteCount += 1
                } else {
                    pixelClass = .neutral
                }

                classes[y * gridSize + x] = pixelClass

                if pixelClass == .red || pixelClass == .yellow || pixelClass == .green || pixelClass == .blue {
                    minChromaX = min(minChromaX, x)
                    maxChromaX = max(maxChromaX, x)
                    minChromaY = min(minChromaY, y)
                    maxChromaY = max(maxChromaY, y)
                }

                if pixelClass != .white && pixelClass != .transparent {
                    minFgX = min(minFgX, x)
                    maxFgX = max(maxFgX, x)
                    minFgY = min(minFgY, y)
                    maxFgY = max(maxFgY, y)
                }
            }
        }

        let denom = Double(max(opaqueCount, 1))
        let redRatio = Double(redCount) / denom
        let yellowRatio = Double(yellowCount) / denom
        let greenRatio = Double(greenCount) / denom
        let blueRatio = Double(blueCount) / denom
        let whiteRatio = Double(whiteCount) / denom
        let darkRatio = Double(darkCount) / denom

        let chromaCount = redCount + yellowCount + greenCount + blueCount
        let useChromaBox = Double(chromaCount) / denom > 0.025 && maxChromaX > minChromaX && maxChromaY > minChromaY

        let boxMinX = useChromaBox ? minChromaX : (maxFgX > minFgX ? minFgX : 0)
        let boxMaxX = useChromaBox ? maxChromaX : (maxFgX > minFgX ? maxFgX : gridSize - 1)
        let boxMinY = useChromaBox ? minChromaY : (maxFgY > minFgY ? minFgY : 0)
        let boxMaxY = useChromaBox ? maxChromaY : (maxFgY > minFgY ? maxFgY : gridSize - 1)

        let boxWidth = max(boxMaxX - boxMinX + 1, 1)
        let boxHeight = max(boxMaxY - boxMinY + 1, 1)

        var centerTotal = 0
        var centerRed = 0
        var centerBlue = 0
        var centerDark = 0

        var diagSamples = 0
        var diagRed = 0
        var antiDiagSamples = 0
        var antiDiagRed = 0

        var cornerTotal = 0
        var cornerChromaOrFg = 0

        var topMinX = gridSize, topMaxX = -1
        var midMinX = gridSize, midMaxX = -1
        var botMinX = gridSize, botMaxX = -1

        for y in boxMinY...boxMaxY {
            let ny = Double(y - boxMinY) / Double(max(boxHeight - 1, 1))
            for x in boxMinX...boxMaxX {
                let nx = Double(x - boxMinX) / Double(max(boxWidth - 1, 1))
                let pc = classes[y * gridSize + x]
                let isSignPixel = useChromaBox
                    ? (pc == .red || pc == .yellow || pc == .green || pc == .blue)
                    : (pc != .white && pc != .transparent)

                if isSignPixel {
                    if ny >= 0.10 && ny <= 0.25 {
                        topMinX = min(topMinX, x)
                        topMaxX = max(topMaxX, x)
                    } else if ny >= 0.42 && ny <= 0.58 {
                        midMinX = min(midMinX, x)
                        midMaxX = max(midMaxX, x)
                    } else if ny >= 0.75 && ny <= 0.90 {
                        botMinX = min(botMinX, x)
                        botMaxX = max(botMaxX, x)
                    }
                }

                if nx >= 0.30 && nx <= 0.70 && ny >= 0.30 && ny <= 0.70 {
                    centerTotal += 1
                    if pc == .red { centerRed += 1 }
                    if pc == .blue { centerBlue += 1 }
                    if pc == .dark { centerDark += 1 }
                }

                if nx >= 0.25 && nx <= 0.75 && ny >= 0.25 && ny <= 0.75 {
                    if abs(nx - ny) < 0.11 {
                        diagSamples += 1
                        if pc == .red { diagRed += 1 }
                    }
                    if abs(nx - (1.0 - ny)) < 0.11 {
                        antiDiagSamples += 1
                        if pc == .red { antiDiagRed += 1 }
                    }
                }

                let inCornerX = nx <= 0.16 || nx >= 0.84
                let inCornerY = ny <= 0.16 || ny >= 0.84
                if inCornerX && inCornerY {
                    cornerTotal += 1
                    if isSignPixel {
                        cornerChromaOrFg += 1
                    }
                }
            }
        }

        let centerDenom = Double(max(centerTotal, 1))
        let centerRedRatio = Double(centerRed) / centerDenom
        let centerBlueRatio = Double(centerBlue) / centerDenom
        let centerDarkInkRatio = Double(centerDark) / centerDenom
        let cornerFillRatio = Double(cornerChromaOrFg) / Double(max(cornerTotal, 1))

        let diagRedDensity = Double(diagRed) / Double(max(diagSamples, 1))
        let antiDiagRedDensity = Double(antiDiagRed) / Double(max(antiDiagSamples, 1))
        let hasDiagonalRedSlash = max(diagRedDensity, antiDiagRedDensity) > 0.24 && centerRedRatio < 0.45

        let topWidth = topMaxX >= topMinX ? Double(topMaxX - topMinX + 1) : 0
        let midWidth = midMaxX >= midMinX ? Double(midMaxX - midMinX + 1) : 0
        let botWidth = botMaxX >= botMinX ? Double(botMaxX - botMinX + 1) : 0
        let aspect = Double(boxWidth) / Double(boxHeight)

        let detectedShape: DetectedSignShape
        if botWidth > max(topWidth * 1.45, 8.0) && cornerFillRatio < 0.25 {
            detectedShape = .uprightTriangle
        } else if topWidth > max(botWidth * 1.45, 8.0) && cornerFillRatio < 0.25 {
            detectedShape = .invertedTriangle
        } else if midWidth > max(topWidth * 1.45, 10.0) && midWidth > max(botWidth * 1.45, 10.0) && cornerFillRatio < 0.18 {
            detectedShape = .diamond
        } else if cornerFillRatio > 0.40 {
            detectedShape = (aspect >= 0.82 && aspect <= 1.22) ? .square : .rectangle
        } else if midWidth > 10 && cornerFillRatio < 0.26 && abs(topWidth - botWidth) <= max(midWidth * 0.35, 8.0) {
            detectedShape = .circle
        } else {
            detectedShape = .unknown
        }

        let dominantColor = describeDominantColor(
            redRatio: redRatio,
            yellowRatio: yellowRatio,
            greenRatio: greenRatio,
            blueRatio: blueRatio,
            whiteRatio: whiteRatio,
            darkRatio: darkRatio
        )

        let metrics = SignColorMetrics(
            redRatio: redRatio,
            yellowRatio: yellowRatio,
            greenRatio: greenRatio,
            blueRatio: blueRatio,
            whiteRatio: whiteRatio,
            darkRatio: darkRatio,
            centerRedRatio: centerRedRatio,
            centerBlueRatio: centerBlueRatio,
            centerDarkInkRatio: centerDarkInkRatio,
            cornerFillRatio: cornerFillRatio,
            hasDiagonalRedSlash: hasDiagonalRedSlash,
            dominantDescription: dominantColor
        )
        return (detectedShape, metrics)
    }

    private static func describeDominantColor(
        redRatio: Double,
        yellowRatio: Double,
        greenRatio: Double,
        blueRatio: Double,
        whiteRatio: Double,
        darkRatio: Double
    ) -> String {
        var components: [String] = []
        if redRatio > 0.04 { components.append("Đỏ") }
        if yellowRatio > 0.04 { components.append("Vàng") }
        if greenRatio > 0.05 { components.append("Xanh lá") }
        if blueRatio > 0.05 { components.append("Xanh dương") }
        if darkRatio > 0.25 { components.append("Nền tối") }
        if whiteRatio > 0.35 { components.append("Trắng") }
        if components.isEmpty {
            return "Trung tính"
        }
        return components.joined(separator: " • ")
    }

    private static func rgbToHSV(r: Double, g: Double, b: Double) -> (h: Double, s: Double, v: Double) {
        let maxVal = max(r, max(g, b))
        let minVal = min(r, min(g, b))
        let delta = maxVal - minVal

        let v = maxVal
        let s = maxVal > 0 ? (delta / maxVal) : 0
        guard delta > 0.0001 else {
            return (0, s, v)
        }

        var h: Double
        if maxVal == r {
            h = 60.0 * (((g - b) / delta).truncatingRemainder(dividingBy: 6.0))
        } else if maxVal == g {
            h = 60.0 * (((b - r) / delta) + 2.0)
        } else {
            h = 60.0 * (((r - g) / delta) + 4.0)
        }

        if h < 0 {
            h += 360.0
        }
        return (h, s, v)
    }
}

@Observable
final class VisionSignRecognizer {
    var isAnalyzing: Bool = false
    var matches: [VisionSignMatch] = []
    var lastSummary: VisionAnalysisSummary?
    var errorMessage: String?

    func reset() {
        isAnalyzing = false
        matches = []
        lastSummary = nil
        errorMessage = nil
    }

    func analyze(image: UIImage, against signs: [TrafficSign]) async {
        isAnalyzing = true
        errorMessage = nil

        guard !signs.isEmpty else {
            isAnalyzing = false
            errorMessage = "Kho dữ liệu biển báo chưa sẵn sàng."
            return
        }

        guard let prepared = prepareCGImage(from: image) else {
            isAnalyzing = false
            errorMessage = "Không thể đọc dữ liệu ảnh đầu vào."
            return
        }

        do {
            let features = try await Task.detached(priority: .userInitiated) {
                try VisionImageAnalyzer.analyze(
                    cgImage: prepared.cgImage,
                    orientation: prepared.orientation
                )
            }.value

            let categoryScores = computeCategoryAffinities(from: features)
            let inferredCategory = categoryScores.max(by: { $0.value < $1.value })?.key

            let ranked = rankMatches(
                features: features,
                categoryScores: categoryScores,
                signs: signs
            )

            self.matches = ranked
            self.lastSummary = VisionAnalysisSummary(
                inferredCategory: inferredCategory,
                shapeLabel: features.shape.vietnameseLabel,
                dominantColorText: features.colorMetrics.dominantDescription,
                recognizedTexts: features.recognizedTexts,
                detectedRectanglesCount: features.detectedRectanglesCount,
                processingTimeMs: Int(features.processingTimeMs.rounded())
            )
            self.isAnalyzing = false
        } catch {
            self.isAnalyzing = false
            self.errorMessage = "Phân tích Vision gặp sự cố: \(error.localizedDescription)"
        }
    }

    private func prepareCGImage(from image: UIImage) -> (cgImage: CGImage, orientation: CGImagePropertyOrientation)? {
        if let cgImage = image.cgImage {
            return (cgImage, cgImageOrientation(from: image.imageOrientation))
        }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let rendered = renderer.image { _ in
            image.draw(at: .zero)
        }
        if let cgImage = rendered.cgImage {
            return (cgImage, .up)
        }
        return nil
    }

    private func cgImageOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    private func computeCategoryAffinities(from features: VisionRawFeatures) -> [TrafficSignCategory: Double] {
        let color = features.colorMetrics
        let texts = normalizedTokens(from: features.recognizedTexts)
        var scores: [TrafficSignCategory: Double] = [
            .prohibition: 0.08,
            .warning: 0.08,
            .mandatory: 0.08,
            .guide: 0.08,
            .auxiliary: 0.05,
            .marking: 0.05
        ]

        // Red + Circle or Red ring -> Prohibition
        if color.redRatio > 0.045 && color.yellowRatio < 0.06 {
            scores[.prohibition, default: 0] += 0.42 + min(color.redRatio, 0.35)
        }
        if features.shape == .circle && color.redRatio > 0.03 {
            scores[.prohibition, default: 0] += 0.22
        }
        if color.hasDiagonalRedSlash {
            scores[.prohibition, default: 0] += 0.18
        }
        if texts.contains("STOP") {
            scores[.prohibition, default: 0] += 0.35
        }

        // Yellow + Red / Triangle -> Warning
        if color.yellowRatio > 0.05 && (color.redRatio > 0.02 || features.shape == .uprightTriangle || features.shape == .invertedTriangle) {
            scores[.warning, default: 0] += 0.46 + min(color.yellowRatio, 0.35)
        }
        if features.shape == .uprightTriangle || features.shape == .invertedTriangle {
            scores[.warning, default: 0] += 0.30
        }

        // Blue + Circle vs Blue + Rectangle -> Mandatory vs Guide; Green / Yellow diamond -> Guide
        if color.greenRatio > 0.12 {
            scores[.guide, default: 0] += 0.56 + min(color.greenRatio, 0.30)
        }
        if features.shape == .diamond && color.yellowRatio > 0.05 && color.redRatio < 0.02 {
            scores[.guide, default: 0] += 0.54
        }
        if color.blueRatio > 0.08 && color.redRatio < 0.05 {
            if features.shape == .circle || (features.detectedRectanglesCount == 0 && color.cornerFillRatio < 0.30) {
                scores[.mandatory, default: 0] += 0.52 + min(color.blueRatio, 0.30)
                scores[.guide, default: 0] += 0.16
            } else {
                scores[.guide, default: 0] += 0.52 + min(color.blueRatio, 0.30)
                scores[.mandatory, default: 0] += 0.16
            }
        }
        if features.detectedRectanglesCount > 0 && (color.blueRatio > 0.08 || color.greenRatio > 0.08) {
            scores[.guide, default: 0] += 0.24
        }

        // White circle with dark lines -> end-restriction prohibition (DP.)
        if features.shape == .circle && color.redRatio < 0.03 && color.yellowRatio < 0.03 && color.blueRatio < 0.03 {
            scores[.prohibition, default: 0] += 0.28
        }

        // White rectangle with black border/text -> Auxiliary; dark road -> Marking
        if color.redRatio < 0.03 && color.yellowRatio < 0.03 && color.greenRatio < 0.03 && color.blueRatio < 0.03 {
            if color.whiteRatio > 0.35 && (features.detectedRectanglesCount > 0 || !texts.isEmpty) && features.shape != .circle {
                scores[.auxiliary, default: 0] += 0.45
            }
            if color.darkRatio > 0.28 {
                scores[.marking, default: 0] += 0.55
            }
        }

        if texts.contains(where: { $0.hasSuffix("M") && $0.dropLast().allSatisfy(\.isNumber) }) {
            scores[.auxiliary, default: 0] += 0.30
        }

        return scores
    }

    private func rankMatches(
        features: VisionRawFeatures,
        categoryScores: [TrafficSignCategory: Double],
        signs: [TrafficSign]
    ) -> [VisionSignMatch] {
        let color = features.colorMetrics
        let tokens = normalizedTokens(from: features.recognizedTexts)
        let joinedUpper = features.recognizedTexts.joined(separator: " ").uppercased()
        let compactJoined = joinedUpper
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")

        var results: [VisionSignMatch] = []

        for sign in signs {
            var score = (categoryScores[sign.category] ?? 0.05) * 0.48
            var reasons: [String] = []

            let signCodeUpper = sign.code.uppercased()
            let compactCode = signCodeUpper.replacingOccurrences(of: ".", with: "")
            let signNameUpper = sign.name.uppercased()
            let signSymbolUpper = sign.diagram.symbol.uppercased()
            let keywordsUpper = sign.keywords.map { $0.uppercased() }

            if (categoryScores[sign.category] ?? 0) >= 0.45 {
                reasons.append("Nhóm \(sign.category.vietnameseTitle)")
            }

            // 1. Exact or compact sign code OCR match
            if !compactCode.isEmpty && compactJoined.contains(compactCode) {
                score += 0.65
                reasons.append("Khớp mã biển \(sign.code)")
            }

            // 2. OCR token matching (STOP, speed numbers, P, H, height/weight/distance)
            for token in tokens {
                if token == "STOP" && (signCodeUpper.contains("122") || signNameUpper.contains("DỪNG LẠI") || signSymbolUpper.contains("STOP")) {
                    score += 0.65
                    reasons.append("Nhận diện chữ STOP")
                } else if token.allSatisfy(\.isNumber) && token.count >= 2 {
                    if signNameUpper.contains(token) || signSymbolUpper.contains(token) || keywordsUpper.contains(where: { $0.contains(token) }) {
                        score += 0.52
                        reasons.append("Nhận diện số \(token)")
                    }
                } else if token == "P" {
                    if sign.category == .guide && (signNameUpper.contains("ĐỖ XE") || signSymbolUpper.contains("PARKING")) {
                        score += 0.36
                        reasons.append("Chữ P trên nền xanh")
                    } else if sign.category == .prohibition && (signNameUpper.contains("CẤM ĐỖ") || signNameUpper.contains("CẤM DỪNG")) {
                        score += 0.30
                        reasons.append("Chữ P trên biển cấm")
                    }
                } else if token == "H" && (signNameUpper.contains("BỆNH VIỆN") || signSymbolUpper.contains("HOSPITAL")) {
                    score += 0.36
                    reasons.append("Chữ H bệnh viện")
                } else if token.count >= 3 {
                    if signNameUpper.contains(token) || keywordsUpper.contains(where: { $0.contains(token) }) {
                        score += 0.24
                        reasons.append("Khớp từ khóa \"\(token)\"")
                    }
                }
            }

            // 3. Geometric & color sub-features inside category
            switch sign.category {
            case .prohibition:
                if color.hasDiagonalRedSlash == sign.diagram.hasSlash {
                    score += 0.14
                    if color.hasDiagonalRedSlash {
                        reasons.append("Phát hiện gạch chéo đỏ")
                    }
                } else {
                    score -= 0.08
                }

                if color.centerRedRatio > 0.35 && (signCodeUpper.contains("102") || signSymbolUpper.contains("ONE_WAY") || signSymbolUpper.contains("NO_ENTRY")) {
                    score += 0.28
                    reasons.append("Nền đỏ đặc trưng biển cấm đi ngược chiều")
                } else if color.centerRedRatio < 0.12 && color.centerDarkInkRatio < 0.05 && !color.hasDiagonalRedSlash && signCodeUpper.contains("101") {
                    score += 0.26
                    reasons.append("Lõi trắng trống đặc trưng Cấm đi")
                } else if color.centerBlueRatio > 0.18 && (signCodeUpper.contains("130") || signCodeUpper.contains("131")) {
                    score += 0.24
                    reasons.append("Lõi xanh dương biển cấm dừng/đỗ")
                }

            case .warning:
                if features.shape == .invertedTriangle && (signCodeUpper.contains("208") || signSymbolUpper.contains("GIVE_WAY") || signNameUpper.contains("GIAO NHAU VỚI ĐƯỜNG ƯU TIÊN")) {
                    score += 0.32
                    reasons.append("Tam giác ngược nhường đường")
                } else if features.shape == .uprightTriangle && !signCodeUpper.contains("208") {
                    score += 0.10
                    reasons.append("Tam giác cảnh báo viền đỏ")
                }

            case .mandatory:
                if features.shape == .circle && color.blueRatio > 0.12 {
                    score += 0.14
                    reasons.append("Hình tròn xanh hiệu lệnh")
                }

            case .guide:
                if (features.shape == .rectangle || features.shape == .square || features.detectedRectanglesCount > 0) && color.blueRatio > 0.10 {
                    score += 0.14
                    reasons.append("Khung chữ nhật xanh chỉ dẫn")
                } else if color.greenRatio > 0.10 && (signCodeUpper.contains("437") || signSymbolUpper.contains("HIGHWAY")) {
                    score += 0.30
                    reasons.append("Nền xanh lá cao tốc")
                } else if features.shape == .diamond && color.yellowRatio > 0.05 && (signCodeUpper.contains("401") || signCodeUpper.contains("402") || signSymbolUpper.contains("PRIORITY")) {
                    score += 0.32
                    reasons.append("Hình thoi vàng đường ưu tiên")
                }

            case .auxiliary:
                if features.detectedRectanglesCount > 0 || features.shape == .rectangle {
                    score += 0.12
                }

            case .marking:
                if color.darkRatio > 0.28 {
                    score += 0.18
                    reasons.append("Tương phản vạch trên mặt đường")
                }
            }

            if reasons.isEmpty {
                reasons.append("Màu sắc: \(color.dominantDescription)")
            }

            let clampedScore = min(max(score, 0.05), 0.99)
            results.append(
                VisionSignMatch(
                    sign: sign,
                    confidence: clampedScore,
                    matchReasons: Array(NSOrderedSet(array: reasons).compactMap { $0 as? String }.prefix(3))
                )
            )
        }

        return Array(
            results
                .sorted { lhs, rhs in
                    if abs(lhs.confidence - rhs.confidence) > 0.001 {
                        return lhs.confidence > rhs.confidence
                    }
                    return lhs.sign.code < rhs.sign.code
                }
                .prefix(4)
        )
    }

    private func normalizedTokens(from texts: [String]) -> [String] {
        var tokens: [String] = []
        for line in texts {
            let parts = line
                .uppercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
            for part in parts where !tokens.contains(part) {
                tokens.append(part)
            }
        }
        return tokens
    }
}
