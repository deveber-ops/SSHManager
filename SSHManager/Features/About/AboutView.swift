import SwiftUI

struct AboutView: View {
    var appName: String { L10n.appName }
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "app.connected.to.app.below.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text(appName)
                .font(.system(size: 28, weight: .bold))

            Text(L10n.aboutVersion(appVersion))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(L10n.appDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .frame(maxWidth: 300)

            VStack(alignment: .leading, spacing: 10) {
                Label(L10n.aboutFeature1, systemImage: "server.rack")
                Label(L10n.aboutFeature2, systemImage: "arrow.triangle.2.circlepath")
                Label(L10n.aboutFeature3, systemImage: "antenna.radiowaves.left.and.right")
                Label(L10n.aboutFeature4, systemImage: "bell")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 16) {
                HStack {
                    Button {
                        if let url = URL(string: "mailto:deveber.dev@gmail.com") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 13))
                            Text("deveber.dev@gmail.com")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .hoverBackground(shape: Capsule())
                }
                .liquidGlassCapsule(0)

                HStack {
                    Button {
                        if let url = URL(string: "https://t.me/deveber") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 13))
                            Text("@deveber")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .hoverBackground(shape: Capsule())
                }
                .liquidGlassCapsule(0)
            }

            Text("© 2026 deveber")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
