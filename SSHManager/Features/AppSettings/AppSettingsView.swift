import SwiftUI
import ServiceManagement
import UserNotifications

struct AppSettingsView: View {
    @ObservedObject var configManager: TunnelConfigManager
    @ObservedObject var locManager = LocalizationManager.shared
    @ObservedObject var updateManager = UpdateManager.shared

    var body: some View {
        Form {
            Section(L10n.settingsLanguage) {
                Picker(L10n.settingsLanguage, selection: Binding(
                    get: { locManager.language },
                    set: { locManager.language = $0 }
                )) {
                    ForEach(Language.allCases) { lang in
                        Text(lang.name).tag(lang)
                    }
                }
            }
            
            Section(L10n.settingsMenuBar) {
                HStack(spacing: 10) {
                    Text(L10n.settingsMenuBarSymbol)
                    Spacer()
                    IconPickerButton(selectedIcon: Binding(
                        get: { configManager.menuBarIcon },
                        set: { configManager.saveMenuBarIcon($0) }
                    ))
                }
            }

            Section(L10n.settingsMonitoring) {
                Toggle(isOn: $configManager.autoReconnect) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.settingsAutoReconnect)
                        Text(L10n.settingsAutoReconnectDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if configManager.autoReconnect {
                    HStack {
                        Text(L10n.settingsReconnectDelay)
                        Spacer()
                        Picker("", selection: $configManager.reconnectDelay) {
                            Text("1 \(L10n.settingsSec)").tag(1)
                            Text("2 \(L10n.settingsSec)").tag(2)
                            Text("3 \(L10n.settingsSec)").tag(3)
                            Text("4 \(L10n.settingsSec)").tag(4)
                            Text("5 \(L10n.settingsSec)").tag(5)
                            Text("10 \(L10n.settingsSec)").tag(10)
                        }
                        .labelsHidden()
                        .frame(width: 100)
                    }

                    HStack {
                        Text(L10n.settingsReconnectAttempts)
                        Spacer()
                        Picker("", selection: $configManager.reconnectAttempts) {
                            Text("1").tag(1)
                            Text("2").tag(2)
                            Text("3").tag(3)
                            Text("5").tag(5)
                            Text("10").tag(10)
                            Text(L10n.infinity).tag(Int.max)
                        }
                        .labelsHidden()
                        .frame(width: 80)
                    }

                    HStack {
                        Text(L10n.settingsCheckInterval)
                        Spacer()
                        Picker("", selection: $configManager.checkInterval) {
                            ForEach([1,2,3,4,5,10,15,20,25,30,40,50,60], id: \.self) { s in
                                Text("\(s) \(L10n.settingsSec)").tag(s)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 100)
                    }
                }
            }
            .animation(.easeInOut, value: configManager.autoReconnect)

            Section {
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Версия \(UpdateManager.shared.currentVersion)")
                                .font(.body)
                            if updateManager.isChecking {
                                HStack(spacing: 6) {
                                    ProgressView().controlSize(.small).scaleEffect(0.8)
                                    Text("Проверяем обновления...").font(.caption).foregroundStyle(.secondary)
                                }
                            } else if updateManager.lastCheckUpToDate {
                                Text("Установлена актуальная версия ПО").font(.caption).foregroundStyle(.green)
                            } else if updateManager.updateAvailable, let v = updateManager.availableVersion {
                                Text("Доступно новое обновление — \(v)")
                                    .font(.caption).foregroundStyle(.blue)
                            }
                        }
                        Spacer()
                        if updateManager.updateAvailable {
                            Button("Обновить сейчас") { UpdateManager.shared.showUpdateWindow() }
                                .buttonStyle(.borderedProminent).controlSize(.small)
                        } else {
                            Button("Проверить обновления") { UpdateManager.shared.checkForUpdates() }
                                .buttonStyle(.bordered).controlSize(.small).disabled(updateManager.isChecking)
                        }
                    }

                    Toggle(isOn: $updateManager.autoShowUpdateWindow) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Показывать окно обновления автоматически")
                            Text("При обнаружении новой версии сразу открывать окно установки")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    }
            } header: {
                Text("Обновления")
            }

            Section(L10n.settingsPermissions) {
                Toggle(isOn: Binding(
                    get: { configManager.notificationsEnabled },
                    set: { newValue in
                        if newValue {
                            Task {
                                let granted = await configManager.requestNotifications()
                                if !granted {
                                    configManager.notificationsEnabled = false
                                }
                            }
                        } else {
                            configManager.notificationsEnabled = false
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.settingsNotifications)
                        if configManager.isWaitingForNotificationPermission {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(L10n.settingsWaitingPermission)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(L10n.settingsNotificationsDesc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(configManager.isWaitingForNotificationPermission)

                Toggle(isOn: $configManager.backgroundPermissionGranted) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.settingsBackgroundMode)
                        Text(L10n.settingsBackgroundModeDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: configManager.backgroundPermissionGranted) { _, newValue in
                    if newValue {
                        // Уведомляем пользователя что нужно добавить в фоновый режим
                        showBackgroundAlert()
                    }
                }

                Toggle(isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            // Если не удалось — сбрасываем и ведём в настройки
                            configManager.launchAtLogin = false
                            showLoginItemsAlert()
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.settingsAutoLaunch)
                        Text(L10n.settingsAutoLaunchDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Spacer()
                    Button(L10n.settingsResetPermissions) {
                        resetAllPermissions()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func resetAllPermissions() {
        // Реально сбрасываем разрешения
        configManager.notificationsEnabled = false
        configManager.backgroundPermissionGranted = false
        try? SMAppService.mainApp.unregister()
        configManager.launchAtLogin = false

        // Очищаем доставленные уведомления
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()

        // Ведём пользователя в системные настройки для полного сброса
        Task {
            // Сначала показываем алерт
            let alert = NSAlert()
            alert.messageText = L10n.settingsResetPermissions
            alert.informativeText = "Все разрешения сброшены. Откройте системные настройки чтобы изменить разрешения вручную."
            alert.addButton(withTitle: L10n.settingsOpenSettings)
            alert.addButton(withTitle: "OK")
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications?bundleId=deveber.sshmanager") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func showBackgroundAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.settingsBackgroundMode
        alert.informativeText = "Чтобы приложение работало в фоне, добавьте SSH Manager в «Разрешены в фоне» в Системных настройках → Общие → Элементы входа."
        alert.addButton(withTitle: L10n.settingsOpenSettings)
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func showLoginItemsAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.settingsAutoLaunch
        alert.informativeText = L10n.settingsAutoLaunchDesc
        alert.addButton(withTitle: L10n.settingsOpenSettings)
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        }
    }

}
