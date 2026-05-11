import SwiftUI
import AppKit
import RarKit

struct AboutWindowView: View {
    @State private var detector = RarStatusDetector()
    @State private var disclaimerExpanded = false
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
                if detector.binaryPath != nil {
                    Text("RAR engine: \(detector.version ?? "?")")
                        .font(.caption)
                } else {
                    Text("RAR engine: not installed")
                        .font(.caption).foregroundStyle(.orange)
                }
            }

            Divider().padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").foregroundStyle(.purple)
                    Text("Developed with Claude (Anthropic AI)")
                        .font(.caption)
                }
                DisclosureGroup(isExpanded: $disclaimerExpanded) {
                    disclaimerText
                } label: {
                    Text("Legal disclaimer & third-party notices")
                        .font(.caption.weight(.medium))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 14) {
                Link("GitHub", destination: URL(string: "https://github.com/bechou0410/macrar")!)
                Link("RARLAB", destination: URL(string: "https://www.rarlab.com")!)
                Spacer()
                Button("OK") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
        .task { await detector.detect(using: model.runner) }
    }

    private var disclaimerText: some View {
        Text("""
MacRAR is an **independent open-source project** developed with the assistance of Claude (Anthropic AI). It is NOT affiliated with, endorsed by, or sponsored by RARLAB, win.rar GmbH, Alexander Roshal, or any other party.

"RAR", "WinRAR", and related marks are trademarks of win.rar GmbH. The RAR compression algorithm and the `rar`/`unrar` binaries are proprietary software © RARLAB / Alexander Roshal — distributed under their own license. MacRAR merely provides a user interface that invokes those tools.

The bundled `unrar` binary is redistributed under the UnRAR component exception of RARLAB's EULA. The `rar` binary is NOT bundled; users obtain it directly from RARLAB at their own discretion.

THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED. The authors and contributors of MacRAR shall not be liable for any data loss, archive corruption, license-key misuse, or any other damages arising from the use of this software, the bundled UnRAR, or any third-party RAR CLI invoked by it.

You are solely responsible for complying with the licensing terms of any third-party software you use through MacRAR — including the RAR/UnRAR license agreement with RARLAB. Source code is available on GitHub for full transparency.
""")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }
}
