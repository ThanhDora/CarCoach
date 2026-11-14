//
//  DashboardView.swift
//  CarCoach
//

import Foundation
import SwiftUI

struct DashboardView: View {
    let repository: CarCoachRepository
    let storeManager: StoreKitManager
    let onOpenExamTab: () -> Void
    let onOpenProfile: () -> Void
    let onPresentPaywall: () -> Void

    @State private var selectedLatestReviewAttempt: ExamAttemptRecord?

    init(
        repository: CarCoachRepository,
        storeManager: StoreKitManager,
        onOpenExamTab: @escaping () -> Void,
        onOpenProfile: @escaping () -> Void,
        onPresentPaywall: @escaping () -> Void
    ) {
        self.repository = repository
        self.storeManager = storeManager
        self.onOpenExamTab = onOpenExamTab
        self.onOpenProfile = onOpenProfile
        self.onPresentPaywall = onPresentPaywall
    }

    private var greetingHeadline: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:
            return "Chào buổi sáng"
        case 12..<18:
            return "Chào buổi chiều"
        default:
            return "Chào buổi tối"
        }
    }

    private var daysUntilExam: Int? {
        guard let target = repository.targetExamDate else { return nil }
        let startToday = Calendar.current.startOfDay(for: .now)
        let startTarget = Calendar.current.startOfDay(for: target)
        let diff = Calendar.current.dateComponents([.day], from: startToday, to: startTarget).day
        return diff
    }

    private var quickActionColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: ClaudeSpacing.sm),
            GridItem(.flexible(), spacing: ClaudeSpacing.sm)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClaudeSpacing.lg) {
                if let loadError = repository.loadErrorMessage {
                    loadErrorBanner(loadError)
                }

                greetingHeader
                readinessCard
                quickActionsSection
                smartRoadmapSection
                chapterProgressSection
                latestExamSection
            }
            .padding(.horizontal, ClaudeSpacing.md)
            .padding(.top, ClaudeSpacing.sm)
            .padding(.bottom, ClaudeSpacing.section)
        }
        .background(ClaudePalette.canvas.ignoresSafeArea())
        .navigationTitle("Tổng quan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: ClaudeSpacing.xs) {
                    Image("BrandLogo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(ClaudePalette.hairline, lineWidth: 1)
                        )
                    Text("CarCoach")
                        .font(ClaudeTypography.nav)
                        .foregroundStyle(ClaudePalette.ink)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, 4)
                .fixedSize(horizontal: true, vertical: false)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenProfile) {
                    HStack(spacing: 6) {
                        if storeManager.isPremium {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13))
                        }
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 18, weight: .regular))
                    }
                    .foregroundStyle(ClaudePalette.inkPrimary)
                }
                .accessibilityLabel("Hồ sơ và CarCoach Premium")
            }
        }
        .navigationDestination(item: $selectedLatestReviewAttempt) { attempt in
            let orderedQuestions = repository.questionsForAttempt(attempt)
            ExamResultView(
                attempt: attempt,
                questions: orderedQuestions,
                repository: repository,
                storeManager: storeManager,
                onPresentPaywall: onPresentPaywall,
                onRetake: {
                    selectedLatestReviewAttempt = nil
                    onOpenExamTab()
                }
            )
        }
    }

    private func loadErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: ClaudeSpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(ClaudePalette.wrong)
            Text(message)
                .font(ClaudeTypography.bodyXS)
                .foregroundStyle(ClaudePalette.inkPrimary)
            Spacer()
        }
        .claudeCompactCard(padding: ClaudeSpacing.md)
    }

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            Text(greetingHeadline)
                .font(ClaudeTypography.headingMD)
                .foregroundStyle(ClaudePalette.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ClaudeSpacing.xs) {
                    Menu {
                        Section("Xe máy & Mô tô") {
                            ForEach(LicenseClass.allCases.filter(\.isMotorcycle)) { item in
                                Button {
                                    repository.currentLicense = item
                                } label: {
                                    if item == repository.currentLicense {
                                        Label("\(item.title) • \(item.groupTitle)", systemImage: "checkmark")
                                    } else {
                                        Text("\(item.title) • \(item.groupTitle)")
                                    }
                                }
                            }
                        }

                        Section("Ô tô & Hạng nặng") {
                            ForEach(LicenseClass.allCases.filter { !$0.isMotorcycle }) { item in
                                Button {
                                    repository.currentLicense = item
                                } label: {
                                    if item == repository.currentLicense {
                                        Label("\(item.title) • \(item.groupTitle)", systemImage: "checkmark")
                                    } else {
                                        Text("\(item.title) • \(item.groupTitle)")
                                    }
                                }
                            }
                        }
                    } label: {
                        quickChipLabel(
                            icon: repository.currentLicense.vehicleIconName,
                            text: repository.currentLicense.title,
                            isDark: true
                        )
                    }

                    if repository.currentLicense.isMotorcycle {
                        quickChipLabel(
                            icon: "checkmark.shield",
                            text: repository.currentExamStructure.ruleBadgeText,
                            isDark: false,
                            showsChevron: false
                        )
                    } else {
                        Menu {
                            ForEach(ExamRegulationEra.allCases) { era in
                                Button {
                                    repository.currentRegulationEra = era
                                } label: {
                                    if era == repository.currentRegulationEra {
                                        Label(era.title, systemImage: "checkmark")
                                    } else {
                                        Text(era.title)
                                    }
                                }
                            }
                        } label: {
                            quickChipLabel(
                                icon: "calendar.badge.clock",
                                text: repository.currentExamStructure.is2027Rule ? "Quy định 03/2027" : "Quy định hiện hành",
                                isDark: false
                            )
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func quickChipLabel(
        icon: String,
        text: String,
        isDark: Bool,
        showsChevron: Bool = true
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
            Text(text)
                .font(ClaudeTypography.nav)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .foregroundStyle(isDark ? ClaudePalette.canvas : ClaudePalette.inkPrimary)
        .padding(.horizontal, ClaudeSpacing.sm)
        .frame(minHeight: 38)
        .background(
            RoundedRectangle(cornerRadius: ClaudeRadius.xs, style: .continuous)
                .fill(isDark ? ClaudePalette.inkPrimary : ClaudePalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClaudeRadius.xs, style: .continuous)
                .stroke(isDark ? ClaudePalette.inkPrimary : ClaudePalette.hairline, lineWidth: 1)
        )
    }

    private var readinessCard: some View {
        let totalQuestions = repository.questions.count
        let criticalTotal = repository.criticalQuestions.count
        let structure = repository.currentExamStructure

        return VStack(alignment: .leading, spacing: ClaudeSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MỨC ĐỘ SẴN SÀNG THI")
                        .font(ClaudeTypography.headingSM)
                        .foregroundStyle(ClaudePalette.textMuted)

                    HStack(alignment: .firstTextBaseline, spacing: ClaudeSpacing.xs) {
                        Text("\(repository.readinessScorePercent)%")
                            .font(ClaudeTypography.display(44))
                            .monospacedDigit()
                            .foregroundStyle(ClaudePalette.ink)
                        Text("chỉ số sẵn sàng")
                            .font(ClaudeTypography.bodySM)
                            .foregroundStyle(ClaudePalette.textMuted)
                    }
                }

                Spacer()

                if let days = daysUntilExam {
                    VStack(alignment: .trailing, spacing: 2) {
                        ClaudeBadge(
                            text: days > 0 ? "Còn \(days) ngày" : (days == 0 ? "Thi hôm nay" : "Đã qua ngày thi"),
                            tone: days <= 7 && days >= 0 ? .critical : .dark
                        )
                        Text("mục tiêu sát hạch")
                            .font(ClaudeTypography.captionXS)
                            .foregroundStyle(ClaudePalette.textMuted)
                    }
                } else {
                    Button("Đặt ngày thi") {
                        onOpenProfile()
                    }
                    .font(ClaudeTypography.captionXS.weight(.medium))
                    .foregroundStyle(ClaudePalette.inkPrimary)
                    .padding(.horizontal, ClaudeSpacing.xs)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: ClaudeRadius.xs, style: .continuous)
                            .fill(ClaudePalette.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ClaudeRadius.xs, style: .continuous)
                            .stroke(ClaudePalette.hairline, lineWidth: 1)
                    )
                }
            }

            GeometryReader { proxy in
                let ratio = max(0, min(1, Double(repository.readinessScorePercent) / 100.0))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(ClaudePalette.surfaceRaised)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(ClaudePalette.inkPrimary)
                        .frame(width: max(0, proxy.size.width * ratio))
                }
            }
            .frame(height: 8)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: ClaudeSpacing.xs),
                    GridItem(.flexible(), spacing: ClaudeSpacing.xs)
                ],
                spacing: ClaudeSpacing.xs
            ) {
                readinessStatBox(
                    label: "Đã nắm vững",
                    value: "\(repository.totalMasteredCount)/\(totalQuestions)"
                )
                readinessStatBox(
                    label: "Câu điểm liệt",
                    value: "\(repository.criticalMasteredCount)/\(criticalTotal)"
                )
                readinessStatBox(
                    label: "Độ chính xác",
                    value: "\(repository.overallAccuracyPercent)%"
                )
                readinessStatBox(
                    label: "Chuỗi ngày học",
                    value: "\(repository.studyStreakDays) ngày"
                )
            }

            HStack {
                Text("Đề \(structure.licenseClass.title): \(structure.totalQuestions) câu • \(structure.durationMinutes) phút • Đạt \(structure.passScore)+")
                    .font(ClaudeTypography.captionXS)
                    .foregroundStyle(ClaudePalette.textMuted)
                Spacer()
            }
        }
        .claudeCard(padding: ClaudeSpacing.lg)
    }

    private func readinessStatBox(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(ClaudeTypography.captionXS)
                .foregroundStyle(ClaudePalette.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(value)
                .font(ClaudeTypography.buttonStrong)
                .monospacedDigit()
                .foregroundStyle(ClaudePalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ClaudeSpacing.sm)
        .padding(.vertical, ClaudeSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: ClaudeRadius.xs, style: .continuous)
                .fill(ClaudePalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClaudeRadius.xs, style: .continuous)
                .stroke(ClaudePalette.hairline, lineWidth: 1)
        )
    }

    private var quickActionsSection: some View {
        let criticalTotal = repository.criticalQuestions.count

        return VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            Text("HÀNH ĐỘNG NHANH")
                .font(ClaudeTypography.headingSM)
                .foregroundStyle(ClaudePalette.textMuted)

            LazyVGrid(columns: quickActionColumns, spacing: ClaudeSpacing.sm) {
                NavigationLink {
                    QuestionPracticeView(
                        title: "\(criticalTotal) câu điểm liệt",
                        subtitle: "Sai hoặc bỏ trống 1 câu sẽ trượt bài thi",
                        questions: repository.criticalQuestions,
                        repository: repository,
                        storeManager: storeManager,
                        onPresentPaywall: onPresentPaywall
                    )
                } label: {
                    quickActionCard(
                        icon: "exclamationmark.triangle",
                        title: "\(criticalTotal) câu điểm liệt",
                        subtitle: "Đã vững \(repository.criticalMasteredCount)/\(criticalTotal) câu",
                        badge: "Bắt buộc",
                        badgeTone: .critical
                    )
                }
                .buttonStyle(.plain)

                let wrongList = repository.wrongQuestions
                let fallbackDue = repository.dueForReviewQuestions
                let reviewPool = wrongList.isEmpty ? fallbackDue : wrongList
                NavigationLink {
                    QuestionPracticeView(
                        title: wrongList.isEmpty ? "Ôn tập đến hạn" : "Câu hay sai",
                        subtitle: wrongList.isEmpty ? "Các câu cần củng cố theo lịch nhắc" : "Tập trung xử lý các câu từng chọn sai",
                        questions: reviewPool.isEmpty ? Array(repository.questions.prefix(30)) : reviewPool,
                        repository: repository,
                        storeManager: storeManager,
                        onPresentPaywall: onPresentPaywall
                    )
                } label: {
                    quickActionCard(
                        icon: "arrow.counterclockwise",
                        title: "Ôn câu hay sai",
                        subtitle: wrongList.isEmpty ? "Chưa có câu sai nào" : "\(wrongList.count) câu cần sửa",
                        badge: wrongList.isEmpty ? "Sạch lỗi" : "\(wrongList.count) câu",
                        badgeTone: wrongList.isEmpty ? .correct : .wrong
                    )
                }
                .buttonStyle(.plain)

                Button(action: onOpenExamTab) {
                    quickActionCard(
                        icon: "checklist",
                        title: "Thi thử ngay",
                        subtitle: "\(repository.currentExamStructure.totalQuestions) câu • \(repository.currentExamStructure.durationMinutes) phút",
                        badge: "Không giới hạn",
                        badgeTone: .neutral
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    VisionSignScannerView(
                        repository: repository,
                        storeManager: storeManager,
                        onPresentPaywall: onPresentPaywall
                    )
                } label: {
                    quickActionCard(
                        icon: "camera.viewfinder",
                        title: "Nhận diện biển",
                        subtitle: "Camera, Ảnh & Biển mẫu",
                        badge: "Vision",
                        badgeTone: .dark
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func quickActionCard(
        icon: String,
        title: String,
        subtitle: String,
        badge: String,
        badgeTone: BadgeTone
    ) -> some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(ClaudePalette.inkPrimary)
                Spacer()
                ClaudeBadge(text: badge, tone: badgeTone)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ClaudeTypography.bodyMD.weight(.medium))
                    .foregroundStyle(ClaudePalette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(ClaudeTypography.captionXS)
                    .foregroundStyle(ClaudePalette.textMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .claudeCompactCard(padding: ClaudeSpacing.md)
    }

    private var smartRoadmapSection: some View {
        let roadmap = repository.buildSmartStudyRoadmap()

        return VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            ClaudeSectionHeader(
                eyebrow: "LỘ TRÌNH CÁ NHÂN HÓA",
                title: "Đề xuất ôn tập hôm nay",
                subtitle: "Tự động sắp xếp theo độ phủ \(repository.questions.count) câu, câu điểm liệt và chương yếu nhất."
            )

            ForEach(roadmap) { item in
                NavigationLink {
                    QuestionPracticeView(
                        title: item.title,
                        subtitle: item.subtitle,
                        questions: item.targetQuestions,
                        repository: repository,
                        storeManager: storeManager,
                        onPresentPaywall: onPresentPaywall
                    )
                } label: {
                    HStack(alignment: .center, spacing: ClaudeSpacing.md) {
                        VStack(alignment: .leading, spacing: ClaudeSpacing.xxs) {
                            HStack(spacing: ClaudeSpacing.xs) {
                                ClaudeBadge(
                                    text: item.badge,
                                    tone: item.badge == "Điểm liệt" ? .critical : (item.badge == "Ưu tiên cao" ? .wrong : .neutral)
                                )
                                Text("\(item.targetQuestions.count) câu")
                                    .font(ClaudeTypography.captionXS)
                                    .foregroundStyle(ClaudePalette.textMuted)
                            }

                            Text(item.title)
                                .font(ClaudeTypography.bodyMD.weight(.medium))
                                .foregroundStyle(ClaudePalette.ink)
                                .multilineTextAlignment(.leading)

                            Text(item.subtitle)
                                .font(ClaudeTypography.bodyXS)
                                .foregroundStyle(ClaudePalette.textMuted)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ClaudePalette.textMuted)
                    }
                    .claudeSurfaceRow(isSelected: false)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var chapterProgressSection: some View {
        let visibleChapters = ChapterInfo.allChapters.compactMap { chapter -> (info: ChapterInfo, stats: (answered: Int, correct: Int, total: Int))? in
            let stats = repository.chapterProgress(chapter: chapter.id)
            guard stats.total > 0 else { return nil }
            return (chapter, stats)
        }

        return VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            Text("TIẾN ĐỘ THEO CHƯƠNG (\(visibleChapters.count) CHƯƠNG)")
                .font(ClaudeTypography.headingSM)
                .foregroundStyle(ClaudePalette.textMuted)

            if visibleChapters.isEmpty {
                Text("Đang tải dữ liệu các chương...")
                    .font(ClaudeTypography.bodySM)
                    .foregroundStyle(ClaudePalette.textMuted)
                    .claudeCompactCard(padding: ClaudeSpacing.md)
            } else {
                VStack(spacing: ClaudeSpacing.sm) {
                    ForEach(visibleChapters, id: \.info.id) { item in
                        let denominator = max(item.stats.total, 1)
                        let ratio = min(1.0, Double(item.stats.correct) / Double(denominator))

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Chương \(item.info.id): \(item.info.shortTitle)")
                                    .font(ClaudeTypography.bodySM.weight(.medium))
                                    .foregroundStyle(ClaudePalette.inkPrimary)
                                Spacer()
                                Text("\(item.stats.correct)/\(item.stats.total) vững")
                                    .font(ClaudeTypography.captionXS)
                                    .monospacedDigit()
                                    .foregroundStyle(ClaudePalette.textMuted)
                            }

                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(ClaudePalette.surfaceRaised)
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(ClaudePalette.inkPrimary)
                                        .frame(width: max(0, proxy.size.width * ratio))
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
                .claudeCompactCard(padding: ClaudeSpacing.md)
            }
        }
    }

    private var latestExamSection: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            Text("LẦN THI THỬ GẦN NHẤT")
                .font(ClaudeTypography.headingSM)
                .foregroundStyle(ClaudePalette.textMuted)

            if let latest = repository.examHistory.first {
                Button {
                    selectedLatestReviewAttempt = latest
                } label: {
                    VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
                        HStack {
                            ClaudeBadge(
                                text: latest.passed ? "ĐẠT" : "TRƯỢT",
                                tone: latest.passed ? .correct : .wrong
                            )
                            ClaudeBadge(
                                text: "Hạng \(latest.licenseCode)",
                                tone: .neutral
                            )
                            Spacer()
                            Text(latest.createdAt, format: .dateTime.day().month().hour().minute())
                                .font(ClaudeTypography.captionXS)
                                .foregroundStyle(ClaudePalette.textMuted)
                        }

                        HStack(alignment: .firstTextBaseline) {
                            Text(latest.examTitle)
                                .font(ClaudeTypography.bodyMD.weight(.medium))
                                .foregroundStyle(ClaudePalette.ink)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Text("\(latest.correctCount)/\(latest.totalQuestions)")
                                .font(ClaudeTypography.bodyXL)
                                .monospacedDigit()
                                .foregroundStyle(ClaudePalette.ink)
                        }

                        if latest.failedByCritical {
                            Text("Trượt do sai hoặc bỏ trống câu điểm liệt.")
                                .font(ClaudeTypography.captionXS)
                                .foregroundStyle(ClaudePalette.wrong)
                        }

                        HStack {
                            Text("Chạm để xem lại chi tiết bài thi")
                                .font(ClaudeTypography.captionXS)
                                .foregroundStyle(ClaudePalette.textMuted)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(ClaudePalette.textMuted)
                        }
                    }
                    .claudeCompactCard(padding: ClaudeSpacing.md)
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
                    Text("Bạn chưa thực hiện bài thi thử nào.")
                        .font(ClaudeTypography.bodyMD.weight(.medium))
                        .foregroundStyle(ClaudePalette.ink)
                    Text("Hãy làm một đề chuẩn \(repository.currentExamStructure.totalQuestions) câu để đo mức độ sẵn sàng thực tế.")
                        .font(ClaudeTypography.bodySM)
                        .foregroundStyle(ClaudePalette.textMuted)
                    Button("Làm đề thi đầu tiên") {
                        onOpenExamTab()
                    }
                    .buttonStyle(ClaudeSecondaryButtonStyle())
                }
                .claudeCompactCard(padding: ClaudeSpacing.md)
            }
        }
    }
}
