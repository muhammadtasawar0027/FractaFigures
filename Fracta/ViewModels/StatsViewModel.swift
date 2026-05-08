import Foundation
import Combine

@MainActor
final class StatsViewModel: ObservableObject {
    @Published var stats: GameStats
    @Published var selectedLevelId: Int?
    
    private let storageService = StorageService.shared
    
    init() {
        stats = storageService.loadGameStats()
    }
    
    func refresh() {
        stats = storageService.loadGameStats()
    }
    
    var formattedTotalTime: String {
        let hours = Int(stats.totalTimePlayed) / 3600
        let minutes = (Int(stats.totalTimePlayed) % 3600) / 60
        let seconds = Int(stats.totalTimePlayed) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    var completionPercentage: Double {
        guard Level.allLevels.count > 0 else { return 0 }
        return Double(stats.levelsCompleted) / Double(Level.allLevels.count) * 100
    }
    
    func getLevelStats(for levelId: Int) -> LevelStats? {
        stats.levelStats[levelId]
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
