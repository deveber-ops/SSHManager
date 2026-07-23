import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SSHConfigExchangeView: View {
    @ObservedObject var configManager: TunnelConfigManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: Tab = .import

    // Import state
    @State private var importHosts: [ParsedSSHHost] = []
    @State private var importSelectedIDs: Set<UUID> = []
    @State private var importErrorMessage: String?
    @State private var importPath: String = ""

    // Export state
    @State private var exportSelectedIDs: Set<UUID> = []
    @State private var exportPath: String = ""

    private let defaultPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".ssh/config").path

    private var validServers: [SSHServer] {
        configManager.servers.filter(\.isValid)
    }

    enum Tab: String, CaseIterable {
        case `import` = "Импорт"
        case export = "Экспорт"

        var icon: String {
            switch self {
            case .import: return "arrow.down.doc"
            case .export: return "arrow.up.doc"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок с табами
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                        }
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedTab == tab
                                ? Color.primary.opacity(0.08)
                                : Color.clear
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button("Отмена") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            if selectedTab == .import {
                importContent
            } else {
                exportContent
            }
        }
        .frame(width: 480, height: 440)
        .onAppear {
            importPath = defaultPath
            exportPath = defaultPath
            parseImportFile(importPath)
            exportSelectedIDs = Set(validServers.map(\.id))
        }
    }

    // MARK: - Import

    private var importContent: some View {
        VStack(spacing: 0) {
            filePickerRow(
                icon: "arrow.down.doc",
                path: importPath,
                action: { selectImportFile() }
            )

            Divider()

            if let error = importErrorMessage {
                emptyState(icon: "exclamationmark.triangle", text: error, iconColor: .yellow)
            } else if importHosts.isEmpty {
                emptyState(icon: "doc.text.magnifyingglass", text: "Хосты не найдены в файле")
            } else {
                hostList
                bottomBar(
                    count: importSelectedIDs.count,
                    emptyText: "Выберите хосты для импорта",
                    selectedText: "Выбрано:",
                    onSelectAll: { importSelectedIDs = Set(importHosts.map(\.id)) },
                    actionTitle: "Импортировать",
                    isActionDisabled: importSelectedIDs.isEmpty,
                    onAction: importSelected
                )
            }
        }
    }

    private var hostList: some View {
        List {
            ForEach(importHosts) { host in
                HStack {
                    Toggle(isOn: importBinding(for: host.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(host.host)
                                .font(.system(size: 13, weight: .medium))
                            HStack(spacing: 4) {
                                Text("\(host.user)@\(host.hostName)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                if host.port != "22" && !host.port.isEmpty {
                                    Text(":\(host.port)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if !host.identityFile.isEmpty {
                                Text(host.identityFile)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Export

    private var exportContent: some View {
        VStack(spacing: 0) {
            filePickerRow(
                icon: "arrow.up.doc",
                path: exportPath,
                action: { selectExportFile() }
            )

            Divider()

            if validServers.isEmpty {
                emptyState(icon: "tray", text: "Нет серверов для экспорта")
            } else {
                List {
                    ForEach(validServers) { server in
                        HStack {
                            Toggle(isOn: exportBinding(for: server.id)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(server.name.isEmpty ? "Без имени" : server.name)
                                        .font(.system(size: 13, weight: .medium))
                                    HStack(spacing: 4) {
                                        Text("\(server.sshUser)@\(server.sshHost)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                        let port = server.sshPort.isEmpty ? "22" : server.sshPort
                                        if port != "22" {
                                            Text(":\(port)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    if server.authType == .key && !server.sshKeyPath.isEmpty {
                                        Text(server.sshKeyPath)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.inset)
                bottomBar(
                    count: exportSelectedIDs.count,
                    emptyText: "Выберите серверы для экспорта",
                    selectedText: "Выбрано:",
                    onSelectAll: { exportSelectedIDs = Set(validServers.map(\.id)) },
                    actionTitle: "Экспортировать",
                    isActionDisabled: exportSelectedIDs.isEmpty,
                    onAction: doExport
                )
            }
        }
    }

    // MARK: - Shared components

    private func filePickerRow(icon: String, path: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .font(.system(size: 11))
            Text(shortPath(path))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button("Выбрать файл...") {
                action()
            }
            .buttonStyle(.link)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04))
    }

    private func emptyState(icon: String, text: String, iconColor: Color = .secondary) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(iconColor)
            Text(text)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bottomBar(
        count: Int,
        emptyText: String,
        selectedText: String,
        onSelectAll: @escaping () -> Void,
        actionTitle: String,
        isActionDisabled: Bool,
        onAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text(count == 0 ? emptyText : "\(selectedText) \(count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Выбрать все") { onSelectAll() }
                    .buttonStyle(.link)
                    .controlSize(.small)
                Button(actionTitle) { onAction() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isActionDisabled)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Helpers

    private func shortPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func selectImportFile() {
        let panel = NSOpenPanel()
        panel.title = "Выберите SSH config файл"
        panel.allowedContentTypes = [.plainText, .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: importPath).deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importPath = url.path
        parseImportFile(importPath)
    }

    private func parseImportFile(_ path: String) {
        importErrorMessage = nil
        guard FileManager.default.fileExists(atPath: path) else {
            importErrorMessage = "Файл не найден: \(shortPath(path))"
            importHosts = []
            importSelectedIDs = []
            return
        }
        importHosts = SSHConfigParser.parse(path)
        if importHosts.isEmpty {
            importErrorMessage = "Хосты не найдены в выбранном файле"
        }
        let existingPairs = Set(configManager.servers.map {
            "\($0.sshHost):\($0.sshPort.isEmpty ? "22" : $0.sshPort)"
        })
        importSelectedIDs = Set(importHosts.filter { host in
            let pair = "\(host.hostName):\(host.port.isEmpty ? "22" : host.port)"
            return !existingPairs.contains(pair)
        }.map(\.id))
    }

    private func selectExportFile() {
        let panel = NSSavePanel()
        panel.title = "Сохранить SSH config"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: exportPath).deletingLastPathComponent()
        panel.nameFieldStringValue = URL(fileURLWithPath: exportPath).lastPathComponent
        guard panel.runModal() == .OK, let url = panel.url else { return }
        exportPath = url.path
    }

    private func importBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { importSelectedIDs.contains(id) },
            set: { selected in
                if selected { importSelectedIDs.insert(id) } else { importSelectedIDs.remove(id) }
            }
        )
    }

    private func exportBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { exportSelectedIDs.contains(id) },
            set: { selected in
                if selected { exportSelectedIDs.insert(id) } else { exportSelectedIDs.remove(id) }
            }
        )
    }

    private func importSelected() {
        let toImport = importHosts.filter { importSelectedIDs.contains($0.id) }
        guard !toImport.isEmpty else { return }
        for host in toImport {
            let server = SSHServer(
                name: host.host,
                sshHost: host.hostName,
                sshPort: host.port,
                sshUser: host.user,
                authType: host.identityFile.isEmpty ? .password : .key,
                sshKeyPath: host.identityFile
            )
            configManager.servers.append(server)
        }
        configManager.saveConnections()
        dismiss()
    }

    private func doExport() {
        let toExport = validServers.filter { exportSelectedIDs.contains($0.id) }
        guard !toExport.isEmpty else { return }
        try? SSHConfigExporter.appendToConfig(toExport, path: exportPath)
        dismiss()
    }
}
