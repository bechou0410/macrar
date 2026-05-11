import Cocoa
import RarKit

/// Bridges macOS Services menu actions ("Compress with MacRAR…", "Extract with MacRAR")
/// into AppModel intents. Registered via `NSApp.servicesProvider`.
///
/// Selectors must be `@objc` and accept the standard NSPasteboard / userData / error signature.
@MainActor
final class ServicesProvider: NSObject {
    weak var model: AppModel?

    @objc func compressService(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        let urls = readFileURLs(from: pasteboard)
        guard !urls.isEmpty else {
            error.pointee = "No files selected" as NSString
            return
        }
        model?.handleServiceCompress(sources: urls)
        bringForward()
    }

    @objc func extractService(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        let urls = readFileURLs(from: pasteboard)
        guard !urls.isEmpty else {
            error.pointee = "No files selected" as NSString
            return
        }
        model?.handleServiceExtract(archives: urls)
        bringForward()
    }

    private func readFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        guard let objects = pasteboard.readObjects(forClasses: [NSURL.self]) else { return [] }
        return objects.compactMap { ($0 as? URL)?.standardizedFileURL }
    }

    /// Surface the sheet window for a Services-triggered op WITHOUT promoting
    /// the app to `.regular` activation policy. The app stays as `.accessory`
    /// (no dock icon) so the user sees only the floating sheet — the full
    /// browser window doesn't appear unless they explicitly open a file.
    ///
    /// On cold launch the SwiftUI window hasn't rendered yet; retry until it
    /// exists, then bring it forward.
    private func bringForward() {
        // Stay .accessory — no dock icon for Service ops
        NSApp.activate(ignoringOtherApps: true)
        scheduleWindowFront(attempts: 12)
    }

    private func scheduleWindowFront(attempts: Int) {
        guard attempts > 0 else { return }
        let windows = NSApp.windows.filter { $0.contentView != nil }
        if let win = windows.first {
            // Float above other apps so the sheet is immediately visible.
            win.level = .floating
            win.makeKeyAndOrderFront(nil)
            win.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.scheduleWindowFront(attempts: attempts - 1)
        }
    }
}
