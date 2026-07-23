#!/usr/bin/env swift
import SwiftUI
import AppKit

// MARK: - Configuration & Helpers

let projectDir: String = {
    // Используем путь к самому скрипту для определения корня проекта
    let scriptPath = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
    return scriptPath
}()
let scheme = "SSHManager"
let configuration = "Release"
let archiveDir = "\(projectDir)/archive"
let dmgDir = "\(projectDir)/release"
let githubRepo = ProcessInfo.processInfo.environment["GITHUB_REPO"] ?? "deveber-ops/SSHManager"

/// Динамическое чтение версии из project.pbxproj
func fetchAppVersion() -> String {
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["-c", "grep 'MARKETING_VERSION' '\(projectDir)/SSHManager.xcodeproj/project.pbxproj' | tail -1 | sed 's/.*= //;s/;//'"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let version = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return version.isEmpty ? "1.0" : version
}

// MARK: - Step Model

class Step: ObservableObject, Identifiable {
    let id = UUID()
    let name: String

    /// 0-pending, 1-running, 2-done, 3-failed
    @Published var status = 0
    @Published var log = ""
    @Published var openPath: String? = nil
    @Published var openURL: String? = nil

    var action: (() -> Bool)?

    init(_ name: String) {
        self.name = name
    }

    func start()  { status = 1 }
    func done(_ ok: Bool) { status = ok ? 2 : 3 }
}

// MARK: - Step Row View

struct StepRow: View {
    @ObservedObject var step: Step
    @State private var isExpanded = false

    var body: some View {
        Section {
            // MARK: - Контент лога и действие
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(step.log.isEmpty ? "—" : step.log)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }

                    // Дополнительные кнопки действий
                    if step.openPath != nil || step.openURL != nil {
                        HStack(spacing: 8) {
                            if let path = step.openPath {
                                Button {
                                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                                } label: {
                                    Label("Показать в Finder", systemImage: "folder")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            if let urlString = step.openURL, let url = URL(string: urlString) {
                                Button {
                                    NSWorkspace.shared.open(url)
                                } label: {
                                    Label("Открыть на GitHub", systemImage: "safari")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(10)
                .background(Color.black.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 2)
                .padding(.bottom, 6)
            }
        } header: {
            // MARK: - Закрепляемый триггер шапки
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    statusIcon

                    Text(step.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, height: 14)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isExpanded ? 0.2 : 0), radius: 4, x: 0, y: 2)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch step.status {
        case 0:
            Circle()
                .fill(.tertiary)
                .frame(width: 12, height: 12)
        case 1:
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.6)
                .frame(width: 12, height: 12)
        case 2:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 13))
        case 3:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 13))
        default:
            EmptyView()
        }
    }
}

// MARK: - Shared State (editor content accessible from VM)
class SharedState {
    static var editorHTML = ""
    static weak var editorCoordinator: EditorTextView.Coordinator?
}

// MARK: - ViewModel

class ReleaseVM: ObservableObject {
    @Published var steps: [Step] = []
    @Published var currentStep = ""
    @Published var progress: Double = 0
    @Published var appVersion: String = ""
    @Published var isRunning = false

    private var isCancelled = false
    private var currentProcess: Process?

    init() {
        setupSteps()
    }

    /// Формирование шагов и возврат в исходное состояние
    func setupSteps() {
        let currentVersion = fetchAppVersion()
        self.appVersion = currentVersion

        let dmgPath = "\(dmgDir)/SSHManager-\(currentVersion).dmg"
        let appcastPath = "\(dmgDir)/appcast.xml"

        // MARK: Step 0 - Очистка
        let s0 = Step("Очистка сборок")
        s0.action = { [weak self] in
            guard let self = self, !self.isCancelled else { return false }
            var logs: [String] = []
            
            if FileManager.default.fileExists(atPath: archiveDir) {
                try? FileManager.default.removeItem(atPath: archiveDir)
                logs.append("🧹 Очищена директория архивов: \(archiveDir)")
            }
            if FileManager.default.fileExists(atPath: dmgDir) {
                try? FileManager.default.removeItem(atPath: dmgDir)
                logs.append("🧹 Очищена директория релиза: \(dmgDir)")
            }
            
            try? FileManager.default.createDirectory(atPath: archiveDir, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(atPath: dmgDir, withIntermediateDirectories: true)
            logs.append("📁 Созданы чистые папки для новой сборки.")

            DispatchQueue.main.async {
                s0.log = logs.joined(separator: "\n")
            }
            return true
        }

        // MARK: Step 1 - Архивирование (Понятные шаги вместо сырого вывода)
        let s1 = Step("Архивирование")
        s1.action = { [weak self] in
            guard let self = self, !self.isCancelled else { return false }
            
            DispatchQueue.main.async {
                s1.log = """
                🔨 Запуск архивации проекта...
                • Проект: \(scheme).xcodeproj
                • Конфигурация: \(configuration)
                • Схема: \(scheme)
                • Целевой путь: \(archiveDir)/\(scheme).xcarchive
                
                ⏳ Выполняется xcodebuild archive...
                """
            }
            
            var errorLogs = ""
            let ok = self.shellOK("xcodebuild -project '\(projectDir)/SSHManager.xcodeproj' -scheme '\(scheme)' -configuration '\(configuration)' -derivedDataPath '\(projectDir)/build' archive -archivePath '\(archiveDir)/\(scheme).xcarchive' CODE_SIGN_STYLE=Automatic 2>&1") { text in
                if text.contains("error:") || text.contains("FAILED") {
                    errorLogs += text + "\n"
                }
            }
            
            guard !self.isCancelled else { return false }
            let appPath = "\(archiveDir)/\(scheme).xcarchive/Products/Applications/SSHManager.app"
            let exists = FileManager.default.fileExists(atPath: appPath)
            
            if ok && exists {
                self.shell("cp -R '\(appPath)' '\(archiveDir)/SSHManager.app'") { _ in }
                DispatchQueue.main.async {
                    s1.log += """
                    
                    
                    ✅ Сборка завершена успешно!
                    📂 Архив создан: \(archiveDir)/\(scheme).xcarchive
                    📦 Приложение скопировано: \(archiveDir)/SSHManager.app
                    """
                }
                return true
            } else {
                DispatchQueue.main.async {
                    s1.log += """
                    
                    
                    ❌ Ошибка сборки xcodebuild!
                    \(errorLogs.isEmpty ? "Проверьте проект в Xcode на наличие ошибок компиляции." : errorLogs)
                    """
                }
                return false
            }
        }

        // MARK: Step 2 - Создание DMG
        let s2 = Step("Создание DMG")
        s2.action = { [weak self] in
            guard let self = self, !self.isCancelled else { return false }
            DispatchQueue.main.async { s2.log = "💿 Подготовка структуры DMG...\n" }
            
            self.shell("xattr -cr '\(archiveDir)/SSHManager.app' 2>/dev/null; true") { _ in }
            let tmp = "\(dmgDir)/tmp"
            try? FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
            self.shell("cp -R '\(archiveDir)/SSHManager.app' '\(tmp)/' && ln -sf /Applications '\(tmp)/Applications'") { _ in }
            
            if FileManager.default.fileExists(atPath: "\(projectDir)/fix_quarantine.command") {
                self.shell("cp '\(projectDir)/fix_quarantine.command' '\(tmp)/'") { _ in }
            }
            
            guard !self.isCancelled else { return false }
            self.shell("hdiutil create -volname 'SSHManager' -srcfolder '\(tmp)' -ov -format UDZO '\(dmgPath)' 2>&1") { text in
                s2.log += text
            }
            self.shell("rm -rf '\(tmp)'") { _ in }
            
            let exists = FileManager.default.fileExists(atPath: dmgPath)
            if exists {
                DispatchQueue.main.async {
                    s2.log += "\n\n✅ Образ DMG успешно создан:\n\(dmgPath)"
                    s2.openPath = dmgPath
                }
            }
            return !self.isCancelled && exists
        }

        // MARK: Step 3 - Описание обновления
        let s3 = Step("Описание обновления")
        s3.action = { [weak self] in
            guard let self = self, !self.isCancelled else { return false }
            let notesFile = "\(dmgDir)/release_notes.txt"
            // Используем содержимое редактора
            let html = SharedState.editorHTML
            if html.isEmpty {
                DispatchQueue.main.async { s3.log = "⚠️ Описание не заполнено" }
                return false
            }
            try? html.write(toFile: notesFile, atomically: true, encoding: .utf8)
            DispatchQueue.main.async { s3.log = "✅ Описание сохранено" }
            return true
        }

        // MARK: Step 4 - Appcast + Push
        let s4 = Step("Appcast + Push")
        s4.action = { [weak self] in
            guard let self = self, !self.isCancelled else { return false }
            let notes = (try? String(contentsOfFile: "\(dmgDir)/release_notes.txt", encoding: .utf8)) ?? "v\(currentVersion)"
            let size = (try? FileManager.default.attributesOfItem(atPath: dmgPath)[.size] as? Int) ?? 0
            let downloadURL = "https://github.com/\(githubRepo)/releases/download/v\(currentVersion)/SSHManager-\(currentVersion).dmg"
            let date = ISO8601DateFormatter().string(from: Date())

            let appcast = """
                <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
                  <channel>
                    <title>SSH Manager</title>
                    <description>SSH Manager updates</description>
                    <item>
                      <title>Version \(currentVersion)</title>
                      <sparkle:version>\(currentVersion)</sparkle:version>
                      <sparkle:shortVersionString>\(currentVersion)</sparkle:shortVersionString>
                      <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
                      <pubDate>\(date)</pubDate>
                      <description><![CDATA[\(notes)]]></description>
                      <enclosure url="\(downloadURL)" sparkle:version="\(currentVersion)" sparkle:shortVersionString="\(currentVersion)" length="\(size)" type="application/octet-stream"/>
                    </item>
                  </channel>
                </rss>
                """
            try? appcast.write(toFile: appcastPath, atomically: true, encoding: .utf8)

            var gitLogOutput = ""
            self.shell("cp '\(appcastPath)' '\(projectDir)/appcast.xml' && cd '\(projectDir)' && git add appcast.xml && git commit -m 'Release v\(currentVersion)' && git push origin main 2>&1") { text in
                gitLogOutput += text
            }
            
            DispatchQueue.main.async {
                s4.log = """
                🚀 Appcast обновлен и отправлен в Git!
                📌 Версия: v\(currentVersion)
                
                --- Вывод Git ---
                \(gitLogOutput.trimmingCharacters(in: .whitespacesAndNewlines))
                """
            }
            return !self.isCancelled
        }

        // MARK: Step 5 - GitHub Release
        let s5 = Step("GitHub Release")
        s5.action = { [weak self] in
            guard let self = self, !self.isCancelled else { return false }
            let htmlNotes = (try? String(contentsOfFile: "\(dmgDir)/release_notes.txt", encoding: .utf8)) ?? "v\(currentVersion)"
            let notes = htmlToText(htmlNotes).replacingOccurrences(of: "'", with: "'\\''")
            let releaseURL = "https://github.com/\(githubRepo)/releases/tag/v\(currentVersion)"
            
            var rawOutput = ""
            let ok = self.shellOK("gh release create 'v\(currentVersion)' --repo '\(githubRepo)' --title 'v\(currentVersion)' --notes '\(notes)' '\(dmgPath)' 2>&1") { text in
                rawOutput += text
            }
            
            DispatchQueue.main.async {
                if ok {
                    s5.log = """
                    🎉 Релиз v\(currentVersion) успешно опубликован на GitHub!
                    🔗 URL: \(releaseURL)
                    """
                    s5.openURL = releaseURL
                } else {
                    s5.log = "❌ Ошибка публикации релиза:\n\(rawOutput)"
                }
            }
            return ok
        }

        steps = [s0, s1, s2, s3, s4, s5]
        currentStep = ""
        progress = 0
        isRunning = false
        isCancelled = false
    }

    /// Сброс всех полей к исходному состоянию
    func reset() {
        stopProcess()
        setupSteps()
    }

    /// Прерывание работы
    func stop() {
        stopProcess()
        if let step = steps.first(where: { $0.status == 1 }) {
            step.log += "\n[Остановлено пользователем]"
            step.done(false)
        }
        currentStep = "Остановлено пользователем 🛑"
    }

    private func stopProcess() {
        isCancelled = true
        isRunning = false
        currentProcess?.terminate()
        currentProcess = nil
    }

    func start() {
        guard !isRunning else { return }
        setupSteps()
        isRunning = true
        isCancelled = false
        runNext(0)
    }

    private func runNext(_ index: Int) {
        guard !isCancelled else { return }

        guard index < steps.count else {
            currentStep = "Готово! ✅"
            progress = 100
            isRunning = false
            return
        }

        let step = steps[index]
        DispatchQueue.main.async {
            step.start()
            self.currentStep = step.name
            self.progress = Double(index) / Double(self.steps.count) * 100
        }

        DispatchQueue.global().async {
            let ok = step.action?() ?? false
            DispatchQueue.main.async {
                guard !self.isCancelled else { return }
                step.done(ok)
                self.progress = Double(index + 1) / Double(self.steps.count) * 100
                if !ok {
                    self.currentStep = "Ошибка на шаге: \(step.name) ❌"
                    self.isRunning = false
                    return
                }
                self.runNext(index + 1)
            }
        }
    }

    // MARK: - Shell Helpers

    func shell(_ command: String, onLog: @escaping (String) -> Void) {
        guard !isCancelled else { return }
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        task.environment = ProcessInfo.processInfo.environment
        task.environment?["DEVELOPER_DIR"] = "/Applications/Xcode.app/Contents/Developer"

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    onLog(text)
                }
            }
        }

        currentProcess = task
        try? task.run()
        task.waitUntilExit()

        pipe.fileHandleForReading.readabilityHandler = nil
        let remainingData = pipe.fileHandleForReading.readDataToEndOfFile()
        if !remainingData.isEmpty, let text = String(data: remainingData, encoding: .utf8) {
            DispatchQueue.main.async {
                onLog(text)
            }
        }

        currentProcess = nil
    }

    func shellOK(_ command: String, onLog: @escaping (String) -> Void) -> Bool {
        guard !isCancelled else { return false }
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        task.environment = ProcessInfo.processInfo.environment
        task.environment?["DEVELOPER_DIR"] = "/Applications/Xcode.app/Contents/Developer"

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    onLog(text)
                }
            }
        }

        currentProcess = task
        try? task.run()
        task.waitUntilExit()

        pipe.fileHandleForReading.readabilityHandler = nil
        let remainingData = pipe.fileHandleForReading.readDataToEndOfFile()
        if !remainingData.isEmpty, let text = String(data: remainingData, encoding: .utf8) {
            DispatchQueue.main.async {
                onLog(text)
            }
        }

        currentProcess = nil
        return !isCancelled && task.terminationStatus == 0
    }
}

// MARK: - Native Editor NSViewRepresentable

extension NSMutableParagraphStyle {
    func also(_ block: (NSMutableParagraphStyle) -> Void) -> NSMutableParagraphStyle { block(self); return self }
}

struct EditorTextView: NSViewRepresentable {
    @Binding var html: String
    var onReady: ((Coordinator) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let tv = NSTextView()
        tv.isRichText = true; tv.allowsUndo = true; tv.font = NSFont.systemFont(ofSize: 13)
        tv.delegate = context.coordinator
        let scroll = NSScrollView()
        scroll.documentView = tv; scroll.hasVerticalScroller = true
        context.coordinator.textView = tv
        onReady?(context.coordinator)

        if let data = html.data(using: .utf8),
           let attr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil) {
            tv.textStorage?.setAttributedString(attr)
        }
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {}

    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: EditorTextView
        weak var textView: NSTextView?
        init(_ p: EditorTextView) { self.parent = p }
        func textDidChange(_ notification: Notification) { saveHTML() }

        func toolAction(_ action: String) {
            guard let tv = textView else { return }
            let ts = tv.textStorage!
            let sel = tv.selectedRange()
            switch action {
            case "B": toggleTrait(.boldFontMask, in: sel, ts: ts)
            case "I": toggleTrait(.italicFontMask, in: sel, ts: ts)
            case "U":
                ts.enumerateAttribute(.underlineStyle, in: sel, options: []) { v, r, _ in
                    ts.addAttribute(.underlineStyle, value: (v as? Int) == 1 ? 0 : 1, range: r)
                }
            case "H1": ts.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 22), range: sel)
            case "H2": ts.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 18), range: sel)
            case "H3": ts.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 15), range: sel)
            case "P": ts.addAttribute(.font, value: NSFont.systemFont(ofSize: 13), range: sel)
            case "•": tv.insertText("\n• ", replacementRange: sel)
            case "1.": tv.insertText("\n1. ", replacementRange: sel)
            case "☑": tv.insertText("\n☐ ", replacementRange: sel)
            case "🔗":
                if let url = URL(string: promptInput("URL:") ?? "https://") { ts.addAttribute(.link, value: url, range: sel) }
            case "🖼":
                if let url = promptInput("URL изображения:") { tv.insertText("\n[Изображение: \(url)]\n", replacementRange: sel) }
            case "⊞": tv.insertText("\n| A | B |\n| — | — |\n| x | y |\n", replacementRange: sel)
            case "—": tv.insertText("\n——\n", replacementRange: sel)
            case "❝": tv.insertText("\n> ", replacementRange: sel)
            case "<>": tv.insertText("`code`", replacementRange: sel)
            case "{}": tv.insertText("\n```\ncode\n```\n", replacementRange: sel)
            case "⇤": ts.addAttribute(.paragraphStyle, value: NSMutableParagraphStyle().also { $0.alignment = NSTextAlignment.left }, range: sel)
            case "⇔": ts.addAttribute(.paragraphStyle, value: NSMutableParagraphStyle().also { $0.alignment = NSTextAlignment.center }, range: sel)
            case "⇥": ts.addAttribute(.paragraphStyle, value: NSMutableParagraphStyle().also { $0.alignment = NSTextAlignment.right }, range: sel)
            case "🎨": ts.addAttribute(.foregroundColor, value: NSColor.red, range: sel)
            case "◧": ts.addAttribute(.backgroundColor, value: NSColor.yellow, range: sel)
            case "✕": ts.setAttributes([.font: NSFont.systemFont(ofSize: 13)], range: sel)
            default: break
            }
            saveHTML()
        }

        private func saveHTML() {
            guard let tv = textView else { return }
            let attr = tv.attributedString()
            if let d = try? attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.html]),
               let str = String(data: d, encoding: .utf8) {
                parent.html = str
                SharedState.editorHTML = str
            }
        }

        private func toggleTrait(_ trait: NSFontTraitMask, in range: NSRange, ts: NSTextStorage) {
            guard range.length > 0 else { return }
            ts.enumerateAttribute(.font, in: range, options: []) { v, r, _ in
                if let font = v as? NSFont {
                    ts.addAttribute(.font, value: NSFontManager.shared.convert(font, toHaveTrait: trait), range: r)
                }
            }
            saveHTML()
        }
    }
}

private func promptInput(_ msg: String) -> String? {
    let a = NSAlert(); a.messageText = msg; a.addButton(withTitle: "OK"); a.addButton(withTitle: "Отмена")
    let f = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
    a.accessoryView = f
    return a.runModal() == .alertFirstButtonReturn ? f.stringValue : nil
}

// MARK: - Main Release View

struct ReleaseView: View {
    @StateObject private var vm = ReleaseVM()
    @State private var copied = false
    @State private var editorHTML = SharedState.editorHTML

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 220)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.prominentDetail)
        .frame(minWidth: 850, minHeight: 600)
    }

    private var sidebar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "app.connected.to.app.below.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tint)
                Text("SSHManager").font(.system(size: 13, weight: .bold))
                Text("v\(vm.appVersion)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(Color.primary.opacity(0.06), in: Capsule())
                Spacer()
            }
            .padding(.horizontal, 10).padding(.top, 8)

            ScrollView {
                LazyVStack(spacing: 6, pinnedViews: [.sectionHeaders]) {
                    ForEach(vm.steps) { step in StepRow(step: step) }
                }
                .padding(.horizontal, 8).padding(.bottom, 8)
            }

            if !vm.currentStep.isEmpty {
                Text(vm.currentStep).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10)
                ProgressView(value: vm.progress, total: 100).progressViewStyle(.linear).padding(.horizontal, 10)
            }

            HStack {
                Button("Копировать лог") {
                    let all = vm.steps.map { "\($0.name):\n\($0.log)" }.joined(separator: "\n\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(all, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                }
                .disabled(vm.steps.allSatisfy { $0.log.isEmpty })
                if copied { Text("✓").font(.caption).foregroundColor(.green) }
            }
            .padding(.horizontal, 10).padding(.bottom, 8)
        }
    }

    private var detailView: some View {
        VStack(spacing: 8) {
            // Хедер с кнопками форматирования
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(toolbarGroups.indices, id: \.self) { gi in
                        HStack(spacing: 2) {
                            ForEach(toolbarGroups[gi].indices, id: \.self) { i in
                                let item = toolbarGroups[gi][i]
                                Button(item) {
                                    SharedState.editorCoordinator?.toolAction(item)
                                }
                                .buttonStyle(.borderless)
                                .frame(width: 28, height: 24)
                            }
                        }
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
                        )
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
            }
            .frame(height: 36)

            EditorTextView(html: $editorHTML, onReady: { SharedState.editorCoordinator = $0 })
                .onChange(of: editorHTML) { _, _ in SharedState.editorHTML = editorHTML }

            HStack {
                if vm.isRunning {
                    Button("Остановить") { vm.stop() }.buttonStyle(.borderedProminent).tint(.red)
                } else {
                    Button("Запустить") { vm.start() }.buttonStyle(.borderedProminent)
                }
                Button("Сбросить") { vm.reset() }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
        }
        .padding(.top, 8)
    }
}

let toolbarItems: [String] = ["B","I","U","","H1","H2","H3","P","","•","1.","☑","","🔗","🖼","⊞","—","","❝","<>","{}","","⇤","⇔","⇥","","🎨","◧","✕"]

let toolbarGroups: [[String]] = [
    ["B","I","U"],
    ["H1","H2","H3","P"],
    ["•","1.","☑"],
    ["🔗","🖼","⊞","—"],
    ["❝","<>","{}"],
    ["⇤","⇔","⇥"],
    ["🎨","◧","✕"],
]

// MARK: - App Entry Point

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let window = NSWindow(contentViewController: NSHostingController(rootView: ReleaseView()))
window.title = "SSH Manager Release Builder"
window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
window.titlebarAppearsTransparent = true
window.setContentSize(NSSize(width: 850, height: 600))
window.center()
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
app.run()

// Utility functions used by the app

func htmlToText(_ html: String) -> String {
    var text = html
    text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
    text = text.replacingOccurrences(of: "</p>", with: "\n")
    text = text.replacingOccurrences(of: "</li>", with: "\n")
    text = text.replacingOccurrences(of: "</h3>", with: "\n")
    text = text.replacingOccurrences(of: "</ul>", with: "\n")
    text = text.replacingOccurrences(of: "<li>", with: "• ")
    text = text.replacingOccurrences(of: "\\s*<li>", with: "• ", options: .regularExpression)
    text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    text = text.replacingOccurrences(of: "&amp;", with: "&")
    text = text.replacingOccurrences(of: "&lt;", with: "<")
    text = text.replacingOccurrences(of: "&gt;", with: ">")
    text = text.replacingOccurrences(of: "&quot;", with: "\"")
    while text.contains("\n\n\n") { text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
}
