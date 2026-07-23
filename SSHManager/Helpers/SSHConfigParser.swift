import Foundation

struct ParsedSSHTunnel: Identifiable, Equatable {
    let id = UUID()
    let localPort: String
    let remoteHost: String
    let remotePort: String
}

struct ParsedSSHHost: Identifiable, Equatable {
    let id = UUID()
    let host: String
    let hostName: String
    let user: String
    let port: String
    let identityFile: String
    var tunnels: [ParsedSSHTunnel] = []
}

enum SSHConfigParser {
    static func parse(_ path: String? = nil) -> [ParsedSSHHost] {
        let configPath = path ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh/config").path

        guard FileManager.default.fileExists(atPath: configPath),
              let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return []
        }

        var hosts: [ParsedSSHHost] = []
        var currentHost = ""
        var currentHostName = ""
        var currentUser = ""
        var currentPort = ""
        var currentIdentityFile = ""
        var currentTunnels: [ParsedSSHTunnel] = []

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            guard let firstSpace = trimmed.firstIndex(where: { $0 == " " || $0 == "\t" }) else { continue }
            let key = String(trimmed[..<firstSpace]).lowercased()
            let value = String(trimmed[trimmed.index(after: firstSpace)...]).trimmingCharacters(in: .whitespaces)

            switch key {
            case "host":
                if !currentHost.isEmpty && !currentHostName.isEmpty && !isWildcard(currentHost) {
                    var host = ParsedSSHHost(
                        host: currentHost,
                        hostName: currentHostName,
                        user: currentUser,
                        port: currentPort,
                        identityFile: currentIdentityFile
                    )
                    host.tunnels = currentTunnels
                    hosts.append(host)
                }
                currentHost = value
                currentHostName = ""
                currentUser = ""
                currentPort = ""
                currentIdentityFile = ""
                currentTunnels = []

            case "hostname":
                currentHostName = value
            case "user":
                currentUser = value
            case "port":
                currentPort = value
            case "identityfile":
                currentIdentityFile = value
            case "localforward":
                if let tunnel = parseLocalForward(value) {
                    currentTunnels.append(tunnel)
                }
            default:
                break
            }
        }

        if !currentHost.isEmpty && !currentHostName.isEmpty && !isWildcard(currentHost) {
            var host = ParsedSSHHost(
                host: currentHost,
                hostName: currentHostName,
                user: currentUser,
                port: currentPort,
                identityFile: currentIdentityFile
            )
            host.tunnels = currentTunnels
            hosts.append(host)
        }

        return hosts
    }

    private static func parseLocalForward(_ value: String) -> ParsedSSHTunnel? {
        // Форматы:
        // "localPort remoteHost:remotePort"
        // "bindAddress:localPort remoteHost:remotePort"
        let parts = value.components(separatedBy: .whitespaces)
        guard parts.count >= 2 else { return nil }

        let localPart = parts[0]
        let remotePart = parts[1]

        // Извлекаем локальный порт (последняя часть после ":")
        let localPort: String
        if localPart.contains(":") {
            localPort = String(localPart.split(separator: ":").last ?? "")
        } else {
            localPort = localPart
        }

        // Извлекаем удалённый хост и порт
        let remoteComponents = remotePart.split(separator: ":")
        guard remoteComponents.count == 2 else { return nil }
        let remoteHost = String(remoteComponents[0])
        let remotePort = String(remoteComponents[1])

        return ParsedSSHTunnel(localPort: localPort, remoteHost: remoteHost, remotePort: remotePort)
    }

    private static func isWildcard(_ host: String) -> Bool {
        host.contains("*") || host.contains("?") || host.contains("!")
    }
}
