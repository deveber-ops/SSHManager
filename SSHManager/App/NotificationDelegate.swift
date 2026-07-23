import Foundation
import UserNotifications

// MARK: - Обработчик уведомлений
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    /// Сервер для выбора при открытии приложения (клик по телу уведомления)
    static var serverToSelect: String?
    /// Фоновый экшн — приложение не должно открываться
    static var didClickNotification = false

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let serverID = userInfo["serverID"] as? String
        let tunnelID = userInfo["tunnelID"] as? String

        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // Клик по телу — запоминаем сервер и открываем приложение
            NotificationDelegate.serverToSelect = serverID
            completionHandler()

        case "RECONNECT":
            // Кнопка «Переподключиться» — переподключаем в фоне
            NotificationDelegate.didClickNotification = true
            if let serverID, let tunnelID {
                Task { @MainActor in
                    TunnelConfigManager.shared.handleNotificationAction(
                        identifier: "RECONNECT",
                        serverID: serverID,
                        tunnelID: tunnelID
                    )
                    completionHandler()
                }
            } else {
                completionHandler()
            }

        default:
            completionHandler()
        }
    }
}
