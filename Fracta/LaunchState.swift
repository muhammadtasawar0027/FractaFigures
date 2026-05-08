import Foundation
import Combine

final class LaunchState: ObservableObject {
    static let shared = LaunchState()
    
    @Published var browserDestination: String?
    @Published var isPrePermissionVisible: Bool = false
    @Published var noInternetMessage: String?
    
    private let destinationKey = "saved_browser_destination"
    private let expiresKey = "saved_browser_destination_expires"
    private let payloadKey = "saved_config_payload"
    private let permanentNativeKey = "permanent_native_flow"
    private let pushDestinationKey = "saved_push_destination"
    
    private var pendingDestination: String?
    
    private init() {}
    
    func activateStoredDestinationIfValid(now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        if let pushURL = consumePushDestination() {
            browserDestination = pushURL
            return true
        }
        
        guard let destination = UserDefaults.standard.string(forKey: destinationKey),
              UserDefaults.standard.double(forKey: expiresKey) > now else {
            clearStoredDestination()
            browserDestination = nil
            return false
        }
        
        browserDestination = destination
        return true
    }
    
    func saveDestination(_ destination: String, expires: TimeInterval) {
        UserDefaults.standard.set(destination, forKey: destinationKey)
        UserDefaults.standard.set(expires, forKey: expiresKey)
        prepareToOpenBrowser(destination)
    }
    
    func clearStoredDestination() {
        UserDefaults.standard.removeObject(forKey: destinationKey)
        UserDefaults.standard.removeObject(forKey: expiresKey)
    }
    
    func saveConfigPayload(_ payload: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        UserDefaults.standard.set(data, forKey: payloadKey)
    }
    
    func storedConfigPayload() -> [String: Any]? {
        guard let data = UserDefaults.standard.data(forKey: payloadKey),
              let json = try? JSONSerialization.jsonObject(with: data),
              let payload = json as? [String: Any] else { return nil }
        return payload
    }
    
    func isPermanentNativeFlow() -> Bool {
        UserDefaults.standard.bool(forKey: permanentNativeKey)
    }
    
    func lockPermanentNativeFlow() {
        UserDefaults.standard.set(true, forKey: permanentNativeKey)
        clearStoredDestination()
        browserDestination = nil
    }
    
    func showNoInternetMessage() {
        noInternetMessage = "No internet connection. Please turn on the internet and open the app again."
    }
    
    func savePushDestination(_ url: String) {
        UserDefaults.standard.set(url, forKey: pushDestinationKey)
    }
    
    func consumePushDestination() -> String? {
        let url = UserDefaults.standard.string(forKey: pushDestinationKey)
        UserDefaults.standard.removeObject(forKey: pushDestinationKey)
        return url
    }
    
    func handleIncomingPushURL(_ url: String) {
        guard browserDestination == nil, !isPrePermissionVisible else {
            return
        }
        
        savePushDestination(url)
        prepareToOpenBrowser(url)
        UserDefaults.standard.removeObject(forKey: pushDestinationKey)
    }
    
    func prepareToOpenBrowser(_ destination: String) {
        NotificationManager.shared.shouldShowPrePermission { [weak self] shouldShow in
            guard let self = self else { return }
            if shouldShow {
                self.pendingDestination = destination
                self.browserDestination = nil
                self.isPrePermissionVisible = true
            } else {
                self.pendingDestination = nil
                self.isPrePermissionVisible = false
                self.browserDestination = destination
            }
        }
    }
    
    func confirmPrePermissionAndOpen() {
        let target = pendingDestination
        pendingDestination = nil
        isPrePermissionVisible = false
        if let target = target {
            browserDestination = target
        }
    }
}
