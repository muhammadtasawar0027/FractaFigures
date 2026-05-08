import Foundation

struct GameStats: Codable {
    var totalGamesPlayed: Int
    var totalMoves: Int
    var totalTimePlayed: TimeInterval
    var levelsCompleted: Int
    var perfectLevels: Int
    var currentStreak: Int
    var bestStreak: Int
    var levelStats: [Int: LevelStats]
    
    init() {
        totalGamesPlayed = 0
        totalMoves = 0
        totalTimePlayed = 0
        levelsCompleted = 0
        perfectLevels = 0
        currentStreak = 0
        bestStreak = 0
        levelStats = [:]
    }
    
    mutating func updateAfterLevel(levelId: Int, moves: Int, time: TimeInterval, targetMoves: Int) {
        totalGamesPlayed += 1
        totalMoves += moves
        totalTimePlayed += time
        
        let isPerfect = moves <= targetMoves
        
        if levelStats[levelId] == nil {
            levelsCompleted += 1
            levelStats[levelId] = LevelStats(
                levelId: levelId,
                timesPlayed: 1,
                bestMoves: moves,
                bestTime: time,
                totalMoves: moves,
                totalTime: time,
                perfectCompletions: isPerfect ? 1 : 0
            )
        } else {
            levelStats[levelId]?.timesPlayed += 1
            levelStats[levelId]?.totalMoves += moves
            levelStats[levelId]?.totalTime += time
            
            if moves < (levelStats[levelId]?.bestMoves ?? Int.max) {
                levelStats[levelId]?.bestMoves = moves
            }
            if time < (levelStats[levelId]?.bestTime ?? .infinity) {
                levelStats[levelId]?.bestTime = time
            }
            if isPerfect {
                levelStats[levelId]?.perfectCompletions += 1
            }
        }
        
        if isPerfect {
            perfectLevels += 1
            currentStreak += 1
            if currentStreak > bestStreak {
                bestStreak = currentStreak
            }
        } else {
            currentStreak = 0
        }
    }
}

struct LevelStats: Codable {
    let levelId: Int
    var timesPlayed: Int
    var bestMoves: Int
    var bestTime: TimeInterval
    var totalMoves: Int
    var totalTime: TimeInterval
    var perfectCompletions: Int
    
    var averageMoves: Double {
        guard timesPlayed > 0 else { return 0 }
        return Double(totalMoves) / Double(timesPlayed)
    }
    
    var averageTime: TimeInterval {
        guard timesPlayed > 0 else { return 0 }
        return totalTime / Double(timesPlayed)
    }
}
