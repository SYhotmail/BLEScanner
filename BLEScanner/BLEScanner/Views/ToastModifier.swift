import SwiftUI

/// A transient, bottom-anchored status message. Purely presentational — driven entirely by
/// `isPresented`, with no timer of its own — so the feature reducer stays the single source of
/// truth for how long the message stays up (and stays covered by `TestStore`/`TestClock`
/// assertions), rather than duplicating that timing in the view layer.
private struct ToastModifier: ViewModifier {
    let isPresented: Bool
    let message: String

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.8), in: Capsule())
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .accessibilityIdentifier("toast.message")
                }
            }
            .animation(.easeOut(duration: 0.2), value: isPresented)
    }
}

extension View {
    /// Shows `message` in a toast anchored to the bottom of this view whenever `isPresented`
    /// is true, animating in/out as it toggles.
    func toast(isPresented: Bool, message: String) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message))
    }
}
