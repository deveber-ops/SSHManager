import Foundation

enum SSHConfigExporter {
    private static let marker = "# Added by SSH Manager"

    static func export(_ servers: [SSHServer]) -> String {
        guard !servers.isEmpty else { return "" }

        var entries: [String] = [marker]
        for server in servers where server.isValid {
            var lines: [String] = []
            lines.append("Host \(server.name.replacingOccurrences(of: " ", with: "-"))")
            lines.append("    HostName \(server.sshHost)")
            if !server.sshUser.isEmpty {
                lines.append("    User \(server.sshUser)")
            }
            let port = server.sshPort.isEmpty ? "22" : server.sshPort
            if port != "22" {
                lines.append("    Port \(port)")
            }
            if server.authType == .key && !server.sshKeyPath.isEmpty {
                lines.append("    IdentityFile \(server.sshKeyPath)")
            }
            entries.append(lines.joined(separator: "\n"))
        }
        return entries.joined(separator: "\n\n") + "\n"
    }

    static func appendToConfig(_ servers: [SSHServer], path: String? = nil) throws {
        let exportBlock = export(servers)
        guard !exportBlock.isEmpty else { return }

        let configURL: URL
        if let customPath = path {
            configURL = URL(fileURLWithPath: customPath)
        } else {
            configURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".ssh/config")
        }

        var existing = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""

        // Удаляем предыдущий блок SSH Manager если есть
        let parts = existing.components(separatedBy: marker)
        if parts.count > 1 {
            existing = parts[0].trimmingCharacters(in: .newlines)
        }

        if existing.isEmpty {
            existing = exportBlock
        } else {
            existing = existing + "\n\n" + exportBlock
        }

        let data = Data(existing.utf8)
        try data.write(to: configURL, options: .atomic)
    }
}
