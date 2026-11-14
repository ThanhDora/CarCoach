//
//  ProfileAndPaywallView.swift
//  CarCoach
//

import Foundation
import SwiftUI

enum ProfilePaywallSection: String, CaseIterable, Identifiable {
    case profile
    case paywall

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: return "Hồ sơ & Cài đặt"
        case .paywall: return "CarCoach Premium"
        }
    }
}

struct ProfileAndPaywallView: View {
    let repository: CarCoachRepository
    let storeManager: StoreKitManager

    @Environment(\.dismiss) private var dismiss

    @State private var activeSection: ProfilePaywallSection
    @State private var showResetConfirmation = false
    @State private var showResetSuccessBanner = false
    @State private var hasTargetDate: Bool
    @State private var draftTargetDate: Date

    init(
        repository: CarCoachRepository,
        storeManager: StoreKitManager,
        initialSection: ProfilePaywallSection = .profile
    ) {
        self.repository = repository
        self.storeManager = storeManager
        _activeSection = State(initialValue: initialSection)
        _hasTargetDate = State(initialValue: repository.targetExamDate != nil)
        _draftTargetDate = State(
            initialValue: repository.targetExamDate
                ?? (Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ClaudeSpacing.lg) {
                    sectionSwitcher

                    if activeSection == .paywall {
                        paywallContent
                    } else {
                        profileContent
                    }
                }
                .padding(.horizontal, ClaudeSpacing.md)
                .padding(.vertical, ClaudeSpacing.md)
            }
            .background(ClaudePalette.canvas.ignoresSafeArea())
            .navigationTitle(activeSection == .paywall ? "CarCoach Premium" : "Hồ sơ & Cài đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") {
                        dismiss()
                    }
                    .font(ClaudeTypography.buttonStrong)
                    .foregroundStyle(ClaudePalette.inkPrimary)
                }
            }
            .alert("Đặt lại toàn bộ tiến độ?", isPresented: $showResetConfirmation) {
                Button("Hủy", role: .cancel) {}
                Button("Đặt lại tất cả", role: .destructive) {
                    repository.resetAllProgress()
                    showResetSuccessBanner = true
                }
            } message: {
                Text("Thao tác này sẽ xóa toàn bộ lịch sử thi thử, trạng thái đúng/sai, đánh dấu câu hỏi và chuỗi ngày học. Không thể hoàn tác.")
            }
        }
    }

    private var sectionSwitcher: some View {
        HStack(spacing: ClaudeSpacing.xs) {
            ForEach(ProfilePaywallSection.allCases) { section in
                let isSelected = activeSection == section
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        activeSection = section
                    }
                } label: {
                    HStack(spacing: 6) {
                        if section == .paywall {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13, weight: .medium))
                        }
                        Text(section.title)
                            .font(ClaudeTypography.nav)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(isSelected ? ClaudePalette.canvas : ClaudePalette.inkPrimary)
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

    // MARK: - Profile & Settings Content

    private var profileContent: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.lg) {
            brandIntroCard
            statusSummaryCard
            licenseSelectorSection
            regulationSection
            targetDateSection
            appearanceSection
            resetProgressSection
        }
    }

    private var brandIntroCard: some View {
        HStack(spacing: ClaudeSpacing.md) {
            Image("BrandLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(ClaudePalette.hairline, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("CarCoach")
                    .font(ClaudeTypography.headingSerifSM)
                    .foregroundStyle(ClaudePalette.ink)
                Text("Your Drive. Our Guidance.")
                    .font(ClaudeTypography.bodySM)
                    .foregroundStyle(ClaudePalette.textMuted)
            }

            Spacer(minLength: 0)
        }
        .claudeCompactCard(padding: ClaudeSpacing.md)
    }

    private var statusSummaryCard: some View {
        let structure = repository.currentExamStructure
        return VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TRẠNG THÁI TÀI KHOẢN")
                        .font(ClaudeTypography.headingSM)
                        .foregroundStyle(ClaudePalette.textMuted)
                    Text("CarCoach Premium đang hoạt động")
                        .font(ClaudeTypography.headingSerifSM)
                        .foregroundStyle(ClaudePalette.ink)
                }
                Spacer()
                ClaudeBadge(
                    text: "Đã mở khóa",
                    tone: .correct
                )
            }

            Divider()
                .overlay(ClaudePalette.hairline)

            HStack(spacing: ClaudeSpacing.xs) {
                summaryChip(label: "Hạng đang học", value: structure.licenseClass.title)
                summaryChip(label: "Đã nắm vững", value: "\(repository.totalMasteredCount)/\(repository.questions.count)")
                summaryChip(label: "Lượt thi thử", value: "Không giới hạn")
            }
        }
        .claudeCard(padding: ClaudeSpacing.lg)
    }

    private func summaryChip(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(ClaudeTypography.captionXS)
                .foregroundStyle(ClaudePalette.textMuted)
            Text(value)
                .font(ClaudeTypography.bodySM.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(ClaudePalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ClaudeSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: ClaudeRadius.xs, style: .continuous)
                .fill(ClaudePalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClaudeRadius.xs, style: .continuous)
                .stroke(ClaudePalette.hairline, lineWidth: 1)
        )
    }

    private var licenseSelectorSection: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.md) {
            ClaudeSectionHeader(
                eyebrow: "HẠNG GIẤY PHÉP",
                title: "Đổi hạng bằng lái",
                subtitle: repository.currentLicense.vehicleSummary
            )

            licenseGroupBlock(
                title: "Xe máy & Mô tô",
                classes: [.A1, .A, .B1]
            )

            licenseGroupBlock(
                title: "Ô tô & Hạng nặng",
                classes: LicenseClass.allCases.filter { !$0.isMotorcycle }
            )
        }
    }

    private func licenseGroupBlock(title: String, classes: [LicenseClass]) -> some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.xs) {
            Text(title.uppercased())
                .font(ClaudeTypography.headingSM)
                .foregroundStyle(ClaudePalette.textMuted)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: ClaudeSpacing.xs),
                    GridItem(.flexible(), spacing: ClaudeSpacing.xs),
                    GridItem(.flexible(), spacing: ClaudeSpacing.xs),
                    GridItem(.flexible(), spacing: ClaudeSpacing.xs)
                ],
                spacing: ClaudeSpacing.xs
            ) {
                ForEach(classes) { item in
                    let isSelected = repository.currentLicense == item
                    Button {
                        repository.currentLicense = item
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: item.vehicleIconName)
                                .font(.system(size: 11, weight: .medium))
                            Text(item.code)
                                .font(ClaudeTypography.buttonStrong)
                        }
                        .foregroundStyle(isSelected ? ClaudePalette.canvas : ClaudePalette.inkPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
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

    private var regulationSection: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            ClaudeSectionHeader(
                eyebrow: "QUY ĐỊNH SÁT HẠCH",
                title: "Chế độ đề thi áp dụng",
                subtitle: "Áp dụng ngay lập tức cho cấu trúc đề và thời gian thi thử."
            )

            ForEach(ExamRegulationEra.allCases) { era in
                let isSelected = repository.currentRegulationEra == era
                let preview = repository.currentLicense.examStructure(for: era)
                Button {
                    repository.currentRegulationEra = era
                } label: {
                    HStack(spacing: ClaudeSpacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(era.title)
                                .font(ClaudeTypography.bodyMD.weight(.medium))
                                .foregroundStyle(ClaudePalette.ink)
                            Text("\(preview.totalQuestions) câu • \(preview.durationMinutes) phút • Đạt \(preview.passScore)+ • \(preview.criticalQuestionCount) điểm liệt")
                                .font(ClaudeTypography.captionXS)
                                .foregroundStyle(ClaudePalette.textMuted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(isSelected ? ClaudePalette.ink : ClaudePalette.borderStrong)
                    }
                    .claudeSurfaceRow(isSelected: isSelected)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var targetDateSection: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            ClaudeSectionHeader(
                eyebrow: "MỤC TIÊU",
                title: "Ngày thi dự kiến"
            )

            VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
                Toggle(isOn: $hasTargetDate) {
                    Text("Hiển thị đếm ngược ngày thi")
                        .font(ClaudeTypography.bodyMD.weight(.medium))
                        .foregroundStyle(ClaudePalette.ink)
                }
                .tint(ClaudePalette.ink)
                .onChange(of: hasTargetDate) { _, enabled in
                    repository.targetExamDate = enabled ? draftTargetDate : nil
                }

                if hasTargetDate {
                    Divider()
                        .overlay(ClaudePalette.hairline)

                    DatePicker(
                        "Ngày thi",
                        selection: $draftTargetDate,
                        in: Date.now...,
                        displayedComponents: .date
                    )
                    .tint(ClaudePalette.ink)
                    .onChange(of: draftTargetDate) { _, newDate in
                        if hasTargetDate {
                            repository.targetExamDate = newDate
                        }
                    }
                }
            }
            .claudeCompactCard(padding: ClaudeSpacing.md)
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            ClaudeSectionHeader(
                eyebrow: "HIỂN THỊ",
                title: "Giao diện Sáng / Tối"
            )

            HStack(spacing: ClaudeSpacing.xs) {
                ForEach(AppAppearanceMode.allCases) { mode in
                    let isSelected = repository.currentAppearanceMode == mode
                    Button {
                        repository.currentAppearanceMode = mode
                    } label: {
                        Text(mode.title)
                            .font(ClaudeTypography.nav)
                            .foregroundStyle(isSelected ? ClaudePalette.canvas : ClaudePalette.inkPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44)
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

    private var resetProgressSection: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            ClaudeSectionHeader(
                eyebrow: "DỮ LIỆU HỌC TẬP",
                title: "Đặt lại tiến độ",
                subtitle: "Xóa toàn bộ tiến độ câu hỏi, lịch sử thi thử và chuỗi ngày học trên thiết bị này."
            )

            if showResetSuccessBanner {
                HStack(spacing: ClaudeSpacing.xs) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(ClaudePalette.correct)
                    Text("Đã đặt lại toàn bộ tiến độ học tập.")
                        .font(ClaudeTypography.bodySM)
                        .foregroundStyle(ClaudePalette.inkPrimary)
                }
                .claudeCompactCard(padding: ClaudeSpacing.sm)
            }

            Button {
                showResetConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Đặt lại toàn bộ tiến độ học")
                }
                .foregroundStyle(ClaudePalette.wrong)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ClaudeSecondaryButtonStyle())
        }
    }

    // MARK: - Premium Unlocked Content

    private var paywallContent: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.lg) {
            premiumUnlockedHeroCard
            premiumUnlockedBenefitsCard
        }
    }

    private var premiumUnlockedHeroCard: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            HStack(spacing: ClaudeSpacing.md) {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(ClaudePalette.hairline, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    ClaudeBadge(
                        text: storeManager.isPremium ? "ĐÃ MỞ KHÓA MIỄN PHÍ" : "CARCOACH PREMIUM",
                        tone: .correct
                    )
                    Text("Your Drive. Our Guidance.")
                        .font(ClaudeTypography.captionXS)
                        .foregroundStyle(ClaudePalette.textMuted)
                }

                Spacer(minLength: 0)
            }

            Text("ĐÃ MỞ KHÓA TRỌN BỘ PREMIUM MIỄN PHÍ")
                .font(ClaudeTypography.headingMD)
                .foregroundStyle(ClaudePalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Tất cả tính năng thi thử không giới hạn, trợ lý AI giải thích chi tiết và nhận diện biển báo thông minh đều đã sẵn sàng.")
                .font(ClaudeTypography.bodySM)
                .foregroundStyle(ClaudePalette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .claudeCard(padding: ClaudeSpacing.xl)
    }

    private var premiumUnlockedBenefitsCard: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.md) {
            Text("TOÀN BỘ TÍNH NĂNG ĐÃ SẴN SÀNG")
                .font(ClaudeTypography.headingSM)
                .foregroundStyle(ClaudePalette.textMuted)

            benefitRow(
                title: "Thi thử & bộ đề không giới hạn",
                detail: "Luyện tập và thi thử thoải mái mỗi ngày cho đủ 15 hạng bằng từ A1, A, B1 (xe máy & mô tô) đến B–DE (ô tô & hạng nặng)."
            )
            benefitRow(
                title: "Giải thích chi tiết & câu điểm liệt",
                detail: "Phân tích từng phương án đúng/sai, mẹo ghi nhớ nhanh và luyện tập chuyên sâu toàn bộ câu điểm liệt theo từng hạng bằng."
            )
            benefitRow(
                title: "Nhận diện biển báo thông minh (Vision)",
                detail: "Quét và phân tích biển báo giao thông QCVN 41:2019 trực tiếp trên thiết bị, liên kết ngay tới các câu hỏi lý thuyết tương ứng."
            )
            benefitRow(
                title: "Lộ trình thích ứng & cập nhật 2027+",
                detail: "Tự động áp dụng quy định trước và từ 01/03/2027, hoàn toàn ngoại tuyến và không quảng cáo."
            )
        }
        .claudeCompactCard(padding: ClaudeSpacing.lg)
    }

    private func benefitRow(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: ClaudeSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(ClaudePalette.correct)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ClaudeTypography.bodyMD.weight(.medium))
                    .foregroundStyle(ClaudePalette.ink)
                Text(detail)
                    .font(ClaudeTypography.bodyXS)
                    .foregroundStyle(ClaudePalette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
