import Foundation
import OSLog

private let logger = Logger(subsystem: "com.deveber.SSHManager", category: "TunnelManager")

// MARK: - SSH туннель manager
final class TunnelManager: @unchecked Sendable {
    static let shared = TunnelManager()

    @discardableResult
    func runSSHTunnel(tunnel: TunnelConnection, server: SSHServer) -> Bool {
        let port = tunnel.effectiveLocalPort
        guard tunnel.isValid, server.isValid, !port.isEmpty else { return false }
        let task = Process()
        var arguments: [String] = []
        let sshPath = "/usr/bin/ssh"
        if server.authType == .password && !server.sshPassword.isEmpty {
            let p1 = "/opt/homebrew/bin/sshpass"
            let p2 = "/usr/local/bin/sshpass"
            if FileManager.default.fileExists(atPath: p1) {
                task.launchPath = p1; arguments += ["-p", server.sshPassword, "ssh"]
            } else if FileManager.default.fileExists(atPath: p2) {
                task.launchPath = p2; arguments += ["-p", server.sshPassword, "ssh"]
            } else {
                task.launchPath = sshPath
            }
        } else { task.launchPath = sshPath }
        arguments += ["-f", "-N"]
        if !server.sshPort.isEmpty && server.sshPort != "22" {
            arguments += ["-p", server.sshPort]
        }
        if server.authType == .key && !server.sshKeyPath.isEmpty {
            let r = (server.sshKeyPath as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: r) { arguments += ["-i", r, "-o", "IdentitiesOnly=yes"] }
        }
        let remoteHost = tunnel.remoteHost.isEmpty ? "localhost" : tunnel.remoteHost
        arguments += ["-L", "\(port):\(remoteHost):\(tunnel.remotePort)"]
        arguments += ["\(server.sshUser)@\(server.sshHost)"]
        arguments += ["-o", "ServerAliveInterval=60", "-o", "StrictHostKeyChecking=no", "-o", "ExitOnForwardFailure=yes"]
        task.arguments = arguments
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()
        // -f форкает SSH, родитель завершается сразу. Проверяем появление порта.
        for _ in 0..<15 {
            if checkTunnelIsRunning(tunnel) { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }

    func killSSHTunnel(tunnel: TunnelConnection) {
        let port = tunnel.effectiveLocalPort
        guard !port.isEmpty else { return }
        // Убиваем SSH процесс по порту
        let pkill = Process(); pkill.launchPath = "/usr/bin/pkill"
        pkill.arguments = ["-f", "ssh.*-L.*\(port):"]
        try? pkill.run(); pkill.waitUntilExit()
        // Дополнительно через lsof (на случай sshpass)
        let lsof = Process(); lsof.launchPath = "/usr/sbin/lsof"
        lsof.arguments = ["-ti", "tcp:\(port)"]
        let out = Pipe(); lsof.standardOutput = out; lsof.standardError = Pipe()
        try? lsof.run(); lsof.waitUntilExit()
        let pids = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !pids.isEmpty else { return }
        let kill = Process(); kill.launchPath = "/usr/bin/kill"
        kill.arguments = pids.components(separatedBy: "\n").filter { !$0.isEmpty }
        try? kill.run(); kill.waitUntilExit()
    }

    func checkTunnelIsRunning(_ tunnel: TunnelConnection) -> Bool {
        let port = tunnel.effectiveLocalPort
        guard !port.isEmpty else { return false }
        let t = Process(); t.launchPath = "/usr/sbin/lsof"
        t.arguments = ["-ti", "tcp:\(port)"]
        let p = Pipe(); t.standardOutput = p; t.standardError = Pipe()
        try? t.run(); t.waitUntilExit()
        let o = String(data: p.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return !o.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func checkServerConnection(_ server: SSHServer) async -> (success: Bool, reason: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let t = Process(); t.launchPath = "/usr/bin/ssh"
                var args = ["-o", "ConnectTimeout=5", "-o", "StrictHostKeyChecking=no", "-o", "LogLevel=ERROR", "-o", "BatchMode=yes"]
                if !server.sshPort.isEmpty && server.sshPort != "22" {
                    args += ["-p", server.sshPort]
                }
                if server.authType == .key && !server.sshKeyPath.isEmpty {
                    let r = (server.sshKeyPath as NSString).expandingTildeInPath
                    if FileManager.default.fileExists(atPath: r) { args += ["-i", r, "-o", "IdentitiesOnly=yes"] }
                }
                args += ["\(server.sshUser)@\(server.sshHost)", "-T"]
                t.arguments = args
                let errPipe = Pipe()
                t.standardOutput = Pipe()
                t.standardError = errPipe
                try? t.run(); t.waitUntilExit()

                let ok = t.terminationStatus == 0
                let reason: String
                if ok {
                    reason = ""
                } else {
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if errStr.contains("Could not resolve hostname") || errStr.contains("Name or service not known") {
                        reason = "Не удалось найти сервер (проверьте адрес)"
                    } else if errStr.contains("Connection refused") {
                        reason = "Сервер отклонил подключение (порт закрыт или сервис не запущен)"
                    } else if errStr.contains("Connection timed out") || errStr.contains("Operation timed out") {
                        reason = "Сервер не отвечает (истекло время ожидания)"
                    } else if errStr.contains("No route to host") {
                        reason = "Нет связи с сервером (проверьте интернет-соединение)"
                    } else if errStr.contains("Connection closed by remote host") || errStr.contains("kex_exchange_identification") {
                        reason = "Сервер разорвал подключение (возможно, блокировка или перегрузка)"
                    } else if errStr.contains("Permission denied") {
                        reason = "Ошибка входа (неверный ключ или пароль)"
                    } else if errStr.contains("Host key verification failed") {
                        reason = "Ключ сервера не совпадает (изменился или подмена)"
                    } else if errStr.contains("Network is unreachable") {
                        reason = "Сеть недоступна (проверьте интернет-соединение)"
                    } else {
                        let firstLine = errStr.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces) ?? ""
                        reason = firstLine.isEmpty ? "Неизвестная ошибка подключения" : firstLine
                    }
                }
                continuation.resume(returning: (ok, reason))
            }
        }
    }
}
