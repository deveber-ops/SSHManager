import SwiftUI
import AppKit

// MARK: - Встроенная SSH-консоль
struct EmbeddedTerminalView: View {
    let server: SSHServer
    let onSaveSnippet: (CommandSnippet) -> Void
    let onUpdateSnippet: (CommandSnippet) -> Void
    let onDeleteSnippet: (UUID) -> Void
    @State private var output = ""
    @State private var input = ""
    @State private var showFormSheet = false
    @State private var editingSnippet: CommandSnippet?
    @State private var formName = ""
    @State private var formCommand = ""
    @State private var formDescription = ""
    @State private var formRequireConfirmation = false
    @FocusState private var isDescriptionFocused: Bool
    @FocusState private var isCommandFocused: Bool
    @State private var snippets: [CommandSnippet] = []
    @State private var selectedSnippetID: UUID?
    @State private var showDescriptionSnippetID: UUID?
    @State private var confirmSnippet: CommandSnippet?
    private let terminal = TerminalSession()

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            snippetsSidebar
                .padding(-6)
                .navigationSplitViewColumnWidth(min: 250, ideal: 250, max: 250)
        } detail: {
            terminalDetail
        }
        .navigationSplitViewStyle(.prominentDetail)
        .frame(minWidth: 850, minHeight: 600)
        .onAppear {
            snippets = server.snippets
            terminal.outputHandler = { text in
                output += text
            }
            terminal.connect(to: server)
        }
        .onDisappear {
            terminal.disconnect()
        }
        .sheet(isPresented: $showFormSheet) {
            snippetFormSheet
        }
        .confirmationDialog(
            "Выполнить команду?",
            isPresented: Binding(
                get: { confirmSnippet != nil },
                set: { if !$0 { confirmSnippet = nil } }
            )
        ) {
            Button("Выполнить") {
                if let snippet = confirmSnippet {
                    sendImmediate(snippet.command)
                }
                confirmSnippet = nil
            }
        } message: {
            if let snippet = confirmSnippet {
                Text("\(snippet.name)\n\(snippet.command)")
            }
        }
    }

    // MARK: - Sidebar
    private var snippetsSidebar: some View {
        VStack(spacing: 0) {
            if snippets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "terminal")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Нет команд")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Button("Добавить команду") {
                        editingSnippet = nil
                        formName = ""
                        formCommand = ""
                        formDescription = ""
                        formRequireConfirmation = false
                        showFormSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(snippets) { snippet in
                        snippetRow(snippet)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if snippet.requireConfirmation {
                                    confirmSnippet = snippet
                                } else {
                                    sendImmediate(snippet.command)
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedSnippetID == snippet.id ? Color.gray.opacity(0.3) : Color.clear)
                            )
                            .listRowInsets(EdgeInsets(top: 0, leading: -8, bottom: 0, trailing: -8))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .onDelete { offsets in
                        let toDelete = offsets.map { snippets[$0].id }
                        for id in toDelete {
                            onDeleteSnippet(id)
                        }
                        snippets.removeAll { toDelete.contains($0.id) }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    editingSnippet = nil
                    formName = ""
                    formCommand = ""
                    formDescription = ""
                    formRequireConfirmation = false
                    showFormSheet = true
                }) {
                    Label("Добавить", systemImage: "plus")
                    Text("Добавить команду")
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 250, ideal: 250, max: 250)
    }

    // MARK: - Строка сниппета
    private func snippetRow(_ snippet: CommandSnippet) -> some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.name.isEmpty ? "Команда" : snippet.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(snippet.command)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 4) {
                    if !snippet.description.isEmpty {
                        Button {
                            showDescriptionSnippetID = snippet.id
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .frame(width: 22, height: 22)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .hoverBackground(shape: Circle(), padding: 0)
                        .help("Описание команды")
                        .popover(isPresented: Binding(
                            get: { showDescriptionSnippetID == snippet.id },
                            set: { if !$0 { showDescriptionSnippetID = nil } }
                        ), arrowEdge: .bottom) {
                            Text(snippet.description)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(nil)
                                .padding(12)
                                .frame(width: 300, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Button {
                        input = snippet.command
                    } label: {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverBackground(shape: Circle(), padding: 0)
                    .help("Вставить в поле ввода")

                    Button {
                        editingSnippet = snippet
                        showFormSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverBackground(shape: Circle(), padding: 0)
                    .help("Редактировать")

                    Button(role: .destructive) {
                        if let idx = snippets.firstIndex(where: { $0.id == snippet.id }) {
                            snippets.remove(at: idx)
                            onDeleteSnippet(snippet.id)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverBackground(shape: Circle(), padding: 0)
                }
                .liquidGlassCapsule()
            }
        }
        .hoverBackground(shape: RoundedRectangle(cornerRadius: 16), padding: 8)
    }

    // MARK: - Terminal + input
    private var terminalDetail: some View {
        VStack(spacing: 0) {
            TerminalOutputView(text: output)

            Divider()

            HStack {
                TextField("", text: $input, prompt: Text("Введите команду...").foregroundColor(.white.opacity(0.3)))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        submitCommand()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .liquidGlassCapsule()
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Форма добавления / редактирования команды
    private var snippetFormSheet: some View {
        let isEditing = editingSnippet != nil
        let title = isEditing ? (formName.isEmpty ? editingSnippet?.name ?? "Команда" : formName) : "Добавить команду"
        let buttonTitle = isEditing ? "Сохранить" : "Добавить"

        return VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .padding()
            
            VStack (spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Название")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ZStack(alignment: .trailing) {
                        TextField("", text: $formName, prompt: Text("Например: Логи Docker"))
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: formName) { _, new in
                                if new.count > 50 { formName = String(new.prefix(50)) }
                            }
                        Text("\(formName.count)/50")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(formName.count >= 50 ? Color.red : .secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(0.08))
                            )
                            .padding(.trailing, 6)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Описание")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ZStack(alignment: .bottomTrailing) {
                        TextEditor(text: $formDescription)
                            .focused($isDescriptionFocused)
                            .font(.system(size: 12))
                            .frame(height: 80)
                            .scrollContentBackground(.hidden)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isDescriptionFocused ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isDescriptionFocused ? 1.5 : 0.5)
                            )
                            .onChange(of: formDescription) { _, new in
                                if new.count > 200 { formDescription = String(new.prefix(200)) }
                            }
                        Text("\(formDescription.count)/200")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(formDescription.count >= 200 ? Color.red : .secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(0.08))
                            )
                            .padding(.trailing, 6)
                            .padding(.bottom, 4)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Команда")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $formCommand)
                        .focused($isCommandFocused)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(height: 200)
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isCommandFocused ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isCommandFocused ? 1.5 : 0.5)
                        )
                }
            }
            .padding(.horizontal, 24)

            Form {
                Section {
                    Toggle(isOn: $formRequireConfirmation) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Подтверждение команды")
                            Text("Требовать подтверждения выполнения команды")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            HStack {
                Button("Отмена") { showFormSheet = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(buttonTitle) {
                    if isEditing, var snippet = editingSnippet {
                        snippet.name = formName
                        snippet.command = formCommand
                        snippet.description = formDescription
                        snippet.requireConfirmation = formRequireConfirmation
                        if let idx = snippets.firstIndex(where: { $0.id == snippet.id }) {
                            snippets[idx] = snippet
                        }
                        onUpdateSnippet(snippet)
                    } else {
                        let snippet = CommandSnippet(
                            name: formName,
                            command: formCommand,
                            description: formDescription,
                            requireConfirmation: formRequireConfirmation
                        )
                        snippets.append(snippet)
                        onSaveSnippet(snippet)
                    }
                    showFormSheet = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(formName.isEmpty || formCommand.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .frame(width: 480)
        .fixedSize()
        .onAppear {
            if let snippet = editingSnippet {
                formName = snippet.name
                formCommand = snippet.command
                formDescription = snippet.description
                formRequireConfirmation = snippet.requireConfirmation
            }
        }
    }

    private func sendImmediate(_ cmd: String) {
        terminal.send(cmd + "\n")
        output += cmd + "\n"
    }

    private func submitCommand() {
        let cmd = input
        guard !cmd.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        terminal.send(cmd + "\n")
        output += cmd + "\n"
        input = ""
    }
}

// MARK: - Область вывода терминала
struct TerminalOutputView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true

        let textView = NSTextView()
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = NSColor(white: 0.08, alpha: 1)
        textView.textColor = .white
        textView.isRichText = false
        textView.isEditable = false
        textView.allowsUndo = false
        scroll.documentView = textView

        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            textView.scrollToEndOfDocument(nil)
        }
    }
}

// MARK: - Terminal Session (Pipe-based SSH)
class TerminalSession {
    var outputHandler: ((String) -> Void)?
    private var process: Process?
    private var stdinHandle: FileHandle?

    func connect(to server: SSHServer) {
        let user = server.sshUser
        let host = server.sshHost
        let port = server.sshPort.isEmpty ? "22" : server.sshPort

        let outPipe = Pipe()
        let inPipe = Pipe()

        let p = Process()
        p.launchPath = "/usr/bin/ssh"
        var args = ["-t", "-p", port]
        if server.authType == .key && !server.sshKeyPath.isEmpty {
            let keyPath = (server.sshKeyPath as NSString).expandingTildeInPath
            args += ["-i", keyPath, "-o", "IdentitiesOnly=yes"]
        }
        args += ["\(user)@\(host)"]
        p.arguments = args

        p.standardOutput = outPipe
        p.standardError = outPipe
        p.standardInput = inPipe

        p.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.outputHandler?("\n[Соединение закрыто]\n") }
        }

        try? p.run()
        process = p
        stdinHandle = inPipe.fileHandleForWriting

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { self?.outputHandler?(text) }
            }
        }
    }

    func send(_ text: String) {
        if let data = text.data(using: .utf8) {
            stdinHandle?.write(data)
        }
    }

    func disconnect() {
        process?.terminate()
        process = nil
        stdinHandle = nil
    }
}

// MARK: - Открыть окно
func openTerminalWindow(for server: SSHServer) {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 850, height: 600),
        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
        backing: .buffered, defer: false
    )
    window.title = "\(server.name) — \(server.sshUser)@\(server.sshHost)"
    window.titlebarAppearsTransparent = true
    window.isOpaque = false
    window.backgroundColor = .clear
    window.center()
    window.isReleasedWhenClosed = false
    let hosting = NSHostingController(rootView: EmbeddedTerminalView(
        server: server,
        onSaveSnippet: { snippet in
            guard let idx = TunnelConfigManager.shared.servers.firstIndex(where: { $0.id == server.id }) else { return }
            TunnelConfigManager.shared.servers[idx].snippets.append(snippet)
            TunnelConfigManager.shared.saveConnections()
        },
        onUpdateSnippet: { snippet in
            guard let sIdx = TunnelConfigManager.shared.servers.firstIndex(where: { $0.id == server.id }),
                  let snIdx = TunnelConfigManager.shared.servers[sIdx].snippets.firstIndex(where: { $0.id == snippet.id })
            else { return }
            TunnelConfigManager.shared.servers[sIdx].snippets[snIdx] = snippet
            TunnelConfigManager.shared.saveConnections()
        },
        onDeleteSnippet: { snippetID in
            guard let sIdx = TunnelConfigManager.shared.servers.firstIndex(where: { $0.id == server.id }) else { return }
            TunnelConfigManager.shared.servers[sIdx].snippets.removeAll { $0.id == snippetID }
            TunnelConfigManager.shared.saveConnections()
        }
    ))
    hosting.view.wantsLayer = true
    hosting.view.layer?.backgroundColor = NSColor(white: 0.08, alpha: 1).cgColor
    window.contentViewController = hosting
    window.makeKeyAndOrderFront(nil)
}
