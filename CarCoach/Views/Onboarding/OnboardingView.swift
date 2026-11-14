//
//  OnboardingView.swift
//  CarCoach
//

import Foundation
import SwiftUI

struct OnboardingView: View {
    let repository: CarCoachRepository

    @State private var selectedLicense: LicenseClass = .B
    @State private var selectedEra: ExamRegulationEra = .auto
    @State private var includeTargetDate: Bool = false
    @State private var targetExamDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now

    private let licenseGroups: [(title: String, items: [LicenseClass])] = [
        ("Hạng xe máy & mô tô", [.A1, .A, .B1]),
        ("Hạng phổ thông", [.B]),
        ("Hạng xe tải", [.C1, .C]),
        ("Hạng xe chở người", [.D1, .D2, .D]),
        ("Hạng kéo rơ moóc", [.BE, .C1E, .CE, .D1E, .D2E, .DE])
    ]

    private var previewStructure: ExamStructure {
        selectedLicense.examStructure(for: selectedEra, referenceDate: includeTargetDate ? targetExamDate : .now)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClaudeSpacing.xl) {
                heroHeader
                licenseSelectionSection
                regulationEraSection
                targetDateSection
                structurePreviewCard
                startActionSection
            }
            .padding(.horizontal, ClaudeSpacing.md)
            .padding(.top, ClaudeSpacing.xl)
            .padding(.bottom, ClaudeSpacing.band)
        }
        .background(ClaudePalette.canvas.ignoresSafeArea())
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            Image("BrandLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(ClaudePalette.hairline, lineWidth: 1)
                )

            ClaudeBadge(text: "LÝ THUYẾT XE MÁY & Ô TÔ • QCVN 41:2019", tone: .neutral)

            Text("Luyện thi sát hạch lái xe chuẩn xác, tinh gọn.")
                .font(ClaudeTypography.display(36))
                .foregroundStyle(ClaudePalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Chọn hạng giấy phép xe máy (250–300 câu) hoặc ô tô (600 câu) để CarCoach tự động điều chỉnh ngân hàng câu hỏi, câu điểm liệt và cấu trúc đề thi.")
                .font(ClaudeTypography.bodyMD)
                .foregroundStyle(ClaudePalette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var licenseSelectionSection: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.md) {
            ClaudeSectionHeader(
                eyebrow: "BƯỚC 1 / 3",
                title: "Chọn hạng giấy phép lái xe",
                subtitle: "Hỗ trợ đầy đủ 15 hạng xe máy, mô tô và ô tô (A1–DE) theo quy chuẩn hiện hành."
            )

            ForEach(licenseGroups, id: \.title) { group in
                VStack(alignment: .leading, spacing: ClaudeSpacing.xs) {
                    Text(group.title.uppercased())
                        .font(ClaudeTypography.headingSM)
                        .foregroundStyle(ClaudePalette.textMuted)
                        .padding(.top, ClaudeSpacing.xxs)

                    ForEach(group.items) { item in
                        let isSelected = selectedLicense == item
                        Button {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                selectedLicense = item
                            }
                        } label: {
                            HStack(alignment: .center, spacing: ClaudeSpacing.md) {
                                Text(item.code)
                                    .font(ClaudeTypography.bodyMD.weight(.semibold))
                                    .foregroundStyle(isSelected ? ClaudePalette.canvas : ClaudePalette.ink)
                                    .frame(width: 48, height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: ClaudeRadius.xs, style: .continuous)
                                            .fill(isSelected ? ClaudePalette.ink : ClaudePalette.canvas)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: ClaudeRadius.xs, style: .continuous)
                                            .stroke(isSelected ? ClaudePalette.ink : ClaudePalette.hairline, lineWidth: 1)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(ClaudeTypography.bodyMD.weight(.medium))
                                        .foregroundStyle(ClaudePalette.ink)
                                    Text(item.vehicleSummary)
                                        .font(ClaudeTypography.bodyXS)
                                        .foregroundStyle(ClaudePalette.textMuted)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
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
        }
    }

    private var regulationEraSection: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            ClaudeSectionHeader(
                eyebrow: "BƯỚC 2 / 3",
                title: "Quy định cấu trúc đề thi",
                subtitle: "Chuyển đổi linh hoạt giữa cấu trúc trước 01/03/2027 và quy định mới từ 01/03/2027."
            )

            ForEach(ExamRegulationEra.allCases) { era in
                let isSelected = selectedEra == era
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selectedEra = era
                    }
                } label: {
                    HStack(alignment: .center, spacing: ClaudeSpacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(era.title)
                                .font(ClaudeTypography.bodyMD.weight(.medium))
                                .foregroundStyle(ClaudePalette.ink)
                            Text(eraDescription(era))
                                .font(ClaudeTypography.bodyXS)
                                .foregroundStyle(ClaudePalette.textMuted)
                                .multilineTextAlignment(.leading)
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
                eyebrow: "BƯỚC 3 / 3 (TÙY CHỌN)",
                title: "Ngày thi dự kiến",
                subtitle: "Đặt mục tiêu để Dashboard hiển thị đếm ngược và gợi ý tốc độ ôn tập."
            )

            VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
                Toggle(isOn: $includeTargetDate.animation(.easeInOut(duration: 0.18))) {
                    Text("Đặt ngày thi sát hạch")
                        .font(ClaudeTypography.bodyMD.weight(.medium))
                        .foregroundStyle(ClaudePalette.ink)
                }
                .tint(ClaudePalette.ink)

                if includeTargetDate {
                    Divider()
                        .overlay(ClaudePalette.hairline)

                    DatePicker(
                        "Ngày thi",
                        selection: $targetExamDate,
                        in: Date.now...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(ClaudePalette.ink)
                }
            }
            .claudeCompactCard(padding: ClaudeSpacing.md)
        }
    }

    private var structurePreviewCard: some View {
        let structure = previewStructure
        return VStack(alignment: .leading, spacing: ClaudeSpacing.md) {
            HStack {
                Text("CẤU TRÚC ĐỀ ÁP DỤNG")
                    .font(ClaudeTypography.headingSM)
                    .foregroundStyle(ClaudePalette.textMuted)
                Spacer()
                ClaudeBadge(text: structure.ruleBadgeText, tone: structure.is2027Rule ? .dark : .neutral)
            }

            HStack(spacing: ClaudeSpacing.xs) {
                metricBox(title: "Hạng", value: structure.licenseClass.code)
                metricBox(title: "Số câu", value: "\(structure.totalQuestions)")
                metricBox(title: "Thời gian", value: "\(structure.durationMinutes)p")
                metricBox(title: "Điểm đạt", value: "\(structure.passScore)/\(structure.totalQuestions)")
            }

            Text("Bao gồm \(structure.criticalQuestionCount) câu điểm liệt. Bạn có thể thay đổi hạng bằng và quy định bất cứ lúc nào trong Hồ sơ.")
                .font(ClaudeTypography.captionXS)
                .foregroundStyle(ClaudePalette.textMuted)
        }
        .claudeCard(padding: ClaudeSpacing.lg)
    }

    private func metricBox(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(ClaudeTypography.captionXS)
                .foregroundStyle(ClaudePalette.textMuted)
            Text(value)
                .font(ClaudeTypography.bodyMD.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(ClaudePalette.ink)
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

    private var startActionSection: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                repository.completeOnboarding(
                    license: selectedLicense,
                    era: selectedEra,
                    targetDate: includeTargetDate ? targetExamDate : nil
                )
            }
        } label: {
            Text("Bắt đầu ôn luyện • \(selectedLicense.title)")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(ClaudePrimaryButtonStyle())
    }

    private func eraDescription(_ era: ExamRegulationEra) -> String {
        switch era {
        case .auto:
            return "Tự động áp dụng bộ đề trước 01/03/2027 nếu thi sớm hơn, và tự chuyển sang cấu trúc mới từ 01/03/2027."
        case .currentPre2027:
            return "Xe máy (A1, A, B1) gồm 25 câu / 19 phút; ô tô hạng B gồm 30 câu / 20 phút (đạt từ 27/30, 1 câu điểm liệt)."
        case .newFromMarch2027:
            return "Xe máy (A1, A, B1) giữ 25 câu / 19 phút; ô tô tăng số câu (hạng B 50 câu / 33 phút, đạt từ 45/50, 2 câu điểm liệt)."
        }
    }
}
