import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Устанавливаем язык ДО инициализации Sparkle
        let lang = LocalizationManager.shared.language.rawValue
        UserDefaults.standard.set([lang], forKey: "AppleLanguages")
        CFPreferencesSetAppValue("AppleLanguages" as CFString, [lang] as CFArray, kCFPreferencesCurrentApplication)
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Клик по телу уведомления — окно откроется, сервер выбран
        if NotificationDelegate.serverToSelect != nil {
            return
        }
        // RECONNECT или другой action — деактивируем, чтобы окно не открылось
        if NotificationDelegate.didClickNotification {
            NotificationDelegate.didClickNotification = false
            NSApp.deactivate()
        }
    }
}
