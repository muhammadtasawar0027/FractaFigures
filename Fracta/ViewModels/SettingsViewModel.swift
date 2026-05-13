import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var hapticEnabled: Bool {
        didSet {
            settings.hapticEnabled = hapticEnabled
            saveSettings()
            HapticService.shared.setEnabled(hapticEnabled)
        }
    }
    
    @Published var soundEnabled: Bool {
        didSet {
            settings.soundEnabled = soundEnabled
            saveSettings()
        }
    }
    
    @Published var selectedTheme: ColorTheme {
        didSet {
            settings.selectedTheme = selectedTheme
            saveSettings()
        }
    }
    
    @Published var showResetConfirmation: Bool = false
    
    private var settings: UserSettings
    private let storageService = StorageService.shared
    private let hapticService = HapticService.shared
    
    init() {
        settings = storageService.loadUserSettings()
        hapticEnabled = settings.hapticEnabled
        soundEnabled = settings.soundEnabled
        selectedTheme = settings.selectedTheme
        HapticService.shared.setEnabled(settings.hapticEnabled)
    }
    
    private func saveSettings() {
        storageService.saveUserSettings(settings)
    }
    
    func resetAllData() {
        storageService.resetAllData()
        settings = UserSettings()
        hapticEnabled = settings.hapticEnabled
        soundEnabled = settings.soundEnabled
        selectedTheme = settings.selectedTheme
        showResetConfirmation = false
        hapticService.warning()
    }
    
    func confirmReset() {
        showResetConfirmation = true
    }
    
    func cancelReset() {
        showResetConfirmation = false
    }
}
