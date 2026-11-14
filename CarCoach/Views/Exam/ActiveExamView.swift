import Foundation
import SwiftData
import SwiftUI
import UIKit

struct ActiveExamView: View {
    @Environment(\.dismiss) private var dismiss

    let examTitle: String
    let structure: ExamStructure
    let repository: CarCoachRepository
    let storeManager: StoreKitManager
    let onPresentPaywall: () -> Void

    @State private var currentExamTitle: String
    @State private var currentQuestions: [Question]
    @State private var currentIndex: Int = 0
    @State private var selectedAnswers: [Int: Int] = [:]
    @State private var flaggedIDs: Set<Int> = []
    @State private var startDate: Date = .now
    @State private var endDate: Date
    @State private var remainingSeconds: Int
    @State private var showNavigatorSheet: Bool = false
    @State private var showSubmitAlert: Bool = false
    @State private var showExitAlert: Bool = false
    @State private var submittedAttempt: ExamAttemptRecord?

    init(
        examTitle: String,
        questions: [Question],
        structure: ExamStructure,
        repository: CarCoachRepository,
        storeManager: StoreKitManager,
        onPresentPaywall: @escaping () -> Void
    ) {
        self.examTitle = examTitle
        self.structure = structure
        self.repository = repository
        self.storeManager = storeManager
        self.onPresentPaywall = onPresentPaywall
        _currentExamTitle = State(initialValue: examTitle)
        _currentQuestions = State(initialValue: questions)
        let totalSecs = max(60, structure.durationSeconds)
        _remainingSeconds = State(initialValue: totalSecs)
        _endDate = State(initialValue: Date().addingTimeInterval(TimeInterval(totalSecs)))
    }

    private var answeredCount: Int {
        currentQuestions.filter { selectedAnswers[$0.id] != nil }.count
    }

    private var unansweredCount: Int {
        max(0, currentQuestions.count - answeredCount)
    }

    private var isCriticalDrill: Bool {
        !currentQuestions.isEmpty && currentQuestions.allSatisfy(\.isCritical)
    }

    var body: some View {
        Group {
            if let attempt = submittedAttempt {
                ExamResultView(
                    attempt: attempt,
                    questions: currentQuestions,
                    repository: repository,
                    storeManager: storeManager,
                    onPresentPaywall: onPresentPaywall,
                    onRetake: handleRetake
                )
            } else if currentQuestions.isEmpty {
                emptyQuestionsView
            } else {
                activeExamContent(question: currentQuestions[currentIndex])
            }
        }
        .toolbar(submittedAttempt == nil ? .hidden : .automatic, for: .tabBar)
        .task(id: submittedAttempt == nil) {
            guard submittedAttempt == nil, !currentQuestions.isEmpty else { return }
            await runCountdownTimer()
        }
    }

    private var emptyQuestionsView: some View {
        VStack(spacing: ClaudeSpacing.md) {
            Text("Không thể khởi tạo đề thi")
                .font(ClaudeTypography.headingSerifSM)
                .foregroundStyle(ClaudePalette.ink)
            Text("Vui lòng quay lại phòng thi thử và thử lại.")
                .font(ClaudeTypography.bodySM)
                .foregroundStyle(ClaudePalette.textMuted)
            Button("Quay lại") {
                dismiss()
            }
            .buttonStyle(ClaudePrimaryButtonStyle())
        }
        .padding(ClaudeSpacing.xl)
        .claudeCard()
        .padding(ClaudeSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ClaudePalette.canvas.ignoresSafeArea())
    }

    private func activeExamContent(question: Question) -> some View {
        let isFlagged = flaggedIDs.contains(question.id)
        let picked = selectedAnswers[question.id]

        return ScrollView {
            VStack(alignment: .leading, spacing: ClaudeSpacing.md) {
                examStatusHeader

                // Question header + Flag button
                HStack(spacing: ClaudeSpacing.xs) {
                    ClaudeBadge(text: "Câu \(currentIndex + 1)/\(currentQuestions.count)", tone: .dark)
                    ClaudeBadge(text: "Hạng \(structure.licenseClass.code)", tone: .neutral)

                    Spacer()

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        toggleFlag(for: question.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isFlagged ? "flag.fill" : "flag")
                            Text("Xem lại")
                        }
                        .font(ClaudeTypography.captionXS)
                        .foregroundStyle(isFlagged ? ClaudePalette.critical : ClaudePalette.textMuted)
                        .padding(.horizontal, ClaudeSpacing.sm)
                        .frame(minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                                .fill(isFlagged ? ClaudePalette.criticalSoft : ClaudePalette.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                                .stroke(isFlagged ? ClaudePalette.critical.opacity(0.5) : ClaudePalette.hairline, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Question Text
                Text(question.text)
                    .font(ClaudeTypography.bodyMD)
                    .fontWeight(.semibold)
                    .foregroundStyle(ClaudePalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let diagram = question.diagram {
                    QuestionDiagramCard(diagram: diagram, size: 180)
                }

                // Options (no right/wrong reveal during real exam)
                VStack(spacing: ClaudeSpacing.xs) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { index, optionText in
                        QuestionOptionRow(
                            index: index,
                            text: optionText,
                            state: picked == index ? .selected : .normal,
                            isInteractive: true
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedAnswers[question.id] = index
                        }
                    }
                }
            }
            .padding(.horizontal, ClaudeSpacing.md)
            .padding(.top, ClaudeSpacing.sm)
            .padding(.bottom, ClaudeSpacing.xxl)
        }
        .background(ClaudePalette.canvas.ignoresSafeArea())
        .navigationTitle(currentExamTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Thoát") {
                    showExitAlert = true
                }
                .font(ClaudeTypography.nav)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Nộp bài") {
                    requestSubmit()
                }
                .font(ClaudeTypography.buttonStrong)
                .foregroundStyle(ClaudePalette.ink)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sheet(isPresented: $showNavigatorSheet) {
            QuestionIndexGridSheet(
                title: "Bảng câu hỏi bài thi",
                entries: gridEntries,
                currentIndex: currentIndex,
                markedLegendLabel: "Xem lại",
                showCriticalFilter: false,
                footerActionTitle: "Nộp bài ngay (\(answeredCount)/\(currentQuestions.count))",
                onFooterAction: requestSubmit,
                onSelectIndex: { newIndex in
                    currentIndex = newIndex
                }
            )
        }
        .alert("Xác nhận nộp bài?", isPresented: $showSubmitAlert) {
            Button("Tiếp tục làm bài", role: .cancel) {}
            Button("Nộp bài ngay", role: .destructive) {
                submitExam(autoSubmitted: false)
            }
        } message: {
            Text("Bạn còn \(unansweredCount) câu chưa trả lời. Câu bỏ trống sẽ bị tính là sai (nếu trúng câu điểm liệt sẽ trượt ngay).")
        }
        .alert("Thoát bài thi?", isPresented: $showExitAlert) {
            Button("Ở lại thi tiếp", role: .cancel) {}
            Button("Thoát", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("Tiến trình bài thi hiện tại sẽ không được lưu nếu bạn thoát trước khi nộp bài.")
        }
    }

    private var examStatusHeader: some View {
        let ratio = currentQuestions.isEmpty ? 0 : Double(answeredCount) / Double(currentQuestions.count)
        let timerColor: Color = {
            if remainingSeconds <= 60 {
                return ClaudePalette.wrong
            }
            if remainingSeconds <= 180 {
                return ClaudePalette.critical
            }
            return ClaudePalette.ink
        }()

        return VStack(alignment: .leading, spacing: ClaudeSpacing.xs) {
            HStack(spacing: ClaudeSpacing.sm) {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 15, weight: .semibold))
                    Text(ExamFormatters.formatDuration(remainingSeconds))
                        .font(ClaudeTypography.bodyXL)
                        .monospacedDigit()
                }
                .foregroundStyle(timerColor)

                Spacer()

                Text("Đã làm \(answeredCount)/\(currentQuestions.count)")
                    .font(ClaudeTypography.nav)
                    .monospacedDigit()
                    .foregroundStyle(ClaudePalette.inkPrimary)

                Button {
                    showNavigatorSheet = true
                } label: {
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(ClaudePalette.ink)
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
                .accessibilityLabel("Mở danh sách câu hỏi")
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ClaudePalette.surfaceRaised)
                    Capsule()
                        .fill(ClaudePalette.ink)
                        .frame(width: ratio > 0 ? max(6, proxy.size.width * ratio) : 0)
                }
            }
            .frame(height: 6)
        }
        .claudeCompactCard(padding: ClaudeSpacing.sm)
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(ClaudePalette.hairline)

            HStack(spacing: ClaudeSpacing.sm) {
                Button {
                    if currentIndex > 0 {
                        currentIndex -= 1
                    }
                } label: {
                    Label("Trước", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClaudeSecondaryButtonStyle())
                .disabled(currentIndex == 0)
                .opacity(currentIndex == 0 ? 0.45 : 1)

                Button {
                    showNavigatorSheet = true
                } label: {
                    Text("\(currentIndex + 1)/\(currentQuestions.count)")
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

                if currentIndex < currentQuestions.count - 1 {
                    Button {
                        currentIndex += 1
                    } label: {
                        HStack(spacing: 4) {
                            Text("Tiếp")
                            Image(systemName: "chevron.right")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClaudePrimaryButtonStyle())
                } else {
                    Button {
                        requestSubmit()
                    } label: {
                        Text("Nộp bài")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClaudePrimaryButtonStyle())
                }
            }
            .padding(.horizontal, ClaudeSpacing.md)
            .padding(.vertical, ClaudeSpacing.sm)
            .background(ClaudePalette.canvas)
        }
    }

    // MARK: - Actions & Timer

    private func toggleFlag(for questionID: Int) {
        if flaggedIDs.contains(questionID) {
            flaggedIDs.remove(questionID)
        } else {
            flaggedIDs.insert(questionID)
        }
    }

    private func runCountdownTimer() async {
        while submittedAttempt == nil && !Task.isCancelled {
            let left = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
            remainingSeconds = left
            if left == 0 {
                submitExam(autoSubmitted: true)
                break
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func requestSubmit() {
        if unansweredCount > 0 {
            showSubmitAlert = true
        } else {
            submitExam(autoSubmitted: false)
        }
    }

    private func submitExam(autoSubmitted: Bool) {
        guard submittedAttempt == nil else { return }
        let elapsed = min(
            structure.durationSeconds,
            max(1, Int(Date().timeIntervalSince(startDate)))
        )
        let usedSeconds = autoSubmitted ? structure.durationSeconds : elapsed

        let attempt = repository.saveExamAttempt(
            title: currentExamTitle,
            questions: currentQuestions,
            selectedAnswers: selectedAnswers,
            flaggedIDs: Array(flaggedIDs),
            durationUsedSeconds: usedSeconds,
            structure: structure
        )
        UINotificationFeedbackGenerator().notificationOccurred(attempt.passed ? .success : .error)
        submittedAttempt = attempt
    }

    private func handleRetake() {
        let freshQuestions = isCriticalDrill
            ? repository.generateCriticalDrillExam()
            : repository.generateRandomExam()

        currentExamTitle = isCriticalDrill
            ? "Thi thử \(freshQuestions.count) câu điểm liệt"
            : "Đề ngẫu nhiên • Hạng \(structure.licenseClass.code)"
        currentQuestions = freshQuestions
        currentIndex = 0
        selectedAnswers = [:]
        flaggedIDs = []
        startDate = .now
        let totalSecs = max(60, structure.durationSeconds)
        remainingSeconds = totalSecs
        endDate = Date().addingTimeInterval(TimeInterval(totalSecs))
        submittedAttempt = nil
    }

    private var gridEntries: [QuestionGridEntry] {
        currentQuestions.enumerated().map { index, question in
            QuestionGridEntry(
                id: index,
                questionNumber: index + 1,
                status: selectedAnswers[question.id] != nil ? .answered : .unanswered,
                isCritical: false,
                isMarked: flaggedIDs.contains(question.id)
            )
        }
    }
}
