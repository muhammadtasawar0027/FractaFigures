import Foundation

enum AppConstants {
    static let appsFlyerDevKey = "MCaesbL7TBCb8DhNice8vS"
    static let appsFlyerAppleAppID = "6765881339"
    
    static let appName = "Fracta"
    static var bundleID: String {
        Bundle.main.bundleIdentifier ?? "com.FractaFigures"
    }
    static var storeID: String {
        "id\(appsFlyerAppleAppID)"
    }
    
    static let configEndpoint = "https://wallen-eatery.space/json-test-app/config.php"
    static let privacyPolicyURL = "https://telegra.ph/Support-Fracta-Figures-05-02"
    
    static let osName = "IOS"
    static let pushTokenPlaceholder = "00000000000000000000"
    static let firebaseProjectID = "274283782374"
    
    static let gcdRetryDelay: TimeInterval = 5.0
    static let mergeWaitInterval: TimeInterval = 15.0
    
    static let webViewApplicationName = "Mobile/15E148 appid/\(appsFlyerAppleAppID) appname/\(appName)"
    
    static let pushPermissionRetryDelay: TimeInterval = 60 * 60 * 24 * 3
    
    static let pushDataURLKey = "url"
    static let firstLaunchInternetCheckCompletedKey = "first_launch_internet_check_completed"
    static let firstLaunchNoInternetAlertShownKey = "first_launch_no_internet_alert_shown"
}
