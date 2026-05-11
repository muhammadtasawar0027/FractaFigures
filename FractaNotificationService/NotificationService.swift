import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    private var downloadTask: URLSessionDataTask?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        let userInfo = request.content.userInfo
        logPayload(userInfo)
        
        guard let bestAttemptContent else {
            contentHandler(request.content)
            return
        }
        
        applyAutoBadge(to: bestAttemptContent) { [weak self] in
            guard let self else { return }
            
            guard let imageURL = self.imageURL(from: userInfo) else {
                NSLog("[PushExt] No image URL found in payload. Returning content with badge = %@", String(describing: bestAttemptContent.badge))
                contentHandler(bestAttemptContent)
                return
            }
            
            NSLog("[PushExt] Downloading image from %@", imageURL.absoluteString)
            self.downloadAttachment(from: imageURL) { [weak self] attachment in
                guard let self else { return }
                if let attachment {
                    bestAttemptContent.attachments = [attachment]
                    NSLog("[PushExt] Attachment added.")
                } else {
                    NSLog("[PushExt] Attachment download failed.")
                }
                contentHandler(bestAttemptContent)
                self.contentHandler = nil
            }
        }
    }
    
    private func applyAutoBadge(to content: UNMutableNotificationContent, completion: @escaping () -> Void) {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let nextBadge = notifications.count + 1
            content.badge = NSNumber(value: nextBadge)
            NSLog("[PushExt] Badge auto-set to %d", nextBadge)
            completion()
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        NSLog("[PushExt] serviceExtensionTimeWillExpire called.")
        downloadTask?.cancel()
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
        contentHandler = nil
    }
    
    private func logPayload(_ userInfo: [AnyHashable: Any]) {
        var safe: [String: Any] = [:]
        for (key, value) in userInfo {
            guard let stringKey = key as? String else { continue }
            safe[stringKey] = jsonSafeValue(value)
        }
        let hasMutableContent = (userInfo["aps"] as? [AnyHashable: Any])?["mutable-content"] != nil
        NSLog("[PushExt] ==========================================")
        NSLog("[PushExt] didReceive called.")
        NSLog("[PushExt] mutable-content present: %@", hasMutableContent ? "true" : "false")
        if JSONSerialization.isValidJSONObject(safe),
           let data = try? JSONSerialization.data(withJSONObject: safe, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            NSLog("[PushExt] Push payload: %@", json)
        } else {
            NSLog("[PushExt] Push payload (raw): %@", String(describing: userInfo))
        }
        NSLog("[PushExt] ==========================================")
    }
    
    private func jsonSafeValue(_ value: Any) -> Any {
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
        if value is NSNumber || value is String || value is Bool {
            return value
        }
        if JSONSerialization.isValidJSONObject([value]) {
            return value
        }
        return "\(value)"
    }
    
    private func imageURL(from userInfo: [AnyHashable: Any]) -> URL? {
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
            if let url = validURL(userInfo[key]) {
                return url
            }
        }
        
        if let fcmOptions = userInfo["fcm_options"] as? [AnyHashable: Any],
           let url = validURL(fcmOptions["image"]) {
            return url
        }
        if let fcmOptions = userInfo["fcm_options"] as? [AnyHashable: Any],
           let url = validURL(fcmOptions["imageUrl"]) {
            return url
        }
        
        if let data = userInfo["data"] as? [AnyHashable: Any] {
            for key in keys {
                if let url = validURL(data[key]) {
                    return url
                }
            }
        }
        
        if let message = userInfo["message"] as? [AnyHashable: Any],
           let data = message["data"] as? [AnyHashable: Any] {
            for key in keys {
                if let url = validURL(data[key]) {
                    return url
                }
            }
        }
        
        if let url = recursiveImageURL(from: userInfo) {
            return url
        }
        
        return nil
    }
    
    private func recursiveImageURL(from value: Any) -> URL? {
        if let dictionary = value as? [AnyHashable: Any] {
            for (key, nestedValue) in dictionary {
                if let key = key as? String,
                   isImageKey(key),
                   let url = validURL(nestedValue) {
                    return url
                }
                if let url = recursiveImageURL(from: nestedValue) {
                    return url
                }
            }
        }
        
        if let array = value as? [Any] {
            for item in array {
                if let url = recursiveImageURL(from: item) {
                    return url
                }
            }
        }
        
        return nil
    }
    
    private func isImageKey(_ key: String) -> Bool {
        let lowercased = key.lowercased()
        return lowercased.contains("image")
            || lowercased.contains("picture")
            || lowercased.contains("thumbnail")
    }
    
    private func validURL(_ value: Any?) -> URL? {
        guard let string = value as? String,
              let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }
        return url
    }
    
    private func downloadAttachment(from url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        downloadTask = URLSession.shared.dataTask(with: url) { data, response, _ in
            guard let data,
                  let attachment = self.attachment(from: data, response: response, sourceURL: url) else {
                completion(nil)
                return
            }
            completion(attachment)
        }
        downloadTask?.resume()
    }
    
    private func attachment(from data: Data, response: URLResponse?, sourceURL: URL) -> UNNotificationAttachment? {
        let fileExtension = resolvedFileExtension(response: response, sourceURL: sourceURL)
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        
        do {
            try data.write(to: fileURL)
            return try UNNotificationAttachment(identifier: "image", url: fileURL)
        } catch {
            return nil
        }
    }
    
    private func resolvedFileExtension(response: URLResponse?, sourceURL: URL) -> String {
        let pathExtension = sourceURL.pathExtension
        if !pathExtension.isEmpty {
            return pathExtension
        }
        
        guard let mimeType = response?.mimeType?.lowercased() else {
            return "jpg"
        }
        
        switch mimeType {
        case "image/png":
            return "png"
        case "image/gif":
            return "gif"
        case "image/heic":
            return "heic"
        case "image/webp":
            return "webp"
        default:
            return "jpg"
        }
    }
}
