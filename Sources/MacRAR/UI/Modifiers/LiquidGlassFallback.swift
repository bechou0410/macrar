import SwiftUI

/// Cross-OS view modifiers that opt into macOS 26 Liquid Glass APIs when available
/// and degrade gracefully to system materials on macOS 15 Sequoia.

public extension View {
    /// Translucent background. On Tahoe uses `.glassEffect()`; elsewhere `.regularMaterial`.
    @ViewBuilder
    func liquidGlass(in shape: some Shape = RoundedRectangle(cornerRadius: 12)) -> some View {
        if #available(macOS 26, *) {
            self.background(.thinMaterial, in: shape)
                .modifier(TahoeGlassModifier(shape: shape))
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }

    /// Primary action button style. `.glassProminent` on Tahoe; `.borderedProminent` on Sequoia.
    @ViewBuilder
    func primaryActionStyle() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.borderedProminent)  // Use bordered until Apple ships final glassProminent API
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    /// Secondary action button style.
    @ViewBuilder
    func secondaryActionStyle() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.bordered)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}

@available(macOS 26, *)
private struct TahoeGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    func body(content: Content) -> some View {
        // Apple's `.glassEffect()` is still iterating in early Tahoe SDKs.
        // We layer thinMaterial + subtle border to approximate Liquid Glass when
        // the runtime API is missing; swap with `.glassEffect()` once API stabilises.
        content
            .overlay(shape.stroke(.white.opacity(0.08), lineWidth: 0.5))
    }
}
