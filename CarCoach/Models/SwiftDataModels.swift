import Foundation
import SwiftData

@Model
final class QuestionProgressRecord {
    var questionID: Int = 0
    var selectedAnswerIndex: Int?
    var attemptsCount: Int = 0
    var correctCount: Int = 0
    var wrongCount: Int = 0
    var lastAnsweredCorrectly: Bool = false
    var isBookmarked: Bool = false
    var lastStudiedAt: Date?
    var nextReviewAt: Date?

    init(
        questionID: Int,
        selectedAnswerIndex: Int? = nil,
        attemptsCount: Int = 0,
        correctCount: Int = 0,
        wrongCount: Int = 0,
        lastAnsweredCorrectly: Bool = false,
        isBookmarked: Bool = false,
        lastStudiedAt: Date? = nil,
        nextReviewAt: Date? = nil
    ) {
        self.questionID = questionID
        self.selectedAnswerIndex = selectedAnswerIndex
        self.attemptsCount = attemptsCount
        self.correctCount = correctCount
        self.wrongCount = wrongCount
        self.lastAnsweredCorrectly = lastAnsweredCorrectly
        self.isBookmarked = isBookmarked
        self.lastStudiedAt = lastStudiedAt
        self.nextReviewAt = nextReviewAt
    }
}

@Model
final class ExamAttemptRecord {
    var attemptID: UUID = UUID()
    var createdAt: Date = Date()
    var licenseCode: String = "B"
    var is2027Rule: Bool = false
    var examTitle: String = ""
    var totalQuestions: Int = 0
    var correctCount: Int = 0
    var passScore: Int = 0
    var failedByCritical: Bool = false
    var passed: Bool = false
    var durationUsedSeconds: Int = 0
    var questionIDs: [Int] = []
    var flaggedIDs: [Int] = []
    var answersJSON: String = "{}"

    init(
        attemptID: UUID = UUID(),
        createdAt: Date = .now,
        licenseCode: String,
        is2027Rule: Bool,
        examTitle: String,
        totalQuestions: Int,
        correctCount: Int,
        passScore: Int,
        failedByCritical: Bool,
        passed: Bool,
        durationUsedSeconds: Int,
        questionIDs: [Int],
        flaggedIDs: [Int],
        selectedAnswers: [Int: Int]
    ) {
        self.attemptID = attemptID
        self.createdAt = createdAt
        self.licenseCode = licenseCode
        self.is2027Rule = is2027Rule
        self.examTitle = examTitle
        self.totalQuestions = totalQuestions
        self.correctCount = correctCount
        self.passScore = passScore
        self.failedByCritical = failedByCritical
        self.passed = passed
        self.durationUsedSeconds = durationUsedSeconds
        self.questionIDs = questionIDs
        self.flaggedIDs = flaggedIDs
        self.answersJSON = Self.encodeAnswers(selectedAnswers)
    }

    var answersMap: [Int: Int] {
        Self.decodeAnswers(answersJSON)
    }

    static func encodeAnswers(_ map: [Int: Int]) -> String {
        let stringKeyed = Dictionary(uniqueKeysWithValues: map.map { (String($0.key), $0.value) })
        guard let data = try? JSONEncoder().encode(stringKeyed),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    static func decodeAnswers(_ json: String) -> [Int: Int] {
        guard let data = json.data(using: .utf8) else { return [:] }
        if let stringKeyed = try? JSONDecoder().decode([String: Int].self, from: data) {
            var result: [Int: Int] = [:]
            result.reserveCapacity(stringKeyed.count)
            for (key, value) in stringKeyed {
                if let intKey = Int(key) {
                    result[intKey] = value
                }
            }
            return result
        }
        if let intKeyed = try? JSONDecoder().decode([Int: Int].self, from: data) {
            return intKeyed
        }
        return [:]
    }
}

@Model
final class UserSettingsRecord {
    var singletonKey: String = "default"
    var hasCompletedOnboarding: Bool = false
    var selectedLicenseCode: String = "B"
    var regulationEraRaw: String = ExamRegulationEra.auto.rawValue
    var appearanceModeRaw: String = AppAppearanceMode.system.rawValue
    var targetExamDate: Date?
    var studyStreakDays: Int = 0
    var lastStudyDayStamp: String = ""
    var dailyFreeExamsUsed: Int = 0
    var dailyFreeAIUsed: Int = 0
    var quotaDayStamp: String = ""

    init(
        singletonKey: String = "default",
        hasCompletedOnboarding: Bool = false,
        selectedLicenseCode: String = LicenseClass.B.rawValue,
        regulationEraRaw: String = ExamRegulationEra.auto.rawValue,
        appearanceModeRaw: String = AppAppearanceMode.system.rawValue,
        targetExamDate: Date? = nil,
        studyStreakDays: Int = 0,
        lastStudyDayStamp: String = "",
        dailyFreeExamsUsed: Int = 0,
        dailyFreeAIUsed: Int = 0,
        quotaDayStamp: String = ""
    ) {
        self.singletonKey = singletonKey
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.selectedLicenseCode = selectedLicenseCode
        self.regulationEraRaw = regulationEraRaw
        self.appearanceModeRaw = appearanceModeRaw
        self.targetExamDate = targetExamDate
        self.studyStreakDays = studyStreakDays
        self.lastStudyDayStamp = lastStudyDayStamp
        self.dailyFreeExamsUsed = dailyFreeExamsUsed
        self.dailyFreeAIUsed = dailyFreeAIUsed
        self.quotaDayStamp = quotaDayStamp
    }
}
