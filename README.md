# SSH Manager

> macOS menu bar SSH tunnel manager. Manage SSH servers and port tunnels right from the menu bar.

<p align="center">
  <img src="SSHManager/Resources/appIcon128.png" width="128" alt="SSH Manager Icon">
</p>

**SSH Manager** is a native macOS application for managing SSH connections and port tunnels. Built with SwiftUI and Swift 6, it lives in your menu bar and provides real-time monitoring, automatic reconnection, and system notifications.

## Features

- **Menu Bar Integration** — Quick access to servers and tunnels from the menu bar with status badges
- **Server Management** — Add SSH servers with key or password authentication
- **Port Tunnels** — Create multiple tunnels per server with custom local/remote ports
- **Real-time Monitoring** — Automatic connection checks with configurable intervals
- **Auto Reconnect** — Automatically restore dropped connections with configurable delay and retry count
- **System Notifications** — Native macOS notifications with server icons and disconnect reasons
- **Multi-language** — English, Русский, Беларуская, 中文, Français
- **Automatic Updates** — Sparkle integration for seamless updates from GitHub Releases
- **Unified Config** — Single `~/.ssh/sshmanager.json` config file (pretty-printed, manually editable)
- **Auto-launch** — Start at login via SMAppService
- **Liquid Glass UI** — Modern macOS 26 design with glass effects and hover animations

## Requirements

- macOS 26.0+ (macOS 14+ supported via deployment target)
- Xcode 26.0+ (Swift 6)
- `sshpass` (optional, for password authentication): `brew install hudochenkov/sshpass/sshpass`

## Installation

### From Source

```bash
git clone https://github.com/deveber/SSHManager.git
cd SSHManager
xcodebuild -project SSHManager.xcodeproj -scheme SSHManager -configuration Release build
open build/Build/Products/Release/SSHManager.app
```

### From Release

Download the latest `.dmg` from [GitHub Releases](https://github.com/deveber-ops/SSHManager/releases) and drag to Applications.

## Usage

### Adding a Server

1. Click **Open** in the menu bar or open the app window
2. Click **+** (Add Server) in the toolbar
3. Fill in required fields:
   - **Host** — SSH server address
   - **User** — SSH username
   - **Name** (optional) — display name
   - **Port** (optional) — default 22
   - **Auth Type** — SSH Key or Password
4. Click **Save** — the connection will be tested and server activated

### Adding a Tunnel

1. Select a server in the sidebar
2. Expand the **Tunnels** section
3. Click **Add Tunnel**
4. Configure:
   - **Host** — destination host
   - **Remote Port** — port on destination
   - **Local Port** — port on your machine
5. Toggle the switch to activate

### Menu Bar

- Click a server to open its settings
- Green badge shows active tunnel count
- Expand server row to see individual tunnels with quick toggles

### Settings

- **Menu Bar** — Change the menu bar icon
- **Monitoring** — Auto-reconnect toggle, reconnect delay (1-10s), retry count (1-∞), check interval (1-60s)
- **Language** — Switch between English, Русский, Беларуская, 中文, Français
- **Updates** — View current version and check for updates
- **Permissions** — Notifications, background mode, auto-launch
- **Reset Permissions** — Reset all system-level permissions

## Architecture

```
SSHManager/
├── App/
│   ├── SSHManagerApp.swift         # @main entry point, Window + MenuBarExtra
│   ├── AppDelegate.swift           # NSApplicationDelegate (notification coordination)
│   └── NotificationDelegate.swift  # UNUserNotificationCenterDelegate
├── Features/
│   ├── MenuBar/
│   │   ├── MenuBarView.swift       # Menu bar content (server list, buttons)
│   │   ├── MenuBarLabelView.swift  # Menu bar icon with badge
│   │   ├── MenuBarServerView.swift # Expandable server row with inline tunnels
│   │   └── MenuBarTunnelRowView.swift # Individual tunnel in menu bar
│   ├── Settings/
│   │   ├── SettingsView.swift      # NavigationSplitView (sidebar + detail)
│   │   ├── ServerDetailView.swift  # Server editor with inline tunnel list
│   │   ├── ServerRowView.swift     # Sidebar server row
│   │   ├── TunnelRowView.swift     # Tunnel editor
│   │   └── IconPickerButton.swift  # SF Symbol picker (280+ icons)
│   ├── AppSettings/
│   │   └── AppSettingsView.swift   # App settings form
│   └── About/
│       └── AboutView.swift         # About screen with contacts
├── Helpers/
│   ├── NativeCapsuleModifier.swift  # Liquid Glass capsule style
│   └── HoverBackgroundModifier.swift # Hover highlight modifier
├── Managers/
│   ├── TunnelConfigManager.swift   # Central state, monitoring, notifications
│   ├── TunnelManager.swift         # SSH process management
│   ├── LocalizationManager.swift   # Multi-language support (5 languages)
│   └── UpdateManager.swift         # Sparkle update controller
├── Models/
│   └── SSHServer.swift             # AppConfig, SSHServer, TunnelConnection, SSHAuthType
└── Resources/
    └── Assets.xcassets/            # App icons and assets
```

### Data Flow

```
SSHManagerApp (Window + MenuBarExtra)
    │
    ├── MenuBarView ← TunnelConfigManager (servers, state)
    │       └── TunnelManager (SSH processes)
    │
    └── SettingsView (NavigationSplitView)
            ├── ServerRowView (sidebar list)
            ├── ServerDetailView (server editor)
            │       └── TunnelRowView (tunnel editor)
            ├── AppSettingsView (preferences)
            └── AboutView (app info)

TunnelConfigManager (singleton, @MainActor)
    ├── servers: [SSHServer]        → ~/.ssh/sshmanager.json
    ├── settings: AppSettings       → inside sshmanager.json
    ├── checkTunnels()              → Timer-based monitoring
    └── sendNotification()          → Grouped notifications with icons

UpdateManager (singleton)
    └── SUUpdater                   → Sparkle auto-update
```

### Persistence

All configuration is stored in a single JSON file at `~/.ssh/sshmanager.json`:

```json
{
  "servers": [
    {
      "authType": "SSH Key",
      "icon": "server.rack",
      "id": "UUID",
      "isActive": true,
      "name": "Production",
      "sshHost": "prod.example.com",
      "sshKeyPath": "~/.ssh/id_rsa",
      "sshPort": "22",
      "sshUser": "admin",
      "tunnels": [
        {
          "id": "UUID",
          "isActive": true,
          "localPort": "3306",
          "name": "MySQL",
          "remoteHost": "db.internal",
          "remotePort": "3306"
        }
      ]
    }
  ],
  "settings": {
    "autoReconnect": true,
    "checkInterval": 10,
    "launchAtLogin": false,
    "menuBarIcon": "app.connected.to.app.below.fill",
    "notificationsEnabled": true,
    "reconnectAttempts": 3,
    "reconnectDelay": 5
  }
}
```

The file is pretty-printed with sorted keys, making it easy to edit manually or version-control.

### Monitoring

- Tunnels are checked via `lsof` on the local port
- Server connectivity is tested via SSH with `ConnectTimeout=5`
- Configurable check interval (1-60 seconds)
- Cooldown period (30s) prevents notification spam

### Auto Reconnect

When enabled and a connection drops:
1. Notification is sent with disconnect reason and auto-reconnect countdown
2. After configured delay, connection is re-tested
3. If still down, SSH process is restarted
4. Retries up to configured attempt count (or infinite)
5. Success notification upon reconnection

### Notifications

- Server disconnect: shows reason (DNS error, timeout, connection refused, etc.)
- Tunnel disconnect: grouped — multiple tunnels in one notification
- Icons: dynamically rendered SF Symbol with circular gray background
- Actions: "Reconnect" button (disabled when auto-reconnect is on)

## Build

```bash
# Debug build
xcodebuild -project SSHManager.xcodeproj -scheme SSHManager -configuration Debug build

# Release build (for distribution)
xcodebuild -project SSHManager.xcodeproj -scheme SSHManager -configuration Release build

# Archive (for distribution)
xcodebuild -project SSHManager.xcodeproj -scheme SSHManager -configuration Release archive
```

### Code Signing

The project is configured with:
- **Debug**: Automatic signing, no entitlements file needed (app-sandbox disabled)
- **Release**: `CODE_SIGN_ENTITLEMENTS = SSHManager/SSHManager.entitlements`

### Dependencies

- [Sparkle](https://github.com/sparkle-project/Sparkle) (v1.x) — automatic updates via SPM

## Localization

5 languages supported:

| Language    | Code | Coverage |
|-------------|------|----------|
| English     | en   | 100% (default) |
| Русский     | ru   | 100% |
| Беларуская  | be   | 100% |
| 中文         | zh   | 100% |
| Français    | fr   | 100% |

All strings are managed in `LocalizationManager.swift`. To add a language:

1. Add a case to the `Language` enum
2. Add translations to the `strings` dictionary
3. Build and select from Settings

## Release Process

1. Bump `MARKETING_VERSION` in Xcode project settings
2. Archive with Release configuration
3. Export `.app` and package as `.dmg`
4. Generate `appcast.xml` using Sparkle's `generate_appcast`:
   ```bash
   ./bin/generate_appcast /path/to/releases/
   ```
5. Create GitHub Release with `.dmg` and `appcast.xml`
6. Sparkle will automatically detect the update for existing users

## License

MIT © 2026 deveber

## Contacts

- Email: [deveber.dev@gmail.com](mailto:deveber.dev@gmail.com)
- Telegram: [@deveber](https://t.me/deveber)
