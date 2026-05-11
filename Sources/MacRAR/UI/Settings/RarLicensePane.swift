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
                if RarLicenseInstaller.isInstalled() {
                    LabeledContent("Key file", value: RarLicenseInstaller.installLocation.path)
                        .lineLimit(1).truncationMode(.middle)
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
}
