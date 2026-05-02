import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    private var theme: ColorTheme {
        viewModel.selectedTheme
    }
    
    var body: some View {
        ZStack {
            theme.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    SettingsSection(title: "Preferences", theme: theme) {
                        SettingsToggle(
                            title: "Haptic Feedback",
                            icon: "iphone.radiowaves.left.and.right",
                            isOn: $viewModel.hapticEnabled,
                            theme: theme
                        )
                        
                        SettingsToggle(
                            title: "Sound Effects",
                            icon: "speaker.wave.2.fill",
                            isOn: $viewModel.soundEnabled,
                            theme: theme
                        )
                    }
                    
                    SettingsSection(title: "Color Theme", theme: theme) {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(ColorTheme.allCases, id: \.self) { colorTheme in
                                ThemeButton(
                                    colorTheme: colorTheme,
                                    isSelected: viewModel.selectedTheme == colorTheme,
                                    activeTheme: theme
                                ) {
                                    HapticService.shared.lightImpact()
                                    viewModel.selectedTheme = colorTheme
                                }
                            }
                        }
                    }
                    
                    SettingsSection(title: "Data", theme: theme) {
                        Button {
                            HapticService.shared.warning()
                            viewModel.confirmReset()
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 18))
                                
                                Text("Reset All Data")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Spacer()
                            }
                            .foregroundColor(.red)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.1))
                            )
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
        .navigationTitle("Settings")
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
        .alert("Reset All Data?", isPresented: $viewModel.showResetConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelReset()
            }
            Button("Reset", role: .destructive) {
                viewModel.resetAllData()
            }
        } message: {
            Text("This will delete all your progress and statistics. This action cannot be undone.")
        }
        .preferredColorScheme(theme.colorScheme)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let theme: ColorTheme
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.secondary)
                .textCase(.uppercase)
            
            content
        }
    }
}

struct SettingsToggle: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    let theme: ColorTheme
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(theme.primary)
                .frame(width: 32)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.primary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(theme.primary)
                .labelsHidden()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.primary.opacity(0.1))
        )
    }
}

struct ThemeButton: View {
    let colorTheme: ColorTheme
    let isSelected: Bool
    let activeTheme: ColorTheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(colorTheme.primary)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(activeTheme.isDark ? Color.white : Color.white, lineWidth: isSelected ? 3 : 0)
                    )
                    .shadow(color: isSelected ? colorTheme.primary.opacity(0.5) : .clear, radius: 8)
                
                Text(colorTheme.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? activeTheme.primary : activeTheme.subtleText)
            }
            .padding(.vertical, 8)
        }
    }
}
