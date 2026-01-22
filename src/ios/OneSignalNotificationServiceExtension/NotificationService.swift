import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = self.bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // ✅ MARK EXTENSION EXECUTION (VISIBLE)
        bestAttemptContent.body += "\n[EXTENSION ACTIVE]"

        // ✅ MARK EXTENSION EXECUTION (DATA FLAG)
        var userInfo = bestAttemptContent.userInfo
        userInfo["__extension_ran"] = true
        bestAttemptContent.userInfo = userInfo

        // ✅ MARK EXTENSION EXECUTION (FILE)
        writeExtensionHeartbeat()

        let payload = bestAttemptContent.userInfo

        // 🔴 SUPPORT FIREBASE IMAGE
        var imageUrlString: String?

        if let fcmOptions = payload["fcm_options"] as? [String: Any],
           let image = fcmOptions["image"] as? String {
            imageUrlString = image
        }

        if imageUrlString == nil,
           let image = payload["image"] as? String {
            imageUrlString = image
        }

        guard let imageUrl = imageUrlString,
              let url = URL(string: imageUrl) else {
            contentHandler(bestAttemptContent)
            return
        }

        downloadImage(from: url) { attachment in
            if let attachment = attachment {
                bestAttemptContent.attachments = [attachment]
            }
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler,
           let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    // MARK: - Image Download
    private func downloadImage(from url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {

        let task = URLSession.shared.downloadTask(with: url) { location, _, _ in
            guard let location = location else {
                completion(nil)
                return
            }

            let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            let fileURL = tmpDir.appendingPathComponent(url.lastPathComponent)

            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.moveItem(at: location, to: fileURL)

            do {
                let attachment = try UNNotificationAttachment(
                    identifier: "image",
                    url: fileURL,
                    options: nil
                )
                completion(attachment)
            } catch {
                completion(nil)
            }
        }

        task.resume()
    }

    // MARK: - Extension Heartbeat (PROOF)
    private func writeExtensionHeartbeat() {
