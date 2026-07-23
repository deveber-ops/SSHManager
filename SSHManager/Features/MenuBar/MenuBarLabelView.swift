import SwiftUI
import AppKit

struct MenuBarLabelView: View {
    @ObservedObject var configManager: TunnelConfigManager
    let refreshID: UUID

    var body: some View {
        let activeCount = configManager.servers.filter { $0.isActive }.count
        let hasActive = activeCount > 0
        HStack(spacing: 4) {
            Image(systemName: configManager.menuBarIcon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(hasActive ? .white : .primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(hasActive ? Color(nsColor: .controlBackgroundColor) : Color.clear)
                .clipShape(Capsule())
            if hasActive {
                Text("\(activeCount)")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(Capsule())
            }
        }
        .id(refreshID)
    }
}
