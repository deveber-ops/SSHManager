import SwiftUI
import AppKit

// MARK: - Встроенная SSH-консоль
struct EmbeddedTerminalView: View {
    let server: SSHServer
    @State private var output = ""
    @State private var input = ""
    private let terminal = TerminalSession()

    var body: some View {
        VStack(spacing: 0) {
            // Вывод терминала
            TerminalOutputView(text: output)
                .onAppear {
                    terminal.outputHandler = { text in
                        output += text
                    }
                    terminal.connect(to: server)
                }
                .onDisappear {
                    terminal.disconnect()
                }

            Divider()

            // Поле ввода в капсуле
            HStack {
                TextField("", text: $input, prompt: Text("Введите команду...").foregroundColor(.white.opacity(0.3)))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        terminal.send(input + "\n")
                        output += input + "\n"
                        input = ""
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .liquidGlassCapsule()
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 850, minHeight: 600)
        .background(Color(nsColor: NSColor(white: 0.08, alpha: 1)))
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
        contentRect: NSRect(x: 0, y: 0, width: 700, height: 450),
        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
        backing: .buffered, defer: false
    )
    window.title = "SSHManager — \(server.name):\(server.sshUser) — \(server.sshHost)"
    window.titlebarAppearsTransparent = true
    window.backgroundColor = NSColor(white: 0.08, alpha: 1)
    window.isOpaque = false
    window.center()
    window.isReleasedWhenClosed = false
    let hosting = NSHostingController(rootView: EmbeddedTerminalView(server: server))
    hosting.view.wantsLayer = true
    hosting.view.layer?.backgroundColor = NSColor(white: 0.08, alpha: 1).cgColor
    window.contentViewController = hosting
    window.makeKeyAndOrderFront(nil)
}
