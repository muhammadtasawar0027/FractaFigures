import UIKit
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    
    private let lastDeclineKey = "push_permission_last_decline"
    private let pushTokenKey = "stored_fcm_token"
    
    private init() {}
    
    func storeFcmToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: pushTokenKey)
    }
    
    func storedFcmToken() -> String? {
        UserDefaults.standard.string(forKey: pushTokenKey)
    }
    
    func currentPushToken() -> String {
        storedFcmToken() ?? AppConstants.pushTokenPlaceholder
    }
    
    func clearDeliveredNotificationsAndBadge() {
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.setBadgeCount(0) { error in
            if let error {
                print("[Push] Failed to clear badge count: \(error.localizedDescription)")
            } else {
                print("[Push] Delivered notifications and badge count were cleared.")
            }
        }
    }
    
    func registerLastDecline() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastDeclineKey)
    }
    
    func shouldShowPrePermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    completion(true)
                case .denied:
                    let lastDecline = UserDefaults.standard.double(forKey: self.lastDeclineKey)
                    let now = Date().timeIntervalSince1970
                    if lastDecline == 0 {
                        completion(true)
                    } else {
                        completion(now - lastDecline > AppConstants.pushPermissionRetryDelay)
                    }
                case .authorized, .provisional, .ephemeral:
                    completion(false)
                @unknown default:
                    completion(false)
                }
            }
        }
    }
    
    func requestSystemPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    self.registerLastDecline()
                }
                completion(granted)
            }
        }
    }
    
    func registerForRemoteNotificationsIfAuthorized() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}
