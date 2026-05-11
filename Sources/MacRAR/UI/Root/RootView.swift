import SwiftUI
import RarKit

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            if model.launchContext.isHeadless {
                // Invisible 1×1 host — the sheet attached via .appSheetHost()
                // becomes the only visible element. No backdrop flash.
                Color.clear
                    .frame(width: 1, height: 1)
                    .background(HeadlessBackdrop())
                    .onChange(of: model.activeSheet) { _, newValue in
                        if newValue == nil { scheduleHeadlessExit() }
                    }
                    .onChange(of: model.operations.contains(where: { $0.status == .running })) { _, running in
                        if !running && model.activeSheet == nil {
                            scheduleHeadlessExit()
                        }
                    }
            } else {
                NavigationSplitView {
                    SidebarView()
                } detail: {
                    if let session = model.selectedSession {
                        ArchiveBrowserView(session: session)
                    } else {
                        EmptyStateView()
                    }
                }
                .frame(minWidth: 900, minHeight: 560)
            }
        }
        .appSheetHost()
        .overlay(alignment: .topTrailing) {
            if let banner = model.lastResultBanner {
                ResultBannerView(banner: banner) {
                    model.lastResultBanner = nil
                }
                .id(banner.id)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: model.lastResultBanner?.id)
    }

    /// Quit the app shortly after the headless sheet closes — but only when
    /// no operations are still running. Debounced so a quick sheet → progress
    /// transition doesn't accidentally terminate.
    private func scheduleHeadlessExit() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard model.launchContext.isHeadless,
                  model.activeSheet == nil,
                  model.operations.allSatisfy({ $0.status != .running })
            else { return }
            NSApp.terminate(nil)
        }
    }
}
