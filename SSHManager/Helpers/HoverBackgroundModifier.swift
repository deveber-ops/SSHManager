import SwiftUI

// Универсальный модификатор, работающий с любой формой
struct HoverBackgroundModifier<S: Shape>: ViewModifier {
    var color: Color
    var shape: S
    var padding: CGFloat

    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                shape.fill(isHovered ? color : Color.clear)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

extension View {
    /// Хелпер для скруглённого прямоугольника с радиусом (по умолчанию)
    func hoverBackground(
        color: Color = Color.primary.opacity(0.1),
        cornerRadius: CGFloat = 6,
        padding: CGFloat = 4
    ) -> some View {
        self.modifier(HoverBackgroundModifier(
            color: color,
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            padding: padding
        ))
    }

    /// Хелпер для формы Capsule / Circle
    func hoverBackground<S: Shape>(
        color: Color = Color.primary.opacity(0.1),
        shape: S,
        padding: CGFloat = 4
    ) -> some View {
        self.modifier(HoverBackgroundModifier(color: color, shape: shape, padding: padding))
    }
}
