#!/usr/bin/env swift
import SwiftUI
import AppKit
import WebKit

// MARK: - Configuration & Helpers

let projectDir = FileManager.default.currentDirectoryPath
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

// MARK: - HTML Editor (embedded for standalone script)

private let htmlEditorTemplate = """
<!DOCTYPE html><html lang="ru"><head><meta charset="UTF-8"><style>
:root { --bg: #f5f5f5; --toolbar-bg: #e8e8e8; --text: #1d1d1d; --border: #c8c8c8; --btn-hover: #d8d8d8; --editor-bg: #ffffff; }
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, sans-serif; background: var(--bg); display: flex; flex-direction: column; height: 100vh; user-select: none; }
#toolbar { display: flex; gap: 4px; padding: 8px 12px; background: var(--toolbar-bg); border-bottom: 1px solid var(--border); flex-wrap: wrap; }
#toolbar button { background: transparent; border: 1px solid transparent; border-radius: 5px; padding: 5px 9px; cursor: pointer; font-size: 13px; color: var(--text); }
#toolbar button:hover { background: var(--btn-hover); border-color: var(--border); }
#toolbar button.active { background: #c0c0c0; border-color: #aaa; }
#toolbar .sep { width: 1px; background: var(--border); margin: 0 4px; }
#editor { flex: 1; padding: 16px 20px; background: var(--editor-bg); outline: none; font-size: 14px; line-height: 1.6; color: var(--text); overflow-y: auto; }
#editor h1 { font-size: 20px; margin: 0 0 8px; font-weight: 700; }
#editor h2 { font-size: 17px; margin: 0 0 6px; font-weight: 600; }
#editor h3 { font-size: 15px; margin: 0 0 4px; font-weight: 600; }
#editor ul, #editor ol { padding-left: 24px; margin: 4px 0; }
#editor li { margin: 2px 0; }
#editor p { margin: 0 0 6px; }
#status { padding: 2px 12px; font-size: 11px; color: #999; background: var(--toolbar-bg); border-top: 1px solid var(--border); }
</style></head><body>
<div id="toolbar">
<button onclick="exec('bold')" title="Bold (⌘B)"><b>B</b></button>
<button onclick="exec('italic')" title="Italic (⌘I)"><i>I</i></button>
<span class="sep"></span>
<button onclick="exec('formatBlock','h3')" title="Heading"><b>H</b></button>
<button onclick="exec('insertUnorderedList')" title="List">•</button>
<span class="sep"></span>
<button onclick="exec('undo')" title="Undo (⌘Z)">↩</button>
<button onclick="exec('redo')" title="Redo (⌘⇧Z)">↪</button>
</div>
<div id="editor" contenteditable="true"></div>
<div id="status">Ready</div>
<script>
const editor = document.getElementById('editor');
function exec(cmd, arg) { document.execCommand(cmd, false, arg || null); editor.focus(); updateToolbar(); }
function updateToolbar() {
  document.querySelectorAll('#toolbar button').forEach(b => b.classList.remove('active'));
  if (document.queryCommandState('bold')) document.querySelector('[onclick*="bold"]').classList.add('active');
  if (document.queryCommandState('italic')) document.querySelector('[onclick*="italic"]').classList.add('active');
}
editor.addEventListener('keydown', e => {
  if (e.metaKey && e.key === 'b') { e.preventDefault(); exec('bold'); }
  if (e.metaKey && e.key === 'i') { e.preventDefault(); exec('italic'); }
  if (e.metaKey && e.key === 'z' && !e.shiftKey) { e.preventDefault(); exec('undo'); }
  if (e.metaKey && e.key === 'z' && e.shiftKey) { e.preventDefault(); exec('redo'); }
});
editor.addEventListener('input', () => { window.webkit.messageHandlers.contentChanged.postMessage(editor.innerHTML.trim()); });
editor.addEventListener('click', updateToolbar);
editor.addEventListener('keyup', updateToolbar);
function setContent(html) { editor.innerHTML = html; editor.focus(); }
function getContent() { return editor.innerHTML.trim(); }
</script></body></html>
"""

private func openHTMLEditor(initialHTML: String, completion: @escaping (String) -> Void) {
    // Записываем HTML-шаблон во временный файл (нужно для работы JS в WKWebView)
    let tmpDir = FileManager.default.temporaryDirectory
    let htmlFile = tmpDir.appendingPathComponent("sparkle_editor.html")
    try? htmlEditorTemplate.write(to: htmlFile, atomically: true, encoding: .utf8)

    let editor = EditorWindowController(initialHTML: initialHTML, htmlFileURL: htmlFile, completion: completion)
    editor.showWindow(nil)
}

private class EditorWindowController: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let initialHTML: String
    private let htmlFileURL: URL
    private let completion: (String) -> Void
    private var window: NSWindow?
    private var webView: WKWebView?
    private var tabView: NSTabView?

    init(initialHTML: String, htmlFileURL: URL, completion: @escaping (String) -> Void) {
        self.initialHTML = initialHTML
        self.htmlFileURL = htmlFileURL
        self.completion = completion
        super.init()
    }

    func showWindow(_ sender: Any?) {
        // Вкладки: Редактор | Предпросмотр (HTML) | Предпросмотр (Текст)
        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        self.tabView = tabView

        // Вкладка 1: Редактор
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "contentChanged")
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.setValue(false, forKey: "drawsBackground")
        wv.navigationDelegate = self
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.loadFileURL(htmlFileURL, allowingReadAccessTo: htmlFileURL.deletingLastPathComponent())
        self.webView = wv

        let editorTab = NSTabViewItem(identifier: "editor")
        editorTab.label = "Редактор"
        editorTab.view = wv
        tabView.addTabViewItem(editorTab)

        // Вкладка 2: Предпросмотр HTML
        let previewWV = WKWebView(frame: .zero)
        previewWV.setValue(false, forKey: "drawsBackground")
        previewWV.translatesAutoresizingMaskIntoConstraints = false
        previewWV.isHidden = true
        let previewTab = NSTabViewItem(identifier: "preview")
        previewTab.label = "HTML"
        previewTab.view = previewWV
        tabView.addTabViewItem(previewTab)

        // Вкладка 3: Предпросмотр текста
        let textPreview = NSTextView(frame: .zero)
        textPreview.isEditable = false
        textPreview.font = NSFont.systemFont(ofSize: 13)
        textPreview.translatesAutoresizingMaskIntoConstraints = false
        textPreview.backgroundColor = NSColor.white
        let textScroll = NSScrollView()
        textScroll.documentView = textPreview
        textScroll.hasVerticalScroller = true
        textScroll.translatesAutoresizingMaskIntoConstraints = false
        let textTab = NSTabViewItem(identifier: "text")
        textTab.label = "Текст"
        textTab.view = textScroll
        tabView.addTabViewItem(textTab)

        // Сохраняем ссылки для обновления предпросмотра
        tabView.delegate = self

        // Кнопки
        let btnCancel = NSButton(title: "Отмена", target: self, action: #selector(cancel))
        btnCancel.keyEquivalent = "\u{1b}"
        let btnDone = NSButton(title: "Готово", target: self, action: #selector(done))
        btnDone.keyEquivalent = "\r"
        btnDone.keyEquivalentModifierMask = .command
        btnDone.bezelStyle = .rounded

        let bottomBar = NSStackView(views: [btnCancel, NSView(), btnDone])
        bottomBar.orientation = .horizontal
        bottomBar.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(tabView)
        contentView.addSubview(bottomBar)
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tabView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            bottomBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 40)
        ])

        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 520), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        win.title = "Редактор описания обновления"
        win.contentView = contentView
        win.center()
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        self.window = win
    }

    @objc private func cancel() { window?.close() }
    @objc private func done() {
        webView?.evaluateJavaScript("getContent()") { [weak self] result, _ in
            if let html = result as? String {
                self?.completion(html)
            }
            self?.window?.close()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView == self.webView {
            let escaped = initialHTML
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            webView.evaluateJavaScript("setContent(`\(escaped)`)")
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Обновляем предпросмотр при изменении контента
        if let html = message.body as? String {
            updatePreviews(html: html)
        }
    }

    private func updatePreviews(html: String) {
        guard let tabView = tabView else { return }
        // HTML preview
        if let previewWV = (tabView.tabViewItem(at: 1)?.view as? WKWebView) {
            let styled = "<html><head><meta charset='utf-8'><style>body{font-family:-apple-system;font-size:14px;line-height:1.6;padding:16px;color:#1d1d1d;}h3{font-size:15px;margin:0 0 4px;}ul{padding-left:24px;}li{margin:2px 0;}</style></head><body>\(html)</body></html>"
            previewWV.loadHTMLString(styled, baseURL: nil)
        }
        // Text preview
        if let textScroll = (tabView.tabViewItem(at: 2)?.view as? NSScrollView),
           let textView = textScroll.documentView as? NSTextView {
            textView.string = htmlToText(html)
        }
    }
}

extension EditorWindowController: NSTabViewDelegate {
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        if let id = tabViewItem?.identifier as? String, id == "preview" || id == "text" {
            webView?.evaluateJavaScript("getContent()") { [weak self] result, _ in
                if let html = result as? String {
                    self?.updatePreviews(html: html)
                }
            }
        }
    }
}
