//
//  TrafficSignLibraryView.swift
//  CarCoach
//

import Foundation
import SwiftUI

struct TrafficSignLibraryView: View {
    let repository: CarCoachRepository
    let storeManager: StoreKitManager
    let onPresentPaywall: () -> Void
    let onOpenProfile: (() -> Void)?

    @State private var searchQuery: String = ""
    @State private var selectedCategory: TrafficSignCategory? = nil

    init(
        repository: CarCoachRepository,
        storeManager: StoreKitManager,
        onPresentPaywall: @escaping () -> Void,
        onOpenProfile: (() -> Void)? = nil
    ) {
        self.repository = repository
        self.storeManager = storeManager
        self.onPresentPaywall = onPresentPaywall
        self.onOpenProfile = onOpenProfile
    }

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredSigns: [TrafficSign] {
        repository.searchSigns(query: trimmedQuery, category: selectedCategory)
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: ClaudeSpacing.sm),
        GridItem(.flexible(), spacing: ClaudeSpacing.sm)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClaudeSpacing.lg) {
                ClaudeSectionHeader(
                    eyebrow: "QCVN 41:2019",
                    title: "Thư viện biển báo",
                    subtitle: "Tra cứu nhanh \(repository.signs.count) biển báo chuẩn theo 6 nhóm quy định và luyện ngay câu hỏi liên quan."
                )

                visionScannerBanner
                searchBar
                categoryFilterBar

                if filteredSigns.isEmpty {
                    emptySearchCard
                } else if selectedCategory == nil && trimmedQuery.isEmpty {
                    groupedSignsContent
                } else {
                    flatGridContent(signs: filteredSigns)
                }
            }
            .padding(.horizontal, ClaudeSpacing.md)
            .padding(.top, ClaudeSpacing.sm)
            .padding(.bottom, ClaudeSpacing.section)
        }
        .background(ClaudePalette.canvas.ignoresSafeArea())
        .navigationTitle("Biển báo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onOpenProfile {
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
        }
    }

    private var visionScannerBanner: some View {
        NavigationLink {
            VisionSignScannerView(
                repository: repository,
                storeManager: storeManager,
                onPresentPaywall: onPresentPaywall
            )
        } label: {
            HStack(spacing: ClaudeSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                        .fill(ClaudePalette.inkPrimary)
                        .frame(width: 48, height: 48)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(ClaudePalette.canvas)
                }

                VStack(alignment: .leading, spacing: ClaudeSpacing.xxs) {
                    HStack(spacing: ClaudeSpacing.xs) {
                        Text("Nhận diện biển báo (Vision)")
                            .font(ClaudeTypography.bodyMD.weight(.medium))
                            .foregroundStyle(ClaudePalette.ink)
                        ClaudeBadge(text: "On-device", tone: .neutral)
                    }
                    Text("Quét từ Camera, chọn ảnh thư viện hoặc thử nhanh biển mẫu.")
                        .font(ClaudeTypography.bodyXS)
                        .foregroundStyle(ClaudePalette.textMuted)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ClaudePalette.textMuted)
            }
            .claudeCompactCard(padding: ClaudeSpacing.md)
        }
        .buttonStyle(.plain)
    }

    private var searchBar: some View {
        HStack(spacing: ClaudeSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ClaudePalette.textMuted)

            TextField("Tìm mã biển (P.102, W.208), tên hoặc từ khóa...", text: $searchQuery)
                .font(ClaudeTypography.label)
                .foregroundStyle(ClaudePalette.inkPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ClaudePalette.textMuted)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Xóa từ khóa tìm kiếm")
            }
        }
        .padding(.leading, ClaudeSpacing.sm)
        .padding(.trailing, searchQuery.isEmpty ? ClaudeSpacing.sm : 0)
        .frame(minHeight: 46)
        .background(
            RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                .fill(ClaudePalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                .stroke(ClaudePalette.hairline, lineWidth: 1)
        )
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ClaudeSpacing.xs) {
                filterChip(
                    title: "Tất cả (\(repository.signs.count))",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(TrafficSignCategory.allCases) { category in
                    let count = repository.signs(in: category).count
                    filterChip(
                        title: "\(category.vietnameseTitle) (\(count))",
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = (selectedCategory == category) ? nil : category
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ClaudeTypography.nav)
                .foregroundStyle(isSelected ? ClaudePalette.canvas : ClaudePalette.inkPrimary)
                .padding(.horizontal, ClaudeSpacing.sm)
                .frame(minHeight: 38)
                .background(
                    RoundedRectangle(cornerRadius: ClaudeRadius.xs, style: .continuous)
                        .fill(isSelected ? ClaudePalette.inkPrimary : ClaudePalette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ClaudeRadius.xs, style: .continuous)
                        .stroke(isSelected ? ClaudePalette.inkPrimary : ClaudePalette.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var groupedSignsContent: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.xl) {
            ForEach(TrafficSignCategory.allCases) { category in
                let categorySigns = repository.signs(in: category)
                if !categorySigns.isEmpty {
                    VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(category.vietnameseTitle)
                                .font(ClaudeTypography.headingSerifSM)
                                .foregroundStyle(ClaudePalette.ink)
                            Spacer()
                            ClaudeBadge(text: "\(categorySigns.count) biển", tone: .neutral)
                        }

                        LazyVGrid(columns: gridColumns, spacing: ClaudeSpacing.sm) {
                            ForEach(categorySigns) { sign in
                                signCardLink(sign: sign)
                            }
                        }
                    }
                }
            }
        }
    }

    private func flatGridContent(signs: [TrafficSign]) -> some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            Text("\(signs.count) BIỂN BÁO PHÙ HỢP")
                .font(ClaudeTypography.headingSM)
                .foregroundStyle(ClaudePalette.textMuted)

            LazyVGrid(columns: gridColumns, spacing: ClaudeSpacing.sm) {
                ForEach(signs) { sign in
                    signCardLink(sign: sign)
                }
            }
        }
    }

    private func signCardLink(sign: TrafficSign) -> some View {
        NavigationLink {
            TrafficSignDetailView(
                sign: sign,
                repository: repository,
                storeManager: storeManager,
                onPresentPaywall: onPresentPaywall
            )
        } label: {
            VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
                HStack {
                    ClaudeBadge(text: sign.code, tone: .dark)
                    Spacer()
                    let relatedCount = repository.relatedQuestions(for: sign).count
                    if relatedCount > 0 {
                        Text("\(relatedCount) câu")
                            .font(ClaudeTypography.captionXS)
                            .foregroundStyle(ClaudePalette.textMuted)
                    }
                }

                HStack {
                    Spacer()
                    DiagramCanvasView(spec: sign.diagram, size: 78)
                    Spacer()
                }
                .padding(.vertical, ClaudeSpacing.xxs)

                VStack(alignment: .leading, spacing: ClaudeSpacing.xxs) {
                    Text(sign.name)
                        .font(ClaudeTypography.bodySM.weight(.medium))
                        .foregroundStyle(ClaudePalette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(sign.summary)
                        .font(ClaudeTypography.captionXS)
                        .foregroundStyle(ClaudePalette.textMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 205, alignment: .topLeading)
            .claudeCompactCard(padding: ClaudeSpacing.md)
        }
        .buttonStyle(.plain)
    }

    private var emptySearchCard: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            Text("Không tìm thấy biển báo phù hợp")
                .font(ClaudeTypography.headingSerifSM)
                .foregroundStyle(ClaudePalette.ink)
            Text("Thử tìm theo mã như \"P.102\", \"W.208\", \"R.301\" hoặc xóa bộ lọc nhóm hiện tại.")
                .font(ClaudeTypography.bodySM)
                .foregroundStyle(ClaudePalette.textMuted)
            Button("Đặt lại bộ lọc") {
                searchQuery = ""
                selectedCategory = nil
            }
            .buttonStyle(ClaudeSecondaryButtonStyle())
        }
        .claudeCompactCard(padding: ClaudeSpacing.lg)
    }
}

struct TrafficSignDetailView: View {
    let sign: TrafficSign
    let repository: CarCoachRepository
    let storeManager: StoreKitManager
    let onPresentPaywall: () -> Void

    private var relatedQuestions: [Question] {
        repository.relatedQuestions(for: sign)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClaudeSpacing.lg) {
                heroCard
                detailSection(
                    eyebrow: "QUY CHUẨN QCVN 41:2019",
                    title: "Ý nghĩa & hiệu lực pháp lý",
                    content: sign.legalDetail
                )
                penaltyCard
                if !sign.keywords.isEmpty {
                    keywordsSection
                }
                relatedQuestionsSection
            }
            .padding(.horizontal, ClaudeSpacing.md)
            .padding(.vertical, ClaudeSpacing.md)
        }
        .background(ClaudePalette.canvas.ignoresSafeArea())
        .navigationTitle(sign.code)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.md) {
            HStack {
                ClaudeBadge(text: sign.code, tone: .dark)
                ClaudeBadge(text: sign.category.vietnameseTitle, tone: .neutral)
                Spacer()
            }

            HStack {
                Spacer()
                DiagramCanvasView(spec: sign.diagram, size: 176)
                Spacer()
            }
            .padding(.vertical, ClaudeSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: ClaudeRadius.cardCompact, style: .continuous)
                    .fill(ClaudePalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ClaudeRadius.cardCompact, style: .continuous)
                    .stroke(ClaudePalette.hairline, lineWidth: 1)
            )

            Text(sign.name)
                .font(ClaudeTypography.headingMD)
                .foregroundStyle(ClaudePalette.ink)

            Text(sign.summary)
                .font(ClaudeTypography.bodyMD)
                .foregroundStyle(ClaudePalette.textMuted)
        }
        .claudeCard(padding: ClaudeSpacing.xl)
    }

    private func detailSection(eyebrow: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.xs) {
            Text(eyebrow)
                .font(ClaudeTypography.captionXS.weight(.medium))
                .foregroundStyle(ClaudePalette.textMuted)
            Text(title)
                .font(ClaudeTypography.headingSerifSM)
                .foregroundStyle(ClaudePalette.ink)
            Text(content)
                .font(ClaudeTypography.bodyMD)
                .foregroundStyle(ClaudePalette.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .claudeCompactCard(padding: ClaudeSpacing.lg)
    }

    private var penaltyCard: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.xs) {
            HStack(spacing: ClaudeSpacing.xs) {
                Image(systemName: "exclamationmark.shield")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ClaudePalette.critical)
                Text("Mức xử phạt tham khảo")
                    .font(ClaudeTypography.bodyMD.weight(.semibold))
                    .foregroundStyle(ClaudePalette.ink)
            }
            Text(sign.penaltyNote)
                .font(ClaudeTypography.bodySM)
                .foregroundStyle(ClaudePalette.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .claudeCompactCard(padding: ClaudeSpacing.lg)
    }

    private var keywordsSection: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.xs) {
            Text("TỪ KHÓA TRA CỨU")
                .font(ClaudeTypography.headingSM)
                .foregroundStyle(ClaudePalette.textMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ClaudeSpacing.xs) {
                    ForEach(sign.keywords, id: \.self) { keyword in
                        ClaudeBadge(text: keyword, tone: .neutral)
                    }
                }
            }
        }
    }

    private var relatedQuestionsSection: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            HStack {
                Text("Câu hỏi sát hạch liên quan")
                    .font(ClaudeTypography.headingSerifSM)
                    .foregroundStyle(ClaudePalette.ink)
                Spacer()
                ClaudeBadge(text: "\(relatedQuestions.count) câu", tone: .neutral)
            }

            if relatedQuestions.isEmpty {
                Text("Chưa có câu hỏi gắn trực tiếp với mã biển này trong ngân hàng hiện tại.")
                    .font(ClaudeTypography.bodySM)
                    .foregroundStyle(ClaudePalette.textMuted)
                    .claudeCompactCard(padding: ClaudeSpacing.md)
            } else {
                NavigationLink {
                    QuestionPracticeView(
                        title: "Biển \(sign.code)",
                        subtitle: sign.name,
                        questions: relatedQuestions,
                        repository: repository,
                        storeManager: storeManager,
                        onPresentPaywall: onPresentPaywall
                    )
                } label: {
                    HStack(spacing: ClaudeSpacing.xs) {
                        Image(systemName: "play.fill")
                        Text("Luyện ngay \(relatedQuestions.count) câu hỏi về biển \(sign.code)")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClaudePrimaryButtonStyle())

                ForEach(Array(relatedQuestions.enumerated()), id: \.element.id) { index, question in
                    let reordered = Array(relatedQuestions[index...]) + Array(relatedQuestions[..<index])
                    NavigationLink {
                        QuestionPracticeView(
                            title: "Biển \(sign.code)",
                            subtitle: sign.name,
                            questions: reordered,
                            repository: repository,
                            storeManager: storeManager,
                            onPresentPaywall: onPresentPaywall
                        )
                    } label: {
                        HStack(alignment: .top, spacing: ClaudeSpacing.sm) {
                            ClaudeBadge(
                                text: "Câu \(question.id)",
                                tone: question.isCritical ? .critical : .neutral
                            )
                            Text(question.text)
                                .font(ClaudeTypography.bodySM)
                                .foregroundStyle(ClaudePalette.inkPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(ClaudePalette.textMuted)
                                .padding(.top, 4)
                        }
                        .claudeSurfaceRow(isSelected: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
