import UserNotifications
import OneSignal

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        let userInfo = request.content.userInfo

        // Let OneSignal handle its own payload
        OneSignal.didReceiveNotificationExtensionRequest(
            request,
            with: bestAttemptContent
        )

        // Firebase image support
        var imageUrl: String?

        if let fcmOptions = userInfo["fcm_options"] as? [String: Any],
           let image = fcmOptions["image"] as? String {
            imageUrl = image
        }

        if let notification = userInfo["notification"] as? [String: Any],
           let image = notification["image"] as? String {
            imageUrl = image
        }

        guard let imageUrlString = imageUrl,
              let imageURL = URL(string: imageUrlString) else {
            contentHandler(bestAttemptContent)
            return
        }

        URLSession.shared.downloadTask(with: imageURL) { tempURL, _, _ in
            guard let tempURL = tempURL else {
                contentHandler(bestAttemptContent)
                return
            }

            let localURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(imageURL.lastPathComponent)

            try? FileManager.default.moveItem(at: tempURL, to: localURL)

            if let attachment = try? UNNotificationAttachment(
                identifier: "image",
                url: localURL,
                options: nil
            ) {
                bestAttemptContent.attachments = [attachment]
            }

            contentHandler(bestAttemptContent)
        }.resume()
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler,
           let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
