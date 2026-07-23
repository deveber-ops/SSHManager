import SwiftUI

struct TunnelRowView: View {
    @Binding var tunnel: TunnelConnection
    @Binding var server: SSHServer
    @ObservedObject var configManager: TunnelConfigManager

    private var tunnelError: String? {
        configManager.validateTunnel(tunnel, in: server)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Название туннеля — отдельная строка
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    TextField("Название туннеля", text: $tunnel.name)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .frame(minWidth: 400)
                    if let err = tunnelError, err.contains("именем") {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                HStack(spacing: 4) {
                    Toggle(isOn: $tunnel.isActive) {
                        EmptyView()
                    }
                    .frame(maxWidth: 50)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .onChange(of: tunnel.isActive) { _, _ in
                        configManager.saveConnections()
                        if let s = configManager.servers.first(where: { $0.id == server.id }) {
                            configManager.restartSingleTunnel(tunnel: tunnel, server: s)
                        }
                    }

                    Button(role: .destructive) {
                        server.tunnels.removeAll { $0.id == tunnel.id }
                        configManager.saveConnections()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(width: 12, height: 12)
                    }
                    .buttonStyle(.plain)
                    .padding(2)
                    .hoverBackground(shape: Circle())
                }
                .liquidGlassCapsule(top: 4, leading: -4, bottom: 4, trailing: 4)
            }

            // Хост | Удаленный порт | Локальный порт — в одну строку
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    TextField("example.com", text: $tunnel.remoteHost)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .frame(minWidth: 60)

                    TextField("3306", text: $tunnel.remotePort)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .frame(width: 60)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 7))
                    TextField("13306", text: $tunnel.localPort)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .frame(width: 60)
                }
                if let err = tunnelError, !err.contains("именем") {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separatorColor).opacity(0.5), lineWidth: 1)
        )
    }
}
