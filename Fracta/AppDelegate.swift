import UIKit
import UserNotifications
import Network
import AppsFlyerLib
import FirebaseCore
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {
    var orientationLock: UIInterfaceOrientationMask = .portrait
    
    private var conversionData: [String: Any]?
    private var deepLinkData: [String: Any]?
    private var didPrintMergedPayload = false
    private var isWaitingForGCDConversion = false
    private var mergeTimerWorkItem: DispatchWorkItem?
    private var didStartAppsFlyer = false
    private var launchInternetMonitor: NWPathMonitor?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        LaunchState.shared.resetPersistentStateOnFreshInstallIfNeeded()
        NotificationManager.shared.clearDeliveredNotificationsAndBadge()
        NotificationManager.shared.registerForRemoteNotificationsIfAuthorized()
        performFirstLaunchInternetCheckIfNeeded()
        
        if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            handleRemoteNotificationUserInfo(remoteNotification)
        }
        
        if LaunchState.shared.isPermanentNativeFlow() {
            print("[AFSDK] Permanent native flow is active.")
            return true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.continueLaunchFlow()
        }
        
        return true
    }
    
    private func performFirstLaunchInternetCheckIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: AppConstants.firstLaunchInternetCheckCompletedKey) else { return }
        
        defaults.set(true, forKey: AppConstants.firstLaunchInternetCheckCompletedKey)
        
        let monitor = NWPathMonitor()
        launchInternetMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            
            self.launchInternetMonitor?.cancel()
            self.launchInternetMonitor = nil
            
            guard path.status != .satisfied else { return }
            self.showFirstLaunchNoInternetMessageIfNeeded()
        }
        monitor.start(queue: DispatchQueue(label: "com.fracta.firstLaunchInternetCheck"))
    }
    
    private func showFirstLaunchNoInternetMessageIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: AppConstants.firstLaunchNoInternetAlertShownKey) else { return }
        
        defaults.set(true, forKey: AppConstants.firstLaunchNoInternetAlertShownKey)
        DispatchQueue.main.async {
            LaunchState.shared.showNoInternetMessage()
        }
    }
    
    private func continueLaunchFlow() {
        if LaunchState.shared.browserDestination != nil {
            print("[AFSDK] Browser destination already opened by push. Skipping launch flow.")
            return
        }
        
        if LaunchState.shared.activateStoredDestinationIfValid() {
            OrientationManager.shared.unlockAllOrientations()
            print("[AFSDK] Stored browser destination is valid. Browser flow will open.")
            return
        }
        
        if let storedPayload = LaunchState.shared.storedConfigPayload() {
            print("[AFSDK] Stored browser destination expired. Reusing saved payload for config request.")
            sendMergedPayload(storedPayload)
            return
        }
        
        configureAppsFlyerAndStart()
    }
    
    private func configureAppsFlyerAndStart() {
        AppsFlyerLib.shared().appsFlyerDevKey = AppConstants.appsFlyerDevKey
        AppsFlyerLib.shared().appleAppID = AppConstants.appsFlyerAppleAppID
        AppsFlyerLib.shared().delegate = self
        AppsFlyerLib.shared().deepLinkDelegate = self
        
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sendLaunch),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        sendLaunch()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        NotificationManager.shared.clearDeliveredNotificationsAndBadge()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        NotificationManager.shared.clearDeliveredNotificationsAndBadge()
    }
    
    @objc func sendLaunch() {
        guard !didStartAppsFlyer else { return }
        didStartAppsFlyer = true
        
        AppsFlyerLib.shared().start { dictionary, error in
            if let error = error {
                print("AppsFlyer start error: \(error.localizedDescription)")
                self.showNoInternetMessageIfNeeded(error)
                return
            }
            if let dictionary = dictionary {
                print("AppsFlyer start success: \(dictionary)")
            }
        }
        
        let appsFlyerID = AppsFlyerLib.shared().getAppsFlyerUID()
        print("AppsFlyer ID: \(appsFlyerID)")
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if LaunchState.shared.browserDestination != nil || isBrowserPresented(in: window) {
            return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
        }
        return .portrait
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        AppsFlyerLib.shared().handleOpen(url, options: options)
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        AppsFlyerLib.shared().registerUninstall(deviceToken)
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("[Push] APNs token: \(tokenString)")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        logPushPayload(userInfo, source: "didReceiveRemoteNotification")
        handleRemoteNotificationUserInfo(userInfo)
        completionHandler(.newData)
    }
    
    private func handleRemoteNotificationUserInfo(_ userInfo: [AnyHashable: Any]) {
        guard let urlString = extractPushURL(from: userInfo) else { return }
        print("[Push] Received URL from notification: \(urlString)")
        DispatchQueue.main.async {
            LaunchState.shared.handleIncomingPushURL(urlString)
        }
    }
    
    private func logPushPayload(_ userInfo: [AnyHashable: Any], source: String) {
        let safe = sanitizedPushPayload(userInfo)
        let hasMutableContent = (userInfo["aps"] as? [AnyHashable: Any])?["mutable-content"] != nil
        let imageURL = pushImageURL(in: userInfo)
        let appURL = extractPushURL(from: userInfo)
        
        print("==========================================")
        print("[Push] Payload received from \(source)")
        print("[Push] mutable-content present: \(hasMutableContent)")
        print("[Push] image url: \(imageURL ?? "<none>")")
        print("[Push] app url: \(appURL ?? "<none>")")
        printAsJSON(label: "Push payload", payload: safe)
        print("==========================================")
    }
    
    private func sanitizedPushPayload(_ userInfo: [AnyHashable: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in userInfo {
            guard let stringKey = key as? String else { continue }
            result[stringKey] = jsonSafeValue(value)
        }
        return result
    }
    
    private func pushImageURL(in userInfo: [AnyHashable: Any]) -> String? {
        let keys = [
            "image",
            "image_url",
            "imageUrl",
            "picture",
            "thumbnail",
            "attachment-url",
            "attachment_url",
            "gcm.n.image",
            "gcm.notification.image",
            "google.c.a.c_image"
        ]
        for key in keys {
            if let value = userInfo[key] as? String, !value.isEmpty {
                return value
            }
        }
        if let fcmOptions = userInfo["fcm_options"] as? [AnyHashable: Any],
           let value = fcmOptions["image"] as? String, !value.isEmpty {
            return value
        }
        if let fcmOptions = userInfo["fcm_options"] as? [AnyHashable: Any],
           let value = fcmOptions["imageUrl"] as? String, !value.isEmpty {
            return value
        }
        if let data = userInfo["data"] as? [AnyHashable: Any] {
            for key in keys {
                if let value = data[key] as? String, !value.isEmpty {
                    return value
                }
            }
        }
        if let message = userInfo["message"] as? [AnyHashable: Any],
           let data = message["data"] as? [AnyHashable: Any] {
            for key in keys {
                if let value = data[key] as? String, !value.isEmpty {
                    return value
                }
            }
        }
        return recursivePushImageURL(in: userInfo)
    }
    
    private func recursivePushImageURL(in value: Any) -> String? {
        if let dictionary = value as? [AnyHashable: Any] {
            for (key, nestedValue) in dictionary {
                if let key = key as? String,
                   isPushImageKey(key),
                   let url = nestedValue as? String,
                   !url.isEmpty {
                    return url
                }
                if let url = recursivePushImageURL(in: nestedValue) {
                    return url
                }
            }
        }
        
        if let array = value as? [Any] {
            for item in array {
                if let url = recursivePushImageURL(in: item) {
                    return url
                }
            }
        }
        
        return nil
    }
    
    private func isPushImageKey(_ key: String) -> Bool {
        let lowercased = key.lowercased()
        return lowercased.contains("image")
            || lowercased.contains("picture")
            || lowercased.contains("thumbnail")
    }
    
    private func extractPushURL(from userInfo: [AnyHashable: Any]) -> String? {
        if let direct = userInfo[AppConstants.pushDataURLKey] as? String,
           isValidWebURL(direct) {
            return direct
        }
        if let data = userInfo["data"] as? [AnyHashable: Any],
           let dataURL = data[AppConstants.pushDataURLKey] as? String,
           isValidWebURL(dataURL) {
            return dataURL
        }
        if let message = userInfo["message"] as? [AnyHashable: Any] {
            if let data = message["data"] as? [AnyHashable: Any],
               let messageURL = data[AppConstants.pushDataURLKey] as? String,
               isValidWebURL(messageURL) {
                return messageURL
            }
        }
        return nil
    }
    
    private func isValidWebURL(_ value: String) -> Bool {
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https"].contains(scheme)
    }
    
    private func printMergedPayloadIfNeeded(force: Bool = false) {
        guard !didPrintMergedPayload else { return }
        guard !isWaitingForGCDConversion else { return }
        
        let hasConversion = conversionData != nil
        let hasDeepLink = deepLinkData != nil
        
        guard hasConversion else {
            print("[AFSDK] Conversion data is missing. Native flow will remain active.")
            return
        }
        
        let bothReady = hasConversion && hasDeepLink
        let canPrint = bothReady || (force && (hasConversion || hasDeepLink))
        
        guard canPrint else {
            if hasConversion || hasDeepLink {
                scheduleMergeTimeout()
            }
            return
        }
        
        mergeTimerWorkItem?.cancel()
        mergeTimerWorkItem = nil
        didPrintMergedPayload = true
        
        var merged: [String: Any] = deepLinkData ?? [:]
        if let conversion = conversionData {
            for (key, value) in conversion {
                merged[key] = value
            }
        }
        
        finalizeAndSendMergedPayload(merged)
    }
    
    private func handleConversionData(_ data: [String: Any], shouldRetryOrganicWithGCD: Bool) {
        let status = data["af_status"] as? String
        let isOrganic = status?.localizedCaseInsensitiveCompare("Organic") == .orderedSame
        
        if isOrganic && shouldRetryOrganicWithGCD {
            isWaitingForGCDConversion = true
            cancelMergeTimeout()
            print("This is an Organic install.")
            print("[AFSDK] Organic conversion received. GCD retry will start in \(Int(AppConstants.gcdRetryDelay)) seconds.")
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.gcdRetryDelay) { [weak self] in
                self?.fetchGCDConversionData(fallback: data)
            }
            return
        }
        
        conversionData = data
        
        if status?.localizedCaseInsensitiveCompare("Non-organic") == .orderedSame {
            if let sourceID = data["media_source"],
               let campaign = data["campaign"] {
                print("This is a Non-organic install. Media source: \(sourceID)  Campaign: \(campaign)")
            }
        } else if isOrganic {
            print("This is an Organic install.")
        }
        
        printMergedPayloadIfNeeded()
    }
    
    private func fetchGCDConversionData(fallback: [String: Any]) {
        fetchGCDConversionData(
            fallback: fallback,
            candidates: gcdDeviceIDCandidates(),
            index: 0
        )
    }
    
    private func gcdDeviceIDCandidates() -> [(label: String, value: String)] {
        var candidates: [(label: String, value: String)] = [
            ("appsFlyerUID", AppsFlyerLib.shared().getAppsFlyerUID())
        ]
        
        if let idfv = UIDevice.current.identifierForVendor?.uuidString,
           !idfv.isEmpty {
            candidates.append(("idfv", idfv))
        }
        
        return candidates
    }
    
    private func fetchGCDConversionData(fallback: [String: Any], candidates: [(label: String, value: String)], index: Int) {
        guard index < candidates.count else {
            finishGCDConversionData(fallback)
            return
        }
        
        let candidate = candidates[index]
        var components = URLComponents()
        components.scheme = "https"
        components.host = "gcdsdk.appsflyer.com"
        components.path = "/install_data/v4.0/\(AppConstants.storeID)"
        components.queryItems = [
            URLQueryItem(name: "devkey", value: AppConstants.appsFlyerDevKey),
            URLQueryItem(name: "device_id", value: candidate.value)
        ]
        
        guard let url = components.url else {
            finishGCDConversionData(fallback)
            return
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("[AFSDK] GCD request with \(candidate.label): \(url.absoluteString)")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("[AFSDK] GCD request error: \(error.localizedDescription)")
                self?.showNoInternetMessageIfNeeded(error)
                DispatchQueue.main.async {
                    self?.finishGCDConversionData(fallback)
                }
                return
            }
            
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("[AFSDK] GCD response status: \(statusCode)")
            if statusCode == 404, index + 1 < candidates.count {
                print("[AFSDK] GCD returned 404 for \(candidate.label). Trying next device_id candidate.")
                self?.fetchGCDConversionData(fallback: fallback, candidates: candidates, index: index + 1)
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data),
                  let payload = json as? [String: Any] else {
                if let data = data, let responseBody = String(data: data, encoding: .utf8), !responseBody.isEmpty {
                    print("[AFSDK] GCD response body: \(responseBody)")
                }
                DispatchQueue.main.async {
                    self?.finishGCDConversionData(fallback)
                }
                return
            }
            
            var safePayload: [String: Any] = [:]
            for (key, value) in payload {
                safePayload[key] = self?.jsonSafeValue(value) ?? value
            }
            
            DispatchQueue.main.async {
                self?.printAsJSON(label: "GCD Conversion data JSON", payload: safePayload)
                self?.finishGCDConversionData(safePayload)
            }
        }.resume()
    }
    
    private func finishGCDConversionData(_ data: [String: Any]) {
        isWaitingForGCDConversion = false
        conversionData = data
        printMergedPayloadIfNeeded()
    }
    
    private func injectTemplateFields(into merged: inout [String: Any]) {
        let templateKeys: [String: Any] = [
            "af_id": AppsFlyerLib.shared().getAppsFlyerUID(),
            "bundle_id": AppConstants.bundleID,
            "os": AppConstants.osName,
            "store_id": AppConstants.storeID,
            "locale": currentLocaleRFC3066(),
            "push_token": NotificationManager.shared.currentPushToken(),
            "firebase_project_id": AppConstants.firebaseProjectID
        ]
        for (key, value) in templateKeys {
            merged[key] = value
        }
    }
    
    private func finalizeAndSendMergedPayload(_ mergedBeforeTemplate: [String: Any]) {
        var merged = mergedBeforeTemplate
        injectTemplateFields(into: &merged)
        let flat = flattenedPayload(merged)
        LaunchState.shared.saveConfigPayload(flat)
        printAsJSON(label: "Merged payload", payload: flat)
        sendMergedPayload(flat)
    }
    
    private func flattenedPayload(_ payload: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (_, value) in payload {
            if let nested = value as? [String: Any] {
                for (nestedKey, nestedValue) in nested {
                    result[nestedKey] = nestedValue
                }
            }
        }
        for (key, value) in payload where !(value is [String: Any]) {
            result[key] = value
        }
        return result
    }
    
    private func sendMergedPayload(_ payload: [String: Any]) {
        guard let url = URL(string: AppConstants.configEndpoint) else { return }
        guard JSONSerialization.isValidJSONObject(payload),
              let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            print("[AFSDK] Failed to serialize merged payload for upload")
            return
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[AFSDK] Merged payload upload error: \(error.localizedDescription)")
                self.showNoInternetMessageIfNeeded(error)
                print("[AFSDK] Native flow will remain active.")
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            print("[AFSDK] Merged payload upload status: \(status)")
            if !responseBody.isEmpty {
                print("[AFSDK] Merged payload response body: \(responseBody)")
            }
            self.handleMergedPayloadResponse(data: data)
        }.resume()
    }
    
    private func handleMergedPayloadResponse(data: Data?) {
        guard !LaunchState.shared.isPermanentNativeFlow() else {
            print("[AFSDK] Permanent native flow is active. Ignoring browser destination from server response.")
            return
        }
        
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data),
              let payload = json as? [String: Any] else {
            print("[AFSDK] Server response is empty or invalid. Native flow will remain active.")
            LaunchState.shared.recordFirstServerDecision(hasValidLink: false)
            if LaunchState.shared.isPermanentNativeFlow() {
                print("[AFSDK] First server response had no valid link. Permanent native flow was saved.")
            }
            return
        }
        
        let hasOK = (payload["ok"] as? Bool) == true
        let destination = browserDestination(from: payload)
        let expires = browserDestinationExpires(from: payload)
        let hasValidLink = hasOK && destination != nil
        
        LaunchState.shared.recordFirstServerDecision(hasValidLink: hasValidLink)
        if LaunchState.shared.isPermanentNativeFlow() {
            print("[AFSDK] First server response had no valid link. Permanent native flow was saved.")
            return
        }
        
        guard hasOK else {
            print("[AFSDK] Server returned ok=false. Native flow will remain active.")
            return
        }
        
        guard let destination = destination,
              let expires = expires,
              expires > Date().timeIntervalSince1970 else {
            print("[AFSDK] Server returned ok=true without a valid destination or expires. Native flow will remain active.")
            return
        }
        
        DispatchQueue.main.async {
            OrientationManager.shared.unlockAllOrientations()
            LaunchState.shared.saveDestination(destination, expires: expires)
        }
    }
    
    private func showNoInternetMessageIfNeeded(_ error: Error) {
        guard let urlError = error as? URLError else { return }
        let offlineCodes: [URLError.Code] = [
            .notConnectedToInternet,
            .networkConnectionLost,
            .cannotFindHost,
            .cannotConnectToHost,
            .dnsLookupFailed,
            .timedOut
        ]
        guard offlineCodes.contains(urlError.code) else { return }
        DispatchQueue.main.async {
            LaunchState.shared.showNoInternetMessage()
        }
    }
    
    private func browserDestination(from payload: [String: Any]) -> String? {
        let keys = ["url", "link", "destination", "browser_url", "browserUrl"]
        for key in keys {
            if let value = payload[key] as? String,
               let url = URL(string: value),
               let scheme = url.scheme?.lowercased(),
               ["http", "https"].contains(scheme) {
                return value
            }
        }
        if let data = payload["data"] as? [String: Any] {
            return browserDestination(from: data)
        }
        return nil
    }
    
    private func browserDestinationExpires(from payload: [String: Any]) -> TimeInterval? {
        if let value = payload["expires"] as? TimeInterval {
            return value
        }
        if let value = payload["expires"] as? Int {
            return TimeInterval(value)
        }
        if let value = payload["expires"] as? String,
           let interval = TimeInterval(value) {
            return interval
        }
        if let data = payload["data"] as? [String: Any] {
            return browserDestinationExpires(from: data)
        }
        return nil
    }
    
    private func scheduleMergeTimeout() {
        guard mergeTimerWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            self?.mergeTimerWorkItem = nil
            self?.printMergedPayloadIfNeeded(force: true)
        }
        mergeTimerWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.mergeWaitInterval, execute: workItem)
    }
    
    private func cancelMergeTimeout() {
        mergeTimerWorkItem?.cancel()
        mergeTimerWorkItem = nil
    }
    
    private func currentLocaleRFC3066() -> String {
        if let preferred = Locale.preferredLanguages.first, !preferred.isEmpty {
            return preferred
        }
        return Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
    }
    
    fileprivate func jsonSafeValue(_ value: Any) -> Any {
        if let date = value as? Date {
            let formatter = ISO8601DateFormatter()
            return formatter.string(from: date)
        }
        if let url = value as? URL {
            return url.absoluteString
        }
        if let dict = value as? [AnyHashable: Any] {
            var result: [String: Any] = [:]
            for (key, value) in dict {
                guard let stringKey = key as? String else { continue }
                result[stringKey] = jsonSafeValue(value)
            }
            return result
        }
        if let array = value as? [Any] {
            return array.map { jsonSafeValue($0) }
        }
        if value is NSNull { return NSNull() }
        if JSONSerialization.isValidJSONObject([value]) {
            return value
        }
        if value is NSNumber || value is String || value is Bool || value is Int || value is Double {
            return value
        }
        return "\(value)"
    }
    
    private func isBrowserPresented(in window: UIWindow?) -> Bool {
        if let root = window?.rootViewController {
            return containsBrowserController(in: root)
        }
        
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for sceneWindow in scene.windows where containsBrowserController(in: sceneWindow.rootViewController) {
                return true
            }
        }
        return false
    }
    
    private func containsBrowserController(in root: UIViewController?) -> Bool {
        guard var top = root else { return false }
        if top is ContentBrowserController {
            return true
        }
        while let presented = top.presentedViewController {
            if presented is ContentBrowserController {
                return true
            }
            top = presented
        }
        return false
    }
    
    fileprivate func printAsJSON(label: String, payload: Any) {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let jsonString = String(data: data, encoding: .utf8) else {
            print("[AFSDK] \(label) (raw): \(payload)")
            return
        }
        print("[AFSDK] \(label):")
        print(jsonString)
    }
}

extension AppDelegate: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ installData: [AnyHashable: Any]) {
        print("==========================================")
        
        var stringKeyed: [String: Any] = [:]
        for (key, value) in installData {
            guard let stringKey = key as? String else { continue }
            stringKeyed[stringKey] = jsonSafeValue(value)
        }
        
        printAsJSON(label: "Conversion data JSON", payload: stringKeyed)
        print("==========================================")
        
        handleConversionData(stringKeyed, shouldRetryOrganicWithGCD: true)
    }
    
    func onConversionDataFail(_ error: Error) {
        print("==========================================")
        print("Conversion data error: \(error.localizedDescription)")
        print("==========================================")
        showNoInternetMessageIfNeeded(error)
        
        printMergedPayloadIfNeeded()
    }
}

extension AppDelegate: DeepLinkDelegate {
    func didResolveDeepLink(_ result: DeepLinkResult) {
        print("==========================================")
        print("[AFSDK] didResolveDeepLink called")
        
        switch result.status {
        case .notFound:
            print("[AFSDK] Deep link not found")
            print("==========================================")
            printMergedPayloadIfNeeded()
            return
        case .failure:
            if let error = result.error {
                print("[AFSDK] Deep link error: \(error.localizedDescription)")
            }
            print("==========================================")
            printMergedPayloadIfNeeded()
            return
        case .found:
            print("[AFSDK] Deep link found")
        @unknown default:
            print("[AFSDK] Deep link unknown status")
            print("==========================================")
            printMergedPayloadIfNeeded()
            return
        }
        
        guard let deepLinkObj: DeepLink = result.deepLink else {
            print("[AFSDK] Could not extract deep link object")
            print("==========================================")
            printMergedPayloadIfNeeded()
            return
        }
        
        if deepLinkObj.isDeferred {
            print("[AFSDK] This is a deferred deep link")
        } else {
            print("[AFSDK] This is a direct deep link")
        }
        
        var jsonPayload: [String: Any] = [:]
        jsonPayload["isDeferred"] = deepLinkObj.isDeferred
        for (key, value) in deepLinkObj.clickEvent {
            jsonPayload[key] = jsonSafeValue(value)
        }
        if let deepLinkValue = deepLinkObj.deeplinkValue {
            jsonPayload["deep_link_value"] = deepLinkValue
        }
        if let matchType = deepLinkObj.matchType {
            jsonPayload["match_type"] = matchType
        }
        if let mediaSource = deepLinkObj.mediaSource {
            jsonPayload["media_source"] = mediaSource
        }
        if let campaign = deepLinkObj.campaign {
            jsonPayload["campaign"] = campaign
        }
        if let campaignId = deepLinkObj.campaignId {
            jsonPayload["campaign_id"] = campaignId
        }
        
        deepLinkData = jsonPayload
        
        printAsJSON(label: "DeepLink JSON", payload: jsonPayload)
        
        print("==========================================")
        
        printMergedPayloadIfNeeded()
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        print("[Push] FCM token: \(fcmToken)")
        NotificationManager.shared.storeFcmToken(fcmToken)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        logPushPayload(userInfo, source: "willPresent (foreground)")
        print("[Push] Attachments delivered to app: \(notification.request.content.attachments.count)")
        if let urlString = extractPushURL(from: userInfo) {
            DispatchQueue.main.async {
                LaunchState.shared.savePushDestination(urlString)
            }
        }
        completionHandler([.banner, .list, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        logPushPayload(userInfo, source: "didReceive (tap)")
        print("[Push] Attachments delivered to app: \(response.notification.request.content.attachments.count)")
        handleRemoteNotificationUserInfo(userInfo)
        completionHandler()
    }
}
