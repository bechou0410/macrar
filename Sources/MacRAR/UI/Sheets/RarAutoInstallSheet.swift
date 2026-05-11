import SwiftUI
import RarKit

struct RarAutoInstallSheet: View {
    let detector: RarStatusDetector
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var installer = RarAutoInstaller()
    @State private var consented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 480)
        .frame(minHeight: 360)
    }

    private var header: some View {
        HStack {
            Image(systemName: "shippingbox.fill")
                .font(.title2).foregroundStyle(.tint)
            Text("Install RAR CLI Automatically").font(.headline)
            Spacer()
        }
        .padding(16)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !consented {
                    consentPanel
                } else {
                    progressPanel
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var consentPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MacRAR will download the RAR CLI directly from RARLAB and install just the `rar` binary at:")
                .font(.callout)
            Text("~/Library/Application Support/MacRAR/bin/rar")
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 6) {
                Label("Source: rarlab.com/rar/rarmacos-*-722.tar.gz", systemImage: "globe")
                Label("Size: ~750 KB", systemImage: "scalemass")
                Label("License: © RARLAB · trial for 40 days, then asks for a key", systemImage: "doc.text")
                Label("MacRAR does NOT bundle or modify the rar binary", systemImage: "checkmark.shield")
                    .foregroundStyle(.green)
            }
            .font(.caption)

            Toggle("I acknowledge the RAR CLI is proprietary RARLAB software", isOn: $consented)
                .padding(.top, 8)
        }
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                statusIcon
                Text(installer.phase.displayMessage)
                    .font(.callout)
                Spacer()
            }
            ProgressView(value: installer.phase.progressFraction ?? 0)
                .progressViewStyle(.linear)
            if let url = installer.lastDownloadURL {
                Text(url.absoluteString)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch installer.phase {
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
        case .idle:
            Image(systemName: "circle").foregroundStyle(.secondary)
        default:
            ProgressView().controlSize(.small)
        }
    }

    private var footer: some View {
        HStack {
            if case .done = installer.phase {
                Spacer()
                Button("Done") {
                    Task { await detector.detect(using: model.runner) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            } else {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(installer.isRunning)
                Button("Install") {
                    Task {
                        await installer.install()
                        if case .done = installer.phase {
                            await detector.detect(using: model.runner)
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!consented || installer.isRunning)
            }
        }
        .padding(16)
    }
}
