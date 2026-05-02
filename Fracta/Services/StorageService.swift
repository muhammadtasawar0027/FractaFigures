import Foundation

final class StorageService {
    static let shared = StorageService()
    
    private let userDefaults = UserDefaults.standard
    
    private enum Keys {
        static let gameStats = "fracta_game_stats"
        static let userSettings = "fracta_user_settings"
    }
    
    private init() {}
    
    func saveGameStats(_ stats: GameStats) {
        if let encoded = try? JSONEncoder().encode(stats) {
            userDefaults.set(encoded, forKey: Keys.gameStats)
        }
    }
    
    func loadGameStats() -> GameStats {
        guard let data = userDefaults.data(forKey: Keys.gameStats),
              let stats = try? JSONDecoder().decode(GameStats.self, from: data) else {
            return GameStats()
        }
        return stats
    }
    
    func saveUserSettings(_ settings: UserSettings) {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: Keys.userSettings)
        }
    }
    
    func loadUserSettings() -> UserSettings {
        guard let data = userDefaults.data(forKey: Keys.userSettings),
              let settings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            return UserSettings()
        }
        return settings
    }
    
    func resetAllData() {
        userDefaults.removeObject(forKey: Keys.gameStats)
        userDefaults.removeObject(forKey: Keys.userSettings)
    }
}
