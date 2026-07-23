import SwiftUI

// MARK: - Модификатор Liquid Glass Капсулы
struct LiquidGlassCapsuleModifier: ViewModifier {
    var top: CGFloat
    var leading: CGFloat
    var bottom: CGFloat
    var trailing: CGFloat

    func body(content: Content) -> some View {
        content
            // Применяем точные отступы с каждой стороны
            .padding(EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing))
            .background(
                ZStack {
                    // 1. Матовый материал подложки
                    Capsule()
                        .fill(.ultraThinMaterial)

                    // 2. Легкая темная тонировка для сочности
                    Capsule()
                        .fill(Color.black.opacity(0.25))
                }
            )
            // 3. Стеклянный блик по контуру (Glass Specular Stroke)
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25), // Яркий блик сверху слева
                                Color.white.opacity(0.08), // Почти прозрачный снизу
                                Color.white.opacity(0.15)  // Легкий отсвет справа
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            // 4. Мягкая глубинная тень
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Удобное расширение с перегрузкой методов (Overloading)
extension View {
    
    // 1. По отдельности (каждая сторона настраивается индивидуально)
    func liquidGlassCapsule(
        top: CGFloat = 4,
        leading: CGFloat = 4,
        bottom: CGFloat = 4,
        trailing: CGFloat = 4
    ) -> some View {
        self.modifier(
            LiquidGlassCapsuleModifier(
                top: top,
                leading: leading,
                bottom: bottom,
                trailing: trailing
            )
        )
    }

    // 2. Общий отступ для ВСЕХ сторон: .liquidGlassCapsule(4)
    func liquidGlassCapsule(_ all: CGFloat) -> some View {
        self.liquidGlassCapsule(top: all, leading: all, bottom: all, trailing: all)
    }

    // 3. Горизонтальный и вертикальный: .liquidGlassCapsule(4, 10)
    // Где 1-й параметр — горизонтальный, 2-й — вертикальный
    func liquidGlassCapsule(_ horizontal: CGFloat, _ vertical: CGFloat) -> some View {
        self.liquidGlassCapsule(
            top: vertical,
            leading: horizontal,
            bottom: vertical,
            trailing: horizontal
        )
    }
}

// MARK: - Пример компонента управления
struct LiquidGlassControlBar: View {
    var onSettingsTap: () -> Void = {}
    var onInfoTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 14) {
            // Кнопка Настроек
            Button(action: onSettingsTap) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white)
            }
            .buttonStyle(GlassIconButtonStyle())

            // Кнопка Информации
            Button(action: onInfoTap) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white)
            }
            .buttonStyle(GlassIconButtonStyle())
        }
        // Применяем капсулу с точечным заданием всех 4-х отступов
        .liquidGlassCapsule(top: 9, leading: 14, bottom: 9, trailing: 14)
    }
}

// MARK: - Плавный стиль нажатия и ховера для икон-кнопок
struct GlassIconButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : (isHovered ? 1.0 : 0.85))
            .scaleEffect(configuration.isPressed ? 0.92 : (isHovered ? 1.1 : 1.0))
            .onHover { hovering in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHovered = hovering
                }
            }
    }
}
