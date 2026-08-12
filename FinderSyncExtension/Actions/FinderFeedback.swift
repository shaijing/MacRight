import Foundation
import UserNotifications

enum FinderFeedback {
    static func error(_ message: String) {
        NSLog("MacRight: \(message)")

        let content = UNMutableNotificationContent()
        content.title = "MacRight"
        content.body = message
        let request = UNNotificationRequest(
            identifier: "macright-error-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("MacRight: 无法显示错误通知：\(error.localizedDescription)")
            }
        }
    }
}
