import Foundation

struct ParsedSSHHost: Identifiable, Equatable {
    let id = UUID()
    let host: String
    let hostName: String
    let user: String
    let port: String
    let identityFile: String
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

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Пропускаем комментарии и пустые строки
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            // Разбиваем на ключ + значение (учитываем пробелы/табы)
            guard let firstSpace = trimmed.firstIndex(where: { $0 == " " || $0 == "\t" }) else { continue }
            let key = String(trimmed[..<firstSpace]).lowercased()
            let value = String(trimmed[trimmed.index(after: firstSpace)...]).trimmingCharacters(in: .whitespaces)

            switch key {
            case "host":
                // Сохраняем предыдущий хост если он заполнен
                if !currentHost.isEmpty && !currentHostName.isEmpty && !isWildcard(currentHost) {
                    hosts.append(ParsedSSHHost(
                        host: currentHost,
                        hostName: currentHostName,
                        user: currentUser,
                        port: currentPort,
                        identityFile: currentIdentityFile
                    ))
                }
                // Начинаем новый
                currentHost = value
                currentHostName = ""
                currentUser = ""
                currentPort = ""
                currentIdentityFile = ""

            case "hostname":
                currentHostName = value
            case "user":
                currentUser = value
            case "port":
                currentPort = value
            case "identityfile":
                currentIdentityFile = value
            default:
                break
            }
        }

        // Сохраняем последний хост
        if !currentHost.isEmpty && !currentHostName.isEmpty && !isWildcard(currentHost) {
            hosts.append(ParsedSSHHost(
                host: currentHost,
                hostName: currentHostName,
                user: currentUser,
                port: currentPort,
                identityFile: currentIdentityFile
            ))
        }

        return hosts
    }

    private static func isWildcard(_ host: String) -> Bool {
        host.contains("*") || host.contains("?") || host.contains("!")
    }
}
