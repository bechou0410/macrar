import SwiftUI
import AppKit

/// 1×1 transparent backdrop for Services-launched flows.
///
/// Strips the parent NSWindow's chrome (title bar, shadow, background) and
/// centres it on the main screen. The sheet attached to this backdrop appears
/// like a free-floating dialog — no visible window flash before the sheet
/// animates in, no awkward placeholder text behind the sheet.
struct HeadlessBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = HostingNSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    /// Custom NSView that configures its enclosing window once it joins one.
    /// Using `viewDidMoveToWindow` is more reliable than DispatchQueue.async
    /// because it fires exactly when the window is ready.
    private final class HostingNSView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.isMovableByWindowBackground = false
            window.collectionBehavior.insert(.transient)

            // Centre the 1×1 window on the active screen so the attached sheet
            // pops up centred without any visible host window.
            if let screen = window.screen ?? NSScreen.main {
                let f = screen.visibleFrame
                window.setFrame(
                    NSRect(x: f.midX, y: f.midY, width: 1, height: 1),
                    display: false,
                    animate: false
                )
            }
        }
    }
}
