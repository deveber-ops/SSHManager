import SwiftUI
import WebKit

// MARK: - HTML Editor WebView
struct HTMLEditorWebView: NSViewRepresentable {
    @Binding var content: String
    var onHeightChanged: ((CGFloat) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "contentChanged")
        config.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator

        if let url = Bundle.main.url(forResource: "html_editor", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: HTMLEditorWebView
        init(_ parent: HTMLEditorWebView) { self.parent = parent }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "contentChanged", let html = message.body as? String {
                DispatchQueue.main.async { self.parent.content = html }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let escaped = parent.content
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            webView.evaluateJavaScript("setContent(`\(escaped)`)")
            webView.evaluateJavaScript("document.getElementById('editor').scrollHeight") { result, _ in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async { self.parent.onHeightChanged?(height + 100) }
                }
            }
        }
    }
}

// MARK: - Окно редактора
func openHTMLEditor(initialHTML: String, completion: @escaping (String) -> Void) {
    let editor = HTMLEditorWindowController(initialHTML: initialHTML, completion: completion)
    editor.showWindow(nil)
}

private class HTMLEditorWindowController: NSObject {
    private let initialHTML: String
    private let completion: (String) -> Void
    private var window: NSWindow?

    init(initialHTML: String, completion: @escaping (String) -> Void) {
        self.initialHTML = initialHTML
        self.completion = completion
        super.init()
    }

    func showWindow(_ sender: Any?) {
        let editorView = HTMLEditorContentView(
            initialHTML: initialHTML,
            onCancel: { [weak self] in self?.window?.close() },
            onDone: { [weak self] html in
                self?.completion(html)
                self?.window?.close()
            }
        )
        let host = NSHostingController(rootView: editorView)
        let win = NSWindow(contentViewController: host)
        win.title = "Редактор описания обновления"
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.setContentSize(NSSize(width: 550, height: 500))
        win.center()
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        self.window = win
    }
}

struct HTMLEditorContentView: View {
    let initialHTML: String
    let onCancel: () -> Void
    let onDone: (String) -> Void

    @State private var html: String = ""
    @State private var editorHeight: CGFloat = 400

    var body: some View {
        VStack(spacing: 0) {
            HTMLEditorWebView(content: $html, onHeightChanged: { editorHeight = $0 })
                .frame(minHeight: editorHeight)

            Divider()

            HStack {
                Button("Отмена") { onCancel() }
                    .keyboardShortcut(.escape)
                Spacer()
                Text("⌘↩ — применить")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Готово") { onDone(html) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .onAppear { html = initialHTML }
    }
}
