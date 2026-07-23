import SwiftUI

struct SettingsView: View {
    @ObservedObject var configManager: TunnelConfigManager
    @Binding var selectedServer: SSHServer.ID?
    @State private var searchText = ""
    @State private var isProgrammaticSelection = false
    @State private var showImportSheet = false
    @ObservedObject private var updateManager = UpdateManager.shared

    private var filteredServers: [SSHServer] {
        if searchText.isEmpty {
            return configManager.servers
        }
        return configManager.servers.filter { server in
            let q = searchText.lowercased()
            if server.name.lowercased().contains(q) ||
               server.sshHost.lowercased().contains(q) ||
               server.sshUser.lowercased().contains(q) {
                return true
            }
            return server.tunnels.contains { tunnel in
                tunnel.name.lowercased().contains(q) ||
                tunnel.localPort.contains(q) ||
                tunnel.remotePort.contains(q)
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            VStack(spacing: 2) {
                if configManager.servers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Нет серверов")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Button("Добавить сервер") {
                            addServer()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                } else {
                    List {
                        ForEach(filteredServers) { server in
                            serverRow(server)
                        }
                        .onDelete { offsets in
                            let toDelete = offsets.map { filteredServers[$0].id }
                            configManager.servers.removeAll { toDelete.contains($0.id) }
                            if let id = selectedServer, !configManager.servers.contains(where: { $0.id == id }) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedServer = nil
                                }
                            }
                            configManager.saveConnections()
                        }
                    }
                    // 6. Устанавливаем стиль списка (обычно для боковой панели используют .sidebar)
                    .listStyle(.sidebar)
                    .padding(0)
                    .searchable(text: $searchText, placement: .sidebar, prompt: "Поиск серверов и туннелей")
                }
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 250, max: 250)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            if let id = selectedServer,
                      let server = configManager.servers.first(where: { $0.id == id }) {
                ServerDetailView(server: binding(for: server), configManager: configManager)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if configManager.showAppSettings {
                AppSettingsView(configManager: configManager)
            } else {
                AboutView()
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
        .navigationSplitViewColumnWidth(min: 600, ideal: 600, max: 600)
        .onAppear {
            Task {
                await configManager.initializeNotifications()
            }
            // Проверяем обновления при открытии окна (тихо)
            UpdateManager.shared.checkAndMaybeShow()
        }
        .onChange(of: selectedServer) { _, _ in
            if !isProgrammaticSelection {
                configManager.showAppSettings = false
            }
            isProgrammaticSelection = false
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: addServer) {
                    Label("Добавить", systemImage: "plus")
                    Text("Добавить сервер")
                }
                
                Spacer()

                Button(action: { showImportSheet = true }) {
                    Label("Импорт / Экспорт", systemImage: "arrow.up.arrow.down")
                }
                .help("Импорт и экспорт SSH config")

                Button(action: {
                    isProgrammaticSelection = true
                    selectedServer = nil
                    configManager.showAppSettings = true
                }) {
                    HStack(spacing: 4) {
                        Label("Настройки", systemImage: "gearshape")
                        if updateManager.updateAvailable {
                            Circle()
                                .fill(.blue)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                Button(action: {
                    isProgrammaticSelection = true
                    selectedServer = nil
                    configManager.showAppSettings = false
                }) {
                    Label("О приложении", systemImage: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showImportSheet) {
            SSHConfigExchangeView(configManager: configManager)
        }
    }

    private func binding(for server: SSHServer) -> Binding<SSHServer> {
        guard let index = configManager.servers.firstIndex(where: { $0.id == server.id }) else {
            return .constant(server)
        }
        return $configManager.servers[index]
    }

    private func addServer() {
        let count = configManager.servers.count
        let name: String
        if count == 0 {
            name = "Сервер"
        } else {
            name = "Сервер \(count)"
        }
        let server = SSHServer(name: name)
        configManager.servers.append(server)
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedServer = server.id
        }
        configManager.saveConnections()
    }

    @ViewBuilder
    private func serverRow(_ server: SSHServer) -> some View {
        ServerRowView(server: server, configManager: configManager)
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedServer = server.id
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedServer == server.id ? Color.gray.opacity(0.3) : Color.clear)
            )
            .listRowInsets(EdgeInsets(top: 0, leading: -8, bottom: 0, trailing: -8))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
