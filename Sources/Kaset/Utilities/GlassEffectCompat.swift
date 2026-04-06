import SwiftUI

// Fallback shims for Liquid Glass APIs used by the app on newer macOS versions.
struct GlassEffectStyle {
    static let regular = GlassEffectStyle()

    func interactive() -> GlassEffectStyle { self }
    func tint(_: Color) -> GlassEffectStyle { self }
}

struct GlassEffectTransition: Sendable {
    static let materialize = GlassEffectTransition()
    static let identity = GlassEffectTransition()
}

struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View { self.content }
}

extension View {
    @ViewBuilder
    func glassEffect(
        _ style: GlassEffectStyle = .regular,
        in shape: some Shape = Rectangle()
    ) -> some View {
        self.background(.ultraThinMaterial, in: shape)
    }

    func glassEffectID(_ id: some Hashable, in namespace: Namespace.ID) -> some View {
        self
    }

    func glassEffectTransition(_ transition: GlassEffectTransition) -> some View {
        self
    }

    @ViewBuilder
    func toolbarBackgroundHidden() -> some View {
        if #available(macOS 15, *) {
            self.toolbarBackgroundVisibility(.hidden, for: .automatic)
        } else {
            self
        }
    }
}
