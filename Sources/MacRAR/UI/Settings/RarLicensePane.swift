import SwiftUI
import RarKit

struct RarLicensePane: View {
    @Bindable var detector: RarStatusDetector
    @Environment(AppModel.self) private var model
    @State private var picker = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("Current License") {
                statusRow
                if let info = RarLicenseInstaller.readInstalledInfo() {
                    LabeledContent("Owner", value: info.owner)
                    if !info.licenseType.isEmpty {
                        LabeledContent("Type", value: info.licenseType)
                    }
                    if !info.uid.isEmpty {
                        LabeledContent("UID") {
                            Text(info.uid)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                    LabeledContent("Key file") {
                        Text(installedKeyPath ?? RarLicenseInstaller.installLocation.path)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1).truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    DisclosureGroup("About Maintenance") {
                        Text("Maintenance contracts (free upgrades to future major RAR versions) are tracked by RARLAB on the server side — they are NOT encoded in this key file. Your existing key works indefinitely for RAR 7.x. When RAR 8 ships, RARLAB will email a new key if your maintenance is still active.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Section("Manage") {
                Button("Install rarreg.key…") { picker = true }
                if RarLicenseInstaller.isInstalled() {
                    Button("Remove License", role: .destructive) { uninstall() }
                }
            }
            Section("Purchase") {
                Link("Buy a RAR license at rarlab.com/order.htm",
                     destination: URL(string: "https://www.rarlab.com/order.htm")!)
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $picker, allowedContentTypes: [.data]) { result in
            handlePicked(result)
        }
    }

    @ViewBuilder private var statusRow: some View {
        switch detector.licenseState {
        case .notInstalled:
            HStack { Image(systemName: "minus.circle").foregroundStyle(.secondary); Text("rar not detected") }
        case .trial:
            HStack { Image(systemName: "clock").foregroundStyle(.orange); Text("Trial mode") }
        case .unknown:
            HStack { Image(systemName: "questionmark.circle").foregroundStyle(.secondary); Text("Status unknown") }
        case .registered(let owner):
            HStack {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Text("Registered to: \(owner)")
            }
        }
    }

    private func handlePicked(_ result: Result<URL, Error>) {
        if case .success(let url) = result {
            do {
                try RarLicenseInstaller.install(from: url)
                Task { await detector.detect(using: model.runner) }
                error = nil
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func uninstall() {
        do {
            try RarLicenseInstaller.uninstall()
            Task { await detector.detect(using: model.runner) }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Which of the searched paths currently has a key — useful when the user
    /// installed via an older MacRAR build that wrote to the legacy `.rar/` path.
    private var installedKeyPath: String? {
        for path in RarLicenseInstaller.searchPaths {
            if FileManager.default.fileExists(atPath: path.path) {
                return path.path
            }
        }
        return nil
    }
}
