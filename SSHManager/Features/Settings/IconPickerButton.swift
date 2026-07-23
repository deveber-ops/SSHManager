import SwiftUI

struct IconCategory {
    let name: String
    let icons: [String]
}

private let iconCategories: [IconCategory] = [
    IconCategory(name: "Серверы и компьютеры", icons: [
        "server.rack", "desktopcomputer", "laptopcomputer",
        "macmini", "macmini.fill", "macpro.gen1", "macpro.gen2",
        "macstudio", "macstudio.fill", "xserve", "pc",
        "keyboard", "keyboard.fill", "display",
    ]),
    IconCategory(name: "Сеть", icons: [
        "network", "network.badge.shield.half.filled",
        "wifi", "wifi.slash", "wifi.router", "wifi.router.fill",
        "antenna.radiowaves.left.and.right", "dot.radiowaves.left.and.right",
    ]),
    IconCategory(name: "Накопители и хранилище", icons: [
        "externaldrive", "externaldrive.fill", "externaldrive.badge.wifi",
        "externaldrive.badge.plus", "opticaldisc", "opticaldisc.fill",
        "internaldrive", "internaldrive.fill",
        "cube", "cube.fill", "cube.transparent", "cube.transparent.fill",
        "square.stack.3d.up", "square.stack.3d.up.fill",
        "shippingbox", "shippingbox.fill",
        "tray", "tray.fill", "tray.full", "tray.full.fill",
        "tray.and.arrow.down", "tray.and.arrow.down.fill",
        "tray.and.arrow.up", "tray.and.arrow.up.fill",
    ]),
    IconCategory(name: "Файлы и документы", icons: [
        "folder", "folder.fill", "folder.badge.gearshape",
        "folder.badge.plus", "folder.badge.minus",
        "folder.circle", "folder.circle.fill",
        "doc", "doc.fill", "doc.text", "doc.text.fill",
        "doc.badge.plus", "doc.badge.gearshape",
        "doc.circle", "doc.circle.fill", "doc.viewfinder", "doc.viewfinder.fill",
        "doc.on.doc", "doc.on.doc.fill", "doc.on.clipboard", "doc.on.clipboard.fill",
        "doc.richtext", "doc.richtext.fill",
        "list.bullet", "list.bullet.circle", "list.clipboard", "list.clipboard.fill",
        "book", "book.fill", "books.vertical", "books.vertical.fill",
        "text.book.closed", "text.book.closed.fill",
        "bookmark", "bookmark.fill", "bookmark.slash", "bookmark.slash.fill",
    ]),
    IconCategory(name: "Терминал и окна", icons: [
        "terminal", "terminal.fill",
        "window.vertical.open",
        "window.vertical.closed",
        "rectangle.split.2x1", "rectangle.split.2x1.fill",
        "rectangle.split.1x2", "rectangle.split.1x2.fill",
        "rectangle.split.2x2", "rectangle.split.2x2.fill",
        "square.split.bottomrightquarter", "square.split.bottomrightquarter.fill",
    ]),
    IconCategory(name: "Настройки и инструменты", icons: [
        "gearshape", "gearshape.fill", "gearshape.2", "gearshape.2.fill",
        "gearshape.circle", "gearshape.circle.fill",
        "wrench", "wrench.fill", "wrench.adjustable", "wrench.adjustable.fill",
        "hammer", "hammer.fill", "screwdriver", "screwdriver.fill",
        "wrench.and.screwdriver", "wrench.and.screwdriver.fill",
        "slider.horizontal.3",
        "switch.programmable", "switch.programmable.fill",
        "dial.medium", "dial.medium.fill", "dial.low", "dial.low.fill",
        "dpad", "dpad.fill", "circlebadge", "circlebadge.fill",
    ]),
    IconCategory(name: "Безопасность", icons: [
        "lock", "lock.fill", "lock.open", "lock.open.fill",
        "lock.shield", "lock.shield.fill", "lock.slash", "lock.slash.fill",
        "lock.circle", "lock.circle.fill", "lock.rectangle", "lock.rectangle.fill",
        "lock.rectangle.stack", "lock.rectangle.stack.fill",
        "shield", "shield.fill", "shield.checkered", "shield.slash", "shield.slash.fill",
        "shield.lefthalf.filled", "shield.righthalf.filled",
        "key", "key.fill", "key.icloud", "key.icloud.fill",
        "touchid", "faceid", "opticid",
    ]),
    IconCategory(name: "Энергия", icons: [
        "bolt", "bolt.fill", "bolt.slash", "bolt.slash.fill",
        "bolt.circle", "bolt.circle.fill", "bolt.shield", "bolt.shield.fill",
        "bolt.horizontal", "bolt.horizontal.fill",
        "bolt.horizontal.circle", "bolt.horizontal.circle.fill",
        "power", "power.circle", "power.circle.fill", "power.dotted",
        "restart", "restart.circle", "restart.circle.fill",
        "sleep", "sleep.circle", "sleep.circle.fill",
    ]),
    IconCategory(name: "Облако и погода", icons: [
        "cloud", "cloud.fill",
        "cloud.drizzle", "cloud.drizzle.fill", "cloud.rain", "cloud.rain.fill",
        "cloud.heavyrain", "cloud.heavyrain.fill", "cloud.bolt", "cloud.bolt.fill",
        "cloud.bolt.rain", "cloud.bolt.rain.fill", "cloud.snow", "cloud.snow.fill",
        "cloud.fog", "cloud.fog.fill", "cloud.sun", "cloud.sun.fill",
        "cloud.moon", "cloud.moon.fill",
        "icloud", "icloud.fill", "icloud.slash", "icloud.slash.fill",
        "icloud.and.arrow.down", "icloud.and.arrow.down.fill",
        "icloud.and.arrow.up", "icloud.and.arrow.up.fill",
    ]),
    IconCategory(name: "Глобус и местоположение", icons: [
        "globe", "globe.desk", "globe.desk.fill",
        "globe.americas", "globe.americas.fill",
        "globe.europe.africa", "globe.europe.africa.fill",
        "globe.asia.australia", "globe.asia.australia.fill",
        "globe.central.south.asia", "globe.central.south.asia.fill",
        "mappin", "mappin.slash",
        "location", "location.fill", "location.slash", "location.slash.fill",
        "location.circle", "location.circle.fill",
        "pin", "pin.fill", "pin.slash", "pin.slash.fill",
        "map", "map.fill",
        "app.connected.to.app.below.fill",
    ]),
    IconCategory(name: "Поиск", icons: [
        "magnifyingglass", "magnifyingglass.circle", "magnifyingglass.circle.fill",
        "plus.magnifyingglass", "minus.magnifyingglass",
        "binoculars", "binoculars.fill",
        "eye", "eye.fill", "eye.slash", "eye.slash.fill",
        "eye.trianglebadge.exclamationmark", "eye.circle", "eye.circle.fill",
    ]),
    IconCategory(name: "Люди", icons: [
        "person", "person.fill", "person.circle", "person.circle.fill",
        "person.crop.circle", "person.crop.circle.fill",
        "person.crop.circle.badge.plus", "person.crop.circle.badge.minus",
        "person.2", "person.2.fill", "person.2.circle", "person.2.circle.fill",
        "person.3", "person.3.fill",
        "person.badge.key", "person.badge.key.fill",
        "person.badge.shield.checkmark", "person.badge.shield.checkmark.fill",
    ]),
    IconCategory(name: "Инструменты разработчика", icons: [
        "pencil", "pencil.and.outline", "pencil.circle", "pencil.circle.fill",
        "pencil.tip", "pencil.tip.crop.circle",
        "gear", "gear.circle", "gear.circle.fill",
        "cpu", "cpu.fill", "memorychip", "memorychip.fill",
        "fan", "fan.fill", "fanblades", "fanblades.fill",
    ]),
    IconCategory(name: "Стрелки и навигация", icons: [
        "arrow.up.arrow.down", "arrow.up.arrow.down.circle", "arrow.up.arrow.down.circle.fill",
        "arrow.up.arrow.down.square", "arrow.up.arrow.down.square.fill",
        "arrow.triangle.2.circlepath", "arrow.triangle.2.circlepath.circle",
        "arrow.triangle.2.circlepath.circle.fill",
        "arrow.triangle.branch", "arrow.triangle.merge", "arrow.triangle.swap",
        "arrow.forward", "arrow.forward.circle", "arrow.forward.circle.fill",
        "arrow.backward", "arrow.backward.circle", "arrow.backward.circle.fill",
        "arrow.right.arrow.left", "arrow.right.arrow.left.circle",
        "arrow.right.arrow.left.circle.fill",
        "arrow.clockwise", "arrow.clockwise.circle", "arrow.clockwise.circle.fill",
        "arrow.counterclockwise", "arrow.counterclockwise.circle",
        "arrow.up.and.down", "arrow.left.and.right",
    ]),
    IconCategory(name: "Действия", icons: [
        "square.and.arrow.down", "square.and.arrow.down.fill",
        "square.and.arrow.up", "square.and.arrow.up.fill",
        "square.and.arrow.down.on.square", "square.and.arrow.down.on.square.fill",
        "square.and.arrow.up.on.square", "square.and.arrow.up.on.square.fill",
        "square.and.pencil",
        "arrow.down.app", "arrow.down.app.fill",
        "arrow.up.doc", "arrow.up.doc.fill", "arrow.down.doc", "arrow.down.doc.fill",
        "plus", "plus.circle", "plus.circle.fill", "plus.square", "plus.square.fill",
        "minus", "minus.circle", "minus.circle.fill", "minus.square", "minus.square.fill",
        "xmark", "xmark.circle", "xmark.circle.fill", "xmark.square", "xmark.square.fill",
        "checkmark", "checkmark.circle", "checkmark.circle.fill",
        "checkmark.square", "checkmark.square.fill",
        "trash", "trash.fill", "trash.circle", "trash.circle.fill",
        "trash.slash", "trash.slash.fill",
        "delete.left", "delete.left.fill", "delete.right", "delete.right.fill",
    ]),
    IconCategory(name: "Ссылки и QR", icons: [
        "link", "link.circle", "link.circle.fill", "link.badge.plus",
        "qrcode", "qrcode.viewfinder", "barcode", "barcode.viewfinder",
    ]),
    IconCategory(name: "Финансы", icons: [
        "wallet.pass", "wallet.pass.fill", "creditcard", "creditcard.fill",
    ]),
    IconCategory(name: "Графики и статистика", icons: [
        "chart.bar", "chart.bar.fill", "chart.bar.xaxis",
        "chart.pie", "chart.pie.fill",
        "chart.line.downtrend.xyaxis", "chart.line.uptrend.xyaxis",
        "chart.dots.scatter",
    ]),
    IconCategory(name: "Время", icons: [
        "clock", "clock.fill", "clock.badge", "clock.badge.fill",
        "clock.badge.questionmark", "clock.badge.questionmark.fill",
        "clock.badge.exclamationmark", "clock.badge.exclamationmark.fill",
        "alarm", "alarm.fill", "timer", "timer.circle", "timer.circle.fill",
        "stopwatch", "stopwatch.fill",
    ]),
    IconCategory(name: "Уведомления", icons: [
        "bell", "bell.fill", "bell.slash", "bell.slash.fill",
        "bell.badge", "bell.badge.fill",
    ]),
    IconCategory(name: "Метки и теги", icons: [
        "tag", "tag.fill",
    ]),
    IconCategory(name: "Флаги и рейтинг", icons: [
        "flag", "flag.fill", "flag.slash", "flag.slash.fill",
        "flag.circle", "flag.circle.fill",
        "star", "star.fill", "star.slash", "star.slash.fill",
        "star.circle", "star.circle.fill",
        "heart", "heart.fill", "heart.slash", "heart.slash.fill",
        "heart.circle", "heart.circle.fill",
    ]),
    IconCategory(name: "Транспорт и путешествия", icons: [
        "suitcase", "suitcase.fill", "suitcase.cart", "suitcase.cart.fill",
        "suitcase.rolling", "suitcase.rolling.fill",
        "bag", "bag.fill", "bag.badge.plus", "bag.badge.minus",
        "cart", "cart.fill", "cart.badge.plus", "cart.badge.minus",
        "gift", "gift.fill", "gift.circle", "gift.circle.fill",
    ]),
    IconCategory(name: "Здания и места", icons: [
        "house", "house.fill", "house.circle", "house.circle.fill",
        "building", "building.fill", "building.2", "building.2.fill",
        "building.2.crop.circle", "building.2.crop.circle.fill",
    ]),
    IconCategory(name: "Природа", icons: [
        "lightbulb", "lightbulb.fill", "lightbulb.slash", "lightbulb.slash.fill",
        "lightbulb.circle", "lightbulb.circle.fill",
        "drop", "drop.fill", "drop.triangle", "drop.triangle.fill",
        "flame", "flame.fill", "flame.circle", "flame.circle.fill",
        "umbrella", "umbrella.fill", "umbrella.percent",
        "thermometer", "thermometer.sun", "thermometer.snowflake",
    ]),
    IconCategory(name: "Разное", icons: [
        "cylinder", "dice", "puzzlepiece",
        "squareshape", "squareshape.fill", "squareshape.split.2x2", "squareshape.split.3x3",
        "target", "scope", "seal", "seal.fill", "signature",
        "viewfinder", "viewfinder.circle", "viewfinder.circle.fill",
        "rectangle", "rectangle.fill", "square", "square.fill",
        "circle", "circle.fill", "capsule", "capsule.fill",
        "oval", "oval.fill", "triangle", "triangle.fill",
        "diamond", "diamond.fill", "hexagon", "hexagon.fill",
        "pentagon", "pentagon.fill", "octagon", "octagon.fill",
        "rhombus", "rhombus.fill",
        "cross", "cross.fill", "cross.circle", "cross.circle.fill",
        "snowflake", "snowflake.circle", "snowflake.circle.fill",
        "sun.max", "sun.max.fill", "sun.min", "sun.min.fill",
        "sunrise", "sunrise.fill", "sunset", "sunset.fill",
        "moon", "moon.fill", "moon.circle", "moon.circle.fill",
        "moon.stars", "moon.stars.fill", "moon.zzz", "moon.zzz.fill",
        "sparkle", "sparkles", "atom", "leaf", "leaf.fill",
        "leaf.arrow.triangle.circlepath",
        "ant", "ant.fill", "ant.circle", "ant.circle.fill",
        "ladybug", "ladybug.fill", "ladybug.circle", "ladybug.circle.fill",
        "bird", "bird.fill", "bird.circle", "bird.circle.fill",
        "fish", "fish.fill", "fish.circle", "fish.circle.fill",
        "lizard", "lizard.fill", "lizard.circle", "lizard.circle.fill",
        "tortoise", "tortoise.fill", "tortoise.circle", "tortoise.circle.fill",
        "hare", "hare.fill", "hare.circle", "hare.circle.fill",
        "pawprint", "pawprint.fill", "pawprint.circle", "pawprint.circle.fill",
        "dog", "dog.fill", "dog.circle", "dog.circle.fill",
        "cat", "cat.fill", "cat.circle", "cat.circle.fill",
        "hand.raised", "hand.raised.fill", "hand.raised.slash", "hand.raised.slash.fill",
        "hand.point.up", "hand.point.up.fill", "hand.point.down", "hand.point.down.fill",
        "hand.point.left", "hand.point.left.fill", "hand.point.right", "hand.point.right.fill",
        "hand.wave", "hand.wave.fill",
        "hand.thumbsup", "hand.thumbsup.fill", "hand.thumbsdown", "hand.thumbsdown.fill",
        "hand.draw", "hand.draw.fill", "hand.tap", "hand.tap.fill",
        "hand.pinch", "hand.pinch.fill",
    ]),
]

struct IconPickerButton: View {
    @Binding var selectedIcon: String
    @State private var showPopover = false
    @State private var searchText = ""
    @State private var hoveredIcon: String? = nil

    private var filteredCategories: [(category: String, icons: [String])] {
        if searchText.isEmpty {
            return iconCategories.map { ($0.name, $0.icons) }
        }
        return iconCategories.compactMap { cat in
            let matched = cat.icons.filter { $0.localizedCaseInsensitiveContains(searchText) }
            return matched.isEmpty ? nil : (cat.name, matched)
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Image(systemName: selectedIcon)
                .font(.title3)
                .frame(width: 40, height: 40)
                .hoverBackground(shape: Circle())
        }
        .buttonStyle(.plain)
        .liquidGlassCapsule(0)
        .controlSize(.small)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                    TextField("Поиск символов", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.body)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)

                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(filteredCategories, id: \.category) { category in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.category)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)

                                LazyVGrid(columns: columns, spacing: 4) {
                                    ForEach(category.icons, id: \.self) { icon in
                                        Button {
                                            selectedIcon = icon
                                            showPopover = false
                                        } label: {
                                            Image(systemName: icon)
                                                .font(.title3)
                                                .frame(width: 30, height: 30)
                                                .background(
                                                    selectedIcon == icon
                                                        ? Color.accentColor.opacity(0.2)
                                                        : hoveredIcon == icon
                                                            ? Color.gray.opacity(0.15)
                                                            : .clear,
                                                    in: .capsule
                                                )
                                                .overlay {
                                                    if selectedIcon == icon {
                                                        Capsule()
                                                            .stroke(Color.accentColor, lineWidth: 1.5)
                                                    }
                                                }
                                                .contentShape(.capsule)
                                        }
                                        .buttonStyle(.plain)
                                        .onHover { hovering in
                                            hoveredIcon = hovering ? icon : nil
                                        }
                                        .help(icon)
                                    }
                                }
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(width: 280, height: 400)
            }
        }
    }
}
