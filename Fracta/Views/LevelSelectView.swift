import SwiftUI

struct LevelSelectView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @StateObject private var statsViewModel = StatsViewModel()
    @State private var selectedLevel: Level?
    @State private var showGame = false
    @Environment(\.dismiss) private var dismiss
    
    private var theme: ColorTheme {
        settingsViewModel.selectedTheme
    }
    
    private var settings: UserSettings {
        StorageService.shared.loadUserSettings()
    }
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            theme.background
                .ignoresSafeArea()
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Level.allLevels) { level in
                        LevelCard(
                            level: level,
                            isUnlocked: settings.isLevelUnlocked(level.id),
                            stats: statsViewModel.getLevelStats(for: level.id),
                            theme: theme
                        ) {
                            if settings.isLevelUnlocked(level.id) {
                                HapticService.shared.lightImpact()
                                selectedLevel = level
                                showGame = true
                            } else {
                                HapticService.shared.warning()
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Select Level")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    HapticService.shared.lightImpact()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.primary)
                }
            }
        }
        .navigationDestination(isPresented: $showGame) {
            if let level = selectedLevel {
                GameView(level: level, settingsViewModel: settingsViewModel)
            }
        }
        .preferredColorScheme(theme.colorScheme)
        .onAppear {
            OrientationManager.shared.lockToPortrait()
            statsViewModel.refresh()
        }
    }
}

struct LevelCard: View {
    let level: Level
    let isUnlocked: Bool
    let stats: LevelStats?
    let theme: ColorTheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isUnlocked ? level.theme.primary : Color.gray.opacity(0.3))
                        .frame(height: 80)
                    
                    if isUnlocked {
                        Text("\(level.id)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
                
                Text(level.name)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(isUnlocked ? theme.primary : theme.subtleText)
                    .lineLimit(1)
                
                if let stats = stats {
                    HStack(spacing: 2) {
                        ForEach(0..<3) { index in
                            Image(systemName: index < getStars(stats: stats) ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundColor(index < getStars(stats: stats) ? .yellow : .gray.opacity(0.4))
                        }
                    }
                } else {
                    HStack(spacing: 2) {
                        ForEach(0..<3) { _ in
                            Image(systemName: "star")
                                .font(.system(size: 10))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                    }
                }
            }
        }
        .disabled(!isUnlocked)
    }
    
    private func getStars(stats: LevelStats) -> Int {
        let targetMoves = level.targetMoves
        if stats.bestMoves <= targetMoves {
            return 3
        } else if stats.bestMoves <= targetMoves + 5 {
            return 2
        } else {
            return 1
        }
    }
}
