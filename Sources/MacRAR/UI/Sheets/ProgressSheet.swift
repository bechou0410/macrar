import SwiftUI
import RarKit

struct ProgressSheet: View {
    @Bindable var tracker: OperationTracker
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: tracker.kind.iconSystemName)
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text(tracker.kind.displayName).font(.headline)
                    if let archive = tracker.archive {
                        Text(archive.url.lastPathComponent)
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                }
                Spacer()
                Text(tracker.elapsedFormatted)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: tracker.progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)

            Text(currentLineText)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1).truncationMode(.middle)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !tracker.warnings.isEmpty {
                DisclosureGroup("\(tracker.warnings.count) warning(s)") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(tracker.warnings, id: \.self) { msg in
                                Text(msg).font(.caption.monospaced())
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                }
            }

            HStack {
                if isFinal {
                    Spacer()
                    Button("Close") { dismiss() }.keyboardShortcut(.defaultAction)
                } else {
                    Spacer()
                    Button("Cancel", role: .cancel) { tracker.cancel() }
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private var currentLineText: String {
        if tracker.currentFile.isEmpty {
            switch tracker.status {
            case .running:           return "Preparing…"
            case .succeeded:         return "Completed"
            case .failed(let m):     return m
            case .cancelled:         return "Cancelled"
            }
        }
        return tracker.currentFile
    }

    private var isFinal: Bool {
        if case .running = tracker.status { return false }
        return true
    }
}
