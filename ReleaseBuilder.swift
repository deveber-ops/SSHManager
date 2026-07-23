#!/usr/bin/env swift
import SwiftUI
import AppKit

// MARK: - Configuration
let projectDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let scheme = "SSHManager"
let archiveDir = "\(projectDir)/archive"
let dmgDir = "\(projectDir)/release"
let githubRepo = "deveber-ops/SSHManager"

// MARK: - Models
struct Step: Identifiable {
    let id = UUID()
    let name: String
    var log = ""
    var status: StepStatus = .pending
    var action: (() -> Bool)?
    enum StepStatus { case pending, running, done, failed }
}

// MARK: - ViewModel
class ReleaseVM: ObservableObject {
    @Published var steps: [Step] = []
    @Published var progress: Double = 0
    @Published var isRunning = false
    @Published var editorText = "- Что нового\n+ описание\n"
    private var cancelled = false

    func setup() {
        let ver = fetchVersion()
        let dmg = "\(dmgDir)/SSHManager-\(ver).dmg"

        steps = [
            Step(name: "Очистка") { [weak self] in
                [archiveDir, dmgDir].forEach { try? FileManager.default.removeItem(atPath: $0) }
                try? FileManager.default.createDirectory(atPath: archiveDir, withIntermediateDirectories: true)
                try? FileManager.default.createDirectory(atPath: dmgDir, withIntermediateDirectories: true)
                return true
            },
            Step(name: "Сборка") { [weak self] in
                guard let self else { return false }
                return self.shellOK("""
                    xcodebuild -project '\(projectDir)/SSHManager.xcodeproj' -scheme '\(scheme)' -configuration Release -derivedDataPath '\(projectDir)/build' archive -archivePath '\(archiveDir)/\(scheme).xcarchive' CODE_SIGN_STYLE=Automatic 2>&1
                    cp -R '\(archiveDir)/\(scheme).xcarchive/Products/Applications/SSHManager.app' '\(archiveDir)/SSHManager.app'
                    """)
            },
            Step(name: "DMG") { [weak self] in
                guard let self else { return false }
                let tmp = "\(dmgDir)/tmp"
                try? FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
                self.shell("cp -R '\(archiveDir)/SSHManager.app' '\(tmp)/' && ln -sf /Applications '\(tmp)/Applications'")
                let ok = self.shellOK("hdiutil create -volname 'SSHManager' -srcfolder '\(tmp)' -ov -format UDZO '\(dmg)' 2>&1")
                self.shell("rm -rf '\(tmp)'")
                return ok
            },
            Step(name: "Описание") { [weak self] in
                guard let self else { return false }
                let file = "\(dmgDir)/release_notes.txt"
                try? self.editorText.write(toFile: file, atomically: true, encoding: .utf8)
                return true
            },
            Step(name: "Релиз") { [weak self] in
                guard let self else { return false }
                let notes = (try? String(contentsOfFile: "\(dmgDir)/release_notes.txt", encoding: .utf8)) ?? "v\(ver)"
                let size = (try? FileManager.default.attributesOfItem(atPath: dmg)[.size] as? Int) ?? 0
                let url = "https://github.com/\(githubRepo)/releases/download/v\(ver)/SSHManager-\(ver).dmg"
                let date = ISO8601DateFormatter().string(from: Date())
                let appcast = """
                <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
                  <channel><title>SSH Manager</title>
                    <item><title>Version \(ver)</title>
                      <sparkle:version>\(ver)</sparkle:version>
                      <sparkle:shortVersionString>\(ver)</sparkle:shortVersionString>
                      <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
                      <pubDate>\(date)</pubDate>
                      <description><![CDATA[\(notes)]]></description>
                      <enclosure url="\(url)" sparkle:version="\(ver)" sparkle:shortVersionString="\(ver)" length="\(size)" type="application/octet-stream"/>
                    </item></channel></rss>
                """
                try? appcast.write(toFile: "\(dmgDir)/appcast.xml", atomically: true, encoding: .utf8)
                self.shell("cp '\(dmgDir)/appcast.xml' '\(projectDir)/appcast.xml'")
                return self.shellOK("cd '\(projectDir)' && git add appcast.xml && git commit -m 'Release v\(ver)' && git push origin main && gh release create 'v\(ver)' --repo '\(githubRepo)' --title 'v\(ver)' --notes '\(notes)' '\(dmg)' 2>&1")
            },
        ]
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true; cancelled = false; progress = 0
        for i in steps.indices { steps[i].status = .pending; steps[i].log = "" }
        Task {
            for i in steps.indices {
                if cancelled { break }
                steps[i].status = .running
                let ok = steps[i].action?() ?? false
                steps[i].status = ok ? .done : .failed
                progress = Double(i + 1) / Double(steps.count) * 100
                if !ok { break }
            }
            isRunning = false
        }
    }

    func reset() { cancelled = true; isRunning = false; setup() }

    private func fetchVersion() -> String {
        let plist = "\(projectDir)/SSHManager/Info.plist"
        let data = try? Data(contentsOf: URL(fileURLWithPath: plist))
        let dict = data.flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] }
        return dict?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    @discardableResult func shell(_ cmd: String) -> String {
        let p = Process(); p.launchPath = "/bin/bash"; p.arguments = ["-c", cmd]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        try? p.run(); p.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    func shellOK(_ cmd: String) -> Bool {
        let p = Process(); p.launchPath = "/bin/bash"; p.arguments = ["-c", cmd]
        p.environment = ProcessInfo.processInfo.environment
        p.environment?["DEVELOPER_DIR"] = "/Applications/Xcode.app/Contents/Developer"
        try? p.run(); p.waitUntilExit()
        return p.terminationStatus == 0
    }
}

// MARK: - Views
struct StepRow: View {
    let step: Step
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: step.status == .done ? "checkmark.circle.fill" : step.status == .running ? "arrow.triangle.circlepath" : step.status == .failed ? "xmark.circle.fill" : "circle")
                .foregroundStyle(step.status == .done ? .green : step.status == .running ? .blue : step.status == .failed ? .red : .secondary)
            Text(step.name).font(.system(size: 12))
            Spacer()
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
    }
}

struct ReleaseView: View {
    @StateObject private var vm = ReleaseVM()
    @State private var copied = false
    @State private var previewTab = 0

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            HSplitView {
                editorView.frame(minWidth: 300)
                previewView.frame(minWidth: 200, idealWidth: 250)
            }
        }
        .frame(minWidth: 750, minHeight: 500)
        .onAppear { vm.setup() }
    }

    private var sidebar: some View {
        VStack(spacing: 8) {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(vm.steps) { StepRow(step: $0) }
                }.padding(8)
            }
            if vm.isRunning {
                ProgressView(value: vm.progress, total: 100).progressViewStyle(.linear).padding(.horizontal, 8)
            }
            HStack {
                Button(vm.isRunning ? "Стоп" : "Запустить") { vm.isRunning ? vm.reset() : vm.start() }
                    .buttonStyle(.borderedProminent)
                Button("Сбросить") { vm.reset() }
            }.padding(8)
            Button("Копировать лог") {
                let log = vm.steps.map { "\($0.name):\n\($0.log)" }.joined(separator: "\n\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(log, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            }
            if copied { Text("✓").font(.caption).foregroundColor(.green) }
        }
    }

    private var editorView: some View {
        VStack(spacing: 0) {
            Text("Редактор описания").font(.headline).padding(.horizontal).padding(.top, 8)
            Text("- разделы, + пункты").font(.caption).foregroundStyle(.secondary).padding(.horizontal)
            TextEditor(text: $vm.editorText)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
        }
    }

    private var previewView: some View {
        VStack(spacing: 0) {
            Picker("", selection: $previewTab) {
                Text("HTML").tag(0)
                Text("Текст").tag(1)
            }.pickerStyle(.segmented).padding(8)
            ScrollView {
                Text(previewTab == 0 ? parseHTML(vm.editorText) : parseText(vm.editorText))
                    .font(.system(size: 11, design: previewTab == 0 ? .monospaced : .default))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

func parseHTML(_ text: String) -> String {
    var h = ""; var inList = false
    for line in text.components(separatedBy: "\n") {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("- ") { if inList { h += "</ul>\n"; inList = false }; h += "<h3>\(t.dropFirst(2))</h3>\n" }
        else if t.hasPrefix("+ ") { if !inList { h += "<ul>\n"; inList = true }; h += "<li>\(t.dropFirst(2))</li>\n" }
    }
    if inList { h += "</ul>\n" }
    return h
}

func parseText(_ text: String) -> String {
    var r = ""
    for line in text.components(separatedBy: "\n") {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("- ") { r += "\n\(t.dropFirst(2))\n" }
        else if t.hasPrefix("+ ") { r += "• \(t.dropFirst(2))\n" }
    }
    return r.trimmingCharacters(in: .newlines)
}

// MARK: - Entry Point
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let w = NSWindow(contentViewController: NSHostingController(rootView: ReleaseView()))
w.title = "SSH Manager Release Builder"
w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
w.setContentSize(NSSize(width: 750, height: 500))
w.center()
w.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
app.run()
