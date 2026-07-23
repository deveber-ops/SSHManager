import SwiftUI

// MARK: - Вспомогательное View для строки сервера в Менюбаре
struct ServerMenuRowView: View {
    @Binding var server: SSHServer
    var onSelect: () -> Void

    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Шапка сервера
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))

                        Image(systemName: server.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(server.isActive ? Color.accentColor : .secondary)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(server.name.isEmpty ? "Сервер" : server.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(server.sshHost.isEmpty ? "Нет адреса" : server.sshHost)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                HStack {
                    // Кнопка терминала
                    Button(action: { openTerminalWindow(for: server) }) {
                        Image(systemName: "terminal")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverBackground(shape: Circle())
                    .disabled(server.sshHost.isEmpty || server.sshUser.isEmpty)
                    .help("Открыть консоль")

                    // Кнопка перехода в настройки сервера
                    Button(action: onSelect) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverBackground(shape: Circle())

                    // Свитч сервера
                    Toggle("", isOn: $server.isActive)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }
                .liquidGlassCapsule()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            // MARK: - Раскрывающийся список туннелей
            if isExpanded {
                VStack(spacing: 2) {
                    if server.tunnels.isEmpty {
                        Text("Нет настроенных туннелей")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 6)
                    } else {
                        ForEach($server.tunnels) { $tunnel in
                            MenuBarTunnelRowView(tunnel: $tunnel)
                        }
                    }
                }
                .padding(4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
