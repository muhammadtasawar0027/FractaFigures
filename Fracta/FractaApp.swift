import SwiftUI

@main
struct FractaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var launchState = LaunchState.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            Group {
                if launchState.browserDestination != nil {
                    Color.black.ignoresSafeArea()
                } else if launchState.isPrePermissionVisible {
                    NotificationPermissionView(
                        onAccept: handleAcceptPermission,
                        onSkip: handleSkipPermission
                    )
                } else {
                    MainMenuView()
                }
            }
            .onAppear {
                applyLaunchStateChange()
            }
            .onChange(of: launchState.browserDestination) { _ in
                applyLaunchStateChange()
            }
            .onChange(of: launchState.isPrePermissionVisible) { _ in
                applyLaunchStateChange()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    NotificationManager.shared.clearDeliveredNotificationsAndBadge()
                }
            }
            .alert(
                "No Internet Connection",
                isPresented: Binding(
                    get: { launchState.noInternetMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            launchState.noInternetMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(launchState.noInternetMessage ?? "")
            }
        }
    }
    
    private func applyLaunchStateChange() {
        if let destination = launchState.browserDestination {
            OrientationManager.shared.unlockAllOrientations()
            BrowserPresenter.shared.present(destination: destination)
        } else {
            BrowserPresenter.shared.dismiss()
            OrientationManager.shared.lockToPortrait()
        }
    }
    
    private func handleAcceptPermission() {
        NotificationManager.shared.requestSystemPermission { _ in
            launchState.confirmPrePermissionAndOpen()
        }
    }
    
    private func handleSkipPermission() {
        NotificationManager.shared.registerLastDecline()
        launchState.confirmPrePermissionAndOpen()
    }
}
