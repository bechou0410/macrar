import SwiftUI
import RarKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView {
            GeneralPane()
                .tabItem { Label("General", systemImage: "gear") }
            RarInstallPane(detector: model.statusDetector)
                .tabItem { Label("RAR CLI", systemImage: "shippingbox") }
            RarLicensePane(detector: model.statusDetector)
                .tabItem { Label("License", systemImage: "key.fill") }
            UpdatesPane()
                .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
        }
        .frame(width: 560, height: 460)
        .task { await model.statusDetector.detect(using: model.runner) }
    }
}

struct UpdatesPane: View {
    var body: some View {
        Form {
            Section("Auto-Update") {
                Toggle("Check for updates automatically", isOn: .constant(true)).disabled(true)
                Text("Sparkle integration lands in Phase 10.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Channel") {
                Link("View releases on GitHub",
                     destination: URL(string: "https://github.com/bechou0410/macrar/releases")!)
            }
        }
        .formStyle(.grouped)
    }
}
