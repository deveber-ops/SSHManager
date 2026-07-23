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
            // Пробуем загрузить предыдущие заметки или создаём шаблон
            let previousNotes = (try? String(contentsOfFile: notesFile, encoding: .utf8)) ?? ""
            let initialHTML: String
            if previousNotes.isEmpty {
                initialHTML = "<h3>Что нового</h3>\n<ul>\n<li></li>\n</ul>"
            } else {
                initialHTML = convertToHTML(previousNotes)
            }

            DispatchQueue.main.async {
                s3.log = "📝 Ожидание заполнения описания в редакторе..."
            }

            var finalHTML = initialHTML
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.main.async {
                openHTMLEditor(initialHTML: initialHTML) { html in
                    finalHTML = html
                    semaphore.signal()
                }
            }
            semaphore.wait()

            // Сохраняем результат
            try? finalHTML.write(toFile: notesFile, atomically: true, encoding: .utf8)

            if let saved = try? String(contentsOfFile: notesFile, encoding: .utf8) {
                DispatchQueue.main.async {
                    s3.log = saved.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            return !self.isCancelled && FileManager.default.fileExists(atPath: notesFile)
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

// MARK: - Main View

struct ReleaseView: View {
    @StateObject private var vm = ReleaseVM()
    @State private var copied = false

    var body: some View {
        VStack(spacing: 8) {
            // MARK: - Хедер окна с названием и версией
            HStack(spacing: 8) {
                Image(systemName: "app.connected.to.app.below.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.tint)

                Text("SSHManager")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)

                Text("v\(vm.appVersion)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: Capsule())

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 32)

            // LazyVStack с pinnedViews фиксирует шапку шага вверху при скролле
            ScrollView {
                LazyVStack(spacing: 8, pinnedViews: [.sectionHeaders]) {
                    ForEach(vm.steps) { step in
                        StepRow(step: step)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }

            // Прогресс-бар и статус
            VStack(spacing: 4) {
                if !vm.currentStep.isEmpty {
                    Text(vm.currentStep)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ProgressView(value: vm.progress, total: 100)
                    .progressViewStyle(.linear)
            }
            .padding(.horizontal, 16)

            // Кнопки управления
            HStack {
                if vm.isRunning {
                    Button("Остановить") { vm.stop() }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                } else {
                    Button("Запустить") { vm.start() }
                        .buttonStyle(.borderedProminent)
                }

                Button("Сбросить") { vm.reset() }

                Spacer()

                Button("Копировать лог") {
                    let allLogs = vm.steps.map { "\($0.name):\n\($0.log)" }.joined(separator: "\n\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(allLogs, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                }
                .disabled(vm.steps.allSatisfy { $0.log.isEmpty })

                if copied {
                    Text("Скопировано ✓")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(width: 480, height: 420)
        .onChange(of: vm.appVersion) { _, newVersion in
            if let window = NSApp.windows.first {
                window.title = "SSH Manager Release Builder"
            }
        }
    }
}

// MARK: - App Entry Point

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let window = NSWindow(contentViewController: NSHostingController(rootView: ReleaseView()))
window.title = "SSH Manager Release Builder"
window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
window.titlebarAppearsTransparent = true
window.isMovableByWindowBackground = true
window.setContentSize(NSSize(width: 480, height: 420))
window.center()
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
app.run()

// MARK: - Plain text to HTML converter for Sparkle release notes
func convertToHTML(_ text: String) -> String {
    let lines = text.components(separatedBy: "\n")
    var result = ""
    var inList = false
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            if inList {
                result += "</ul>\n"
                inList = false
            }
            continue
        }
        // Bullet points
        if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") {
            if !inList {
                result += "<ul>\n"
                inList = true
            }
            let item = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
            result += "<li>\(item)</li>\n"
        } else {
            if inList {
                result += "</ul>\n"
                inList = false
            }
            // Section header
            result += "<h3>\(trimmed)</h3>\n"
        }
    }
    if inList {
        result += "</ul>\n"
    }
    return result.trimmingCharacters(in: .newlines)
}

func htmlToText(_ html: String) -> String {
    var text = html
    // Заменяем основные теги на markdown-подобный текст
    text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
    text = text.replacingOccurrences(of: "</p>", with: "\n")
    text = text.replacingOccurrences(of: "</li>", with: "\n")
    text = text.replacingOccurrences(of: "</h3>", with: "\n")
    text = text.replacingOccurrences(of: "</ul>", with: "\n")
    // Заменяем li на маркеры
    text = text.replacingOccurrences(of: "<li>", with: "• ")
    text = text.replacingOccurrences(of: "\\s*<li>", with: "• ", options: .regularExpression)
    // Удаляем все оставшиеся теги
    text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    // Декодируем HTML entities
    text = text.replacingOccurrences(of: "&amp;", with: "&")
    text = text.replacingOccurrences(of: "&lt;", with: "<")
    text = text.replacingOccurrences(of: "&gt;", with: ">")
    text = text.replacingOccurrences(of: "&quot;", with: "\"")
    // Убираем множественные пустые строки
    while text.contains("\n\n\n") {
        text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
    }
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Native HTML Editor

private func openHTMLEditor(initialHTML: String, completion: @escaping (String) -> Void) {
    NativeEditorWindow(initial: initialHTML, done: completion).show()
}

private class NativeEditorWindow: NSObject, NSToolbarDelegate, NSTabViewDelegate {
    private var win: NSWindow!
    private var textView: NSTextView!
    private var htmlView: NSTextView!
    private var plainView: NSTextView!
    private var tab: NSTabView!
    private let initial: String
    private let done: (String) -> Void

    init(initial: String, done: @escaping (String) -> Void) {
        self.initial = initial; self.done = done; super.init()
    }

    func show() {
        textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        textView.isRichText = true
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 13)

        htmlView = NSTextView(); htmlView.isEditable = false; htmlView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        plainView = NSTextView(); plainView.isEditable = false; plainView.font = NSFont.systemFont(ofSize: 13)

        let ts1 = NSScrollView(); ts1.documentView = textView; ts1.hasVerticalScroller = true
        let ts2 = NSScrollView(); ts2.documentView = htmlView; ts2.hasVerticalScroller = true
        let ts3 = NSScrollView(); ts3.documentView = plainView; ts3.hasVerticalScroller = true

        tab = NSTabView()
        tab.translatesAutoresizingMaskIntoConstraints = false
        tab.addTabViewItem(NSTabViewItem(identifier: "edit")); tab.tabViewItem(at: 0).label = "Редактор"; tab.tabViewItem(at: 0).view = ts1
        tab.addTabViewItem(NSTabViewItem(identifier: "html")); tab.tabViewItem(at: 1).label = "HTML"; tab.tabViewItem(at: 1).view = ts2
        tab.addTabViewItem(NSTabViewItem(identifier: "text")); tab.tabViewItem(at: 2).label = "Текст"; tab.tabViewItem(at: 2).view = ts3
        tab.delegate = self

        let doneBtn = NSButton(title: "Готово", target: self, action: #selector(finish))
        doneBtn.keyEquivalent = "\r"
        doneBtn.keyEquivalentModifierMask = .command
        doneBtn.bezelStyle = .rounded
        let cancelBtn = NSButton(title: "Отмена", target: self, action: #selector(cancel))
        cancelBtn.keyEquivalent = "\u{1b}"

        let bottom = NSStackView(views: [cancelBtn, NSView(), doneBtn])
        bottom.orientation = .horizontal; bottom.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        bottom.translatesAutoresizingMaskIntoConstraints = false

        let cv = NSView()
        cv.addSubview(tab); cv.addSubview(bottom)
        tab.topAnchor.constraint(equalTo: cv.topAnchor).isActive = true
        tab.leadingAnchor.constraint(equalTo: cv.leadingAnchor).isActive = true
        tab.trailingAnchor.constraint(equalTo: cv.trailingAnchor).isActive = true
        tab.bottomAnchor.constraint(equalTo: bottom.topAnchor).isActive = true
        bottom.leadingAnchor.constraint(equalTo: cv.leadingAnchor).isActive = true
        bottom.trailingAnchor.constraint(equalTo: cv.trailingAnchor).isActive = true
        bottom.bottomAnchor.constraint(equalTo: cv.bottomAnchor).isActive = true
        bottom.heightAnchor.constraint(equalToConstant: 44).isActive = true

        win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 550),
                       styleMask: [.titled, .closable, .miniaturizable, .resizable],
                       backing: .buffered, defer: false)
        win.title = "Редактор описания обновления"
        win.contentView = cv; win.center(); win.isReleasedWhenClosed = false

        let tb = NSToolbar(identifier: "Editor")
        tb.delegate = self; tb.displayMode = .iconOnly; tb.allowsUserCustomization = false
        win.toolbarStyle = .unified; win.toolbar = tb

        // Загружаем исходный HTML
        if let data = initial.data(using: .utf8),
           let attr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
            textView.textStorage?.setAttributedString(attr)
        } else {
            textView.string = initial
        }

        win.makeKeyAndOrderFront(nil)
    }

    @objc private func cancel() { win.close() }
    @objc private func finish() {
        let attr = textView.attributedString()
        if let htmlData = try? attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.html]) {
            done(String(data: htmlData, encoding: .utf8) ?? "")
        } else {
            done(textView.string)
        }
        win.close()
    }

    func tabView(_ tabView: NSTabView, didSelect item: NSTabViewItem?) {
        let attr = textView.attributedString()
        if tabView.indexOfTabViewItem(item!) == 1 {
            if let d = try? attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.html]) {
                htmlView.string = String(data: d, encoding: .utf8) ?? ""
            }
        } else if tabView.indexOfTabViewItem(item!) == 2 {
            plainView.string = htmlToText(htmlView.string)
        }
    }

    // NSToolbar
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let info = nativeToolItems[id.rawValue] else { return nil }
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = info
        let btn = NSButton(frame: NSRect(x: 0, y: 0, width: 32, height: 24))
        btn.title = info; btn.bezelStyle = .toolbar; btn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        btn.target = self; btn.action = #selector(toolClick(_:))
        item.view = btn
        return item
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        ids(["bold","italic","underline",.space,"h1","h2","h3","para",.space,"bull","num","task",.space,"link","img","table","hr",.space,"quote","code","preBlock",.space,"left","center","right",.space,"color","bg","clear"])
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarDefaultItemIdentifiers(toolbar) }
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [] }

    @objc private func toolClick(_ sender: NSButton) {
        let ts = textView.textStorage!
        let sel = textView.selectedRange()
        switch sender.title {
        case "B": toggleTrait(.boldFontMask, in: sel)
        case "I": toggleTrait(.italicFontMask, in: sel)
        case "U": ts.toggleUnderline(nil)
        case "H1": ts.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 22), range: sel)
        case "H2": ts.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 18), range: sel)
        case "H3": ts.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 15), range: sel)
        case "¶": ts.addAttribute(.font, value: NSFont.systemFont(ofSize: 13), range: sel)
        case "•": textView.insertText("\n• ", replacementRange: sel)
        case "1.": textView.insertText("\n1. ", replacementRange: sel)
        case "☑": textView.insertText("\n☐ ", replacementRange: sel)
        case "🔗":
            if let url = URL(string: prompt("URL:") ?? "https://") {
                ts.addAttribute(.link, value: url, range: sel)
            }
        case "🖼":
            if let url = prompt("URL изображения:") {
                textView.insertText("\n[Изображение: \(url)]\n", replacementRange: sel)
            }
        case "⊞": textView.insertText("\n| Колонка 1 | Колонка 2 |\n| — | — |\n| Данные | Данные |\n", replacementRange: sel)
        case "—": textView.insertText("\n——\n", replacementRange: sel)
        case "❝": textView.insertText("\n> ", replacementRange: sel)
        case "<>": textView.insertText("`code`", replacementRange: sel)
        case "{}": textView.insertText("\n```\ncode\n```\n", replacementRange: sel)
        case "⇤": ts.addAttribute(.paragraphStyle, value: NSMutableParagraphStyle().also { $0.alignment = .left }, range: sel)
        case "⇔": ts.addAttribute(.paragraphStyle, value: NSMutableParagraphStyle().also { $0.alignment = .center }, range: sel)
        case "⇥": ts.addAttribute(.paragraphStyle, value: NSMutableParagraphStyle().also { $0.alignment = .right }, range: sel)
        case "🎨": ts.addAttribute(.foregroundColor, value: NSColor.red, range: sel)
        case "◧": ts.addAttribute(.backgroundColor, value: NSColor.yellow, range: sel)
        case "✕": ts.setAttributes([.font: NSFont.systemFont(ofSize: 13)], range: sel)
        default: break
        }
    }

    private func toggleTrait(_ trait: NSFontTraitMask, in range: NSRange) {
        guard range.length > 0 else { return }
        let ts = textView.textStorage!
        ts.enumerateAttribute(.font, in: range, options: []) { value, r, _ in
            if let font = value as? NSFont {
                let newFont = NSFontManager.shared.convert(font, toHaveTrait: trait)
                ts.addAttribute(.font, value: newFont, range: r)
            }
        }
    }
}

private func ids(_ arr: [Any]) -> [NSToolbarItem.Identifier] {
    arr.map {
        if let s = $0 as? String { return NSToolbarItem.Identifier(s) }
        return NSToolbarItem.Identifier.space
    }
}

extension NSMutableParagraphStyle {
    func also(_ block: (NSMutableParagraphStyle) -> Void) -> NSMutableParagraphStyle { block(self); return self }
}

private func prompt(_ msg: String) -> String? {
    let alert = NSAlert()
    alert.messageText = msg
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Отмена")
    let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
    alert.accessoryView = input
    return alert.runModal() == .alertFirstButtonReturn ? input.stringValue : nil
}

private let nativeToolItems: [String: String] = [
    "bold":"B","italic":"I","underline":"U",
    "h1":"H1","h2":"H2","h3":"H3","para":"¶",
    "bull":"•","num":"1.","task":"☑",
    "link":"🔗","img":"🖼","table":"⊞","hr":"—",
    "quote":"❝","code":"<>","preBlock":"{}",
    "left":"⇤","center":"⇔","right":"⇥",
    "color":"🎨","bg":"◧","clear":"✕",
]
