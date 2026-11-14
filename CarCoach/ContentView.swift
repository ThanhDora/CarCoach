//
//  ContentView.swift
//  CarCoach
//

import Foundation
import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case dashboard
    case study
    case exam
    case signs
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var repository = CarCoachRepository()
    @State private var storeManager = StoreKitManager()
    @State private var selectedTab: AppTab = .dashboard
    @State private var profileSheetSection: ProfilePaywallSection?
    @State private var didAttachRepository = false

    var body: some View {
        Group {
            if repository.hasCompletedOnboarding {
                mainTabShell
            } else {
                OnboardingView(repository: repository)
            }
        }
        .preferredColorScheme(repository.currentAppearanceMode.colorScheme)
        .onAppear {
            if !didAttachRepository {
                didAttachRepository = true
                repository.attach(modelContext: modelContext)
            }
        }
        .task {
            await storeManager.loadProducts()
        }
        .sheet(item: $profileSheetSection) { section in
            ProfileAndPaywallView(
                repository: repository,
                storeManager: storeManager,
                initialSection: section
            )
            .preferredColorScheme(repository.currentAppearanceMode.colorScheme)
        }
    }

    private var mainTabShell: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(
                    repository: repository,
                    storeManager: storeManager,
                    onOpenExamTab: { selectedTab = .exam },
                    onOpenProfile: { profileSheetSection = .profile },
                    onPresentPaywall: { profileSheetSection = .paywall }
                )
            }
            .tabItem {
                Label("Tổng quan", systemImage: "square.grid.2x2")
            }
            .tag(AppTab.dashboard)

            NavigationStack {
                StudyHubView(
                    repository: repository,
                    storeManager: storeManager,
                    onPresentPaywall: { profileSheetSection = .paywall }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        profileToolbarButton
                    }
                }
            }
            .tabItem {
                Label("Học tập", systemImage: "book.closed")
            }
            .tag(AppTab.study)

            NavigationStack {
                ExamLobbyView(
                    repository: repository,
                    storeManager: storeManager,
                    onPresentPaywall: { profileSheetSection = .paywall }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        profileToolbarButton
                    }
                }
            }
            .tabItem {
                Label("Thi thử", systemImage: "checklist")
            }
            .tag(AppTab.exam)

            NavigationStack {
                TrafficSignLibraryView(
                    repository: repository,
                    storeManager: storeManager,
                    onPresentPaywall: { profileSheetSection = .paywall },
                    onOpenProfile: { profileSheetSection = .profile }
                )
            }
            .tabItem {
                Label("Biển báo", systemImage: "exclamationmark.triangle")
            }
            .tag(AppTab.signs)
        }
        .tint(ClaudePalette.ink)
    }

    private var profileToolbarButton: some View {
        Button {
            profileSheetSection = .profile
        } label: {
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

#Preview {
    ContentView()
        .modelContainer(
            for: [
                QuestionProgressRecord.self,
                ExamAttemptRecord.self,
                UserSettingsRecord.self
            ],
            inMemory: true
        )
}
