import SwiftUI

// MARK: - Отдельное View для туннеля с типом TunnelConnection
struct MenuBarTunnelRowView: View {
    @Binding var tunnel: TunnelConnection
    @State private var isTunnelHovered = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(tunnel.name.isEmpty ? "Туннель" : tunnel.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 3) {
                    Text("\(tunnel.remoteHost):")
                    Text((tunnel.remotePort.isEmpty ? "—"  :tunnel.remotePort))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 7))
                    Text((tunnel.effectiveLocalPort.isEmpty ? "—" : tunnel.effectiveLocalPort))
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $tunnel.isActive)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isTunnelHovered ? Color.primary.opacity(0.08) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isTunnelHovered = hovering
            }
        }
    }
}
