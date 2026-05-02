import SwiftUI

struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    private var theme: ColorTheme {
        settingsViewModel.selectedTheme
    }
    
    var body: some View {
        ZStack {
            theme.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    OverviewCard(viewModel: viewModel, theme: theme)
                    
                    ProgressCard(viewModel: viewModel, theme: theme)
                    
                    LevelStatsSection(viewModel: viewModel, theme: theme)
                }
                .padding()
            }
        }
        .navigationTitle("Statistics")
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
        .preferredColorScheme(theme.colorScheme)
        .onAppear {
            viewModel.refresh()
        }
    }
}

struct OverviewCard: View {
    @ObservedObject var viewModel: StatsViewModel
    let theme: ColorTheme
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Overview")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(theme.primary)
            
            HStack(spacing: 20) {
                StatItem(
                    value: "\(viewModel.stats.totalGamesPlayed)",
                    label: "Games Played",
                    icon: "gamecontroller.fill",
                    theme: theme
                )
                
                StatItem(
                    value: "\(viewModel.stats.totalMoves)",
                    label: "Total Moves",
                    icon: "arrow.left.arrow.right",
                    theme: theme
                )
                
                StatItem(
                    value: viewModel.formattedTotalTime,
                    label: "Time Played",
                    icon: "clock.fill",
                    theme: theme
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.primary.opacity(0.1))
        )
    }
}

struct ProgressCard: View {
    @ObservedObject var viewModel: StatsViewModel
    let theme: ColorTheme
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Progress")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(theme.primary)
            
            VStack(spacing: 12) {
                ProgressRow(
                    label: "Levels Completed",
                    value: "\(viewModel.stats.levelsCompleted) / \(Level.allLevels.count)",
                    progress: viewModel.completionPercentage / 100,
                    theme: theme
                )
                
                HStack(spacing: 20) {
                    MiniStatItem(
                        value: "\(viewModel.stats.perfectLevels)",
                        label: "Perfect",
                        icon: "star.fill",
                        color: .yellow,
                        theme: theme
                    )
                    
                    MiniStatItem(
                        value: "\(viewModel.stats.bestStreak)",
                        label: "Best Streak",
                        icon: "flame.fill",
                        color: .orange,
                        theme: theme
                    )
                    
                    MiniStatItem(
                        value: "\(viewModel.stats.currentStreak)",
                        label: "Current",
                        icon: "bolt.fill",
                        color: theme.primary,
                        theme: theme
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.primary.opacity(0.1))
        )
    }
}

struct LevelStatsSection: View {
    @ObservedObject var viewModel: StatsViewModel
    let theme: ColorTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Level Details")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(theme.primary)
            
            ForEach(Level.allLevels) { level in
                if let stats = viewModel.getLevelStats(for: level.id) {
                    LevelStatCard(level: level, stats: stats, viewModel: viewModel, theme: theme)
                }
            }
            
            if viewModel.stats.levelStats.isEmpty {
                Text("No levels completed yet")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.subtleText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
    }
}

struct LevelStatCard: View {
    let level: Level
    let stats: LevelStats
    @ObservedObject var viewModel: StatsViewModel
    let theme: ColorTheme
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(level.theme.primary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("\(level.id)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.primary)
                    
                    Text("Played \(stats.timesPlayed) times")
                        .font(.system(size: 12))
                        .foregroundColor(theme.subtleText)
                }
                
                Spacer()
                
                HStack(spacing: 2) {
                    ForEach(0..<3) { index in
                        Image(systemName: index < getStars() ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundColor(index < getStars() ? .yellow : .gray.opacity(0.4))
                    }
                }
            }
            
            HStack(spacing: 16) {
                MiniStat(label: "Best", value: "\(stats.bestMoves) moves", theme: theme)
                MiniStat(label: "Time", value: viewModel.formatTime(stats.bestTime), theme: theme)
                MiniStat(label: "Avg", value: String(format: "%.1f", stats.averageMoves), theme: theme)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(level.theme.primary.opacity(0.1))
        )
    }
    
    private func getStars() -> Int {
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

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let theme: ColorTheme
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(theme.primary)
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(theme.primary)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(theme.subtleText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MiniStatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    let theme: ColorTheme
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(color)
            }
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(theme.subtleText)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProgressRow: View {
    let label: String
    let value: String
    let progress: Double
    let theme: ColorTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.subtleText)
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.primary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.subtleText.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.primary)
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

struct MiniStat: View {
    let label: String
    let value: String
    let theme: ColorTheme
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(theme.subtleText)
            
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.primary)
        }
        .frame(maxWidth: .infinity)
    }
}
