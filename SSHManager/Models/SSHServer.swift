import Foundation

// MARK: - Единый конфиг приложения
struct AppConfig: Codable, Equatable {
    var settings: AppSettings
    var servers: [SSHServer]

    static let `default` = AppConfig(
        settings: AppSettings(),
        servers: []
    )
}

struct AppSettings: Codable, Equatable {
    var menuBarIcon: String = "app.connected.to.app.below.fill"
    var launchAtLogin: Bool = false
    var autoReconnect: Bool = false
    var reconnectDelay: Int = 5
    var reconnectAttempts: Int = 3
    var checkInterval: Int = 10
    var notificationsEnabled: Bool = true
}

// MARK: - Сервер
struct SSHServer: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = ""
    var sshHost: String = ""
    var sshPort: String = ""
    var sshUser: String = ""
    var authType: SSHAuthType = .key
    var sshPassword: String = ""
    var sshKeyPath: String = ""
    var isActive: Bool = false
    var icon: String = "server.rack"
    var tunnels: [TunnelConnection] = []

    var isValid: Bool {
        !sshHost.isEmpty && !sshUser.isEmpty
    }
}

struct TunnelConnection: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = ""
    var localPort: String = ""
    var remoteHost: String = ""
    var remotePort: String = ""
    var isActive: Bool = false

    var effectiveLocalPort: String {
        localPort.isEmpty ? remotePort : localPort
    }

    var isValid: Bool {
        !remoteHost.isEmpty && !remotePort.isEmpty
    }
}

enum SSHAuthType: String, Codable, CaseIterable, Identifiable {
    case key = "SSH Key"
    case password = "Password"
    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = SSHAuthType(rawValue: raw) ?? .key
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
