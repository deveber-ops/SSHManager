import Foundation
import Combine
import Sparkle

/// Менеджер обновлений. Использует стандартный UI Sparkle.
@MainActor
final class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()

    lazy var controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
    var updater: SPUUpdater { controller.updater }

    @Published var updateAvailable = false
    @Published var availableVersion: String?
    @Published var isChecking = false
    @Published var lastCheckUpToDate = false
    @Published var autoShowUpdateWindow: Bool {
        didSet { UserDefaults.standard.set(autoShowUpdateWindow, forKey: "autoShowUpdateWindow") }
    }

    private var skippedVersion: String {
        get { UserDefaults.standard.string(forKey: "skippedUpdateVersion") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "skippedUpdateVersion") }
    }

    private override init() {
        autoShowUpdateWindow = UserDefaults.standard.object(forKey: "autoShowUpdateWindow") as? Bool ?? true
        super.init()
        _ = controller
        try? updater.start()
    }

    // MARK: - Действия

    func checkAndMaybeShow() { check() }
    func checkForUpdates()    { check() }
    func showUpdateWindow()   { syncLang(); updater.checkForUpdates() }

    private func check() {
        syncLang()
        isChecking = true
        updateAvailable = false
        availableVersion = nil
        lastCheckUpToDate = false
        updater.checkForUpdatesInBackground()
    }

    private func syncLang() {
        let lang = LocalizationManager.shared.language.rawValue
        UserDefaults.standard.set([lang], forKey: "AppleLanguages")
    }

    // MARK: - Свойства

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - SPUUpdaterDelegate
extension UpdateManager: SPUUpdaterDelegate {

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        isChecking = false
        lastCheckUpToDate = false
        updateAvailable = true
        availableVersion = item.displayVersionString
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        isChecking = false
        lastCheckUpToDate = true
        updateAvailable = false
        availableVersion = nil
    }
}
