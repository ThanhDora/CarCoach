import Foundation
import SwiftData
import SwiftUI
import UIKit

// MARK: - Shared UI Helpers (Study & Exam)

enum OptionVisualState: Sendable {
    case normal
    case selected
    case correct
    case wrong
    case missedCorrect
}

struct QuestionOptionRow: View {
    let index: Int
    let text: String
    let state: OptionVisualState
    let isInteractive: Bool
    let action: (() -> Void)?

    init(
        index: Int,
        text: String,
        state: OptionVisualState,
        isInteractive: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.index = index
        self.text = text
        self.state = state
        self.isInteractive = isInteractive
        self.action = action
    }

    var body: some View {
        Group {
            if isInteractive, let action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: ClaudeSpacing.sm) {
            optionIndicator
                .padding(.top, 2)

            Text(text)
                .font(ClaudeTypography.bodyMD)
                .foregroundStyle(ClaudePalette.inkPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            trailingStatusIcon
        }
        .padding(.horizontal, ClaudeSpacing.md)
        .padding(.vertical, ClaudeSpacing.sm)
        .frame(minHeight: 52, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .contentShape(RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous))
    }

    @ViewBuilder
    private var optionIndicator: some View {
        Text("\(index + 1)")
            .font(ClaudeTypography.nav)
            .foregroundStyle(indicatorForeground)
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(indicatorBackground)
            )
            .overlay(
                Circle()
                    .stroke(indicatorBorder, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var trailingStatusIcon: some View {
        switch state {
        case .correct, .missedCorrect:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ClaudePalette.correct)
        case .wrong:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ClaudePalette.wrong)
        case .selected:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ClaudePalette.ink)
        case .normal:
            EmptyView()
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .normal:
            return ClaudePalette.canvas
        case .selected:
            return ClaudePalette.surfaceRaised
        case .correct:
            return ClaudePalette.correctSoft
        case .missedCorrect:
            return ClaudePalette.correctSoft.opacity(0.6)
        case .wrong:
            return ClaudePalette.wrongSoft
        }
    }

    private var borderColor: Color {
        switch state {
        case .normal:
            return ClaudePalette.hairline
        case .selected:
            return ClaudePalette.ink
        case .correct, .missedCorrect:
            return ClaudePalette.correct
        case .wrong:
            return ClaudePalette.wrong
        }
    }

    private var borderWidth: CGFloat {
        state == .normal ? 1 : 1.5
    }

    private var indicatorBackground: Color {
        switch state {
        case .normal:
            return ClaudePalette.surface
        case .selected:
            return ClaudePalette.ink
        case .correct, .missedCorrect:
            return ClaudePalette.correct
        case .wrong:
            return ClaudePalette.wrong
        }
    }

    private var indicatorForeground: Color {
        switch state {
        case .normal:
            return ClaudePalette.inkPrimary
        case .selected:
            return ClaudePalette.canvas
        case .correct, .missedCorrect, .wrong:
            return Color.white
        }
    }

    private var indicatorBorder: Color {
        switch state {
        case .normal:
            return ClaudePalette.borderStrong
        case .selected, .correct, .missedCorrect, .wrong:
            return .clear
        }
    }
}

struct QuestionDiagramCard: View {
    let diagram: DiagramSpec
    var size: CGFloat = 176

    var body: some View {
        VStack(spacing: ClaudeSpacing.sm) {
            DiagramCanvasView(spec: diagram, size: size)
                .frame(maxWidth: .infinity)

            if let caption = diagram.caption,
               !caption.isEmpty,
               diagram.kind.lowercased() != "sahinh" {
                Text(caption)
                    .font(ClaudeTypography.captionXS)
                    .foregroundStyle(ClaudePalette.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .claudeCompactCard(padding: ClaudeSpacing.md)
    }
}

struct AITutorSectionView: View {
    let question: Question
    let explanation: AITutorExplanation?
    let repository: CarCoachRepository
    let onGenerated: (AITutorExplanation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            HStack(spacing: ClaudeSpacing.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ClaudePalette.ink)

                Text("Giải thích sâu bằng AI")
                    .font(ClaudeTypography.buttonStrong)
                    .foregroundStyle(ClaudePalette.ink)

                Spacer()

                ClaudeBadge(
                    text: "AI Giải thích • Miễn phí",
                    tone: .correct
                )
            }

            if let ai = explanation {
                VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
                    Text(ai.headline)
                        .font(ClaudeTypography.bodyMD)
                        .fontWeight(.semibold)
                        .foregroundStyle(ClaudePalette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    aiBlock(title: "Nguyên tắc cốt lõi", body: ai.coreRule)

                    if !ai.optionBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: ClaudeSpacing.xxs) {
                            Text("Phân tích từng phương án")
                                .font(ClaudeTypography.headingSM)
                                .foregroundStyle(ClaudePalette.textMuted)

                            ForEach(Array(ai.optionBreakdown.enumerated()), id: \.offset) { _, line in
                                HStack(alignment: .top, spacing: ClaudeSpacing.xs) {
                                    Text("•")
                                        .font(ClaudeTypography.bodySM)
                                        .foregroundStyle(ClaudePalette.textMuted)
                                    Text(line)
                                        .font(ClaudeTypography.bodySM)
                                        .foregroundStyle(ClaudePalette.inkPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    aiBlock(title: "Tình huống thực tế", body: ai.realWorldScenario)

                    VStack(alignment: .leading, spacing: ClaudeSpacing.xxs) {
                        Text("Điểm neo ghi nhớ")
                            .font(ClaudeTypography.headingSM)
                            .foregroundStyle(ClaudePalette.textMuted)
                        Text(ai.memoryAnchor)
                            .font(ClaudeTypography.bodySM)
                            .fontWeight(.medium)
                            .foregroundStyle(ClaudePalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(ClaudeSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                            .fill(ClaudePalette.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                            .stroke(ClaudePalette.hairline, lineWidth: 1)
                    )
                }
                .padding(.top, ClaudeSpacing.xxs)
            } else {
                Text("Phân tích chi tiết căn cứ luật, lý do đúng/sai của từng lựa chọn và tình huống lái xe thực tế.")
                    .font(ClaudeTypography.bodySM)
                    .foregroundStyle(ClaudePalette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    let generated = repository.generateAITutorExplanation(for: question)
                    onGenerated(generated)
                } label: {
                    Label("Phân tích chuyên sâu câu này", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClaudeSecondaryButtonStyle())
            }
        }
        .claudeCompactCard(padding: ClaudeSpacing.md)
    }

    private func aiBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.xxs) {
            Text(title)
                .font(ClaudeTypography.headingSM)
                .foregroundStyle(ClaudePalette.textMuted)
            Text(body)
                .font(ClaudeTypography.bodySM)
                .foregroundStyle(ClaudePalette.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

enum QuestionGridStatus: Sendable {
    case unanswered
    case answered
    case correct
    case wrong
}

struct QuestionGridEntry: Identifiable, Sendable {
    let id: Int
    let questionNumber: Int
    let status: QuestionGridStatus
    let isCritical: Bool
    let isMarked: Bool
}

struct QuestionIndexGridSheet: View {
    enum GridFilter: String, CaseIterable, Identifiable {
        case all = "Tất cả"
        case unanswered = "Chưa làm"
        case marked = "Đánh dấu"
        case critical = "Điểm liệt"

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss

    let title: String
    let entries: [QuestionGridEntry]
    let currentIndex: Int
    let markedLegendLabel: String
    let showCriticalFilter: Bool
    let footerActionTitle: String?
    let onFooterAction: (() -> Void)?
    let onSelectIndex: (Int) -> Void

    @State private var selectedFilter: GridFilter = .all

    private var availableFilters: [GridFilter] {
        showCriticalFilter ? GridFilter.allCases : [.all, .unanswered, .marked]
    }

    private var filteredEntries: [QuestionGridEntry] {
        entries.filter { entry in
            switch selectedFilter {
            case .all:
                return true
            case .unanswered:
                return entry.status == .unanswered
            case .marked:
                return entry.isMarked
            case .critical:
                return entry.isCritical
            }
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: ClaudeSpacing.xs), count: 5)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ClaudeSpacing.xs) {
                            ForEach(availableFilters) { filter in
                                let isSelected = selectedFilter == filter
                                Button {
                                    selectedFilter = filter
                                } label: {
                                    Text(filterLabel(filter))
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
                        .padding(.horizontal, ClaudeSpacing.md)
                    }

                    legendRow
                        .padding(.horizontal, ClaudeSpacing.md)
                }
                .padding(.vertical, ClaudeSpacing.sm)
                .background(ClaudePalette.canvas)

                Divider()
                    .overlay(ClaudePalette.hairline)

                ScrollView {
                    if filteredEntries.isEmpty {
                        Text("Không có câu hỏi nào thuộc nhóm này.")
                            .font(ClaudeTypography.bodySM)
                            .foregroundStyle(ClaudePalette.textMuted)
                            .padding(ClaudeSpacing.xl)
                            .frame(maxWidth: .infinity)
                    } else {
                        LazyVGrid(columns: columns, spacing: ClaudeSpacing.xs) {
                            ForEach(filteredEntries) { entry in
                                gridCell(entry)
                            }
                        }
                        .padding(ClaudeSpacing.md)
                    }
                }
                .background(ClaudePalette.canvas)

                if let footerActionTitle, let onFooterAction {
                    VStack(spacing: 0) {
                        Divider()
                            .overlay(ClaudePalette.hairline)
                        Button {
                            dismiss()
                            onFooterAction()
                        } label: {
                            Text(footerActionTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ClaudePrimaryButtonStyle())
                        .padding(ClaudeSpacing.md)
                    }
                    .background(ClaudePalette.canvas)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") {
                        dismiss()
                    }
                    .font(ClaudeTypography.nav)
                }
            }
        }
    }

    private func filterLabel(_ filter: GridFilter) -> String {
        switch filter {
        case .all:
            return "Tất cả (\(entries.count))"
        case .unanswered:
            let count = entries.filter { $0.status == .unanswered }.count
            return "Chưa làm (\(count))"
        case .marked:
            let count = entries.filter(\.isMarked).count
            return "\(markedLegendLabel) (\(count))"
        case .critical:
            let count = entries.filter(\.isCritical).count
            return "Điểm liệt (\(count))"
        }
    }

    private var legendRow: some View {
        HStack(spacing: ClaudeSpacing.md) {
            if showCriticalFilter {
                legendDot(color: ClaudePalette.correct, text: "Đúng")
                legendDot(color: ClaudePalette.wrong, text: "Sai")
                legendDot(color: ClaudePalette.critical, text: "Điểm liệt")
            } else {
                legendDot(color: ClaudePalette.ink, text: "Đã chọn")
                legendDot(color: ClaudePalette.surfaceRaised, text: "Chưa làm")
                legendDot(color: ClaudePalette.critical, text: markedLegendLabel)
            }
            Spacer()
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(ClaudeTypography.captionXS)
                .foregroundStyle(ClaudePalette.textMuted)
        }
    }

    private func gridCell(_ entry: QuestionGridEntry) -> some View {
        let isCurrent = entry.id == currentIndex
        return Button {
            onSelectIndex(entry.id)
            dismiss()
        } label: {
            ZStack(alignment: .topTrailing) {
                Text("\(entry.questionNumber)")
                    .font(ClaudeTypography.nav)
                    .monospacedDigit()
                    .foregroundStyle(cellTextColor(entry.status))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                            .fill(cellBackground(entry.status))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                            .stroke(
                                isCurrent ? ClaudePalette.ink : cellBorder(entry),
                                lineWidth: isCurrent ? 2 : 1
                            )
                    )

                if entry.isMarked || (showCriticalFilter && entry.isCritical) {
                    Circle()
                        .fill(entry.isCritical && showCriticalFilter ? ClaudePalette.critical : ClaudePalette.ink)
                        .frame(width: 7, height: 7)
                        .padding(5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func cellBackground(_ status: QuestionGridStatus) -> Color {
        switch status {
        case .unanswered:
            return ClaudePalette.surface
        case .answered:
            return ClaudePalette.surfaceRaised
        case .correct:
            return ClaudePalette.correctSoft
        case .wrong:
            return ClaudePalette.wrongSoft
        }
    }

    private func cellTextColor(_ status: QuestionGridStatus) -> Color {
        switch status {
        case .unanswered:
            return ClaudePalette.textMuted
        case .answered:
            return ClaudePalette.ink
        case .correct:
            return ClaudePalette.correct
        case .wrong:
            return ClaudePalette.wrong
        }
    }

    private func cellBorder(_ entry: QuestionGridEntry) -> Color {
        switch entry.status {
        case .unanswered:
            return entry.isCritical && showCriticalFilter ? ClaudePalette.critical.opacity(0.6) : ClaudePalette.hairline
        case .answered:
            return ClaudePalette.borderStrong
        case .correct:
            return ClaudePalette.correct.opacity(0.5)
        case .wrong:
            return ClaudePalette.wrong.opacity(0.5)
        }
    }
}

// MARK: - QuestionPracticeView

struct QuestionPracticeView: View {
    let title: String
    let subtitle: String?
    let questions: [Question]
    let repository: CarCoachRepository
    let storeManager: StoreKitManager
    let onPresentPaywall: () -> Void

    @State private var currentIndex: Int = 0
    @State private var sessionSelections: [Int: Int] = [:]
    @State private var revealedQuestionIDs: Set<Int> = []
    @State private var aiExplanations: [Int: AITutorExplanation] = [:]
    @State private var showNavigatorSheet: Bool = false

    init(
        title: String,
        subtitle: String? = nil,
        questions: [Question],
        repository: CarCoachRepository,
        storeManager: StoreKitManager,
        onPresentPaywall: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.questions = questions
        self.repository = repository
        self.storeManager = storeManager
        self.onPresentPaywall = onPresentPaywall
    }

    var body: some View {
        Group {
            if questions.isEmpty {
                emptyStateView
            } else {
                practiceContent(for: questions[currentIndex])
            }
        }
        .background(ClaudePalette.canvas.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !questions.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNavigatorSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.grid.3x3")
                            Text("\(currentIndex + 1)/\(questions.count)")
                                .monospacedDigit()
                        }
                        .font(ClaudeTypography.nav)
                    }
                }
            }
        }
        .sheet(isPresented: $showNavigatorSheet) {
            QuestionIndexGridSheet(
                title: "Danh sách câu hỏi",
                entries: gridEntries,
                currentIndex: currentIndex,
                markedLegendLabel: "Đánh dấu",
                showCriticalFilter: true,
                footerActionTitle: nil,
                onFooterAction: nil,
                onSelectIndex: { newIndex in
                    currentIndex = newIndex
                }
            )
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: ClaudeSpacing.md) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(ClaudePalette.textMuted)

            Text("Chưa có câu hỏi trong mục này")
                .font(ClaudeTypography.headingSerifSM)
                .foregroundStyle(ClaudePalette.ink)
                .multilineTextAlignment(.center)

            Text("Các câu hỏi bạn làm sai, đánh dấu hoặc đến hạn ôn tập sẽ xuất hiện tại đây.")
                .font(ClaudeTypography.bodySM)
                .foregroundStyle(ClaudePalette.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(ClaudeSpacing.xl)
        .claudeCard()
        .padding(ClaudeSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func practiceContent(for question: Question) -> some View {
        let selectedIndex = sessionSelections[question.id]
        let isAnswered = selectedIndex != nil
        let isRevealed = isAnswered || revealedQuestionIDs.contains(question.id)
        let bookmarked = repository.isBookmarked(question.id)
        let savedProgress = repository.progress(for: question.id)

        return ScrollView {
            VStack(alignment: .leading, spacing: ClaudeSpacing.md) {
                progressHeader

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(ClaudeTypography.bodyXS)
                        .foregroundStyle(ClaudePalette.textMuted)
                }

                // Metadata & Bookmark bar
                HStack(alignment: .center, spacing: ClaudeSpacing.xs) {
                    ClaudeBadge(text: "Câu #\(question.id)", tone: .dark)
                    ClaudeBadge(text: "Chương \(question.chapter)", tone: .neutral)

                    if question.isCritical {
                        ClaudeBadge(text: "Điểm liệt", tone: .critical)
                    }

                    Spacer()

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        repository.toggleBookmark(questionID: question.id)
                    } label: {
                        Image(systemName: bookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(bookmarked ? ClaudePalette.ink : ClaudePalette.textMuted)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                                    .fill(ClaudePalette.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                                    .stroke(ClaudePalette.hairline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(bookmarked ? "Bỏ đánh dấu câu hỏi" : "Đánh dấu câu hỏi")
                }

                if selectedIndex == nil, let prev = savedProgress, prev.attemptsCount > 0 {
                    HStack(spacing: ClaudeSpacing.xs) {
                        Circle()
                            .fill(prev.lastAnsweredCorrectly ? ClaudePalette.correct : ClaudePalette.wrong)
                            .frame(width: 7, height: 7)
                        Text("Đã luyện \(prev.attemptsCount) lần • Gần nhất: \(prev.lastAnsweredCorrectly ? "Đúng" : "Sai")")
                            .font(ClaudeTypography.captionXS)
                            .foregroundStyle(ClaudePalette.textMuted)
                    }
                }

                // Question prompt
                Text(question.text)
                    .font(ClaudeTypography.bodyMD)
                    .fontWeight(.semibold)
                    .foregroundStyle(ClaudePalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, ClaudeSpacing.xxs)

                // Diagram if present
                if let diagram = question.diagram {
                    QuestionDiagramCard(diagram: diagram, size: 180)
                }

                // Answer Options
                VStack(spacing: ClaudeSpacing.xs) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { index, optionText in
                        QuestionOptionRow(
                            index: index,
                            text: optionText,
                            state: optionState(
                                optionIndex: index,
                                selectedIndex: selectedIndex,
                                correctIndex: question.correctIndex,
                                isRevealed: isRevealed
                            ),
                            isInteractive: !isAnswered
                        ) {
                            handleSelectOption(index, for: question)
                        }
                    }
                }

                if !isRevealed {
                    Button {
                        revealedQuestionIDs.insert(question.id)
                    } label: {
                        Text("Xem đáp án & giải thích")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClaudeSecondaryButtonStyle())
                }

                // Feedback + Explanation + Tip
                if isRevealed {
                    feedbackAndExplanationCard(
                        question: question,
                        selectedIndex: selectedIndex
                    )
                }

                // AI Deep Explanation Block
                AITutorSectionView(
                    question: question,
                    explanation: aiExplanations[question.id],
                    repository: repository,
                    onGenerated: { explanation in
                        aiExplanations[question.id] = explanation
                    }
                )
            }
            .padding(.horizontal, ClaudeSpacing.md)
            .padding(.top, ClaudeSpacing.sm)
            .padding(.bottom, ClaudeSpacing.xxl)
        }
        .safeAreaInset(edge: .bottom) {
            bottomNavigationBar
        }
    }

    private var progressHeader: some View {
        let ratio = questions.isEmpty ? 0 : Double(currentIndex + 1) / Double(questions.count)
        return VStack(alignment: .leading, spacing: ClaudeSpacing.xxs) {
            HStack {
                Text("Câu \(currentIndex + 1) / \(questions.count)")
                    .font(ClaudeTypography.headingSM)
                    .monospacedDigit()
                    .foregroundStyle(ClaudePalette.textMuted)
                Spacer()
                Text("\(Int((ratio * 100).rounded()))%")
                    .font(ClaudeTypography.captionXS)
                    .monospacedDigit()
                    .foregroundStyle(ClaudePalette.textMuted)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ClaudePalette.surfaceRaised)
                    Capsule()
                        .fill(ClaudePalette.ink)
                        .frame(width: max(6, proxy.size.width * ratio))
                }
            }
            .frame(height: 5)
        }
    }

    private func feedbackAndExplanationCard(question: Question, selectedIndex: Int?) -> some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            if let selectedIndex {
                let isCorrect = selectedIndex == question.correctIndex
                HStack(alignment: .top, spacing: ClaudeSpacing.xs) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isCorrect ? ClaudePalette.correct : ClaudePalette.wrong)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isCorrect ? "Chính xác" : "Chưa đúng — Đáp án đúng là số \(question.correctIndex + 1)")
                            .font(ClaudeTypography.buttonStrong)
                            .foregroundStyle(isCorrect ? ClaudePalette.correct : ClaudePalette.wrong)

                        if !isCorrect && question.isCritical {
                            Text("Lưu ý: Đây là câu điểm liệt — sai trong bài thi thật sẽ bị trượt ngay.")
                                .font(ClaudeTypography.captionXS)
                                .foregroundStyle(ClaudePalette.wrong)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(ClaudeSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                        .fill(isCorrect ? ClaudePalette.correctSoft : ClaudePalette.wrongSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                        .stroke((isCorrect ? ClaudePalette.correct : ClaudePalette.wrong).opacity(0.45), lineWidth: 1)
                )
            } else {
                ClaudeBadge(text: "Đáp án đúng: Số \(question.correctIndex + 1)", tone: .correct)
            }

            VStack(alignment: .leading, spacing: ClaudeSpacing.xs) {
                Text("Giải thích chi tiết")
                    .font(ClaudeTypography.headingSM)
                    .foregroundStyle(ClaudePalette.textMuted)
                Text(question.explanation)
                    .font(ClaudeTypography.bodySM)
                    .foregroundStyle(ClaudePalette.inkPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !question.tip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: ClaudeSpacing.xxs) {
                    Text("Mẹo ghi nhớ")
                        .font(ClaudeTypography.headingSM)
                        .foregroundStyle(ClaudePalette.textMuted)
                    Text(question.tip)
                        .font(ClaudeTypography.bodySM)
                        .foregroundStyle(ClaudePalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(ClaudeSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                        .fill(ClaudePalette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                        .stroke(ClaudePalette.hairline, lineWidth: 1)
                )
            }

            if selectedIndex != nil {
                Button {
                    sessionSelections.removeValue(forKey: question.id)
                    revealedQuestionIDs.remove(question.id)
                } label: {
                    Label("Chọn lại câu này", systemImage: "arrow.counterclockwise")
                        .font(ClaudeTypography.bodyXS)
                        .foregroundStyle(ClaudePalette.textMuted)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .claudeCompactCard(padding: ClaudeSpacing.md)
    }

    private var bottomNavigationBar: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(ClaudePalette.hairline)

            HStack(spacing: ClaudeSpacing.sm) {
                Button {
                    if currentIndex > 0 {
                        currentIndex -= 1
                    }
                } label: {
                    Label("Câu trước", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClaudeSecondaryButtonStyle())
                .disabled(currentIndex == 0)
                .opacity(currentIndex == 0 ? 0.45 : 1)

                Button {
                    showNavigatorSheet = true
                } label: {
                    Text("\(currentIndex + 1)/\(questions.count)")
                        .font(ClaudeTypography.nav)
                        .monospacedDigit()
                        .foregroundStyle(ClaudePalette.inkPrimary)
                        .padding(.horizontal, ClaudeSpacing.sm)
                        .frame(minWidth: 68, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                                .fill(ClaudePalette.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                                .stroke(ClaudePalette.hairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    if currentIndex < questions.count - 1 {
                        currentIndex += 1
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Câu tiếp")
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClaudePrimaryButtonStyle())
                .disabled(currentIndex >= questions.count - 1)
                .opacity(currentIndex >= questions.count - 1 ? 0.45 : 1)
            }
            .padding(.horizontal, ClaudeSpacing.md)
            .padding(.vertical, ClaudeSpacing.sm)
            .background(ClaudePalette.canvas)
        }
    }

    private func optionState(
        optionIndex: Int,
        selectedIndex: Int?,
        correctIndex: Int,
        isRevealed: Bool
    ) -> OptionVisualState {
        if let selectedIndex {
            if optionIndex == selectedIndex {
                return selectedIndex == correctIndex ? .correct : .wrong
            }
            if optionIndex == correctIndex {
                return .missedCorrect
            }
            return .normal
        }
        if isRevealed && optionIndex == correctIndex {
            return .correct
        }
        return .normal
    }

    private func handleSelectOption(_ index: Int, for question: Question) {
        sessionSelections[question.id] = index
        repository.recordStudyAnswer(question: question, selectedIndex: index)
        let isCorrect = index == question.correctIndex
        UINotificationFeedbackGenerator().notificationOccurred(isCorrect ? .success : .error)
    }

    private var gridEntries: [QuestionGridEntry] {
        questions.enumerated().map { index, question in
            let status: QuestionGridStatus
            if let sessionPick = sessionSelections[question.id] {
                status = sessionPick == question.correctIndex ? .correct : .wrong
            } else if let progress = repository.progress(for: question.id), progress.attemptsCount > 0 {
                status = progress.lastAnsweredCorrectly ? .correct : .wrong
            } else {
                status = .unanswered
            }

            return QuestionGridEntry(
                id: index,
                questionNumber: index + 1,
                status: status,
                isCritical: question.isCritical,
                isMarked: repository.isBookmarked(question.id)
            )
        }
    }
}
