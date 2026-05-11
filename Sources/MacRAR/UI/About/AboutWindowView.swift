import SwiftUI
import AppKit
import RarKit

struct AboutWindowView: View {
    @State private var detector = RarStatusDetector()
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 96, height: 96)
            Text("MacRAR").font(.title.bold())
            Text("Version \(appVersion) (build \(appBuild))")
                .foregroundStyle(.secondary).font(.callout)
            Text("Free, open source · MIT")
                .font(.caption).foregroundStyle(.secondary)

            Divider().padding(.vertical, 4)

            VStack(spacing: 4) {
                Text("UnRAR: \(model.runner.unrarURL.lastPathComponent)")
                    .font(.caption)
                if let rar = detector.binaryPath {
                    Text("RAR engine: \(detector.version ?? "?")")
                        .font(.caption)
                } else {
                    Text("RAR engine: not installed")
                        .font(.caption).foregroundStyle(.orange)
                }
                Text("© RARLAB. Distributed under their license.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Divider().padding(.vertical, 4)

            HStack(spacing: 14) {
                Link("GitHub", destination: URL(string: "https://github.com/bechou0410/macrar")!)
                Link("RARLAB", destination: URL(string: "https://www.rarlab.com")!)
                Spacer()
                Button("OK") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380)
        .task { await detector.detect(using: model.runner) }
    }
}
