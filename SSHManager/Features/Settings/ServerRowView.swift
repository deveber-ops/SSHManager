import SwiftUI

struct ServerRowView: View {
    let server: SSHServer
    @ObservedObject var configManager: TunnelConfigManager

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: server.icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.name.isEmpty ? "Сервер" : server.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(server.sshHost.isEmpty ? "Нет адреса" : server.sshHost)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 4) {
                Button(action: {
                    if let i = configManager.servers.firstIndex(where: { $0.id == server.id }) {
                        configManager.servers[i].isActive.toggle()
                        configManager.saveConnections()
                        configManager.restartTunnels(for: configManager.servers[i])
                    }
                }) {
                    Image(systemName: "power")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(server.isActive ? .green : .secondary)
                        .frame(width: 22, height: 22)
                        .background(server.isActive ? Color.green.opacity(0.15) : .clear, in: .circle)
                }
                .buttonStyle(.plain)
                .hoverBackground(shape: Circle(), padding: 0)

                Button(action: { openTerminalWindow(for: server) }) {
                    Image(systemName: "terminal")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .hoverBackground(shape: Circle(), padding: 0)
                .disabled(server.sshHost.isEmpty || server.sshUser.isEmpty)

                Button(role: .destructive) {
                    configManager.servers.removeAll { $0.id == server.id }
                    configManager.saveConnections()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .hoverBackground(shape: Circle(), padding: 0)
            }
            .liquidGlassCapsule()
        }
        .padding(4)
        .contentShape(Capsule())
    }
}
