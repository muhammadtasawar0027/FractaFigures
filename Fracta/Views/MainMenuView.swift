import SwiftUI

struct MainMenuView: View {
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var showLevelSelect = false
    @State private var showSettings = false
    @State private var showStats = false
    @State private var showPrivacyPolicy = false
    @State private var animateTitle = false
    
    private var theme: ColorTheme {
        settingsViewModel.selectedTheme
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Text("FRACTA")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(theme.primary)
                            .scaleEffect(animateTitle ? 1.0 : 0.8)
                            .opacity(animateTitle ? 1.0 : 0.0)
                        
                        Text("Puzzle Adventure")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(theme.secondary)
                            .opacity(animateTitle ? 1.0 : 0.0)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        MenuButton(title: "Play", icon: "play.fill", theme: theme) {
                            HapticService.shared.lightImpact()
                            showLevelSelect = true
                        }
                        
                        MenuButton(title: "Statistics", icon: "chart.bar.fill", theme: theme) {
                            HapticService.shared.lightImpact()
                            showStats = true
                        }
                        
                        MenuButton(title: "Settings", icon: "gearshape.fill", theme: theme) {
                            HapticService.shared.lightImpact()
                            showSettings = true
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    Button {
                        HapticService.shared.selection()
                        showPrivacyPolicy = true
                    } label: {
                        Text("Privacy Policy")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.secondary.opacity(0.9))
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 22)
                }
            }
            .navigationDestination(isPresented: $showLevelSelect) {
                LevelSelectView(settingsViewModel: settingsViewModel)
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView(viewModel: settingsViewModel)
            }
            .navigationDestination(isPresented: $showStats) {
                StatsView()
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyModalView(urlString: AppConstants.privacyPolicyURL)
            }
        }
        .preferredColorScheme(theme.colorScheme)
        .onAppear {
            OrientationManager.shared.lockToPortrait()
            withAnimation(.easeOut(duration: 0.8)) {
                animateTitle = true
            }
        }
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    let theme: ColorTheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.primary)
                    .shadow(color: theme.primary.opacity(0.4), radius: 8, x: 0, y: 4)
            )
        }
    }
}
