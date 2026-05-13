import Foundation

struct UserSettings: Codable {
    var hapticEnabled: Bool
    var selectedTheme: ColorTheme
    var soundEnabled: Bool
    var unlockedLevels: Set<Int>
    
    init() {
        hapticEnabled = true
        selectedTheme = .ocean
        soundEnabled = true
        unlockedLevels = [1]
    }
    
    mutating func unlockLevel(_ levelId: Int) {
        unlockedLevels.insert(levelId)
    }
    
    func isLevelUnlocked(_ levelId: Int) -> Bool {
        unlockedLevels.contains(levelId)
    }
}
