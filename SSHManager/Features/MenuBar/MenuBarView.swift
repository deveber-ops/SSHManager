import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var configManager: TunnelConfigManager
    @Binding var selectedServer: SSHServer.ID?
    @Environment(\.openWindow) var openWindow
    
    // Состояния ховера для нижних кнопок
    @State private var isHoveringOpen = false
    @State private var isHoveringQuit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if configManager.servers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Нет серверов")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        // Используем $configManager.servers для получения $server Binding
                        ForEach(configManager.servers) { server in
                            ServerMenuRowView(
                                server: binding(for: server),
                                onSelect: {
                                    configManager.showAppSettings = false
                                    selectedServer = server.id
                                    openWindow(id: "settings")
                                    NSApp.activate(ignoringOtherApps: true)
                                }
                            )
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: 400)

                // Нижняя панель действий
                Section {
                    HStack(spacing: 0) {
                        // Кнопка "Открыть" с ховером
                        Button {
                            selectedServer = nil
                            configManager.showAppSettings = false
                            openWindow(id: "settings")
                            NSApp.activate(ignoringOtherApps: true)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.system(size: 11))
                                Text("Открыть")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(isHoveringOpen ? .primary : .secondary)
                            .background(isHoveringOpen ? Color.primary.opacity(0.1) : Color.clear)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isHoveringOpen = hovering
                            }
                        }

                        // Кнопка "Выйти" с ховером
                        Button(action: { NSApp.terminate(nil) }) {
                            ZStack {
                                // 1. Обычное состояние (Красный цвет)
                                HStack(spacing: 5) {
                                    Image(systemName: "power")
                                        .font(.system(size: 11))
                                    Text("Выйти")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundStyle(.red)
                                .opacity(isHoveringQuit ? 0 : 1)

                                // 2. Состояние при наведении (Белый цвет)
                                HStack(spacing: 5) {
                                    Image(systemName: "power")
                                        .font(.system(size: 11))
                                    Text("Выйти")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundStyle(.white)
                                .opacity(isHoveringQuit ? 1 : 0)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isHoveringQuit ? Color.red.opacity(0.2) : Color.clear)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            isHoveringQuit = hovering
                        }
                        .animation(.easeInOut(duration: 0.15), value: isHoveringQuit)
                    }
                    .liquidGlassCapsule()
                }
                .padding(4)
            }
        }
        .frame(minWidth: 240, minHeight: 400)
    }

    private func binding(for server: SSHServer) -> Binding<SSHServer> {
        guard let idx = configManager.servers.firstIndex(where: { $0.id == server.id }) else {
            return .constant(server)
        }
        return $configManager.servers[idx]
    }
}
