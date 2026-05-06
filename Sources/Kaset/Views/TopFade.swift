import SwiftUI

enum TopFadeStyle {
    case background
    case contentMask
}

// MARK: - TopFade

/// A lightweight top overlay that fades scrolling content beneath hidden toolbar backgrounds.
@available(macOS 26.0, *)
struct TopFade: View {
    let height: CGFloat
    let style: TopFadeStyle

    var body: some View {
        LinearGradient(
            colors: self.colors,
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: self.height)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var colors: [Color] {
        switch self.style {
        case .background:
            [
                Color.black.opacity(0.30),
                Color.black.opacity(0.18),
                Color.black.opacity(0.05),
                Color.clear,
            ]
        case .contentMask:
            [
                Color.clear,
                Color.clear,
            ]
        }
    }
}

// MARK: - TopFadeMask

/// A mask that makes foreground content transparent at the top edge.
@available(macOS 26.0, *)
private struct TopFadeMask: View {
    let height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(0.28), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: min(self.height, proxy.size.height))

                Rectangle()
                    .fill(Color.black)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - TopFadeModifier

@available(macOS 26.0, *)
struct TopFadeModifier: ViewModifier {
    let height: CGFloat
    let style: TopFadeStyle

    func body(content: Content) -> some View {
        switch self.style {
        case .background:
            content
                .overlay(alignment: .top) {
                    TopFade(height: self.height, style: self.style)
                }
        case .contentMask:
            content
                .mask {
                    TopFadeMask(height: self.height)
                }
        }
    }
}

extension View {
    /// Adds the same top fade treatment used by toolbar-backed pages when the toolbar background is hidden.
    /// - Parameters:
    ///   - height: The height of the fade treatment.
    ///   - style: The fade treatment to use for the page background.
    /// - Returns: A view with a non-interactive top fade treatment.
    @ViewBuilder
    func topFade(height: CGFloat = 96, style: TopFadeStyle = .background) -> some View {
        if #available(macOS 26.0, *) {
            self.modifier(TopFadeModifier(height: height, style: style))
        } else {
            self
        }
    }
}
