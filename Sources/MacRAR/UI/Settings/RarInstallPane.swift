import SwiftUI
import AppKit
import RarKit

struct RarInstallPane: View {
    @Bindable var detector: RarStatusDetector
    @Environment(AppModel.self) private var model
    @State private var picker = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("Status") {
                if let path = detector.binaryPath {
                    LabeledContent("Installed at", value: path.path)
                        .lineLimit(1).truncationMode(.middle)
                    LabeledContent("Version", value: detector.version ?? "unknown")
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("RAR CLI is not installed. Extraction works without it; creation requires it.")
                    }
                }
                Button("Re-detect") {
                    Task { await detector.detect(using: model.runner) }
                }
            }
            Section("Install Automatically (recommended)") {
                Button {
                    model.activeSheet = .rarAutoInstall
                } label: {
                    Label("Download & Install from RARLAB", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Text("MacRAR will download the official RAR CLI (~750 KB) and install it locally. No browser, terminal, or Homebrew needed.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("System Integration") {
                Button("Repair Finder Integration") {
                    FirstRunBootstrapper.forceRun()
                }
                Text("Re-registers file associations and re-enables the Services menu items if they ever stop showing up in Finder right-click.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Other install methods") {
                HStack {
                    Text("brew install rar")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("brew install rar", forType: .string)
                    }
                }
                Link("Manual download from rarlab.com",
                     destination: URL(string: "https://www.rarlab.com/download.htm")!)
                Button("Choose existing rar binary…") { picker = true }
            }
            Section {
                Text("⚠️ The `rar` CLI is proprietary software © RARLAB. The trial is fully functional for 40 days; purchase a license to remove reminders.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $picker,
            allowedContentTypes: [.unixExecutable, .executable, .data]
        ) { result in
            handlePicked(result)
        }
    }

    private func handlePicked(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                try RarInstaller.install(from: url)
                Task { await detector.detect(using: model.runner) }
                error = nil
            } catch {
                self.error = error.localizedDescription
            }
        case .failure(let err):
            self.error = err.localizedDescription
        }
    }
}
