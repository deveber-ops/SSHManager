import SwiftUI
import UniformTypeIdentifiers

struct ServerDetailView: View {
    @Binding var server: SSHServer
    @ObservedObject var configManager: TunnelConfigManager

    @State private var tunnelsExpanded: Bool = true
    @State private var isSaving: Bool = false
    @State private var saveError: String? = nil
    @State private var saveTask: Task<Void, Never>?
    @State private var wasSaved: Bool = false

    private var isNewServer: Bool { !wasSaved && !server.isValid }

    private var serverError: String? {
        configManager.validateServer(server)
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                // MARK: - Символ и название
                Section {
                    HStack(spacing: 10) {
                        IconPickerButton(selectedIcon: $server.icon)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Название")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("", text: $server.name, prompt: Text("Название сервера"))
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                            if let err = serverError, err.contains("именем") {
                                Text(err)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                } header: {
                    Text("Символ и название")
                }

                // MARK: - Подключение
                Section {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Хост")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("", text: $server.sshHost, prompt: Text("example.com"))
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Порт")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("", text: $server.sshPort, prompt: Text("22"))
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .frame(width: 80)
                        }
                    }
                    .listRowSeparator(.hidden)

                    if let err = serverError, !err.contains("именем") {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Пользователь")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("", text: $server.sshUser, prompt: Text("root"))
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Тип авторизации")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("", selection: $server.authType) {
                                ForEach(SSHAuthType.allCases) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    .listRowSeparator(.hidden)

                    if server.authType == .password {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Пароль")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            SecureField("", text: $server.sshPassword, prompt: Text("••••••••"))
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                        }
                        .listRowSeparator(.hidden)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Путь к ключу")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                TextField("", text: $server.sshKeyPath, prompt: Text("~/.ssh/id_rsa"))
                                    .textFieldStyle(.roundedBorder)
                                    .font(.body)
                                Button("Обзор...") {
                                    let panel = NSOpenPanel()
                                    panel.allowedContentTypes = [.item]
                                    panel.canChooseFiles = true
                                    panel.canChooseDirectories = false
                                    panel.allowsMultipleSelection = false
                                    panel.showsHiddenFiles = true
                                    if !server.sshKeyPath.isEmpty {
                                        panel.directoryURL = URL(fileURLWithPath: NSString(string: server.sshKeyPath).expandingTildeInPath)
                                            .deletingLastPathComponent()
                                    } else {
                                        let sshDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
                                        if FileManager.default.fileExists(atPath: sshDir.path) {
                                            panel.directoryURL = sshDir
                                        }
                                    }
                                    if panel.runModal() == .OK, let url = panel.url {
                                        server.sshKeyPath = url.path
                                    }
                                }
                                .controlSize(.regular)
                            }
                        }
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    Text("Подключение")
                }

                // MARK: - Туннели
                Section {
                    if tunnelsExpanded {
                        if server.tunnels.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text("Нет туннелей")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else {
                            ForEach($server.tunnels) { $tunnel in
                                TunnelRowView(tunnel: $tunnel, server: $server, configManager: configManager)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                } header: {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            tunnelsExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text("Туннели")
                            Text("(\(server.tunnels.count))")
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Button(action: {
                                let count = server.tunnels.count
                                let name: String
                                if count == 0 {
                                    name = "Туннель"
                                } else {
                                    name = "Туннель \(count)"
                                }
                                let tunnel = TunnelConnection(name: name)
                                server.tunnels.append(tunnel)
                                configManager.saveConnections()
                                if !tunnelsExpanded {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        tunnelsExpanded = true
                                    }
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Добавить")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 4)
                                .hoverBackground(shape: Capsule())
                            }
                            .buttonStyle(.plain)
                            .liquidGlassCapsule(0)
                            .help("Добавить туннель")

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .rotationEffect(.degrees(tunnelsExpanded ? 90 : 0))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.inset)
            .environment(\.defaultMinListRowHeight, 1)

            if isNewServer {
                HStack(spacing: 12) {
                    if let err = saveError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                        }
                    }

                    Spacer()

                    HStack {
                        Button(action: saveServer) {
                            if isSaving {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.8)
                                Text(L10n.serverSaving)
                            } else {
                                Image(systemName: "checkmark.circle")
                                Text(L10n.serverSave)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .controlSize(.large)
                        .disabled(isSaving || !server.isValid)
                        .hoverBackground(shape: Capsule())
                    }
                    .liquidGlassCapsule(0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(.bar.opacity(0.5))
                .overlay(alignment: .top) { Divider() }
            }
        }
        .alert("Ошибка сохранения", isPresented: .init(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .onChange(of: server) { _, _ in
            saveTask?.cancel()
            saveTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                configManager.saveConnections()
            }
        }
    }

    private func saveServer() {
        // Валидация
        if let err = configManager.validateServer(server) {
            saveError = err
            return
        }
        saveError = nil
        isSaving = true

        let s = server
        DispatchQueue.global().async {
            // Проверяем подключение
            var cmd = "/usr/bin/ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o LogLevel=ERROR"
            if !s.sshPort.isEmpty && s.sshPort != "22" { cmd += " -p \(s.sshPort)" }
            if s.authType == .key {
                let resolved = (s.sshKeyPath.isEmpty ? "~/.ssh/id_rsa" : s.sshKeyPath as NSString).expandingTildeInPath
                cmd += " -i \(resolved) -o IdentitiesOnly=yes"
            } else if s.authType == .password {
                cmd += " -o PubkeyAuthentication=no -o PreferredAuthentications=password"
            }
            cmd += " \(s.sshUser)@\(s.sshHost) echo ok"

            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-l", "-c", cmd]
            task.qualityOfService = .userInitiated
            let errPipe = Pipe()
            task.standardOutput = Pipe()
            task.standardError = errPipe
            try? task.run()
            task.waitUntilExit()

            DispatchQueue.main.async {
                self.isSaving = false
                if task.terminationStatus == 0 {
                    // Успех — сохраняем и активируем
                    self.server.isActive = true
                    self.configManager.saveConnections()
                    self.configManager.restartTunnels(for: self.server)
                    self.saveError = nil
                    self.wasSaved = true
                } else {
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let errMsg = String(data: errData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Неизвестная ошибка"
                    self.saveError = "Не удалось подключиться: \(errMsg)"
                }
            }
        }
    }

}
