import SwiftUI

@main
struct FractaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainMenuView()
        }
    }
}
