import SwiftUI
import AppKit

@main
struct SSHManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var configManager = TunnelConfigManager.shared
    @Environment(\.openWindow) private var openWindow
    @State private var selectedServer: SSHServer.ID?
    @State private var refreshID = UUID()

    init() {
        let lang = LocalizationManager.shared.language.rawValue
        UserDefaults.standard.set([lang], forKey: "AppleLanguages")
        // Форсируем синхронизацию для Sparkle
        CFPreferencesSetAppValue("AppleLanguages" as CFString, [lang] as CFArray, kCFPreferencesCurrentApplication)
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
    }

    var body: some Scene {
        Window("SSH Manager", id: "settings") {
            SettingsView(configManager: configManager, selectedServer: $selectedServer)
            .frame(width: 850, height: 600)
            .onChange(of: configManager.servers) { _, _ in
                updateWindowTitle()
                refreshID = UUID()
            }
            .onChange(of: selectedServer) { _, _ in
                updateWindowTitle()
            }
            .onAppear {
                if selectedServer == nil, let first = configManager.servers.first {
                    selectedServer = first.id
                }
                updateWindowTitle()
                // Окно открыто — показываем в доке
                NSApp.setActivationPolicy(.regular)
            }
            .onChange(of: configManager.notificationServerToSelect) { _, serverID in
                guard let serverID, let uuid = UUID(uuidString: serverID) else { return }
                selectedServer = uuid
                configManager.notificationServerToSelect = nil
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
                if let window = notification.object as? NSWindow, window.identifier?.rawValue == "settings" {
                    // Окно закрыто крестиком — убираем из дока
                    NSApp.setActivationPolicy(.accessory)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didMiniaturizeNotification)) { notification in
                if let window = notification.object as? NSWindow, window.identifier?.rawValue == "settings" {
                    // Окно свернуто — всё равно показываем в доке
                    NSApp.setActivationPolicy(.regular)
                }
            }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .windowStyle(.hiddenTitleBar)
        .restorationBehavior(.disabled)

        MenuBarExtra {
            MenuBarView(configManager: configManager, selectedServer: $selectedServer)
                .frame(width: 260)
        } label: {
            MenuBarLabelView(configManager: configManager, refreshID: refreshID)
        }
        .menuBarExtraStyle(.window)
    }

    private func updateWindowTitle() {
        let title: String
        if let id = selectedServer, let server = configManager.servers.first(where: { $0.id == id }) {
            title = server.name.isEmpty ? "Сервер" : server.name
        } else {
            title = "SSH Manager"
        }
        NSApp.windows.first { $0.identifier?.rawValue == "settings" }?.title = title
    }
}

struct MenuBarWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            
            // 1. Полностью обесцвечиваем окно
            window.isOpaque = false
            window.backgroundColor = .clear
            
            // 2. Включаем нативную тень macOS, которая будет повторять ФОРМУ ВАШЕГО скругления
            window.hasShadow = true
            
            // 3. Очищаем родительскую рамку окна (NSThemeFrame)
            if let frameView = window.contentView?.superview {
                frameView.wantsLayer = true
                frameView.layer?.backgroundColor = NSColor.clear.cgColor
                
                // Принудительно скрываем системные фоновые плашки (NSVisualEffectView)
                for subview in frameView.subviews {
                    if subview != window.contentView {
                        subview.isHidden = true
                    }
                }
            }
            
            // 4. Очищаем слой самого contentView
            if let contentView = window.contentView {
                contentView.wantsLayer = true
                contentView.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
