import Foundation
#if canImport(UIKit)
import UIKit
#endif

nonisolated enum ExamRegulationEra: String, CaseIterable, Codable, Identifiable, Sendable {
    case auto
    case currentPre2027
    case newFromMarch2027

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            return "Tự động theo ngày (01/03/2027)"
        case .currentPre2027:
            return "Trước 01/03/2027"
        case .newFromMarch2027:
            return "Từ 01/03/2027"
        }
    }

    var shortTitle: String {
        switch self {
        case .auto:
            return "Tự động"
        case .currentPre2027:
            return "Hiện hành"
        case .newFromMarch2027:
            return "Từ 03/2027"
        }
    }

    /// Mốc hiệu lực 2027-03-01T00:00:00+07:00 (giờ Việt Nam).
    static var march2027CutoffDate: Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 7 * 3600)
        components.year = 2027
        components.month = 3
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        return components.date ?? Date(timeIntervalSince1970: 1_803_834_000)
    }

    func resolvedIs2027(on date: Date = .now) -> Bool {
        switch self {
        case .auto:
            return date >= Self.march2027CutoffDate
        case .currentPre2027:
            return false
        case .newFromMarch2027:
            return true
        }
    }
}

nonisolated enum LicenseClass: String, CaseIterable, Codable, Identifiable, Sendable {
    case A1
    case A
    case B1
    case B
    case C1
    case C
    case D1
    case D2
    case D
    case BE
    case C1E
    case CE
    case D1E
    case D2E
    case DE

    var id: String { rawValue }
    var code: String { rawValue }
    var title: String { "Hạng \(rawValue)" }

    var isMotorcycle: Bool {
        switch self {
        case .A1, .A, .B1:
            return true
        default:
            return false
        }
    }

    var vehicleIconName: String {
        if isMotorcycle {
            #if canImport(UIKit)
            return UIImage(systemName: "motorcycle") != nil ? "motorcycle" : "scooter"
            #else
            return "scooter"
            #endif
        }
        return "car"
    }

    var vehicleSummary: String {
        switch self {
        case .A1:
            return "Mô tô hai bánh có dung tích xi-lanh đến 125 cm³ hoặc công suất điện đến 11 kW (250 câu, 20 điểm liệt)"
        case .A:
            return "Mô tô hai bánh có dung tích xi-lanh trên 125 cm³ hoặc công suất điện trên 11 kW và xe hạng A1 (250 câu, 20 điểm liệt)"
        case .B1:
            return "Mô tô ba bánh và các loại xe quy định cho giấy phép lái xe hạng A1 (300 câu, 20 điểm liệt)"
        case .B:
            return "Ô tô chở người đến 8 chỗ (không kể chỗ lái), ô tô tải đến 3.500 kg"
        case .C1:
            return "Ô tô tải và ô tô chuyên dùng trên 3.500 kg đến 7.500 kg"
        case .C:
            return "Ô tô tải và ô tô chuyên dùng có khối lượng toàn bộ trên 7.500 kg"
        case .D1:
            return "Ô tô chở người trên 8 đến 16 chỗ (không kể chỗ lái)"
        case .D2:
            return "Ô tô chở người trên 16 đến 29 chỗ (không kể chỗ lái)"
        case .D:
            return "Ô tô chở người trên 29 chỗ (không kể chỗ lái), ô tô chở người giường nằm"
        case .BE:
            return "Ô tô hạng B kéo rơ moóc có khối lượng toàn bộ trên 750 kg"
        case .C1E:
            return "Ô tô hạng C1 kéo rơ moóc có khối lượng toàn bộ trên 750 kg"
        case .CE:
            return "Ô tô hạng C kéo rơ moóc trên 750 kg, đầu kéo sơ mi rơ moóc"
        case .D1E:
            return "Ô tô hạng D1 kéo rơ moóc có khối lượng toàn bộ trên 750 kg"
        case .D2E:
            return "Ô tô hạng D2 kéo rơ moóc có khối lượng toàn bộ trên 750 kg"
        case .DE:
            return "Ô tô hạng D kéo rơ moóc trên 750 kg, xe khách nối toa"
        }
    }

    var groupTitle: String {
        switch self {
        case .A1, .A, .B1:
            return "Xe máy & Mô tô"
        case .B:
            return "Hạng phổ thông"
        case .C1, .C:
            return "Xe tải"
        case .D1, .D2, .D:
            return "Xe chở người"
        case .BE, .C1E, .CE, .D1E, .D2E, .DE:
            return "Xe kéo rơ moóc"
        }
    }

    func examStructure(for era: ExamRegulationEra, referenceDate: Date = .now) -> ExamStructure {
        let is2027 = era.resolvedIs2027(on: referenceDate)

        switch (self, is2027) {
        case (.A1, _):
            return ExamStructure(
                licenseClass: self,
                is2027Rule: is2027,
                totalQuestions: 25,
                durationMinutes: 19,
                passScore: 21,
                criticalQuestionCount: 1
            )
        case (.A, _):
            return ExamStructure(
                licenseClass: self,
                is2027Rule: is2027,
                totalQuestions: 25,
                durationMinutes: 19,
                passScore: 23,
                criticalQuestionCount: 1
            )
        case (.B1, _):
            return ExamStructure(
                licenseClass: self,
                is2027Rule: is2027,
                totalQuestions: 25,
                durationMinutes: 19,
                passScore: 23,
                criticalQuestionCount: 1
            )
        case (.B, false):
            return ExamStructure(
                licenseClass: self,
                is2027Rule: false,
                totalQuestions: 30,
                durationMinutes: 20,
                passScore: 27,
                criticalQuestionCount: 1
            )
        case (.C1, false):
            return ExamStructure(
                licenseClass: self,
                is2027Rule: false,
                totalQuestions: 35,
                durationMinutes: 22,
                passScore: 32,
                criticalQuestionCount: 1
            )
        case (.C, false):
            return ExamStructure(
                licenseClass: self,
                is2027Rule: false,
                totalQuestions: 40,
                durationMinutes: 24,
                passScore: 36,
                criticalQuestionCount: 1
            )
        case (_, false):
            return ExamStructure(
                licenseClass: self,
                is2027Rule: false,
                totalQuestions: 45,
                durationMinutes: 26,
                passScore: 41,
                criticalQuestionCount: 1
            )
        case (.B, true):
            return ExamStructure(
                licenseClass: self,
                is2027Rule: true,
                totalQuestions: 50,
                durationMinutes: 33,
                passScore: 45,
                criticalQuestionCount: 2
            )
        case (.C1, true):
            return ExamStructure(
                licenseClass: self,
                is2027Rule: true,
                totalQuestions: 55,
                durationMinutes: 36,
                passScore: 50,
                criticalQuestionCount: 2
            )
        case (.C, true):
            return ExamStructure(
                licenseClass: self,
                is2027Rule: true,
                totalQuestions: 60,
                durationMinutes: 40,
                passScore: 54,
                criticalQuestionCount: 2
            )
        case (_, true):
            return ExamStructure(
                licenseClass: self,
                is2027Rule: true,
                totalQuestions: 65,
                durationMinutes: 42,
                passScore: 59,
                criticalQuestionCount: 2
            )
        }
    }
}

nonisolated struct ExamStructure: Equatable, Sendable {
    let licenseClass: LicenseClass
    let is2027Rule: Bool
    let totalQuestions: Int
    let durationMinutes: Int
    let passScore: Int
    let criticalQuestionCount: Int

    var durationSeconds: Int {
        durationMinutes * 60
    }

    var ruleBadgeText: String {
        if licenseClass.isMotorcycle {
            return "Chuẩn sát hạch Mô tô (25 câu)"
        }
        return is2027Rule ? "Quy định từ 01/03/2027" : "Quy định trước 01/03/2027"
    }

    /// Phân bổ số câu theo 6 chương chuẩn (tổng bằng `totalQuestions`).
    var chapterQuotas: [Int: Int] {
        switch (licenseClass, is2027Rule) {
        case (.A1, _), (.A, _):
            return [1: 9, 2: 1, 3: 1, 4: 0, 5: 8, 6: 6]
        case (.B1, _):
            return [1: 8, 2: 1, 3: 1, 4: 1, 5: 8, 6: 6]
        case (.B, false):
            return [1: 8, 2: 1, 3: 1, 4: 1, 5: 10, 6: 9]
        case (.C1, false):
            return [1: 10, 2: 2, 3: 2, 4: 1, 5: 10, 6: 10]
        case (.C, false):
            return [1: 11, 2: 2, 3: 3, 4: 2, 5: 12, 6: 10]
        case (_, false):
            return [1: 12, 2: 2, 3: 3, 4: 2, 5: 14, 6: 12]
        case (.B, true):
            return [1: 15, 2: 2, 3: 4, 4: 3, 5: 14, 6: 12]
        case (.C1, true):
            return [1: 16, 2: 2, 3: 5, 4: 3, 5: 16, 6: 13]
        case (.C, true):
            return [1: 18, 2: 3, 3: 5, 4: 3, 5: 17, 6: 14]
        case (_, true):
            return [1: 19, 2: 3, 3: 6, 4: 4, 5: 18, 6: 15]
        }
    }
}

nonisolated struct ChapterInfo: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let shortTitle: String
    let expectedCount: Int
    let iconSystemName: String
    let summaryPoints: [String]

    static let allChapters: [ChapterInfo] = [
        ChapterInfo(
            id: 1,
            title: "Quy định chung và quy tắc giao thông đường bộ",
            shortTitle: "Quy tắc GTĐB",
            expectedCount: 180,
            iconSystemName: "book.closed",
            summaryPoints: [
                "Nghiêm cấm tuyệt đối nồng độ cồn (> 0) khi điều khiển ô tô tham gia giao thông.",
                "Tốc độ tối đa trong khu dân cư (đường đôi 60 km/h, đường hai chiều 50 km/h) và khoảng cách an toàn.",
                "Thứ tự xe ưu tiên: Chữa cháy → Quân sự → Công an → Cứu thương → Hộ đê/khắc phục sự cố.",
                "Quy tắc nhường đường tại nơi giao nhau, vòng xuyến, đường sắt và đường cao tốc."
            ]
        ),
        ChapterInfo(
            id: 2,
            title: "Văn hóa giao thông, đạo đức người lái xe, PCCC và cứu hộ",
            shortTitle: "Văn hóa & PCCC",
            expectedCount: 25,
            iconSystemName: "heart.text.square",
            summaryPoints: [
                "Trách nhiệm cứu giúp người bị nạn, bảo vệ hiện trường và báo cơ quan chức năng khi xảy ra tai nạn.",
                "Ứng xử văn minh: không sử dụng còi hơi trong đô thị từ 22h đến 5h sáng, nhường đường cho người đi bộ.",
                "Quy trình xử lý cháy nổ trên ô tô: ngắt khóa điện, dùng bình chữa cháy chuyên dụng, sơ tán hành khách."
            ]
        ),
        ChapterInfo(
            id: 3,
            title: "Kỹ thuật lái xe",
            shortTitle: "Kỹ thuật lái xe",
            expectedCount: 58,
            iconSystemName: "steeringwheel",
            summaryPoints: [
                "Kỹ thuật lên/xuống dốc dài: về số thấp tận dụng phanh động cơ, tránh rà phanh liên tục gây mất phanh.",
                "Xử lý đường trơn trượt, ngập nước, sương mù, ban đêm và quay đầu xe an toàn.",
                "Thao tác đúng với hộp số sàn, hộp số tự động và mở cửa xe quan sát phía sau trước khi bước xuống."
            ]
        ),
        ChapterInfo(
            id: 4,
            title: "Cấu tạo và sửa chữa thông thường",
            shortTitle: "Cấu tạo & Sửa chữa",
            expectedCount: 37,
            iconSystemName: "wrench.and.screwdriver",
            summaryPoints: [
                "Nguyên lý động cơ 4 kỳ (nạp – nén – nổ – xả), hệ thống bôi trơn, làm mát và ắc quy.",
                "Vai trò hệ thống phanh ABS chống bó cứng bánh xe và trợ lực lái.",
                "Kiểm tra áp suất lốp, chiều sâu hoa lốp tối thiểu (≥ 1,6 mm) và ý nghĩa các đèn cảnh báo táp-lô."
            ]
        ),
        ChapterInfo(
            id: 5,
            title: "Biển báo hiệu đường bộ",
            shortTitle: "Biển báo hiệu",
            expectedCount: 185,
            iconSystemName: "signpost.right",
            summaryPoints: [
                "Nhận biết 5 nhóm biển chính (Cấm, Nguy hiểm, Hiệu lệnh, Chỉ dẫn, Phụ) và vạch kẻ đường theo QCVN 41:2019.",
                "Thứ tự hiệu lực điều khiển: Người điều khiển GT → Đèn tín hiệu → Biển báo → Vạch kẻ đường.",
                "Phân biệt nhóm biển cấm theo bậc (cấm ô tô con kéo theo cấm xe tải/khách, cấm rẽ trái có cấm quay đầu hay không)."
            ]
        ),
        ChapterInfo(
            id: 6,
            title: "Giải thế sa hình và kỹ năng xử lý tình huống giao thông",
            shortTitle: "Sa hình & Tình huống",
            expectedCount: 115,
            iconSystemName: "map",
            summaryPoints: [
                "Quy tắc vàng 5 bước: Nhất chớm (đã vào giao lộ) → Nhì ưu (xe ưu tiên) → Tam đường (đường ưu tiên) → Tứ hướng (bên phải trống, rẽ phải, đi thẳng, rẽ trái).",
                "Phối hợp tín hiệu đèn giao thông, biển phụ hướng đường ưu tiên và hiệu lệnh của CSGT.",
                "Kiểm tra phạm vi làn đường, cấm vượt, cấm dừng/đỗ trước khi chọn thứ tự xe đi đúng."
            ]
        )
    ]
}

nonisolated struct DiagramSpec: Codable, Equatable, Hashable, Sendable {
    let kind: String
    let code: String
    let symbol: String
    let hasSlash: Bool
    let caption: String?
}

nonisolated struct Question: Codable, Identifiable, Equatable, Hashable, Sendable {
    let id: Int
    let chapter: Int
    let text: String
    let options: [String]
    let correctIndex: Int
    let isCritical: Bool
    let explanation: String
    let tip: String
    let signCode: String?
    let diagram: DiagramSpec?
    let inA1Pool: Bool
    let inB1Pool: Bool
    let isMotoCritical: Bool

    init(
        id: Int,
        chapter: Int,
        text: String,
        options: [String],
        correctIndex: Int,
        isCritical: Bool,
        explanation: String,
        tip: String,
        signCode: String? = nil,
        diagram: DiagramSpec? = nil,
        inA1Pool: Bool = true,
        inB1Pool: Bool = true,
        isMotoCritical: Bool = false
    ) {
        self.id = id
        self.chapter = chapter
        self.text = text
        self.options = options
        self.correctIndex = correctIndex
        self.isCritical = isCritical
        self.explanation = explanation
        self.tip = tip
        self.signCode = signCode
        self.diagram = diagram
        self.inA1Pool = inA1Pool
        self.inB1Pool = inB1Pool
        self.isMotoCritical = isMotoCritical
    }

    enum CodingKeys: String, CodingKey {
        case id
        case chapter
        case text
        case options
        case correctIndex
        case isCritical
        case explanation
        case tip
        case signCode
        case diagram
        case inA1Pool
        case inB1Pool
        case isMotoCritical
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        chapter = try container.decode(Int.self, forKey: .chapter)
        text = try container.decode(String.self, forKey: .text)
        options = try container.decode([String].self, forKey: .options)
        correctIndex = try container.decode(Int.self, forKey: .correctIndex)
        let decodedCritical = try container.decode(Bool.self, forKey: .isCritical)
        isCritical = decodedCritical
        explanation = try container.decode(String.self, forKey: .explanation)
        tip = try container.decode(String.self, forKey: .tip)
        signCode = try container.decodeIfPresent(String.self, forKey: .signCode)
        diagram = try container.decodeIfPresent(DiagramSpec.self, forKey: .diagram)
        inA1Pool = try container.decodeIfPresent(Bool.self, forKey: .inA1Pool) ?? true
        inB1Pool = try container.decodeIfPresent(Bool.self, forKey: .inB1Pool) ?? true
        isMotoCritical = try container.decodeIfPresent(Bool.self, forKey: .isMotoCritical) ?? decodedCritical
    }

    func adapted(for license: LicenseClass) -> Question {
        Question(
            id: id,
            chapter: chapter,
            text: text,
            options: options,
            correctIndex: correctIndex,
            isCritical: license.isMotorcycle ? isMotoCritical : isCritical,
            explanation: explanation,
            tip: tip,
            signCode: signCode,
            diagram: diagram,
            inA1Pool: inA1Pool,
            inB1Pool: inB1Pool,
            isMotoCritical: isMotoCritical
        )
    }
}

nonisolated enum TrafficSignCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case prohibition
    case warning
    case mandatory
    case guide
    case auxiliary
    case marking

    var id: String { rawValue }

    var vietnameseTitle: String {
        switch self {
        case .prohibition:
            return "Biển báo cấm"
        case .warning:
            return "Biển nguy hiểm"
        case .mandatory:
            return "Biển hiệu lệnh"
        case .guide:
            return "Biển chỉ dẫn"
        case .auxiliary:
            return "Biển phụ"
        case .marking:
            return "Vạch kẻ đường"
        }
    }

    var codePrefix: String {
        switch self {
        case .prohibition:
            return "P"
        case .warning:
            return "W"
        case .mandatory:
            return "R"
        case .guide:
            return "I"
        case .auxiliary:
            return "S"
        case .marking:
            return "V"
        }
    }
}

nonisolated struct TrafficSign: Codable, Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let code: String
    let name: String
    let category: TrafficSignCategory
    let summary: String
    let legalDetail: String
    let penaltyNote: String
    let keywords: [String]
    let relatedQuestionIDs: [Int]
    let diagram: DiagramSpec
}

nonisolated struct AITutorExplanation: Equatable, Sendable {
    let headline: String
    let coreRule: String
    let optionBreakdown: [String]
    let realWorldScenario: String
    let memoryAnchor: String
}

nonisolated struct SmartStudyRecommendation: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let badge: String
    let targetQuestions: [Question]
}
