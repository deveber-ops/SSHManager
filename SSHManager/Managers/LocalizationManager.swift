import Foundation
import SwiftUI
import Combine

// MARK: - Языки
enum Language: String, CaseIterable, Identifiable {
    case english = "en"
    case russian = "ru"
    case belarusian = "be"
    case chinese = "zh"
    case french = "fr"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .english: return "English"
        case .russian: return "Русский"
        case .belarusian: return "Беларуская"
        case .chinese: return "中文"
        case .french: return "Français"
        }
    }
}

// MARK: - Менеджер локализации
@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var language: Language {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        language = Language(rawValue: saved) ?? .english
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
    }

    func string(_ key: String) -> String {
        strings[key]?[language] ?? strings[key]?[.english] ?? key
    }

    // swiftlint:disable function_body_length
    private let strings: [String: [Language: String]] = [
        // MARK: - Общие
        "app.name": [.english: "SSH Manager", .russian: "SSH Manager", .belarusian: "SSH Manager", .chinese: "SSH 管理器", .french: "Gestionnaire SSH"],
        "app.description": [
            .english: "SSH Tunnel Manager in Menu Bar",
            .russian: "Менеджер SSH туннелей в строке меню",
            .belarusian: "Менеджар SSH тунэляў у радку меню",
            .chinese: "菜单栏中的 SSH 隧道管理器",
            .french: "Gestionnaire de tunnels SSH dans la barre de menus"
        ],

        // MARK: - Меню
        "menu.open": [.english: "Open", .russian: "Открыть", .belarusian: "Адкрыць", .chinese: "打开", .french: "Ouvrir"],
        "menu.quit": [.english: "Quit", .russian: "Выйти", .belarusian: "Выйсці", .chinese: "退出", .french: "Quitter"],
        "menu.noServers": [.english: "No servers", .russian: "Нет серверов", .belarusian: "Няма сервераў", .chinese: "无服务器", .french: "Aucun serveur"],
        "menu.noAddress": [.english: "No address", .russian: "Нет адреса", .belarusian: "Няма адрасу", .chinese: "无地址", .french: "Pas d'adresse"],
        "menu.server": [.english: "Server", .russian: "Сервер", .belarusian: "Сервер", .chinese: "服务器", .french: "Serveur"],
        "menu.noTunnels": [.english: "No tunnels configured", .russian: "Нет настроенных туннелей", .belarusian: "Няма наладжаных тунэляў", .chinese: "未配置隧道", .french: "Aucun tunnel configuré"],

        // MARK: - Боковая панель
        "sidebar.addServer": [.english: "Add Server", .russian: "Добавить сервер", .belarusian: "Дадаць сервер", .chinese: "添加服务器", .french: "Ajouter un serveur"],
        "sidebar.search": [.english: "Search servers and tunnels", .russian: "Поиск серверов и туннелей", .belarusian: "Пошук сервераў і тунэляў", .chinese: "搜索服务器和隧道", .french: "Rechercher serveurs et tunnels"],
        "sidebar.noServers": [.english: "No servers", .russian: "Нет серверов", .belarusian: "Няма сервераў", .chinese: "无服务器", .french: "Aucun serveur"],

        // MARK: - Настройки (тулбар)
        "toolbar.settings": [.english: "Settings", .russian: "Настройки", .belarusian: "Налады", .chinese: "设置", .french: "Paramètres"],
        "toolbar.about": [.english: "About", .russian: "О приложении", .belarusian: "Аб праграме", .chinese: "关于", .french: "À propos"],

        // MARK: - ServerDetail
        "server.symbolAndName": [.english: "Symbol & Name", .russian: "Символ и название", .belarusian: "Сімвал і назва", .chinese: "符号与名称", .french: "Symbole et nom"],
        "server.name": [.english: "Name", .russian: "Название", .belarusian: "Назва", .chinese: "名称", .french: "Nom"],
        "server.namePlaceholder": [.english: "Server name", .russian: "Название сервера", .belarusian: "Назва сервера", .chinese: "服务器名称", .french: "Nom du serveur"],
        "server.connection": [.english: "Connection", .russian: "Подключение", .belarusian: "Падключэнне", .chinese: "连接", .french: "Connexion"],
        "server.host": [.english: "Host", .russian: "Хост", .belarusian: "Хост", .chinese: "主机", .french: "Hôte"],
        "server.port": [.english: "Port", .russian: "Порт", .belarusian: "Порт", .chinese: "端口", .french: "Port"],
        "server.user": [.english: "User", .russian: "Пользователь", .belarusian: "Карыстальнік", .chinese: "用户", .french: "Utilisateur"],
        "server.authType": [.english: "Auth Type", .russian: "Тип авторизации", .belarusian: "Тып аўтарызацыі", .chinese: "认证类型", .french: "Type d'authentification"],
        "server.password": [.english: "Password", .russian: "Пароль", .belarusian: "Пароль", .chinese: "密码", .french: "Mot de passe"],
        "server.keyPath": [.english: "SSH Key Path", .russian: "Путь к SSH ключу", .belarusian: "Шлях да SSH ключа", .chinese: "SSH 密钥路径", .french: "Chemin de la clé SSH"],
        "server.browse": [.english: "Browse...", .russian: "Обзор...", .belarusian: "Агляд...", .chinese: "浏览...", .french: "Parcourir..."],
        "server.tunnels": [.english: "Tunnels", .russian: "Туннели", .belarusian: "Тунэлі", .chinese: "隧道", .french: "Tunnels"],
        "server.addTunnel": [.english: "Add Tunnel", .russian: "Добавить туннель", .belarusian: "Дадаць тунэль", .chinese: "添加隧道", .french: "Ajouter un tunnel"],
        "server.noTunnels": [.english: "No tunnels", .russian: "Нет туннелей", .belarusian: "Няма тунэляў", .chinese: "无隧道", .french: "Aucun tunnel"],
        "server.save": [.english: "Save", .russian: "Сохранить", .belarusian: "Захаваць", .chinese: "保存", .french: "Enregistrer"],
        "server.saving": [.english: "Saving...", .russian: "Сохранение...", .belarusian: "Захаванне...", .chinese: "保存中...", .french: "Enregistrement..."],

        // MARK: - Tunnel
        "tunnel.name": [.english: "Tunnel name", .russian: "Название туннеля", .belarusian: "Назва тунэля", .chinese: "隧道名称", .french: "Nom du tunnel"],
        "tunnel.tunnel": [.english: "tunnel", .russian: "туннель", .belarusian: "тунэль", .chinese: "隧道", .french: "tunnel"],

        // MARK: - Ошибки валидации
        "validation.serverNameExists": [.english: "Server with name \"%@\" already exists", .russian: "Сервер с именем «%@» уже существует", .belarusian: "Сервер з імем «%@» ужо існуе", .chinese: "名为「%@」的服务器已存在", .french: "Le serveur nommé «%@» existe déjà"],
        "validation.serverHostExists": [.english: "Server %@:%@ already exists", .russian: "Сервер %@:%@ уже добавлен", .belarusian: "Сервер %@:%@ ужо дададзены", .chinese: "服务器 %@:%@ 已添加", .french: "Le serveur %@:%@ existe déjà"],
        "validation.tunnelNameExists": [.english: "Tunnel with name \"%@\" already exists", .russian: "Туннель с именем «%@» уже существует", .belarusian: "Тунэль з імем «%@» ужо існуе", .chinese: "名为「%@」的隧道已存在", .french: "Le tunnel nommé «%@» existe déjà"],
        "validation.tunnelHostExists": [.english: "Tunnel %@:%@→:%@ already exists", .russian: "Туннель %@:%@→:%@ уже добавлен", .belarusian: "Тунэль %@:%@→:%@ ужо дададзены", .chinese: "隧道 %@:%@→:%@ 已添加", .french: "Le tunnel %@:%@→:%@ existe déjà"],
        "save.error.connect": [.english: "Connection failed: %@", .russian: "Не удалось подключиться: %@", .belarusian: "Не атрымалася падключыцца: %@", .chinese: "连接失败: %@", .french: "Échec de connexion: %@"],
        "alert.saveError": [.english: "Save Error", .russian: "Ошибка сохранения", .belarusian: "Памылка захавання", .chinese: "保存错误", .french: "Erreur d'enregistrement"],

        // MARK: - Уведомления
        "notif.serverDown": [.english: "Server connection lost", .russian: "Подключение к серверу разорвано", .belarusian: "Падключэнне да сервера страчана", .chinese: "服务器连接丢失", .french: "Connexion au serveur perdue"],
        "notif.serverUp": [.english: "Server connection restored", .russian: "Подключение к серверу восстановлено", .belarusian: "Падключэнне да сервера адноўлена", .chinese: "服务器连接已恢复", .french: "Connexion au serveur rétablie"],
        "notif.tunnelDown": [.english: "Tunnel connection lost", .russian: "Подключение к туннелю %@ разорвано", .belarusian: "Падключэнне да тунэля %@ страчана", .chinese: "隧道 %@ 连接丢失", .french: "Connexion au tunnel %@ perdue"],
        "notif.tunnelsDown": [.english: "Tunnels disconnected: %@", .russian: "Разорвано подключение к туннелям: %@", .belarusian: "Страчана падключэнне да тунэляў: %@", .chinese: "隧道断开: %@", .french: "Tunnels déconnectés: %@"],
        "notif.tunnelUp": [.english: "Tunnel connection restored", .russian: "Подключение к туннелю %@ восстановлено", .belarusian: "Падключэнне да тунэля %@ адноўлена", .chinese: "隧道 %@ 连接已恢复", .french: "Connexion au tunnel %@ rétablie"],
        "notif.autoReconnect": [.english: "Auto-reconnect in %d sec", .russian: "Автопереподключение через %d сек", .belarusian: "Аўтападключэнне праз %d сек", .chinese: "将在 %d 秒后自动重连", .french: "Reconnexion automatique dans %d sec"],
        "notif.reconnectAction": [.english: "Reconnect", .russian: "Переподключиться", .belarusian: "Перападключыцца", .chinese: "重新连接", .french: "Reconnecter"],
        "notif.reconnectError": [.english: "Reconnect failed: %@", .russian: "Ошибка переподключения: %@", .belarusian: "Памылка перападключэння: %@", .chinese: "重连失败: %@", .french: "Échec de reconnexion: %@"],

        // MARK: - Настройки приложения
        "settings.menuBar": [.english: "Menu Bar", .russian: "Строка меню", .belarusian: "Радок меню", .chinese: "菜单栏", .french: "Barre de menus"],
        "settings.menuBarSymbol": [.english: "Menu Bar Symbol", .russian: "Символ в строке меню", .belarusian: "Сімвал у радку меню", .chinese: "菜单栏符号", .french: "Symbole de la barre de menus"],
        "settings.monitoring": [.english: "Monitoring", .russian: "Мониторинг туннелей", .belarusian: "Маніторынг тунэляў", .chinese: "隧道监控", .french: "Surveillance"],
        "settings.autoReconnect": [.english: "Auto Reconnect", .russian: "Автоматическое переподключение", .belarusian: "Аўтаматычнае перападключэнне", .chinese: "自动重连", .french: "Reconnexion automatique"],
        "settings.autoReconnectDesc": [.english: "Automatically reconnect dropped tunnels", .russian: "Автоматически переподключать упавшие туннели", .belarusian: "Аўтаматычна перападключаць упалыя тунэлі", .chinese: "自动重连断开的隧道", .french: "Reconnecter automatiquement les tunnels perdus"],
        "settings.reconnectDelay": [.english: "Reconnect Delay", .russian: "Задержка перед переподключением", .belarusian: "Затрымка перад перападключэннем", .chinese: "重连延迟", .french: "Délai de reconnexion"],
        "settings.reconnectAttempts": [.english: "Attempts", .russian: "Количество попыток", .belarusian: "Колькасць спроб", .chinese: "尝试次数", .french: "Tentatives"],
        "settings.checkInterval": [.english: "Check every", .russian: "Проверять каждые", .belarusian: "Правяраць кожныя", .chinese: "检查间隔", .french: "Vérifier toutes les"],
        "settings.sec": [.english: "sec", .russian: "сек", .belarusian: "сек", .chinese: "秒", .french: "sec"],
        "settings.permissions": [.english: "Permissions", .russian: "Разрешения", .belarusian: "Дазволы", .chinese: "权限", .french: "Autorisations"],
        "settings.notifications": [.english: "Show Notifications", .russian: "Показывать уведомления", .belarusian: "Паказваць апавяшчэнні", .chinese: "显示通知", .french: "Afficher les notifications"],
        "settings.notificationsDesc": [.english: "Notifications about tunnel state and reconnects", .russian: "Уведомления о состоянии туннелей и переподключениях", .belarusian: "Апавяшчэнні пра стан тунэляў і перападключэнні", .chinese: "关于隧道状态和重连的通知", .french: "Notifications sur l'état des tunnels et reconnexions"],
        "settings.resetPermissions": [.english: "Reset All Permissions", .russian: "Сбросить все разрешения", .belarusian: "Скінуць усе дазволы", .chinese: "重置所有权限", .french: "Réinitialiser toutes les autorisations"],
        "settings.waitingPermission": [.english: "Waiting for notification permission", .russian: "Ожидание разрешения на показ уведомлений", .belarusian: "Чаканне дазволу на паказ апавяшчэнняў", .chinese: "等待通知权限", .french: "En attente de l'autorisation de notification"],
        "settings.notifPermission": [.english: "Notification Permission", .russian: "Разрешение уведомлений", .belarusian: "Дазвол апавяшчэнняў", .chinese: "通知权限", .french: "Autorisation de notification"],
        "settings.notifPermissionDesc": [.english: "To receive notifications, allow them in System Settings.", .russian: "Чтобы SSH Manager мог показывать уведомления, разрешите их в системных настройках.", .belarusian: "Каб SSH Manager мог паказваць апавяшчэнні, дазвольце іх у сістэмных наладах.", .chinese: "要接收通知，请在系统设置中允许。", .french: "Pour recevoir des notifications, autorisez-les dans les réglages système."],
        "settings.openSettings": [.english: "Open Settings", .russian: "Открыть настройки", .belarusian: "Адкрыць налады", .chinese: "打开设置", .french: "Ouvrir les réglages"],
        "settings.backgroundMode": [.english: "Background Mode", .russian: "Фоновый режим", .belarusian: "Фонавы рэжым", .chinese: "后台模式", .french: "Mode arrière-plan"],
        "settings.backgroundModeDesc": [.english: "Allow app to run in background", .russian: "Разрешить приложению работать в фоне", .belarusian: "Дазволіць праграме працаваць у фоне", .chinese: "允许应用在后台运行", .french: "Autoriser l'app à fonctionner en arrière-plan"],
        "settings.autoLaunch": [.english: "Launch at Login", .russian: "Автозапуск", .belarusian: "Аўтазапуск", .chinese: "登录时启动", .french: "Lancer à l'ouverture de session"],
        "settings.autoLaunchDesc": [.english: "Launch app on system startup", .russian: "Запускать приложение при входе в систему", .belarusian: "Запускаць праграму пры ўваходзе ў сістэму", .chinese: "系统启动时启动应用", .french: "Lancer l'app au démarrage du système"],
        "settings.language": [.english: "Language", .russian: "Язык", .belarusian: "Мова", .chinese: "语言", .french: "Langue"],

        // MARK: - About
        "about.version": [.english: "Version %@", .russian: "Версия %@", .belarusian: "Версія %@", .chinese: "版本 %@", .french: "Version %@"],
        "about.feature1": [.english: "SSH server and tunnel management", .russian: "Управление SSH серверами и туннелями", .belarusian: "Кіраванне SSH серверамі і тунэлямі", .chinese: "SSH 服务器和隧道管理", .french: "Gestion des serveurs et tunnels SSH"],
        "about.feature2": [.english: "Automatic reconnection", .russian: "Автоматическое переподключение", .belarusian: "Аўтаматычнае перападключэнне", .chinese: "自动重连", .french: "Reconnexion automatique"],
        "about.feature3": [.english: "Connection monitoring", .russian: "Мониторинг соединений", .belarusian: "Маніторынг злучэнняў", .chinese: "连接监控", .french: "Surveillance des connexions"],
        "about.feature4": [.english: "Status notifications", .russian: "Уведомления о состоянии", .belarusian: "Апавяшчэнні пра стан", .chinese: "状态通知", .french: "Notifications d'état"],

        // MARK: - Подключение
        "connect.success": [.english: "Connected successfully", .russian: "Подключено успешно", .belarusian: "Падключана паспяхова", .chinese: "连接成功", .french: "Connecté avec succès"],

        // MARK: - Обновления
        "update.available": [.english: "New version available", .russian: "Доступна новая версия", .belarusian: "Даступна новая версія", .chinese: "有新版本可用", .french: "Nouvelle version disponible"],
        "update.later": [.english: "Later", .russian: "Позже", .belarusian: "Пазней", .chinese: "稍后", .french: "Plus tard"],
        "update.update": [.english: "Update", .russian: "Обновить", .belarusian: "Абнавіць", .chinese: "更新", .french: "Mettre à jour"],
        "update.checking": [.english: "Checking for updates...", .russian: "Проверяем обновления...", .belarusian: "Правяраем абнаўленні...", .chinese: "检查更新中...", .french: "Vérification des mises à jour..."],
        "update.uptodate": [.english: "Up to date", .russian: "Установлена актуальная версия ПО", .belarusian: "Усталявана актуальная версія ПЗ", .chinese: "已是最新版本", .french: "À jour"],
        "update.install": [.english: "Install Update", .russian: "Установить обновление", .belarusian: "Усталяваць абнаўленне", .chinese: "安装更新", .french: "Installer la mise à jour"],
        "update.autoShow": [.english: "Show update window automatically", .russian: "Показывать окно обновления автоматически", .belarusian: "Паказваць акно абнаўлення аўтаматычна", .chinese: "自动显示更新窗口", .french: "Afficher automatiquement la fenêtre de mise à jour"],
        "update.autoShowDesc": [.english: "When a new version is found, immediately open the install window", .russian: "При обнаружении новой версии сразу открывать окно установки", .belarusian: "Пры выяўленні новай версіі адразу адкрываць акно ўсталёўкі", .chinese: "发现新版本时立即打开安装窗口", .french: "Lorsqu'une nouvelle version est trouvée, ouvrir immédiatement la fenêtre d'installation"],

        // MARK: - Бесконечность
        "infinity": [.english: "∞", .russian: "∞", .belarusian: "∞", .chinese: "∞", .french: "∞"],
    ]
}

// MARK: - L10n (удобный доступ)
enum L10n {
    static var appName: String { LocalizationManager.shared.string("app.name") }
    static var appDescription: String { LocalizationManager.shared.string("app.description") }

    // Меню
    static var menuOpen: String { LocalizationManager.shared.string("menu.open") }
    static var menuQuit: String { LocalizationManager.shared.string("menu.quit") }
    static var menuNoServers: String { LocalizationManager.shared.string("menu.noServers") }
    static var menuNoAddress: String { LocalizationManager.shared.string("menu.noAddress") }
    static var menuServer: String { LocalizationManager.shared.string("menu.server") }
    static var menuNoTunnels: String { LocalizationManager.shared.string("menu.noTunnels") }

    // Боковая панель
    static var sidebarAddServer: String { LocalizationManager.shared.string("sidebar.addServer") }
    static var sidebarSearch: String { LocalizationManager.shared.string("sidebar.search") }
    static var sidebarNoServers: String { LocalizationManager.shared.string("sidebar.noServers") }

    // Тулбар
    static var toolbarSettings: String { LocalizationManager.shared.string("toolbar.settings") }
    static var toolbarAbout: String { LocalizationManager.shared.string("toolbar.about") }

    // Сервер
    static var serverSymbolAndName: String { LocalizationManager.shared.string("server.symbolAndName") }
    static var serverName: String { LocalizationManager.shared.string("server.name") }
    static var serverNamePlaceholder: String { LocalizationManager.shared.string("server.namePlaceholder") }
    static var serverConnection: String { LocalizationManager.shared.string("server.connection") }
    static var serverHost: String { LocalizationManager.shared.string("server.host") }
    static var serverPort: String { LocalizationManager.shared.string("server.port") }
    static var serverUser: String { LocalizationManager.shared.string("server.user") }
    static var serverAuthType: String { LocalizationManager.shared.string("server.authType") }
    static var serverPassword: String { LocalizationManager.shared.string("server.password") }
    static var serverKeyPath: String { LocalizationManager.shared.string("server.keyPath") }
    static var serverBrowse: String { LocalizationManager.shared.string("server.browse") }
    static var serverTunnels: String { LocalizationManager.shared.string("server.tunnels") }
    static var serverAddTunnel: String { LocalizationManager.shared.string("server.addTunnel") }
    static var serverNoTunnels: String { LocalizationManager.shared.string("server.noTunnels") }
    static var serverSave: String { LocalizationManager.shared.string("server.save") }
    static var serverSaving: String { LocalizationManager.shared.string("server.saving") }

    // Туннель
    static var tunnelName: String { LocalizationManager.shared.string("tunnel.name") }
    static var tunnelGeneric: String { LocalizationManager.shared.string("tunnel.tunnel") }

    // Валидация
    static func validationServerNameExists(_ name: String) -> String {
        String(format: LocalizationManager.shared.string("validation.serverNameExists"), name)
    }
    static func validationServerHostExists(_ host: String, _ port: String) -> String {
        String(format: LocalizationManager.shared.string("validation.serverHostExists"), host, port)
    }
    static func validationTunnelNameExists(_ name: String) -> String {
        String(format: LocalizationManager.shared.string("validation.tunnelNameExists"), name)
    }
    static func validationTunnelHostExists(_ host: String, _ rp: String, _ lp: String) -> String {
        String(format: LocalizationManager.shared.string("validation.tunnelHostExists"), host, rp, lp)
    }

    // Уведомления
    static var notifServerDown: String { LocalizationManager.shared.string("notif.serverDown") }
    static var notifServerUp: String { LocalizationManager.shared.string("notif.serverUp") }
    static func notifTunnelDown(_ name: String) -> String {
        String(format: LocalizationManager.shared.string("notif.tunnelDown"), name)
    }
    static func notifTunnelsDown(_ names: String) -> String {
        String(format: LocalizationManager.shared.string("notif.tunnelsDown"), names)
    }
    static func notifTunnelUp(_ name: String) -> String {
        String(format: LocalizationManager.shared.string("notif.tunnelUp"), name)
    }
    static func notifAutoReconnect(_ delay: Int) -> String {
        String(format: LocalizationManager.shared.string("notif.autoReconnect"), delay)
    }
    static var notifReconnectAction: String { LocalizationManager.shared.string("notif.reconnectAction") }

    // Настройки
    static var settingsMenuBar: String { LocalizationManager.shared.string("settings.menuBar") }
    static var settingsMenuBarSymbol: String { LocalizationManager.shared.string("settings.menuBarSymbol") }
    static var settingsMonitoring: String { LocalizationManager.shared.string("settings.monitoring") }
    static var settingsAutoReconnect: String { LocalizationManager.shared.string("settings.autoReconnect") }
    static var settingsAutoReconnectDesc: String { LocalizationManager.shared.string("settings.autoReconnectDesc") }
    static var settingsReconnectDelay: String { LocalizationManager.shared.string("settings.reconnectDelay") }
    static var settingsReconnectAttempts: String { LocalizationManager.shared.string("settings.reconnectAttempts") }
    static var settingsCheckInterval: String { LocalizationManager.shared.string("settings.checkInterval") }
    static var settingsSec: String { LocalizationManager.shared.string("settings.sec") }
    static var settingsPermissions: String { LocalizationManager.shared.string("settings.permissions") }
    static var settingsNotifications: String { LocalizationManager.shared.string("settings.notifications") }
    static var settingsNotificationsDesc: String { LocalizationManager.shared.string("settings.notificationsDesc") }
    static var settingsResetPermissions: String { LocalizationManager.shared.string("settings.resetPermissions") }
    static var settingsWaitingPermission: String { LocalizationManager.shared.string("settings.waitingPermission") }
    static var settingsLanguage: String { LocalizationManager.shared.string("settings.language") }
    static var settingsBackgroundMode: String { LocalizationManager.shared.string("settings.backgroundMode") }
    static var settingsBackgroundModeDesc: String { LocalizationManager.shared.string("settings.backgroundModeDesc") }
    static var settingsAutoLaunch: String { LocalizationManager.shared.string("settings.autoLaunch") }
    static var settingsAutoLaunchDesc: String { LocalizationManager.shared.string("settings.autoLaunchDesc") }
    static var settingsOpenSettings: String { LocalizationManager.shared.string("settings.openSettings") }

    // About
    static func aboutVersion(_ v: String) -> String {
        String(format: LocalizationManager.shared.string("about.version"), v)
    }
    static var aboutFeature1: String { LocalizationManager.shared.string("about.feature1") }
    static var aboutFeature2: String { LocalizationManager.shared.string("about.feature2") }
    static var aboutFeature3: String { LocalizationManager.shared.string("about.feature3") }
    static var aboutFeature4: String { LocalizationManager.shared.string("about.feature4") }

    // Обновления
    static var updateAvailableTitle: String { LocalizationManager.shared.string("update.available") }
    static var updateLater: String { LocalizationManager.shared.string("update.later") }
    static var updateUpdate: String { LocalizationManager.shared.string("update.update") }
    static var updateChecking: String { LocalizationManager.shared.string("update.checking") }
    static var updateUpToDate: String { LocalizationManager.shared.string("update.uptodate") }
    static var updateInstall: String { LocalizationManager.shared.string("update.install") }
    static var updateAutoShow: String { LocalizationManager.shared.string("update.autoShow") }
    static var updateAutoShowDesc: String { LocalizationManager.shared.string("update.autoShowDesc") }

    // Подключение
    static var connectSuccess: String { LocalizationManager.shared.string("connect.success") }
    static var infinity: String { LocalizationManager.shared.string("infinity") }
}
