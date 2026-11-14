import Foundation
import SwiftData
import SwiftUI

enum ExamFormatters {
    static func formatDuration(_ totalSeconds: Int) -> String {
        let clamped = max(0, totalSeconds)
        let minutes = clamped / 60
        let seconds = clamped % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct ExamResultView: View {
    enum ReviewFilter: String, CaseIterable, Identifiable {
        case all = "Tất cả"
        case wrong = "Câu sai"
        case critical = "Điểm liệt"
        case flagged = "Xem lại"

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss

    let attempt: ExamAttemptRecord
    let questions: [Question]
    let repository: CarCoachRepository
    let storeManager: StoreKitManager
    let onPresentPaywall: () -> Void
    let onRetake: () -> Void

    @State private var selectedFilter: ReviewFilter = .all
    @State private var aiExplanations: [Int: AITutorExplanation] = [:]

    init(
        attempt: ExamAttemptRecord,
        questions: [Question],
        repository: CarCoachRepository,
        storeManager: StoreKitManager,
        onPresentPaywall: @escaping () -> Void,
        onRetake: @escaping () -> Void
    ) {
        self.attempt = attempt
        self.questions = questions
        self.repository = repository
        self.storeManager = storeManager
        self.onPresentPaywall = onPresentPaywall
        self.onRetake = onRetake
    }

    private var answersMap: [Int: Int] {
        attempt.answersMap
    }

    private var flaggedSet: Set<Int> {
        Set(attempt.flaggedIDs)
    }

    private var wrongCount: Int {
        questions.filter { isWrongOrUnanswered($0) }.count
    }

    private var unansweredCount: Int {
        questions.filter { answersMap[$0.id] == nil }.count
    }

    private var criticalWrongCount: Int {
        questions.filter { $0.isCritical && isWrongOrUnanswered($0) }.count
    }

    private var indexedQuestions: [(index: Int, question: Question)] {
        questions.enumerated().compactMap { idx, question in
            switch selectedFilter {
            case .all:
                return (idx, question)
            case .wrong:
                return isWrongOrUnanswered(question) ? (idx, question) : nil
            case .critical:
                return question.isCritical ? (idx, question) : nil
            case .flagged:
                return flaggedSet.contains(question.id) ? (idx, question) : nil
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClaudeSpacing.lg) {
                verdictCard
                actionButtons
                filterBar
                reviewListSection
            }
            .padding(.horizontal, ClaudeSpacing.md)
            .padding(.top, ClaudeSpacing.sm)
            .padding(.bottom, ClaudeSpacing.section)
        }
        .background(ClaudePalette.canvas.ignoresSafeArea())
        .navigationTitle("Kết quả bài thi")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Đóng") {
                    dismiss()
                }
                .font(ClaudeTypography.nav)
            }
        }
    }

    // MARK: - Verdict Card

    private var verdictCard: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.md) {
            HStack(alignment: .top, spacing: ClaudeSpacing.sm) {
                VStack(alignment: .leading, spacing: ClaudeSpacing.xxs) {
                    Text(attempt.examTitle)
                        .font(ClaudeTypography.headingSM)
                        .foregroundStyle(ClaudePalette.textMuted)

                    Text(attempt.passed ? "ĐẠT" : "TRƯỢT")
                        .font(ClaudeTypography.display(40))
                        .foregroundStyle(attempt.passed ? ClaudePalette.correct : ClaudePalette.wrong)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: ClaudeSpacing.xxs) {
                    ClaudeBadge(
                        text: "Hạng \(attempt.licenseCode)",
                        tone: .dark
                    )
                    ClaudeBadge(
                        text: ruleBadgeLabel,
                        tone: .neutral
                    )
                }
            }

            if attempt.failedByCritical {
                HStack(alignment: .top, spacing: ClaudeSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ClaudePalette.wrong)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trượt do sai/bỏ trống câu điểm liệt — dù đạt đủ điểm tổng vẫn không đạt")
                            .font(ClaudeTypography.buttonStrong)
                            .foregroundStyle(ClaudePalette.wrong)
                            .fixedSize(horizontal: false, vertical: true)

                        if criticalWrongCount > 0 {
                            Text("Có \(criticalWrongCount) câu điểm liệt bị sai hoặc bỏ trống trong bài thi này.")
                                .font(ClaudeTypography.captionXS)
                                .foregroundStyle(ClaudePalette.wrong)
                        }
                    }
                }
                .padding(ClaudeSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                        .fill(ClaudePalette.wrongSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                        .stroke(ClaudePalette.wrong, lineWidth: 1.5)
                )
            }

            Divider()
                .overlay(ClaudePalette.hairline)

            HStack(spacing: ClaudeSpacing.sm) {
                statMetric(
                    title: "Điểm số",
                    value: "\(attempt.correctCount)/\(attempt.totalQuestions)",
                    detail: "Đạt từ \(attempt.passScore)"
                )
                statMetric(
                    title: "Thời gian",
                    value: ExamFormatters.formatDuration(attempt.durationUsedSeconds),
                    detail: "Đã dùng"
                )
                statMetric(
                    title: "Sai / Trống",
                    value: "\(wrongCount)",
                    detail: "\(unansweredCount) bỏ trống"
                )
            }
        }
        .claudeCard()
    }

    private func statMetric(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(ClaudeTypography.captionXS)
                .foregroundStyle(ClaudePalette.textMuted)
            Text(value)
                .font(ClaudeTypography.bodyXL)
                .monospacedDigit()
                .foregroundStyle(ClaudePalette.ink)
            Text(detail)
                .font(ClaudeTypography.captionXS)
                .foregroundStyle(ClaudePalette.textMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ClaudeSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                .fill(ClaudePalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                .stroke(ClaudePalette.hairline, lineWidth: 1)
        )
    }

    // MARK: - Actions & Filter

    private var actionButtons: some View {
        HStack(spacing: ClaudeSpacing.sm) {
            Button {
                onRetake()
            } label: {
                Label("Thi lại đề mới", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ClaudePrimaryButtonStyle())

            Button {
                dismiss()
            } label: {
                Text("Về phòng thi")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ClaudeSecondaryButtonStyle())
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ClaudeSpacing.xs) {
                ForEach(ReviewFilter.allCases) { filter in
                    let isSelected = selectedFilter == filter
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filterTitle(filter))
                            .font(ClaudeTypography.nav)
                            .foregroundStyle(isSelected ? ClaudePalette.canvas : ClaudePalette.inkPrimary)
                            .padding(.horizontal, ClaudeSpacing.sm)
                            .frame(minHeight: 44)
                            .background(
                                RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                                    .fill(isSelected ? ClaudePalette.ink : ClaudePalette.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                                    .stroke(isSelected ? ClaudePalette.ink : ClaudePalette.hairline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func filterTitle(_ filter: ReviewFilter) -> String {
        switch filter {
        case .all:
            return "Tất cả (\(questions.count))"
        case .wrong:
            return "Câu sai (\(wrongCount))"
        case .critical:
            let count = questions.filter(\.isCritical).count
            return "Điểm liệt (\(count))"
        case .flagged:
            let count = questions.filter { flaggedSet.contains($0.id) }.count
            return "Xem lại (\(count))"
        }
    }

    // MARK: - Review List

    private var reviewListSection: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.md) {
            if indexedQuestions.isEmpty {
                VStack(spacing: ClaudeSpacing.xs) {
                    Text("Không có câu hỏi nào trong mục lọc này")
                        .font(ClaudeTypography.buttonStrong)
                        .foregroundStyle(ClaudePalette.ink)
                    Text("Chọn bộ lọc khác để xem lại toàn bộ bài thi.")
                        .font(ClaudeTypography.bodySM)
                        .foregroundStyle(ClaudePalette.textMuted)
                }
                .frame(maxWidth: .infinity)
                .claudeCompactCard()
            } else {
                LazyVStack(spacing: ClaudeSpacing.md) {
                    ForEach(indexedQuestions, id: \.question.id) { item in
                        reviewQuestionCard(position: item.index + 1, question: item.question)
                    }
                }
            }
        }
    }

    private func reviewQuestionCard(position: Int, question: Question) -> some View {
        let userPick = answersMap[question.id]
        let isCorrect = userPick == question.correctIndex
        let isFlagged = flaggedSet.contains(question.id)

        return VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            HStack(spacing: ClaudeSpacing.xs) {
                ClaudeBadge(text: "Câu \(position) • #\(question.id)", tone: .dark)

                if userPick == nil {
                    ClaudeBadge(text: "Chưa trả lời", tone: .wrong)
                } else {
                    ClaudeBadge(
                        text: isCorrect ? "Đúng" : "Sai",
                        tone: isCorrect ? .correct : .wrong
                    )
                }

                if question.isCritical {
                    ClaudeBadge(text: "Điểm liệt", tone: .critical)
                }

                if isFlagged {
                    ClaudeBadge(text: "Xem lại", tone: .neutral)
                }

                Spacer()
            }

            Text(question.text)
                .font(ClaudeTypography.bodyMD)
                .fontWeight(.semibold)
                .foregroundStyle(ClaudePalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let diagram = question.diagram {
                QuestionDiagramCard(diagram: diagram, size: 156)
            }

            VStack(spacing: ClaudeSpacing.xs) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { idx, optionText in
                    QuestionOptionRow(
                        index: idx,
                        text: optionText,
                        state: reviewOptionState(
                            optionIndex: idx,
                            userPick: userPick,
                            correctIndex: question.correctIndex
                        ),
                        isInteractive: false
                    )
                }
            }

            VStack(alignment: .leading, spacing: ClaudeSpacing.xxs) {
                Text("Đáp án đúng: Số \(question.correctIndex + 1)")
                    .font(ClaudeTypography.captionXS)
                    .fontWeight(.semibold)
                    .foregroundStyle(ClaudePalette.correct)

                Text(question.explanation)
                    .font(ClaudeTypography.bodySM)
                    .foregroundStyle(ClaudePalette.inkPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if !question.tip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Mẹo: \(question.tip)")
                        .font(ClaudeTypography.captionXS)
                        .foregroundStyle(ClaudePalette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(ClaudeSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                    .fill(ClaudePalette.surface)
            )

            AITutorSectionView(
                question: question,
                explanation: aiExplanations[question.id],
                repository: repository,
                onGenerated: { explanation in
                    aiExplanations[question.id] = explanation
                }
            )
        }
        .claudeCompactCard(padding: ClaudeSpacing.md)
    }

    private func reviewOptionState(
        optionIndex: Int,
        userPick: Int?,
        correctIndex: Int
    ) -> OptionVisualState {
        if let userPick {
            if optionIndex == userPick {
                return userPick == correctIndex ? .correct : .wrong
            }
            if optionIndex == correctIndex {
                return .missedCorrect
            }
            return .normal
        }
        if optionIndex == correctIndex {
            return .missedCorrect
        }
        return .normal
    }

    private var ruleBadgeLabel: String {
        if let license = LicenseClass(rawValue: attempt.licenseCode), license.isMotorcycle {
            return "Chuẩn sát hạch Mô tô"
        }
        return attempt.is2027Rule ? "Từ 01/03/2027" : "Trước 01/03/2027"
    }

    private func isWrongOrUnanswered(_ question: Question) -> Bool {
        guard let picked = answersMap[question.id] else {
            return true
        }
        return picked != question.correctIndex
    }
}
