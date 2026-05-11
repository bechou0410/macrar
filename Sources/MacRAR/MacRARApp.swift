import SwiftUI
import RarKit

@main
struct MacRARApp: App {
    @NSApplicationDelegateAdaptor(MacRARAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(appDelegate.model)
                .onOpenURL { url in
                    Task { @MainActor in await appDelegate.model.open(url: url) }
                }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: ["*"])
        .commands {
            AppCommands(model: appDelegate.model)
        }

        Settings {
            SettingsView()
                .environment(appDelegate.model)
        }

        Window("About MacRAR", id: "about") {
            AboutWindowView()
                .environment(appDelegate.model)
        }
        .windowResizability(.contentSize)
    }
}

/// NSApplicationDelegate that owns the AppModel and ServicesProvider.
///
/// Built eagerly via `@NSApplicationDelegateAdaptor` so the Services menu
/// provider is registered BEFORE SwiftUI renders its window — otherwise
/// Services messages on cold launch arrive before `servicesProvider` is set
/// and get dropped, which is the "open then click dock to see sheet" bug.
final class MacRARAppDelegate: NSObject, NSApplicationDelegate {
    @MainActor let model: AppModel
    @MainActor private let servicesProvider = ServicesProvider()

    @MainActor
    override init() {
        self.model = AppModel.makeInitial()
        super.init()
        servicesProvider.model = model
    }

    /// Fires before any window is created. Earliest safe point to advertise
    /// our Services so cold-launched Services messages route correctly.
    @MainActor
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Start as accessory: no dock icon, no menu bar disruption. We only
        // promote to .regular when the user explicitly opens a file (Apple
        // Event) or shortly after launch if no Service intent arrived.
        NSApp.setActivationPolicy(.accessory)
        NSApp.servicesProvider = servicesProvider
        NSUpdateDynamicServices()
    }

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        FirstRunBootstrapper.runIfNeeded()

        // If 300ms passes without a Service message setting headless context,
        // assume normal user launch (dock click, Spotlight, etc.) — show
        // dock icon + browser by switching to .regular.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            if case .normal = model.launchContext {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    @MainActor
    func application(_ application: NSApplication, open urls: [URL]) {
        // User opened a file via Finder double-click / drag-onto-dock /
        // Apple Event. Show the full browser window with dock icon.
        if case .normal = model.launchContext {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            Task { @MainActor in await model.openMany(urls: urls) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        // Headless ops terminate explicitly via RootView.scheduleHeadlessExit.
        false
    }
}

extension AppModel {
    @MainActor
    static func makeInitial() -> AppModel {
        let locator: BinaryLocator
        do {
            locator = try BinaryLocator.resolve()
        } catch {
            locator = BinaryLocator.custom(unrarURL: URL(fileURLWithPath: "/dev/null"))
        }
        return AppModel(runner: RarRunner(binaries: locator))
    }
}
