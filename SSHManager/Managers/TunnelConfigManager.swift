import Foundation
import Combine
import ServiceManagement
import AppKit
import UniformTypeIdentifiers
import UserNotifications

@MainActor
class TunnelConfigManager: ObservableObject {
    static let shared = TunnelConfigManager()

    @Published var servers: [SSHServer] = []
    @Published var showAppSettings: Bool = false
    @Published var menuBarIcon: String = "app.connected.to.app.below.fill"
    @Published var launchAtLogin: Bool = false {
        didSet {
            guard !isLoadingSettings else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Login item error: \(error)")
            }
            saveAll()
        }
    }
    @Published var backgroundPermissionGranted: Bool = false {
        didSet { saveAll() }
    }
    @Published var autoReconnect: Bool = false {
        didSet {
            if !isLoadingSettings { restartMonitoring() }
            saveAll()
        }
    }
    @Published var reconnectDelay: Int = 5 {
        didSet {
            if !isLoadingSettings { restartMonitoring() }
            saveAll()
        }
    }
    @Published var checkInterval: Int = 30 {
        didSet {
            if !isLoadingSettings { restartMonitoring() }
            saveAll()
        }
    }
    @Published var reconnectAttempts: Int = 3 {
        didSet { saveAll() }
    }
    @Published var notificationsEnabled: Bool = false {
        didSet { saveAll() }
    }
    @Published var isWaitingForNotificationPermission: Bool = false
    @Published var notificationServerToSelect: String?

    private var monitoringActive = false
    private var lastKnownStates: [String: Bool] = [:]
    private var isLoadingSettings = false
    private var lastNotificationTimes: [String: Date] = [:]
    private let notificationCooldown: TimeInterval = 30
    private var manualReconnectKeys: Set<String> = []

    nonisolated private var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh/sshmanager.json")
    }

    private var needsStartupRestart = false

    init() {
        loadAll()
        needsStartupRestart = !servers.isEmpty
        // Завершаем все туннели при выходе из приложения
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(killAllTunnels),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        // Проверяем статус уведомлений при возвращении в приложение
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func applicationDidBecomeActive() {
        if isWaitingForNotificationPermission {
            isWaitingForNotificationPermission = false
        }
        // Первый запуск — запускаем активные туннели и запрашиваем разрешения
        if needsStartupRestart {
            needsStartupRestart = false
            restartAllActiveTunnels()
            requestPermissionsOnFirstLaunch()
        }
        // Клик по телу уведомления — выбираем сервер
        if let serverID = NotificationDelegate.serverToSelect {
            NotificationDelegate.serverToSelect = nil
            notificationServerToSelect = serverID
            showAppSettings = true
        }
        guard notificationCenterInitialized else { return }
        Task {
            await checkNotificationStatus()
        }
    }

    @objc private func killAllTunnels() {
        for server in servers {
            for tunnel in server.tunnels {
                TunnelManager.shared.killSSHTunnel(tunnel: tunnel)
            }
        }
    }

    func saveMenuBarIcon(_ icon: String) {
        menuBarIcon = icon
        saveAll()
    }

    func loadAll() {
        let url = configURL
        if FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let config = try? JSONDecoder().decode(AppConfig.self, from: data) {
            servers = config.servers
            applySettings(config.settings)
        } else {
            loadLegacy()
        }
        // Синхронизируем launchAtLogin с реальным статусом
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func loadLegacy() {
        // Миграция из старого tunnels.json + UserDefaults
        let oldURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh/tunnels.json")
        if FileManager.default.fileExists(atPath: oldURL.path),
           let data = try? Data(contentsOf: oldURL),
           let decoded = try? JSONDecoder().decode([SSHServer].self, from: data) {
            servers = decoded
            try? FileManager.default.removeItem(at: oldURL)
        }
        loadSettingsFromDefaults()
        // Сохраняем в новый формат
        saveAll()
    }

    func saveAll() {
        let config = AppConfig(
            settings: currentSettings(),
            servers: servers.filter { !$0.sshHost.isEmpty && !$0.sshUser.isEmpty }
        )
        let url = configURL
        do {
            let dir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Save error: \(error)")
        }
    }

    private func currentSettings() -> AppSettings {
        AppSettings(
            menuBarIcon: menuBarIcon,
            launchAtLogin: launchAtLogin,
            autoReconnect: autoReconnect,
            reconnectDelay: reconnectDelay,
            reconnectAttempts: reconnectAttempts,
            checkInterval: checkInterval,
            notificationsEnabled: notificationsEnabled
        )
    }

    private func applySettings(_ s: AppSettings) {
        isLoadingSettings = true
        menuBarIcon = s.menuBarIcon
        launchAtLogin = s.launchAtLogin
        autoReconnect = s.autoReconnect
        reconnectDelay = s.reconnectDelay
        reconnectAttempts = s.reconnectAttempts
        checkInterval = s.checkInterval
        notificationsEnabled = s.notificationsEnabled
        isLoadingSettings = false
    }

    private func loadSettingsFromDefaults() {
        isLoadingSettings = true
        menuBarIcon = UserDefaults.standard.string(forKey: "menuBarIcon") ?? menuBarIcon
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        autoReconnect = UserDefaults.standard.bool(forKey: "autoReconnect")
        reconnectDelay = UserDefaults.standard.object(forKey: "reconnectDelay") as? Int ?? 5
        reconnectAttempts = UserDefaults.standard.object(forKey: "reconnectAttempts") as? Int ?? 3
        checkInterval = UserDefaults.standard.object(forKey: "checkInterval") as? Int ?? 10
        notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        isLoadingSettings = false
    }

    func validateServer(_ server: SSHServer) -> String? {
        let others = servers.filter { $0.id != server.id }
        if others.contains(where: { $0.name.caseInsensitiveCompare(server.name) == .orderedSame && !server.name.isEmpty }) {
            return "Сервер с именем «\(server.name)» уже существует"
        }
        if !server.sshHost.isEmpty {
            let dup = others.first(where: { $0.sshHost == server.sshHost && $0.sshPort == server.sshPort })
            if dup != nil {
                let portStr = server.sshPort.isEmpty ? "22" : server.sshPort
                return "Сервер \(server.sshHost):\(portStr) уже добавлен"
            }
        }
        return nil
    }

    func validateTunnel(_ tunnel: TunnelConnection, in server: SSHServer) -> String? {
        let others = server.tunnels.filter { $0.id != tunnel.id }
        if others.contains(where: { $0.name.caseInsensitiveCompare(tunnel.name) == .orderedSame && !tunnel.name.isEmpty }) {
            return "Туннель с именем «\(tunnel.name)» уже существует"
        }
        if !tunnel.remoteHost.isEmpty || !tunnel.remotePort.isEmpty || !tunnel.localPort.isEmpty {
            let dup = others.first(where: {
                $0.remoteHost == tunnel.remoteHost &&
                $0.remotePort == tunnel.remotePort &&
                $0.localPort == tunnel.localPort
            })
            if dup != nil {
                let effectivePort = tunnel.effectiveLocalPort
                return "Туннель \(tunnel.remoteHost):\(tunnel.remotePort)→:\(effectivePort) уже добавлен"
            }
        }
        return nil
    }

    // MARK: - Сохранение (устаревший метод, используйте saveAll)
    func saveConnections() { saveAll() }

    func restartTunnels(for server: SSHServer) {
        guard let idx = servers.firstIndex(where: { $0.id == server.id }) else { return }
        let s = servers[idx]
        // Всегда убиваем процессы туннелей, даже если сервер неактивен
        for tunnel in s.tunnels {
            TunnelManager.shared.killSSHTunnel(tunnel: tunnel)
        }
        guard s.isActive, s.isValid else { return }
        for tunnel in s.tunnels where tunnel.isActive && tunnel.isValid {
            TunnelManager.shared.runSSHTunnel(tunnel: tunnel, server: s)
        }
        initLastKnownStates()
        startMonitoring()
    }

    func restartSingleTunnel(tunnel: TunnelConnection, server: SSHServer) {
        TunnelManager.shared.killSSHTunnel(tunnel: tunnel)
        guard server.isActive, server.isValid, tunnel.isActive, tunnel.isValid else { return }
        TunnelManager.shared.runSSHTunnel(tunnel: tunnel, server: server)
        lastKnownStates["\(server.id)-\(tunnel.id)"] = true
        startMonitoring()
    }

    func restartAllActiveTunnels() {
        for server in servers where server.isActive && server.isValid {
            for tunnel in server.tunnels {
                TunnelManager.shared.killSSHTunnel(tunnel: tunnel)
                if tunnel.isActive && tunnel.isValid {
                    TunnelManager.shared.runSSHTunnel(tunnel: tunnel, server: server)
                }
            }
        }
        initLastKnownStates()
        startMonitoring()
    }

    private func initLastKnownStates() {
        lastKnownStates = [:]
        for server in servers where server.isActive {
            Task {
                let result = await TunnelManager.shared.checkServerConnection(server)
                await MainActor.run {
                    lastKnownStates["server-\(server.id)"] = result.success
                }
            }
            for tunnel in server.tunnels where tunnel.isActive {
                let tunnelUp = TunnelManager.shared.checkTunnelIsRunning(tunnel)
                lastKnownStates["\(server.id)-\(tunnel.id)"] = tunnelUp
            }
        }
    }

    // MARK: - Мониторинг туннелей

    func startMonitoring() {
        stopMonitoring()
        let hasActive = servers.contains { $0.isActive }
        guard hasActive else { return }
        monitoringActive = true
        scheduleNextCheck()
    }

    private func scheduleNextCheck() {
        let interval = TimeInterval(max(checkInterval, 5))
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
            guard let self, self.monitoringActive else { return }
            self.checkTunnels()
            self.scheduleNextCheck()
        }
    }

    func stopMonitoring() {
        monitoringActive = false
    }

    private var notificationCenterInitialized = false

    func initializeNotifications() async {
        guard !notificationCenterInitialized else { return }
        notificationCenterInitialized = true

        let center = UNUserNotificationCenter.current()
        await MainActor.run {
            center.delegate = NotificationDelegate.shared
        }
        await checkNotificationStatus(center: center)
        if !isDebuggerAttached() {
            registerNotificationCategories(center: center)
        }

        // Запрашиваем разрешение при первом запуске
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = await requestNotifications()
        }
    }

    private func requestPermissionsOnFirstLaunch() {
        // Запрашиваем уведомления при первом запуске
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = await requestNotifications()
            }
        }
    }

    private func isDebuggerAttached() -> Bool {
        // Xcode/debugger sets OS_ACTIVITY_DT_MODE
        return ProcessInfo.processInfo.environment["OS_ACTIVITY_DT_MODE"] != nil
    }

    private func registerNotificationCategories(center: UNUserNotificationCenter) {
        let reconnect = UNNotificationAction(identifier: "RECONNECT", title: "Переподключиться", options: [])

        let serverDown = UNNotificationCategory(
            identifier: "SERVER_DOWN",
            actions: [reconnect],
            intentIdentifiers: [],
            options: []
        )
        let tunnelDown = UNNotificationCategory(
            identifier: "TUNNEL_DOWN",
            actions: [reconnect],
            intentIdentifiers: [],
            options: []
        )
        // Без кнопки — для авто-реконнекта
        let serverDownAuto = UNNotificationCategory(
            identifier: "SERVER_DOWN_AUTO",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let tunnelDownAuto = UNNotificationCategory(
            identifier: "TUNNEL_DOWN_AUTO",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([serverDown, tunnelDown, serverDownAuto, tunnelDownAuto])
    }

    func checkNotificationStatus(center: UNUserNotificationCenter? = nil) async {
        guard notificationCenterInitialized else { return }
        let center = center ?? UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        await MainActor.run {
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                notificationsEnabled = true
            case .denied, .notDetermined:
                notificationsEnabled = false
            @unknown default:
                notificationsEnabled = false
            }
        }
    }

    func requestNotifications() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .denied:
            showNotificationSettingsAlert()
            return false
        case .authorized, .provisional, .ephemeral:
            await MainActor.run { notificationsEnabled = true }
            return true
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: UNAuthorizationOptions([.alert, .sound]))) ?? false
            if granted {
                await MainActor.run { notificationsEnabled = true }
            } else {
                await MainActor.run { notificationsEnabled = false }
                showNotificationSettingsAlert()
            }
            return granted
        @unknown default:
            return false
        }
    }

    @MainActor
    private func showNotificationSettingsAlert() {
        let alert = NSAlert()
        alert.messageText = "Разрешение уведомлений"
        alert.informativeText = "Чтобы SSH Manager мог показывать уведомления, разрешите их в системных настройках."
        alert.addButton(withTitle: "Открыть настройки")
        alert.addButton(withTitle: "OK")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            isWaitingForNotificationPermission = true
            openSystemNotificationSettings()
        }
    }

    private func openSystemNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications?bundleId=deveber.sshmanager") {
            NSWorkspace.shared.open(url)
        }
    }

    private func restartMonitoring() {
        guard !servers.isEmpty else { return }
        let hasActive = servers.contains { $0.isActive }
        if hasActive { startMonitoring() }
    }

    private func canSendNotification(key: String) -> Bool {
        let now = Date()
        if let last = lastNotificationTimes[key], now.timeIntervalSince(last) < notificationCooldown {
            return false
        }
        lastNotificationTimes[key] = now
        return true
    }

    private func checkTunnels() {
        let serverIDs = servers.filter(\.isActive).map(\.id)

        for serverID in serverIDs {
            guard let server = servers.first(where: { $0.id == serverID }) else { continue }
            let serverKey = "server-\(server.id)"
            let serverWasUp = lastKnownStates[serverKey] ?? true

            Task {
                let result = await TunnelManager.shared.checkServerConnection(server)
                await MainActor.run {
                    guard let sIdx = self.servers.firstIndex(where: { $0.id == server.id }) else { return }
                    self.lastKnownStates[serverKey] = result.success

                    if serverWasUp && !result.success {
                        self.servers[sIdx].isActive = false
                        if self.autoReconnect {
                            let delay = Double(max(self.reconnectDelay, 1))
                            let reconnectServerID = server.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                                guard let self else { return }
                                let key = "server-\(reconnectServerID)"
                                guard !self.manualReconnectKeys.contains(key) else { return }
                                Task {
                                    guard let freshIdx = self.servers.firstIndex(where: { $0.id == reconnectServerID }) else { return }
                                    let stillDown = await TunnelManager.shared.checkServerConnection(self.servers[freshIdx])
                                    if stillDown.success {
                                        self.servers[freshIdx].isActive = true
                                        for tunnel in self.servers[freshIdx].tunnels where tunnel.isActive {
                                            TunnelManager.shared.killSSHTunnel(tunnel: tunnel)
                                            TunnelManager.shared.runSSHTunnel(tunnel: tunnel, server: self.servers[freshIdx])
                                        }
                                        self.lastKnownStates[serverKey] = true
                                        if self.canSendNotification(key: "server-up-\(reconnectServerID)") {
                                            self.sendServerUpNotification(server: self.servers[freshIdx])
                                        }
                                    }
                                }
                            }
                        }
                        if self.canSendNotification(key: "server-down-\(server.id)") {
                            self.sendServerDownNotification(server: self.servers[sIdx], reason: result.reason)
                        }
                    } else if !serverWasUp && result.success {
                        self.servers[sIdx].isActive = true
                        if self.canSendNotification(key: "server-up-\(server.id)") {
                            self.sendServerUpNotification(server: self.servers[sIdx])
                        }
                    }
                }
            }

            // Проверяем туннели синхронно (lsof быстро, не влияет на UI при малом количестве)
            let activeTunnels = server.tunnels.filter(\.isActive)
            var downTunnels: [TunnelConnection] = []
            var upTunnels: [TunnelConnection] = []

            for tunnel in activeTunnels {
                let tunnelKey = "\(server.id)-\(tunnel.id)"
                let wasRunning = lastKnownStates[tunnelKey] ?? true
                let isRunning = TunnelManager.shared.checkTunnelIsRunning(tunnel)

                guard let sIdx = self.servers.firstIndex(where: { $0.id == server.id }),
                      let tIdx = self.servers[sIdx].tunnels.firstIndex(where: { $0.id == tunnel.id })
                else { continue }

                lastKnownStates[tunnelKey] = isRunning

                if wasRunning && !isRunning {
                    self.servers[sIdx].tunnels[tIdx].isActive = false
                    downTunnels.append(self.servers[sIdx].tunnels[tIdx])
                } else if !wasRunning && isRunning {
                    self.servers[sIdx].tunnels[tIdx].isActive = true
                    upTunnels.append(self.servers[sIdx].tunnels[tIdx])
                }
            }

            // Отправляем сгруппированные уведомления
            if !downTunnels.isEmpty {
                let sIdx = self.servers.firstIndex(where: { $0.id == server.id })
                guard let sIdx else { return }
                let currentServer = self.servers[sIdx]

                let names = downTunnels.map { $0.name.isEmpty ? "туннель" : $0.name }.joined(separator: ", ")
                let key = "tunnels-down-\(server.id)-\(downTunnels.map(\.id.uuidString).joined())"
                if self.canSendNotification(key: key) {
                    self.sendTunnelsDownNotification(server: currentServer, tunnels: downTunnels, names: names)
                }
                // Автопереподключение
                if self.autoReconnect {
                    let delay = Double(max(self.reconnectDelay, 1))
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        guard let self else { return }
                        for tunnel in downTunnels {
                            let tKey = "\(server.id)-\(tunnel.id)"
                            guard !self.manualReconnectKeys.contains(tKey) else { continue }
                            guard let freshSIdx = self.servers.firstIndex(where: { $0.id == server.id }),
                                  let freshTIdx = self.servers[freshSIdx].tunnels.firstIndex(where: { $0.id == tunnel.id })
                            else { continue }
                            let stillDown = !TunnelManager.shared.checkTunnelIsRunning(self.servers[freshSIdx].tunnels[freshTIdx])
                            if stillDown {
                                self.servers[freshSIdx].tunnels[freshTIdx].isActive = true
                                TunnelManager.shared.killSSHTunnel(tunnel: self.servers[freshSIdx].tunnels[freshTIdx])
                                TunnelManager.shared.runSSHTunnel(tunnel: self.servers[freshSIdx].tunnels[freshTIdx], server: self.servers[freshSIdx])
                                self.lastKnownStates["\(server.id)-\(tunnel.id)"] = true
                                if self.canSendNotification(key: "tunnel-up-\(server.id)-\(tunnel.id)") {
                                    self.sendTunnelUpNotification(server: self.servers[freshSIdx], tunnel: self.servers[freshSIdx].tunnels[freshTIdx])
                                }
                            }
                        }
                    }
                }
            }

            for tunnel in upTunnels {
                if let sIdx = self.servers.firstIndex(where: { $0.id == server.id }),
                   self.canSendNotification(key: "tunnel-up-\(server.id)-\(tunnel.id)") {
                    self.sendTunnelUpNotification(server: self.servers[sIdx], tunnel: tunnel)
                }
            }
        }
    }

    private func deliverNotification(identifier: String, title: String, body: String, server: SSHServer, categoryIdentifier: String? = nil) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "ssh-\(server.id)"
        if let catID = categoryIdentifier {
            content.categoryIdentifier = catID
        }
        content.userInfo = [
            "serverID": server.id.uuidString,
            "tunnelID": "",
        ]
        if let attachment = serverIconAttachment(for: server) {
            content.attachments = [attachment]
        }
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        center.add(request)
    }

    private func deliverTunnelNotification(identifier: String, title: String, body: String, server: SSHServer, tunnel: TunnelConnection, categoryIdentifier: String? = nil) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "ssh-tunnel-\(server.id)-\(tunnel.id)"
        if let catID = categoryIdentifier {
            content.categoryIdentifier = catID
        }
        content.userInfo = [
            "serverID": server.id.uuidString,
            "tunnelID": tunnel.id.uuidString,
        ]
        if let attachment = serverIconAttachment(for: server) {
            content.attachments = [attachment]
        }
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        center.add(request)
    }

    private func serverIconAttachment(for server: SSHServer) -> UNNotificationAttachment? {
        let symbolName = server.icon.isEmpty ? "server.rack" : server.icon
        let size = CGSize(width: 60, height: 60)
        let renderer = NSImage(size: size)
        renderer.lockFocus()
        let bgRect = CGRect(origin: .zero, size: size)
        let circlePath = NSBezierPath(ovalIn: bgRect)
        NSColor.systemGray.setFill()
        circlePath.fill()
        NSColor.darkGray.setStroke()
        circlePath.lineWidth = 1
        circlePath.stroke()
        let config = NSImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            let symbolRect = CGRect(
                x: (size.width - 28) / 2,
                y: (size.height - 28) / 2,
                width: 28,
                height: 28
            )
            symbol.draw(in: symbolRect)
        }
        renderer.unlockFocus()

        guard let cgImage = renderer.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("notif-icons", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let tempURL = tempDir.appendingPathComponent("server-icon-\(server.id.uuidString).png")
        try? pngData.write(to: tempURL)
        return try? UNNotificationAttachment(identifier: "ServerIcon", url: tempURL, options: nil)
    }

    private func sendServerDownNotification(server: SSHServer, reason: String = "") {
        guard notificationsEnabled else { return }
        var body = "Подключение к серверу разорвано"
        if !reason.isEmpty { body += ": \(reason)" }
        let category: String
        if autoReconnect {
            body += ". Автопереподключение через \(reconnectDelay) сек"
            category = "SERVER_DOWN_AUTO"
        } else {
            category = "SERVER_DOWN"
        }
        deliverNotification(
            identifier: "server-down-\(server.id)",
            title: "SSH Manager → \(server.name)",
            body: body,
            server: server,
            categoryIdentifier: category
        )
    }

    private func sendServerUpNotification(server: SSHServer) {
        guard notificationsEnabled else { return }
        deliverNotification(
            identifier: "server-up-\(server.id)",
            title: "SSH Manager → \(server.name)",
            body: "Подключение к серверу восстановлено",
            server: server
        )
    }

    private func sendTunnelDownNotification(server: SSHServer, tunnel: TunnelConnection) {
        guard notificationsEnabled else { return }
        var body = "Подключение к туннелю \(tunnel.name) разорвано"
        let category: String
        if autoReconnect {
            body += ". Автопереподключение через \(reconnectDelay) сек"
            category = "TUNNEL_DOWN_AUTO"
        } else {
            category = "TUNNEL_DOWN"
        }
        deliverTunnelNotification(
            identifier: "tunnel-down-\(server.id)-\(tunnel.id)",
            title: "SSH Manager → \(server.name)",
            body: body,
            server: server,
            tunnel: tunnel,
            categoryIdentifier: category
        )
    }

    private func sendTunnelsDownNotification(server: SSHServer, tunnels: [TunnelConnection], names: String) {
        guard notificationsEnabled else { return }
        var body: String
        if tunnels.count == 1, let t = tunnels.first {
            body = "Подключение к туннелю \(t.name.isEmpty ? "без имени" : t.name) разорвано"
        } else {
            body = "Разорвано подключение к туннелям: \(names)"
        }
        let category: String
        if autoReconnect {
            body += ". Автопереподключение через \(reconnectDelay) сек"
            category = "TUNNEL_DOWN_AUTO"
        } else {
            category = "TUNNEL_DOWN"
        }
        deliverTunnelNotification(
            identifier: "tunnels-down-\(server.id)-\(Date().timeIntervalSince1970)",
            title: "SSH Manager → \(server.name)",
            body: body,
            server: server,
            tunnel: tunnels.first!,
            categoryIdentifier: category
        )
    }

    private func sendTunnelUpNotification(server: SSHServer, tunnel: TunnelConnection) {
        guard notificationsEnabled else { return }
        deliverTunnelNotification(
            identifier: "tunnel-up-\(server.id)-\(tunnel.id)",
            title: "SSH Manager → \(server.name)",
            body: "Подключение к туннелю \(tunnel.name) восстановлено",
            server: server,
            tunnel: tunnel
        )
    }

    private func sendReconnectErrorNotification(server: SSHServer, tunnel: TunnelConnection?) {
        guard notificationsEnabled else { return }
        let body: String
        if let tunnel {
            body = "Ошибка переподключения туннеля \(tunnel.name)"
        } else {
            body = "Ошибка переподключения сервера"
        }
        if let tunnel {
            deliverTunnelNotification(
                identifier: "reconnect-error-\(server.id)-\(tunnel.id)-\(Date().timeIntervalSince1970)",
                title: "SSH Manager → \(server.name)",
                body: body,
                server: server,
                tunnel: tunnel
            )
        } else {
            deliverNotification(
                identifier: "reconnect-error-\(server.id)-server-\(Date().timeIntervalSince1970)",
                title: "SSH Manager → \(server.name)",
                body: body,
                server: server
            )
        }
    }

    func handleNotificationAction(identifier: String, serverID: String, tunnelID: String) {
        guard let serverUUID = UUID(uuidString: serverID),
              servers.contains(where: { $0.id == serverUUID })
        else { return }

        switch identifier {
        case "RECONNECT":
            if tunnelID.isEmpty {
                // Сервер — перезапускаем все туннели
                manualReconnectKeys.insert("server-\(serverID)")
                guard let idx = servers.firstIndex(where: { $0.id == serverUUID }) else { return }
                servers[idx].isActive = true
                var allSuccess = true
                for tunnel in servers[idx].tunnels where tunnel.isActive {
                    TunnelManager.shared.killSSHTunnel(tunnel: tunnel)
                    let success = TunnelManager.shared.runSSHTunnel(tunnel: tunnel, server: servers[idx])
                    if !success { allSuccess = false }
                }
                lastKnownStates["server-\(serverID)"] = true
                if allSuccess {
                    sendServerUpNotification(server: servers[idx])
                } else {
                    sendReconnectErrorNotification(server: servers[idx], tunnel: nil)
                }
            } else if let tunnelUUID = UUID(uuidString: tunnelID),
                      let serverIdx = servers.firstIndex(where: { $0.id == serverUUID }),
                      let tunnelIdx = servers[serverIdx].tunnels.firstIndex(where: { $0.id == tunnelUUID }) {
                manualReconnectKeys.insert("\(serverID)-\(tunnelID)")
                servers[serverIdx].tunnels[tunnelIdx].isActive = true
                TunnelManager.shared.killSSHTunnel(tunnel: servers[serverIdx].tunnels[tunnelIdx])
                let success = TunnelManager.shared.runSSHTunnel(tunnel: servers[serverIdx].tunnels[tunnelIdx], server: servers[serverIdx])
                lastKnownStates["\(serverID)-\(tunnelID)"] = true
                if success {
                    sendTunnelUpNotification(server: servers[serverIdx], tunnel: servers[serverIdx].tunnels[tunnelIdx])
                } else {
                    sendReconnectErrorNotification(server: servers[serverIdx], tunnel: servers[serverIdx].tunnels[tunnelIdx])
                }
            }
        case "CANCEL":
            if tunnelID.isEmpty {
                lastKnownStates["server-\(serverID)"] = false
            } else {
                lastKnownStates["\(serverID)-\(tunnelID)"] = false
            }
        default:
            break
        }
    }
}
