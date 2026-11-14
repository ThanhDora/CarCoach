import Foundation
import Observation
import SwiftData
import UIKit

@Observable
final class CarCoachRepository {
    static let dailyFreeExamLimit = 2
    static let dailyFreeAILimit = 3

    private(set) var questions: [Question] = []
    private(set) var signs: [TrafficSign] = []
    private(set) var examHistory: [ExamAttemptRecord] = []
    private(set) var loadErrorMessage: String?

    private(set) var hasCompletedOnboarding: Bool = false
    private(set) var studyStreakDays: Int = 0
    private(set) var dailyFreeExamsUsed: Int = 0
    private(set) var dailyFreeAIUsed: Int = 0
    private(set) var progressRevision: Int = 0

    var currentLicense: LicenseClass = .B {
        didSet {
            guard currentLicense != oldValue else { return }
            settingsRecord?.selectedLicenseCode = currentLicense.rawValue
            applyLicenseFilter()
            saveContext()
            progressRevision &+= 1
        }
    }

    var currentRegulationEra: ExamRegulationEra = .auto {
        didSet {
            guard currentRegulationEra != oldValue else { return }
            settingsRecord?.regulationEraRaw = currentRegulationEra.rawValue
            saveContext()
        }
    }

    var currentAppearanceMode: AppAppearanceMode = .system {
        didSet {
            guard currentAppearanceMode != oldValue else { return }
            settingsRecord?.appearanceModeRaw = currentAppearanceMode.rawValue
            saveContext()
        }
    }

    var targetExamDate: Date? = nil {
        didSet {
            guard targetExamDate != oldValue else { return }
            settingsRecord?.targetExamDate = targetExamDate
            saveContext()
        }
    }

    private var modelContext: ModelContext?
    private var settingsRecord: UserSettingsRecord?
    private var progressByQuestionID: [Int: QuestionProgressRecord] = [:]
    private var rawBankQuestions: [Question] = []
    private var rawQuestionByID: [Int: Question] = [:]
    private var questionByID: [Int: Question] = [:]
    private var signByCode: [String: TrafficSign] = [:]

    init() {
        loadBundledContent()
    }

    // MARK: - Computed Status & Quota

    var currentExamStructure: ExamStructure {
        currentLicense.examStructure(for: currentRegulationEra)
    }

    var remainingFreeExamsToday: Int {
        refreshQuotaDayIfNeeded(saveIfChanged: false)
        return max(0, Self.dailyFreeExamLimit - dailyFreeExamsUsed)
    }

    var remainingFreeAIToday: Int {
        refreshQuotaDayIfNeeded(saveIfChanged: false)
        return max(0, Self.dailyFreeAILimit - dailyFreeAIUsed)
    }

    var criticalQuestions: [Question] {
        questions.filter(\.isCritical)
    }

    var wrongQuestions: [Question] {
        _ = progressRevision
        let records = progressByQuestionID
        return questions
            .filter { q in
                guard let rec = records[q.id] else { return false }
                return rec.attemptsCount > 0 && !rec.lastAnsweredCorrectly
            }
            .sorted { lhs, rhs in
                let lw = records[lhs.id]?.wrongCount ?? 0
                let rw = records[rhs.id]?.wrongCount ?? 0
                if lw != rw { return lw > rw }
                return lhs.id < rhs.id
            }
    }

    var bookmarkedQuestions: [Question] {
        _ = progressRevision
        let records = progressByQuestionID
        return questions.filter { records[$0.id]?.isBookmarked == true }
    }

    var dueForReviewQuestions: [Question] {
        _ = progressRevision
        let now = Date.now
        let records = progressByQuestionID
        return questions
            .filter { q in
                guard let rec = records[q.id] else { return false }
                if rec.attemptsCount > 0 && !rec.lastAnsweredCorrectly {
                    return true
                }
                if let nextReview = rec.nextReviewAt, nextReview <= now {
                    return true
                }
                return false
            }
            .sorted { lhs, rhs in
                let ld = records[lhs.id]?.nextReviewAt ?? .distantPast
                let rd = records[rhs.id]?.nextReviewAt ?? .distantPast
                if ld != rd { return ld < rd }
                return lhs.id < rhs.id
            }
    }

    var totalAnsweredCount: Int {
        _ = progressRevision
        let records = progressByQuestionID
        return questions.filter { (records[$0.id]?.attemptsCount ?? 0) > 0 }.count
    }

    var totalMasteredCount: Int {
        _ = progressRevision
        let records = progressByQuestionID
        return questions.filter { records[$0.id]?.lastAnsweredCorrectly == true }.count
    }

    var criticalMasteredCount: Int {
        _ = progressRevision
        return criticalQuestions.filter { progressByQuestionID[$0.id]?.lastAnsweredCorrectly == true }.count
    }

    var overallAccuracyPercent: Int {
        _ = progressRevision
        let totalAttempts = progressByQuestionID.values.reduce(0) { $0 + $1.attemptsCount }
        guard totalAttempts > 0 else { return 0 }
        let totalCorrect = progressByQuestionID.values.reduce(0) { $0 + $1.correctCount }
        return Int((Double(totalCorrect) / Double(totalAttempts) * 100.0).rounded())
    }

    var readinessScorePercent: Int {
        _ = progressRevision
        guard !questions.isEmpty else { return 0 }

        let bankCoverage = Double(totalMasteredCount) / Double(questions.count)
        let criticalTotal = max(criticalQuestions.count, 1)
        let criticalCoverage = Double(criticalMasteredCount) / Double(criticalTotal)

        let recentExamScore: Double
        let sameCategoryExams = examHistory.filter {
            (LicenseClass(rawValue: $0.licenseCode)?.isMotorcycle ?? false) == currentLicense.isMotorcycle
        }
        let recentExams = Array(sameCategoryExams.prefix(3))
        if recentExams.isEmpty {
            recentExamScore = Double(overallAccuracyPercent) / 100.0
        } else {
            let ratios = recentExams.map { attempt -> Double in
                guard attempt.totalQuestions > 0 else { return 0 }
                let raw = Double(attempt.correctCount) / Double(attempt.totalQuestions)
                return attempt.failedByCritical ? min(raw, 0.5) : raw
            }
            recentExamScore = ratios.reduce(0, +) / Double(ratios.count)
        }

        let weighted = (bankCoverage * 40.0) + (criticalCoverage * 30.0) + (recentExamScore * 30.0)
        return max(0, min(100, Int(weighted.rounded())))
    }

    // MARK: - SwiftData Lifecycle

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
        if questions.isEmpty || signs.isEmpty {
            loadBundledContent()
        }

        do {
            let settingsDescriptor = FetchDescriptor<UserSettingsRecord>()
            let fetchedSettings = try modelContext.fetch(settingsDescriptor)
            let canonicalSettings: UserSettingsRecord
            if let existing = fetchedSettings.first(where: { $0.singletonKey == "default" }) ?? fetchedSettings.first {
                canonicalSettings = existing
            } else {
                let created = UserSettingsRecord()
                modelContext.insert(created)
                canonicalSettings = created
            }
            self.settingsRecord = canonicalSettings
            syncSettingsFromRecord(canonicalSettings)

            let progressDescriptor = FetchDescriptor<QuestionProgressRecord>()
            let fetchedProgress = try modelContext.fetch(progressDescriptor)
            var map: [Int: QuestionProgressRecord] = [:]
            for record in fetchedProgress {
                map[record.questionID] = record
            }
            self.progressByQuestionID = map

            let historyDescriptor = FetchDescriptor<ExamAttemptRecord>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            self.examHistory = try modelContext.fetch(historyDescriptor)

            refreshQuotaDayIfNeeded(saveIfChanged: true)
            try modelContext.save()
            progressRevision &+= 1
        } catch {
            self.loadErrorMessage = "Không thể đọc dữ liệu lưu trữ: \(error.localizedDescription)"
        }
    }

    func completeOnboarding(license: LicenseClass, era: ExamRegulationEra, targetDate: Date?) {
        currentLicense = license
        currentRegulationEra = era
        targetExamDate = targetDate
        hasCompletedOnboarding = true

        let record = ensureSettingsRecord()
        record.selectedLicenseCode = license.rawValue
        record.regulationEraRaw = era.rawValue
        record.targetExamDate = targetDate
        record.hasCompletedOnboarding = true
        saveContext()
    }

    func resetAllProgress() {
        if let modelContext {
            do {
                let progressRecords = try modelContext.fetch(FetchDescriptor<QuestionProgressRecord>())
                for record in progressRecords {
                    modelContext.delete(record)
                }
                let examRecords = try modelContext.fetch(FetchDescriptor<ExamAttemptRecord>())
                for record in examRecords {
                    modelContext.delete(record)
                }
            } catch {
                loadErrorMessage = "Không thể đặt lại tiến độ: \(error.localizedDescription)"
            }
        }

        progressByQuestionID = [:]
        examHistory = []
        studyStreakDays = 0
        dailyFreeExamsUsed = 0
        dailyFreeAIUsed = 0

        if let record = settingsRecord {
            record.studyStreakDays = 0
            record.lastStudyDayStamp = ""
            record.dailyFreeExamsUsed = 0
            record.dailyFreeAIUsed = 0
            record.quotaDayStamp = Self.dayStamp(for: .now)
        }

        saveContext()
        progressRevision &+= 1
    }

    // MARK: - Questions & Progress

    func questions(inChapter chapter: Int) -> [Question] {
        questions.filter { $0.chapter == chapter }
    }

    func searchQuestions(query: String) -> [Question] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return questions }

        let normalizedQuery = Self.foldForSearch(trimmed)
        let numericDigits = trimmed.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let exactID = Int(numericDigits)

        return questions.filter { question in
            if let exactID, question.id == exactID {
                return true
            }
            if Self.foldForSearch(question.text).contains(normalizedQuery) {
                return true
            }
            if Self.foldForSearch(question.explanation).contains(normalizedQuery) {
                return true
            }
            if let signCode = question.signCode, Self.foldForSearch(signCode).contains(normalizedQuery) {
                return true
            }
            return question.options.contains { Self.foldForSearch($0).contains(normalizedQuery) }
        }
    }

    func progress(for questionID: Int) -> QuestionProgressRecord? {
        _ = progressRevision
        return progressByQuestionID[questionID]
    }

    func isBookmarked(_ questionID: Int) -> Bool {
        _ = progressRevision
        return progressByQuestionID[questionID]?.isBookmarked ?? false
    }

    func toggleBookmark(questionID: Int) {
        let record = ensureProgressRecord(for: questionID)
        record.isBookmarked.toggle()
        saveContext()
        progressRevision &+= 1
    }

    func recordStudyAnswer(question: Question, selectedIndex: Int) {
        let record = ensureProgressRecord(for: question.id)
        applyAnswer(selectedIndex, to: question, record: record)
        recordStudyActivityToday()
        saveContext()
        progressRevision &+= 1
    }

    func chapterProgress(chapter: Int) -> (answered: Int, correct: Int, total: Int) {
        _ = progressRevision
        let chapterQuestions = questions.filter { $0.chapter == chapter }
        var answered = 0
        var correct = 0
        for q in chapterQuestions {
            if let rec = progressByQuestionID[q.id] {
                if rec.attemptsCount > 0 { answered += 1 }
                if rec.lastAnsweredCorrectly { correct += 1 }
            }
        }
        return (answered: answered, correct: correct, total: chapterQuestions.count)
    }

    // MARK: - Traffic Signs

    func signs(in category: TrafficSignCategory? = nil) -> [TrafficSign] {
        guard let category else { return signs }
        return signs.filter { $0.category == category }
    }

    func searchSigns(query: String, category: TrafficSignCategory? = nil) -> [TrafficSign] {
        let pool = signs(in: category)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return pool }

        let normalizedQuery = Self.foldForSearch(trimmed)
        return pool.filter { sign in
            if Self.foldForSearch(sign.code).contains(normalizedQuery) { return true }
            if Self.foldForSearch(sign.name).contains(normalizedQuery) { return true }
            if Self.foldForSearch(sign.summary).contains(normalizedQuery) { return true }
            return sign.keywords.contains { Self.foldForSearch($0).contains(normalizedQuery) }
        }
    }

    func relatedQuestions(for sign: TrafficSign) -> [Question] {
        let inActivePool = collectRelatedQuestions(for: sign, pool: questions, lookup: questionByID)
        if !inActivePool.isEmpty {
            return inActivePool
        }
        return collectRelatedQuestions(for: sign, pool: rawBankQuestions, lookup: rawQuestionByID)
            .map { $0.adapted(for: currentLicense) }
    }

    func questionsForAttempt(_ attempt: ExamAttemptRecord) -> [Question] {
        let attemptLicense = LicenseClass(rawValue: attempt.licenseCode) ?? currentLicense
        return attempt.questionIDs.compactMap { qID in
            rawQuestionByID[qID]?.adapted(for: attemptLicense)
        }
    }

    private func collectRelatedQuestions(
        for sign: TrafficSign,
        pool: [Question],
        lookup: [Int: Question]
    ) -> [Question] {
        var seen: Set<Int> = []
        var result: [Question] = []

        for qID in sign.relatedQuestionIDs {
            if !seen.contains(qID), let question = lookup[qID] {
                seen.insert(qID)
                result.append(question)
            }
        }

        let targetCode = sign.code.uppercased()
        for question in pool {
            if let qCode = question.signCode?.uppercased(),
               qCode == targetCode,
               !seen.contains(question.id) {
                seen.insert(question.id)
                result.append(question)
            }
        }

        return result
    }

    // MARK: - Exam Generation & Grading

    func generateRandomExam() -> [Question] {
        var rng = SystemRandomNumberGenerator()
        return buildStructuredExam(structure: currentExamStructure, using: &rng)
    }

    func generateFixedExam(setNumber: Int) -> [Question] {
        let structure = currentExamStructure
        let licenseSeed = UInt64(abs(structure.licenseClass.rawValue.hashValue))
        let eraSeed: UInt64 = structure.is2027Rule ? 2027 : 2026
        let seed = UInt64(max(1, setNumber)) &* 0x9E37_79B9_7F4A_7C15 ^ licenseSeed ^ eraSeed
        var rng = SeededGenerator(seed: seed)
        return buildStructuredExam(structure: structure, using: &rng)
    }

    func generateCriticalDrillExam() -> [Question] {
        criticalQuestions.sorted { $0.id < $1.id }
    }

    @discardableResult
    func saveExamAttempt(
        title: String,
        questions: [Question],
        selectedAnswers: [Int: Int],
        flaggedIDs: [Int],
        durationUsedSeconds: Int,
        structure: ExamStructure
    ) -> ExamAttemptRecord {
        var correctCount = 0
        var failedByCritical = false

        for question in questions {
            let selected = selectedAnswers[question.id]
            let isCorrect = (selected == question.correctIndex)
            if isCorrect {
                correctCount += 1
            } else if question.isCritical {
                // Sai hoặc bỏ trống câu điểm liệt đều trượt ngay lập tức.
                failedByCritical = true
            }

            if let selected {
                let record = ensureProgressRecord(for: question.id)
                applyAnswer(selected, to: question, record: record)
            }
        }

        let passed = !failedByCritical && (correctCount >= structure.passScore)

        let attempt = ExamAttemptRecord(
            createdAt: .now,
            licenseCode: structure.licenseClass.rawValue,
            is2027Rule: structure.is2027Rule,
            examTitle: title,
            totalQuestions: questions.count,
            correctCount: correctCount,
            passScore: structure.passScore,
            failedByCritical: failedByCritical,
            passed: passed,
            durationUsedSeconds: max(0, durationUsedSeconds),
            questionIDs: questions.map(\.id),
            flaggedIDs: flaggedIDs,
            selectedAnswers: selectedAnswers
        )

        modelContext?.insert(attempt)
        examHistory.insert(attempt, at: 0)
        recordStudyActivityToday()
        saveContext()
        progressRevision &+= 1
        return attempt
    }

    // MARK: - Freemium Quota

    func canStartExam(isPremium: Bool) -> Bool {
        true
    }

    func consumeFreeExamQuotaIfNeeded(isPremium: Bool) {}

    func canUseAIExplanation(isPremium: Bool) -> Bool {
        true
    }

    func consumeFreeAIQuotaIfNeeded(isPremium: Bool) {}

    // MARK: - AI Tutor & Smart Study Roadmap

    func generateAITutorExplanation(for question: Question) -> AITutorExplanation {
        let chapterInfo = ChapterInfo.allChapters.first { $0.id == question.chapter }
        let chapterName = chapterInfo?.shortTitle ?? "Chương \(question.chapter)"
        let headline: String
        if question.isCritical {
            headline = "Câu điểm liệt — \(chapterName) (sai hoặc bỏ trống sẽ trượt bài thi)"
        } else {
            headline = "Phân tích chuyên sâu — \(chapterName)"
        }

        let coreRule: String
        if let signCode = question.signCode, let sign = signByCode[signCode.uppercased()] {
            coreRule = "\(question.explanation) (Liên quan biển \(sign.code) — \(sign.name): \(sign.legalDetail))"
        } else {
            coreRule = question.explanation
        }

        let breakdown: [String] = question.options.enumerated().map { index, optionText in
            let prefix = "Phương án \(index + 1)"
            if index == question.correctIndex {
                return "✓ \(prefix) ĐÚNG: \"\(optionText)\" — Đáp ứng chính xác quy tắc an toàn và quy định trong câu hỏi."
            } else {
                return "✕ \(prefix) SAI: \"\(optionText)\" — Không đúng quy định hoặc tiềm ẩn nguy cơ mất an toàn giao thông trong tình huống này."
            }
        }

        let realWorldScenario: String
        switch question.chapter {
        case 1:
            realWorldScenario = "Khi lưu thông thực tế trên đường bộ Việt Nam, quy tắc này giúp phòng tránh xung đột giao thông và tránh mức phạt nguội hoặc tước GPLX theo Nghị định xử phạt hiện hành."
        case 2:
            realWorldScenario = "Trong tình huống khẩn cấp hoặc văn hóa ứng xử trên đường, giữ bình tĩnh, ưu tiên tính mạng con người và tuân thủ quy trình cứu hộ luôn là nguyên tắc hàng đầu."
        case 3:
            realWorldScenario = "Trên các cung đường đèo dốc, trời mưa trơn trượt hoặc giao lộ đông đúc, thao tác chân phanh/số đúng kỹ thuật giúp giữ kiểm soát xe ổn định."
        case 4:
            realWorldScenario = "Kiểm tra nhanh tình trạng lốp, hệ thống phanh và đèn báo táp-lô trước mỗi chuyến đi dài giúp ngăn ngừa sự cố kỹ thuật giữa đường."
        case 5:
            realWorldScenario = "Khi quan sát biển báo ngoài thực tế, cần đọc từ xa kết hợp biển phụ phía dưới và vạch kẻ đường để chuyển làn hoặc giảm tốc kịp thời."
        default:
            realWorldScenario = "Khi qua ngã tư hoặc vòng xuyến, áp dụng tuần tự: xe đã vào giao lộ → xe ưu tiên → đường ưu tiên → hướng bên phải trống để xử lý nhanh trong vài giây."
        }

        let memoryAnchor = question.tip.isEmpty
            ? "Ghi nhớ từ khóa cốt lõi trong đáp án đúng và loại trừ phương án có yếu tố thiếu an toàn."
            : question.tip

        return AITutorExplanation(
            headline: headline,
            coreRule: coreRule,
            optionBreakdown: breakdown,
            realWorldScenario: realWorldScenario,
            memoryAnchor: memoryAnchor
        )
    }

    func buildSmartStudyRoadmap() -> [SmartStudyRecommendation] {
        _ = progressRevision
        var recommendations: [SmartStudyRecommendation] = []

        let currentWrong = wrongQuestions
        if !currentWrong.isEmpty {
            recommendations.append(
                SmartStudyRecommendation(
                    id: "smart_wrong",
                    title: "Xử lý \(currentWrong.count) câu hay sai",
                    subtitle: "Ôn lại các câu bạn trả lời sai gần đây để xóa điểm yếu trước ngày thi.",
                    badge: "Ưu tiên cao",
                    targetQuestions: Array(currentWrong.prefix(30))
                )
            )
        }

        let unmasteredCritical = criticalQuestions.filter {
            progressByQuestionID[$0.id]?.lastAnsweredCorrectly != true
        }
        if !unmasteredCritical.isEmpty {
            recommendations.append(
                SmartStudyRecommendation(
                    id: "smart_critical",
                    title: "Hoàn thành \(unmasteredCritical.count) câu điểm liệt chưa vững",
                    subtitle: "Nắm chắc toàn bộ \(criticalQuestions.count) câu điểm liệt để không bị đánh trượt đáng tiếc.",
                    badge: "Điểm liệt",
                    targetQuestions: Array(unmasteredCritical.prefix(30))
                )
            )
        }

        let due = dueForReviewQuestions
        if !due.isEmpty {
            recommendations.append(
                SmartStudyRecommendation(
                    id: "smart_due",
                    title: "Ôn tập ngắt quãng (\(due.count) câu đến hạn)",
                    subtitle: "Lặp lại đúng thời điểm giúp ghi nhớ bền vững bộ \(questions.count) câu hạng \(currentLicense.code).",
                    badge: "Đến hạn",
                    targetQuestions: Array(due.prefix(25))
                )
            )
        }

        let availableChapters = ChapterInfo.allChapters.filter { chapterProgress(chapter: $0.id).total > 0 }
        if let weakestChapter = availableChapters.min(by: { lhs, rhs in
            let lp = chapterProgress(chapter: lhs.id)
            let rp = chapterProgress(chapter: rhs.id)
            let lr = lp.total > 0 ? Double(lp.correct) / Double(lp.total) : 0
            let rr = rp.total > 0 ? Double(rp.correct) / Double(rp.total) : 0
            return lr < rr
        }) {
            let chapterPool = questions(inChapter: weakestChapter.id)
            let unmasteredInWeakest = chapterPool.filter {
                progressByQuestionID[$0.id]?.lastAnsweredCorrectly != true
            }
            let target = unmasteredInWeakest.isEmpty ? chapterPool : unmasteredInWeakest
            if !target.isEmpty {
                let stats = chapterProgress(chapter: weakestChapter.id)
                recommendations.append(
                    SmartStudyRecommendation(
                        id: "smart_chapter_\(weakestChapter.id)",
                        title: "Củng cố Chương \(weakestChapter.id): \(weakestChapter.shortTitle)",
                        subtitle: "Đã vững \(stats.correct)/\(stats.total) câu — luyện thêm để nâng tỷ lệ đạt.",
                        badge: "Theo chương",
                        targetQuestions: Array(target.prefix(30))
                    )
                )
            }
        }

        if recommendations.isEmpty && !questions.isEmpty {
            recommendations.append(
                SmartStudyRecommendation(
                    id: "smart_maintenance",
                    title: "Duy trì phong độ toàn bộ \(questions.count) câu",
                    subtitle: "Bạn đã nắm rất tốt kiến thức, hãy ôn nhanh 30 câu tổng hợp.",
                    badge: "Duy trì",
                    targetQuestions: Array(questions.shuffled().prefix(30))
                )
            )
        }

        return recommendations
    }

    func reloadBundledContent() {
        loadBundledContent()
        progressRevision &+= 1
    }

    // MARK: - Private Helpers

    private func loadBundledContent() {
        var errors: [String] = []

        if let loadedQuestions = loadBundleJSON([Question].self, resourceName: "questions_600") {
            let sorted = loadedQuestions.sorted { $0.id < $1.id }
            self.rawBankQuestions = sorted
            self.rawQuestionByID = Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0) })
            applyLicenseFilter()
        } else {
            errors.append("Không tìm thấy hoặc không đọc được questions_600.json")
        }

        if let loadedSigns = loadBundleJSON([TrafficSign].self, resourceName: "traffic_signs") {
            self.signs = loadedSigns
            var lookup: [String: TrafficSign] = [:]
            for sign in loadedSigns {
                lookup[sign.code.uppercased()] = sign
            }
            self.signByCode = lookup
        } else {
            errors.append("Không tìm thấy hoặc không đọc được traffic_signs.json")
        }

        self.loadErrorMessage = errors.isEmpty ? nil : errors.joined(separator: "\n")
    }

    private func applyLicenseFilter() {
        let filtered: [Question]
        switch currentLicense {
        case .A1, .A:
            filtered = rawBankQuestions.filter(\.inA1Pool)
        case .B1:
            filtered = rawBankQuestions.filter(\.inB1Pool)
        default:
            filtered = rawBankQuestions
        }

        let adapted = filtered.map { $0.adapted(for: currentLicense) }
        self.questions = adapted
        self.questionByID = Dictionary(uniqueKeysWithValues: adapted.map { ($0.id, $0) })
    }

    private func loadBundleJSON<T: Decodable>(_ type: T.Type, resourceName: String) -> T? {
        let decoder = JSONDecoder()

        var seenBundles: Set<ObjectIdentifier> = []
        let allCandidateBundles = ([Bundle.main, Bundle(for: CarCoachRepository.self)] + Bundle.allBundles + Bundle.allFrameworks).filter {
            seenBundles.insert(ObjectIdentifier($0)).inserted
        }

        // Tầng 1: Multi-Bundle JSON (root và subdirectory "Resources")
        for bundle in allCandidateBundles {
            let urls = [
                bundle.url(forResource: resourceName, withExtension: "json"),
                bundle.url(forResource: resourceName, withExtension: "json", subdirectory: "Resources")
            ].compactMap { $0 }

            for url in urls {
                if let data = try? Data(contentsOf: url),
                   let decoded = try? decoder.decode(T.self, from: data) {
                    return decoded
                }
            }
        }

        // Tầng 2: NSDataAsset trong Asset Catalog (hữu ích cho Xcode Previews / app thinning)
        var seenAssetBundles: Set<ObjectIdentifier> = []
        let assetBundles = ([Bundle.main, Bundle(for: CarCoachRepository.self)] + Bundle.allBundles).filter {
            seenAssetBundles.insert(ObjectIdentifier($0)).inserted
        }
        for bundle in assetBundles {
            if let asset = NSDataAsset(name: resourceName, bundle: bundle),
               let decoded = try? decoder.decode(T.self, from: asset.data) {
                return decoded
            }
        }

        // Tầng 3: Fallback từ mã nguồn khi chạy Debug / Previews trên máy phát triển
        #if DEBUG
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/\(resourceName).json")
        if let data = try? Data(contentsOf: sourceURL),
           let decoded = try? decoder.decode(T.self, from: data) {
            return decoded
        }
        #endif

        // Tầng 4: Dữ liệu nhúng nén RFC-1951 deflate trong mã nguồn Swift
        if let embeddedData = EmbeddedContentData.jsonData(for: resourceName),
           let decoded = try? decoder.decode(T.self, from: embeddedData) {
            return decoded
        }

        return nil
    }

    private func buildStructuredExam<R: RandomNumberGenerator>(
        structure: ExamStructure,
        using rng: inout R
    ) -> [Question] {
        guard !questions.isEmpty else { return [] }

        let criticalPool = questions.filter(\.isCritical).shuffled(using: &rng)
        let selectedCritical = Array(criticalPool.prefix(structure.criticalQuestionCount))
        let selectedCriticalIDs = Set(selectedCritical.map(\.id))

        // Đếm số câu điểm liệt đã lấy theo từng chương để trừ vào chỉ tiêu chương tương ứng.
        var criticalCountByChapter: [Int: Int] = [:]
        for q in selectedCritical {
            criticalCountByChapter[q.chapter, default: 0] += 1
        }

        var selectedNonCritical: [Question] = []
        var usedIDs = selectedCriticalIDs

        for chapter in 1...6 {
            let desiredTotalForChapter = structure.chapterQuotas[chapter] ?? 0
            let alreadyCritical = criticalCountByChapter[chapter] ?? 0
            let neededRegular = max(0, desiredTotalForChapter - alreadyCritical)
            guard neededRegular > 0 else { continue }

            let candidates = questions
                .filter { $0.chapter == chapter && !$0.isCritical && !usedIDs.contains($0.id) }
                .shuffled(using: &rng)
            let picked = Array(candidates.prefix(neededRegular))
            selectedNonCritical.append(contentsOf: picked)
            for q in picked {
                usedIDs.insert(q.id)
            }
        }

        let targetCount = min(structure.totalQuestions, questions.count)
        let remainingNeeded = targetCount - (selectedCritical.count + selectedNonCritical.count)
        if remainingNeeded > 0 {
            let fallbackRegular = questions
                .filter { !$0.isCritical && !usedIDs.contains($0.id) }
                .shuffled(using: &rng)
            let extra = Array(fallbackRegular.prefix(remainingNeeded))
            selectedNonCritical.append(contentsOf: extra)
            for q in extra {
                usedIDs.insert(q.id)
            }
        }

        // Trộn ngẫu nhiên câu điểm liệt vào đề thi thực tế.
        let combined = (selectedCritical + selectedNonCritical).prefix(targetCount)
        return Array(combined).shuffled(using: &rng)
    }

    private func ensureProgressRecord(for questionID: Int) -> QuestionProgressRecord {
        if let existing = progressByQuestionID[questionID] {
            return existing
        }
        let created = QuestionProgressRecord(questionID: questionID)
        progressByQuestionID[questionID] = created
        modelContext?.insert(created)
        return created
    }

    private func ensureSettingsRecord() -> UserSettingsRecord {
        if let existing = settingsRecord {
            return existing
        }
        let created = UserSettingsRecord(
            selectedLicenseCode: currentLicense.rawValue,
            regulationEraRaw: currentRegulationEra.rawValue,
            appearanceModeRaw: currentAppearanceMode.rawValue,
            targetExamDate: targetExamDate
        )
        created.hasCompletedOnboarding = hasCompletedOnboarding
        settingsRecord = created
        modelContext?.insert(created)
        return created
    }

    private func syncSettingsFromRecord(_ record: UserSettingsRecord) {
        hasCompletedOnboarding = record.hasCompletedOnboarding
        currentLicense = LicenseClass(rawValue: record.selectedLicenseCode) ?? .B
        currentRegulationEra = ExamRegulationEra(rawValue: record.regulationEraRaw) ?? .auto
        currentAppearanceMode = AppAppearanceMode(rawValue: record.appearanceModeRaw) ?? .system
        targetExamDate = record.targetExamDate
        studyStreakDays = record.studyStreakDays
        dailyFreeExamsUsed = record.dailyFreeExamsUsed
        dailyFreeAIUsed = record.dailyFreeAIUsed
        applyLicenseFilter()
    }

    private func applyAnswer(_ selectedIndex: Int, to question: Question, record: QuestionProgressRecord) {
        let isCorrect = (selectedIndex == question.correctIndex)
        record.selectedAnswerIndex = selectedIndex
        record.attemptsCount += 1
        record.lastStudiedAt = .now

        if isCorrect {
            record.correctCount += 1
            record.lastAnsweredCorrectly = true
            let intervalDays = min(14, max(1, record.correctCount * 2))
            record.nextReviewAt = Calendar.current.date(byAdding: .day, value: intervalDays, to: .now)
        } else {
            record.wrongCount += 1
            record.lastAnsweredCorrectly = false
            record.nextReviewAt = Calendar.current.date(byAdding: .hour, value: 4, to: .now)
        }
    }

    private func recordStudyActivityToday() {
        let today = Self.dayStamp(for: .now)
        let record = ensureSettingsRecord()
        guard record.lastStudyDayStamp != today else { return }

        let yesterdayDate = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        let yesterday = Self.dayStamp(for: yesterdayDate)
        if record.lastStudyDayStamp == yesterday {
            studyStreakDays = max(1, studyStreakDays + 1)
        } else {
            studyStreakDays = 1
        }
        record.studyStreakDays = studyStreakDays
        record.lastStudyDayStamp = today
    }

    private func refreshQuotaDayIfNeeded(saveIfChanged: Bool) {
        let today = Self.dayStamp(for: .now)
        guard let record = settingsRecord else { return }
        if record.quotaDayStamp != today {
            record.quotaDayStamp = today
            record.dailyFreeExamsUsed = 0
            record.dailyFreeAIUsed = 0
            dailyFreeExamsUsed = 0
            dailyFreeAIUsed = 0
            if saveIfChanged {
                saveContext()
            }
        }
    }

    private func saveContext() {
        guard let modelContext else { return }
        try? modelContext.save()
    }

    private static func dayStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func foldForSearch(_ text: String) -> String {
        text
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "d")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x1234_5678_9ABC_DEF0 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
