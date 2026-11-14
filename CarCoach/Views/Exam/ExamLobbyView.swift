import Foundation
import SwiftData
import SwiftUI

struct ExamLobbyView: View {
    private struct ExamLaunchPayload: Identifiable, Hashable {
        let id: UUID
        let title: String
        let questions: [Question]
        let structure: ExamStructure
        let isCriticalDrill: Bool

        init(
            id: UUID = UUID(),
            title: String,
            questions: [Question],
            structure: ExamStructure,
            isCriticalDrill: Bool = false
        ) {
            self.id = id
            self.title = title
            self.questions = questions
            self.structure = structure
            self.isCriticalDrill = isCriticalDrill
        }

        static func == (lhs: ExamLaunchPayload, rhs: ExamLaunchPayload) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    private struct HistoryReviewPayload: Identifiable, Hashable {
        let id: UUID
        let attempt: ExamAttemptRecord
        let questions: [Question]

        static func == (lhs: HistoryReviewPayload, rhs: HistoryReviewPayload) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    let repository: CarCoachRepository
    let storeManager: StoreKitManager
    let onPresentPaywall: () -> Void

    @State private var activeLaunch: ExamLaunchPayload?
    @State private var activeHistoryReview: HistoryReviewPayload?

    private let fixedSetColumns = Array(repeating: GridItem(.flexible(), spacing: ClaudeSpacing.xs), count: 4)

    init(
        repository: CarCoachRepository,
        storeManager: StoreKitManager,
        onPresentPaywall: @escaping () -> Void
    ) {
        self.repository = repository
        self.storeManager = storeManager
        self.onPresentPaywall = onPresentPaywall
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClaudeSpacing.lg) {
                ClaudeSectionHeader(
                    eyebrow: "Sát hạch mô phỏng",
                    title: "Thi thử theo hạng bằng",
                    subtitle: "Đúng cấu trúc đề, đồng hồ đếm ngược và chấm điểm liệt nghiêm ngặt."
                )

                structureCard
                examModesSection
                fixedSetsSection
                historySection
            }
            .padding(.horizontal, ClaudeSpacing.md)
            .padding(.top, ClaudeSpacing.sm)
            .padding(.bottom, ClaudeSpacing.section)
        }
        .background(ClaudePalette.canvas.ignoresSafeArea())
        .navigationTitle("Thi thử")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $activeLaunch) { payload in
            ActiveExamView(
                examTitle: payload.title,
                questions: payload.questions,
                structure: payload.structure,
                repository: repository,
                storeManager: storeManager,
                onPresentPaywall: onPresentPaywall
            )
        }
        .navigationDestination(item: $activeHistoryReview) { payload in
            ExamResultView(
                attempt: payload.attempt,
                questions: payload.questions,
                repository: repository,
                storeManager: storeManager,
                onPresentPaywall: onPresentPaywall,
                onRetake: {
                    activeHistoryReview = nil
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        startRandomExam()
                    }
                }
            )
        }
    }

    // MARK: - Exam Structure Card

    private var structureCard: some View {
        let structure = repository.currentExamStructure
        let license = repository.currentLicense

        return VStack(alignment: .leading, spacing: ClaudeSpacing.md) {
            HStack(alignment: .top, spacing: ClaudeSpacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cấu trúc đề hiện tại")
                        .font(ClaudeTypography.headingSM)
                        .foregroundStyle(ClaudePalette.textMuted)

                    HStack(spacing: ClaudeSpacing.xs) {
                        Image(systemName: license.vehicleIconName)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(ClaudePalette.ink)
                        Text("Hạng \(license.code)")
                            .font(ClaudeTypography.headingMD)
                            .foregroundStyle(ClaudePalette.ink)
                    }

                    Text(license.vehicleSummary)
                        .font(ClaudeTypography.captionXS)
                        .foregroundStyle(ClaudePalette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Menu {
                    Section("Xe máy & Mô tô") {
                        ForEach(LicenseClass.allCases.filter(\.isMotorcycle)) { item in
                            licenseMenuButton(item, current: license)
                        }
                    }

                    Section("Ô tô & Hạng nặng") {
                        ForEach(LicenseClass.allCases.filter { !$0.isMotorcycle }) { item in
                            licenseMenuButton(item, current: license)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: license.vehicleIconName)
                            .font(.system(size: 13, weight: .medium))
                        Text("Đổi hạng")
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(ClaudeTypography.nav)
                    .foregroundStyle(ClaudePalette.inkPrimary)
                    .padding(.horizontal, ClaudeSpacing.sm)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                            .fill(ClaudePalette.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                            .stroke(ClaudePalette.hairline, lineWidth: 1)
                    )
                }
            }

            // Regulation Era Info / Quick Switcher
            VStack(alignment: .leading, spacing: ClaudeSpacing.xs) {
                HStack {
                    Text(license.isMotorcycle ? "Quy định sát hạch" : "Chế độ quy định thi")
                        .font(ClaudeTypography.headingSM)
                        .foregroundStyle(ClaudePalette.textMuted)
                    Spacer()
                    ClaudeBadge(
                        text: structure.ruleBadgeText,
                        tone: (license.isMotorcycle || structure.is2027Rule) ? .dark : .neutral
                    )
                }

                if !license.isMotorcycle {
                    HStack(spacing: ClaudeSpacing.xs) {
                        ForEach(ExamRegulationEra.allCases) { era in
                            let isSelected = repository.currentRegulationEra == era
                            Button {
                                updateRegulationEra(era)
                            } label: {
                                Text(shortEraLabel(era))
                                    .font(ClaudeTypography.captionXS)
                                    .fontWeight(isSelected ? .semibold : .regular)
                                    .foregroundStyle(isSelected ? ClaudePalette.canvas : ClaudePalette.inkPrimary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .padding(.horizontal, 6)
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

            // 4 Structure Metrics
            HStack(spacing: ClaudeSpacing.xs) {
                structureMetric(label: "Số câu", value: "\(structure.totalQuestions)")
                structureMetric(label: "Thời gian", value: "\(structure.durationMinutes)p")
                structureMetric(label: "Điểm đạt", value: "\(structure.passScore)/\(structure.totalQuestions)")
                structureMetric(label: "Điểm liệt", value: "\(structure.criticalQuestionCount)")
            }

            Text("Quy tắc điểm liệt: chỉ cần sai hoặc bỏ trống 1 câu điểm liệt sẽ trượt dù đạt đủ điểm tổng.")
                .font(ClaudeTypography.captionXS)
                .foregroundStyle(ClaudePalette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .claudeCard()
    }

    private func structureMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(ClaudeTypography.captionXS)
                .foregroundStyle(ClaudePalette.textMuted)
            Text(value)
                .font(ClaudeTypography.buttonStrong)
                .monospacedDigit()
                .foregroundStyle(ClaudePalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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

    private func shortEraLabel(_ era: ExamRegulationEra) -> String {
        switch era {
        case .auto:
            return "Tự động"
        case .currentPre2027:
            return "Trước 01/03/27"
        case .newFromMarch2027:
            return "Từ 01/03/27"
        }
    }

    private func licenseMenuButton(_ item: LicenseClass, current: LicenseClass) -> some View {
        Button {
            updateLicense(item)
        } label: {
            Label {
                Text("\(item.title) — \(item.groupTitle)")
            } icon: {
                Image(systemName: item == current ? "checkmark" : item.vehicleIconName)
            }
        }
    }

    // MARK: - Exam Modes

    private var examModesSection: some View {
        let structure = repository.currentExamStructure
        let criticalCount = repository.criticalQuestions.count

        return VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            Text("Chế độ thi thử")
                .font(ClaudeTypography.headingSerifSM)
                .foregroundStyle(ClaudePalette.ink)

            // Random Exam Card
            VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
                HStack {
                    ClaudeBadge(text: "Khuyên dùng", tone: .dark)
                    Spacer()
                    Text("\(structure.totalQuestions) câu • \(structure.durationMinutes) phút")
                        .font(ClaudeTypography.captionXS)
                        .monospacedDigit()
                        .foregroundStyle(ClaudePalette.textMuted)
                }

                Text("Tạo đề ngẫu nhiên chuẩn cấu trúc")
                    .font(ClaudeTypography.buttonStrong)
                    .foregroundStyle(ClaudePalette.ink)

                Text("Hệ thống bốc đề ngẫu nhiên cân đối tỷ lệ các chương và chèn đúng số câu điểm liệt theo hạng \(structure.licenseClass.code).")
                    .font(ClaudeTypography.bodySM)
                    .foregroundStyle(ClaudePalette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    startRandomExam()
                } label: {
                    Label("Bắt đầu đề ngẫu nhiên", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClaudePrimaryButtonStyle())
            }
            .claudeCompactCard(padding: ClaudeSpacing.md)

            // Critical Drill Exam Card
            VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
                HStack {
                    ClaudeBadge(text: "\(criticalCount) câu điểm liệt", tone: .critical)
                    Spacer()
                    Text("Cần đúng \(criticalCount)/\(criticalCount)")
                        .font(ClaudeTypography.captionXS)
                        .monospacedDigit()
                        .foregroundStyle(ClaudePalette.critical)
                }

                Text("Thi thử trọn bộ \(criticalCount) câu điểm liệt")
                    .font(ClaudeTypography.buttonStrong)
                    .foregroundStyle(ClaudePalette.ink)

                Text("Kiểm tra toàn diện \(criticalCount) tình huống mất an toàn nghiêm trọng trong \(structure.durationMinutes) phút — sai 1 câu là trượt.")
                    .font(ClaudeTypography.bodySM)
                    .foregroundStyle(ClaudePalette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    startCriticalDrillExam()
                } label: {
                    Label("Thi thử \(criticalCount) câu điểm liệt", systemImage: "exclamationmark.shield")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClaudeSecondaryButtonStyle())
            }
            .claudeCompactCard(padding: ClaudeSpacing.md)
        }
    }

    // MARK: - Fixed Sets (Đề 1 .. Đề 20)

    private var fixedSetsSection: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            Text("Bộ đề cố định (Đề 1 – Đề 20)")
                .font(ClaudeTypography.headingSerifSM)
                .foregroundStyle(ClaudePalette.ink)

            Text("Các bộ đề chuẩn hóa ổn định để luyện lặp lại và đối chiếu tiến bộ.")
                .font(ClaudeTypography.bodySM)
                .foregroundStyle(ClaudePalette.textMuted)

            LazyVGrid(columns: fixedSetColumns, spacing: ClaudeSpacing.xs) {
                ForEach(1...20, id: \.self) { setNumber in
                    Button {
                        startFixedExam(setNumber: setNumber)
                    } label: {
                        Text("Đề \(setNumber)")
                            .font(ClaudeTypography.nav)
                            .monospacedDigit()
                            .foregroundStyle(ClaudePalette.inkPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44)
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
                }
            }
            .claudeCompactCard(padding: ClaudeSpacing.md)
        }
    }

    // MARK: - Exam History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            Text("Lịch sử các lần thi")
                .font(ClaudeTypography.headingSerifSM)
                .foregroundStyle(ClaudePalette.ink)

            if repository.examHistory.isEmpty {
                VStack(alignment: .leading, spacing: ClaudeSpacing.xxs) {
                    Text("Chưa có lượt thi nào")
                        .font(ClaudeTypography.buttonStrong)
                        .foregroundStyle(ClaudePalette.ink)
                    Text("Hoàn thành bài thi đầu tiên để lưu điểm số, thời gian làm bài và xem lại chi tiết các câu sai.")
                        .font(ClaudeTypography.bodySM)
                        .foregroundStyle(ClaudePalette.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .claudeCompactCard()
            } else {
                LazyVStack(spacing: ClaudeSpacing.sm) {
                    ForEach(repository.examHistory, id: \.attemptID) { attempt in
                        Button {
                            openHistoryAttempt(attempt)
                        } label: {
                            historyRow(attempt)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func historyRow(_ attempt: ExamAttemptRecord) -> some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.xs) {
            HStack(alignment: .center, spacing: ClaudeSpacing.xs) {
                Text(attempt.examTitle)
                    .font(ClaudeTypography.buttonStrong)
                    .foregroundStyle(ClaudePalette.ink)
                    .lineLimit(1)

                Spacer()

                if attempt.passed {
                    ClaudeBadge(text: "ĐẠT", tone: .correct)
                } else if attempt.failedByCritical {
                    ClaudeBadge(text: "TRƯỢT • ĐIỂM LIỆT", tone: .wrong)
                } else {
                    ClaudeBadge(text: "TRƯỢT", tone: .wrong)
                }
            }

            HStack(spacing: ClaudeSpacing.sm) {
                Text("Hạng \(attempt.licenseCode)")
                Text("•")
                Text("\(attempt.correctCount)/\(attempt.totalQuestions) câu")
                    .monospacedDigit()
                Text("•")
                Text(ExamFormatters.formatDuration(attempt.durationUsedSeconds))
                    .monospacedDigit()
                Spacer()
                Text(attempt.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(ClaudeTypography.captionXS)
            .foregroundStyle(ClaudePalette.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .claudeCompactCard()
    }

    // MARK: - Helpers

    private func startRandomExam() {
        let structure = repository.currentExamStructure
        let questions = repository.generateRandomExam()
        activeLaunch = ExamLaunchPayload(
            title: "Đề ngẫu nhiên • Hạng \(structure.licenseClass.code)",
            questions: questions,
            structure: structure
        )
    }

    private func startFixedExam(setNumber: Int) {
        let structure = repository.currentExamStructure
        let questions = repository.generateFixedExam(setNumber: setNumber)
        activeLaunch = ExamLaunchPayload(
            title: "Đề cố định số \(setNumber) • Hạng \(structure.licenseClass.code)",
            questions: questions,
            structure: structure
        )
    }

    private func startCriticalDrillExam() {
        let questions = repository.generateCriticalDrillExam()
        let current = repository.currentExamStructure
        let drillStructure = ExamStructure(
            licenseClass: current.licenseClass,
            is2027Rule: current.is2027Rule,
            totalQuestions: questions.count,
            durationMinutes: current.durationMinutes,
            passScore: questions.count,
            criticalQuestionCount: questions.count
        )
        activeLaunch = ExamLaunchPayload(
            title: "Thi thử \(questions.count) câu điểm liệt",
            questions: questions,
            structure: drillStructure,
            isCriticalDrill: true
        )
    }

    private func openHistoryAttempt(_ attempt: ExamAttemptRecord) {
        let orderedQuestions = repository.questionsForAttempt(attempt)
        activeHistoryReview = HistoryReviewPayload(
            id: attempt.attemptID,
            attempt: attempt,
            questions: orderedQuestions
        )
    }

    private func updateLicense(_ license: LicenseClass) {
        repository.currentLicense = license
    }

    private func updateRegulationEra(_ era: ExamRegulationEra) {
        repository.currentRegulationEra = era
    }
}
