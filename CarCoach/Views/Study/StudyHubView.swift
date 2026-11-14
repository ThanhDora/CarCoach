import Foundation
import SwiftData
import SwiftUI

struct StudyHubView: View {
    let repository: CarCoachRepository
    let storeManager: StoreKitManager
    let onPresentPaywall: () -> Void

    @State private var searchText: String = ""
    @State private var expandedChapterIDs: Set<Int> = []

    init(
        repository: CarCoachRepository,
        storeManager: StoreKitManager,
        onPresentPaywall: @escaping () -> Void
    ) {
        self.repository = repository
        self.storeManager = storeManager
        self.onPresentPaywall = onPresentPaywall
    }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchResults: [Question] {
        guard !trimmedQuery.isEmpty else { return [] }
        return repository.searchQuestions(query: trimmedQuery)
    }

    private var visibleChapters: [(info: ChapterInfo, questions: [Question])] {
        ChapterInfo.allChapters.compactMap { chapter in
            let qs = repository.questions(inChapter: chapter.id)
            guard !qs.isEmpty else { return nil }
            return (chapter, qs)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClaudeSpacing.lg) {
                ClaudeSectionHeader(
                    eyebrow: "\(repository.currentLicense.title) • Ngân hàng \(repository.questions.count) câu",
                    title: "Học tập lý thuyết",
                    subtitle: "Tra cứu nhanh, ôn nhóm ưu tiên và học theo \(visibleChapters.count) chương chuẩn."
                )

                searchField

                if !trimmedQuery.isEmpty {
                    searchResultsSection
                } else {
                    quickPracticeSection
                    fullBankRow
                    chaptersSection
                }
            }
            .padding(.horizontal, ClaudeSpacing.md)
            .padding(.top, ClaudeSpacing.sm)
            .padding(.bottom, ClaudeSpacing.section)
        }
        .background(ClaudePalette.canvas.ignoresSafeArea())
        .navigationTitle("Học tập")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Search Bar & Results

    private var searchField: some View {
        HStack(spacing: ClaudeSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ClaudePalette.textMuted)

            TextField("Tìm trong \(repository.questions.count) câu (từ khóa, số câu, biển báo...)", text: $searchText)
                .font(ClaudeTypography.label)
                .foregroundStyle(ClaudePalette.inkPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ClaudePalette.textMuted)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Xóa tìm kiếm")
            }
        }
        .padding(.leading, ClaudeSpacing.sm)
        .padding(.trailing, searchText.isEmpty ? ClaudeSpacing.sm : 0)
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

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            Text("Tìm thấy \(searchResults.count) câu hỏi")
                .font(ClaudeTypography.headingSM)
                .foregroundStyle(ClaudePalette.textMuted)

            if searchResults.isEmpty {
                VStack(alignment: .leading, spacing: ClaudeSpacing.xs) {
                    Text("Không tìm thấy câu hỏi phù hợp")
                        .font(ClaudeTypography.buttonStrong)
                        .foregroundStyle(ClaudePalette.ink)
                    Text("Thử tìm bằng từ khóa ngắn hơn như \"nồng độ cồn\", \"cao tốc\", \"P.102\" hoặc số thứ tự câu.")
                        .font(ClaudeTypography.bodySM)
                        .foregroundStyle(ClaudePalette.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .claudeCompactCard()
            } else {
                LazyVStack(spacing: ClaudeSpacing.sm) {
                    ForEach(searchResults) { question in
                        let reordered = [question] + searchResults.filter { $0.id != question.id }
                        NavigationLink {
                            QuestionPracticeView(
                                title: "Kết quả tìm kiếm",
                                subtitle: "Từ khóa: \"\(trimmedQuery)\"",
                                questions: reordered,
                                repository: repository,
                                storeManager: storeManager,
                                onPresentPaywall: onPresentPaywall
                            )
                        } label: {
                            searchResultRow(question)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func searchResultRow(_ question: Question) -> some View {
        let progress = repository.progress(for: question.id)

        return VStack(alignment: .leading, spacing: ClaudeSpacing.xs) {
            HStack(spacing: ClaudeSpacing.xs) {
                ClaudeBadge(text: "Câu #\(question.id)", tone: .dark)
                ClaudeBadge(text: "Chương \(question.chapter)", tone: .neutral)

                if question.isCritical {
                    ClaudeBadge(text: "Điểm liệt", tone: .critical)
                }

                Spacer()

                if let progress, progress.attemptsCount > 0 {
                    ClaudeBadge(
                        text: progress.lastAnsweredCorrectly ? "Đúng" : "Sai",
                        tone: progress.lastAnsweredCorrectly ? .correct : .wrong
                    )
                }
            }

            Text(question.text)
                .font(ClaudeTypography.bodySM)
                .foregroundStyle(ClaudePalette.inkPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .claudeCompactCard()
    }

    // MARK: - Quick Practice Section

    private var quickPracticeSection: some View {
        let critical = repository.criticalQuestions
        let wrong = repository.wrongQuestions
        let bookmarked = repository.bookmarkedQuestions
        let due = repository.dueForReviewQuestions

        let columns = [
            GridItem(.flexible(), spacing: ClaudeSpacing.sm),
            GridItem(.flexible(), spacing: ClaudeSpacing.sm),
        ]

        return VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            Text("Nhóm luyện nhanh")
                .font(ClaudeTypography.headingSerifSM)
                .foregroundStyle(ClaudePalette.ink)

            LazyVGrid(columns: columns, spacing: ClaudeSpacing.sm) {
                NavigationLink {
                    QuestionPracticeView(
                        title: "\(critical.count) câu điểm liệt",
                        subtitle: "Sai 1 câu là trượt ngay — bắt buộc nắm vững 100%",
                        questions: critical,
                        repository: repository,
                        storeManager: storeManager,
                        onPresentPaywall: onPresentPaywall
                    )
                } label: {
                    quickGroupCard(
                        icon: "exclamationmark.shield.fill",
                        badgeText: "Điểm liệt",
                        badgeTone: .critical,
                        title: "\(critical.count) câu điểm liệt",
                        countText: "\(critical.count) câu",
                        caption: "Sai là trượt ngay",
                        highlightCritical: true
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    QuestionPracticeView(
                        title: "Câu hay sai",
                        subtitle: "Ôn lại các câu bạn đã trả lời chưa chính xác",
                        questions: wrong,
                        repository: repository,
                        storeManager: storeManager,
                        onPresentPaywall: onPresentPaywall
                    )
                } label: {
                    quickGroupCard(
                        icon: "arrow.uturn.backward.circle",
                        badgeText: wrong.isEmpty ? "Sạch lỗi" : "Cần sửa",
                        badgeTone: wrong.isEmpty ? .correct : .wrong,
                        title: "Câu hay sai",
                        countText: "\(wrong.count) câu",
                        caption: "Tập trung gỡ lỗi",
                        highlightCritical: false
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    QuestionPracticeView(
                        title: "Câu đã đánh dấu",
                        subtitle: "Danh sách câu quan trọng bạn đã lưu",
                        questions: bookmarked,
                        repository: repository,
                        storeManager: storeManager,
                        onPresentPaywall: onPresentPaywall
                    )
                } label: {
                    quickGroupCard(
                        icon: "bookmark.fill",
                        badgeText: "Đã lưu",
                        badgeTone: .neutral,
                        title: "Đã đánh dấu",
                        countText: "\(bookmarked.count) câu",
                        caption: "Xem lại nhanh",
                        highlightCritical: false
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    QuestionPracticeView(
                        title: "Câu cần ôn lại",
                        subtitle: "Lặp lại ngắt quãng để nhớ lâu",
                        questions: due,
                        repository: repository,
                        storeManager: storeManager,
                        onPresentPaywall: onPresentPaywall
                    )
                } label: {
                    quickGroupCard(
                        icon: "clock.arrow.circlepath",
                        badgeText: due.isEmpty ? "Đã xong" : "Đến hạn",
                        badgeTone: due.isEmpty ? .neutral : .dark,
                        title: "Cần ôn lại",
                        countText: "\(due.count) câu",
                        caption: "Nhắc ôn thông minh",
                        highlightCritical: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func quickGroupCard(
        icon: String,
        badgeText: String,
        badgeTone: BadgeTone,
        title: String,
        countText: String,
        caption: String,
        highlightCritical: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.xs) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(highlightCritical ? ClaudePalette.critical : ClaudePalette.ink)
                Spacer()
                ClaudeBadge(text: badgeText, tone: badgeTone)
            }

            Spacer(minLength: ClaudeSpacing.xxs)

            Text(title)
                .font(ClaudeTypography.buttonStrong)
                .foregroundStyle(ClaudePalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(countText)
                .font(ClaudeTypography.bodyXL)
                .monospacedDigit()
                .foregroundStyle(ClaudePalette.ink)

            Text(caption)
                .font(ClaudeTypography.captionXS)
                .foregroundStyle(ClaudePalette.textMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(ClaudeSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: ClaudeRadius.cardCompact, style: .continuous)
                .fill(highlightCritical ? ClaudePalette.criticalSoft.opacity(0.35) : ClaudePalette.canvas)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClaudeRadius.cardCompact, style: .continuous)
                .stroke(
                    highlightCritical ? ClaudePalette.critical.opacity(0.45) : ClaudePalette.hairline,
                    lineWidth: 1
                )
        )
    }

    private var fullBankRow: some View {
        NavigationLink {
            QuestionPracticeView(
                title: "Toàn bộ \(repository.questions.count) câu",
                subtitle: "Ôn luyện tuần tự \(repository.questions.count) câu hỏi \(repository.currentLicense.title)",
                questions: repository.questions,
                repository: repository,
                storeManager: storeManager,
                onPresentPaywall: onPresentPaywall
            )
        } label: {
            HStack(spacing: ClaudeSpacing.sm) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(ClaudePalette.ink)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                            .fill(ClaudePalette.surface)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ôn toàn bộ \(repository.questions.count) câu hỏi")
                        .font(ClaudeTypography.buttonStrong)
                        .foregroundStyle(ClaudePalette.ink)
                    Text("Học tuần tự đầy đủ \(visibleChapters.count) chương của \(repository.currentLicense.title) kèm giải thích chi tiết")
                        .font(ClaudeTypography.captionXS)
                        .foregroundStyle(ClaudePalette.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ClaudePalette.textMuted)
            }
            .claudeCompactCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chapters Section

    private var chaptersSection: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            Text("\(visibleChapters.count) chương theo \(repository.currentLicense.title)")
                .font(ClaudeTypography.headingSerifSM)
                .foregroundStyle(ClaudePalette.ink)

            VStack(spacing: ClaudeSpacing.md) {
                ForEach(visibleChapters, id: \.info.id) { item in
                    chapterCard(item.info, questions: item.questions)
                }
            }
        }
    }

    private func chapterCard(_ chapter: ChapterInfo, questions chapterQuestions: [Question]) -> some View {
        let stats = repository.chapterProgress(chapter: chapter.id)
        let total = max(stats.total, chapterQuestions.count)
        let ratio = total > 0 ? min(1.0, Double(stats.correct) / Double(total)) : 0
        let isExpanded = expandedChapterIDs.contains(chapter.id)

        return VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            HStack(alignment: .top, spacing: ClaudeSpacing.sm) {
                Image(systemName: chapter.iconSystemName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(ClaudePalette.ink)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                            .fill(ClaudePalette.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                            .stroke(ClaudePalette.hairline, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: ClaudeSpacing.xs) {
                        ClaudeBadge(text: "Chương \(chapter.id)", tone: .neutral)
                        Text("\(chapterQuestions.count) câu")
                            .font(ClaudeTypography.captionXS)
                            .monospacedDigit()
                            .foregroundStyle(ClaudePalette.textMuted)
                    }

                    Text(chapter.title)
                        .font(ClaudeTypography.buttonStrong)
                        .foregroundStyle(ClaudePalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Progress bar (correct / total)
            VStack(alignment: .leading, spacing: ClaudeSpacing.xxs) {
                HStack {
                    Text("Đúng \(stats.correct)/\(total) câu")
                        .font(ClaudeTypography.captionXS)
                        .monospacedDigit()
                        .foregroundStyle(ClaudePalette.textMuted)
                    Spacer()
                    Text("\(Int((ratio * 100).rounded()))%")
                        .font(ClaudeTypography.captionXS)
                        .monospacedDigit()
                        .foregroundStyle(ClaudePalette.inkPrimary)
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

            // Expandable Key Theory Summary
            if !chapter.summaryPoints.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedChapterIDs.remove(chapter.id)
                        } else {
                            expandedChapterIDs.insert(chapter.id)
                        }
                    }
                } label: {
                    HStack {
                        Label("Tóm tắt lý thuyết trọng tâm", systemImage: "text.book.closed")
                            .font(ClaudeTypography.bodyXS)
                            .foregroundStyle(ClaudePalette.inkPrimary)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ClaudePalette.textMuted)
                    }
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
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: ClaudeSpacing.xs) {
                        ForEach(Array(chapter.summaryPoints.enumerated()), id: \.offset) { _, point in
                            HStack(alignment: .top, spacing: ClaudeSpacing.xs) {
                                Text("•")
                                    .font(ClaudeTypography.bodySM)
                                    .foregroundStyle(ClaudePalette.textMuted)
                                Text(point)
                                    .font(ClaudeTypography.bodySM)
                                    .foregroundStyle(ClaudePalette.inkPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(ClaudeSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: ClaudeRadius.md, style: .continuous)
                            .fill(ClaudePalette.surface)
                    )
                }
            }

            NavigationLink {
                QuestionPracticeView(
                    title: "Chương \(chapter.id): \(chapter.shortTitle)",
                    subtitle: chapter.title,
                    questions: chapterQuestions,
                    repository: repository,
                    storeManager: storeManager,
                    onPresentPaywall: onPresentPaywall
                )
            } label: {
                Text("Vào luyện tập (\(chapterQuestions.count) câu)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ClaudePrimaryButtonStyle())
        }
        .claudeCompactCard(padding: ClaudeSpacing.md)
    }
}
