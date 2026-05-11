import SwiftUI
import UniformTypeIdentifiers
import RarKit

struct EmptyStateView: View {
    @Environment(AppModel.self) private var model
    @State private var importerPresented = false
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Drop an archive here")
                .font(.title2.bold())
            Text("Supports RAR, ZIP, 7z, TAR, GZ, BZ2, ISO …")
                .foregroundStyle(.secondary)
                .font(.callout)
            HStack(spacing: 12) {
                Button("Open Archive…") { importerPresented = true }
                    .primaryActionStyle()
                    .keyboardShortcut("o")
                Button("New Archive…") { model.activeSheet = .create(prefilledSources: []) }
                    .secondaryActionStyle()
                    .disabled(!model.runner.rarAvailable)
            }

            if !model.runner.rarAvailable {
                Label("Extract works. Install `rar` for archive creation.",
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.top, 8)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlass()
        .padding(20)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(hovering ? Color.accentColor : .secondary.opacity(0.3),
                              style: .init(lineWidth: 2, dash: [8, 6]))
                .padding(20)
        )
        .acceptArchiveDrop { urls in
            Task { await model.openMany(urls: urls) }
        }
        .fileImporter(
            isPresented: $importerPresented,
            allowedContentTypes: [.archive, .data],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                Task { await model.openMany(urls: urls) }
            }
        }
    }
}
