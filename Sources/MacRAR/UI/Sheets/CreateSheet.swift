import SwiftUI
import AppKit
import RarKit

struct CreateSheet: View {
    let prefilledSources: [URL]
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var sources: [URL]
    @State private var folder: URL
    @State private var filename: String
    @State private var opts = CreateOptions()
    @State private var collisionAction: CollisionAction = .askLater
    /// Flips when the user edits the auto-suggested filename. Suppresses the
    /// collision warning during init so the default suggestion never warns —
    /// only manual edits that collide will trigger the banner.
    @State private var userEditedName = false

    /// What to do when the destination already exists at submit time.
    private enum CollisionAction: Equatable {
        case askLater         // no decision yet — start() will warn
        case overwrite        // rm existing, then create fresh
        case appendToExisting // let rar `a` append/update (its default behavior)
        case autoRename       // append (1), (2), … until unique
    }

    private var destinationURL: URL {
        folder.appendingPathComponent(ensuredRarSuffix(filename))
    }

    init(prefilledSources: [URL]) {
        self.prefilledSources = prefilledSources
        _sources = State(initialValue: prefilledSources)
        let firstParent = prefilledSources.first?.deletingLastPathComponent()
            ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let stem = prefilledSources.first?.deletingPathExtension().lastPathComponent ?? "archive"
        _folder = State(initialValue: firstParent)
        // Pre-pick a unique name now so the sheet opens without a warning even
        // if `<stem>.rar` already exists next to the source.
        _filename = State(initialValue: Self.uniqueName(stem: stem, ext: "rar", in: firstParent))
    }

    /// Returns the first `<stem>.<ext>`, `<stem> (1).<ext>`, `<stem> (2).<ext>`, …
    /// that doesn't currently exist in `folder`.
    private static func uniqueName(stem: String, ext: String, in folder: URL) -> String {
        let fm = FileManager.default
        let first = "\(stem).\(ext)"
        if !fm.fileExists(atPath: folder.appendingPathComponent(first).path) { return first }
        for i in 1...999 {
            let candidate = "\(stem) (\(i)).\(ext)"
            if !fm.fileExists(atPath: folder.appendingPathComponent(candidate).path) {
                return candidate
            }
        }
        return first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView { form.padding(16) }
            Divider()
            footer
        }
        .frame(width: 560)
        .frame(minHeight: 580, maxHeight: 760)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "plus.rectangle.on.folder")
                    .font(.title2).foregroundStyle(.tint)
                Text("New RAR Archive").font(.title3.bold())
                Spacer()
            }
            if !model.runner.rarAvailable {
                RarInstallBanner().padding(.top, 6)
            }
        }
        .padding(16)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            sourcesSection
            destinationSection
            compressionSection
            encryptionSection
            advancedSection
        }
    }

    @ViewBuilder private var sourcesSection: some View {
        sectionHeader("Sources")
        if sources.isEmpty {
            Text("Add files or folders to compress").foregroundStyle(.secondary).font(.callout)
        } else {
            ForEach(sources, id: \.self) { url in
                HStack {
                    Image(systemName: url.hasDirectoryPath ? "folder" : "doc")
                    Text(url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button { sources.removeAll { $0 == url } } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        Button("Add Files…") { pickSources() }
    }

    @ViewBuilder private var destinationSection: some View {
        sectionHeader("Destination")

        HStack {
            Text("Name").frame(width: 60, alignment: .leading)
            TextField("archive.rar", text: $filename)
                .textFieldStyle(.roundedBorder)
                .onChange(of: filename) { _, _ in
                    userEditedName = true
                    collisionAction = .askLater
                }
            if showCollisionUI {
                Button("Auto-rename") { applyAutoRename() }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("Pick the next available name like archive (1).rar")
            }
        }

        HStack {
            Text("Folder").frame(width: 60, alignment: .leading)
            Text(folder.path)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
            Spacer()
            Button("Choose…") { pickFolder() }
        }

        if showCollisionUI {
            collisionWarning
        }
    }

    /// Collision warning only surfaces after the user manually changes the name
    /// into one that collides. The default auto-renamed suggestion stays silent.
    private var showCollisionUI: Bool {
        userEditedName && destinationExists
    }

    @ViewBuilder private var collisionWarning: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout)
                Text("\"\(ensuredRarSuffix(filename))\" already exists")
                    .font(.subheadline.bold())
                Spacer()
            }

            HStack(spacing: 6) {
                CollisionChoiceChip(
                    label: "Replace",
                    icon: "arrow.triangle.2.circlepath",
                    isSelected: collisionAction == .overwrite,
                    accent: .red
                ) { collisionAction = .overwrite }

                CollisionChoiceChip(
                    label: "Append",
                    icon: "plus.square.on.square",
                    isSelected: collisionAction == .appendToExisting,
                    accent: .blue
                ) { collisionAction = .appendToExisting }

                CollisionChoiceChip(
                    label: "Rename",
                    icon: "pencil",
                    isSelected: collisionAction == .autoRename,
                    accent: .green
                ) {
                    collisionAction = .autoRename
                    applyAutoRename()
                }
                Spacer()
            }

            if collisionAction != .askLater {
                Text(actionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
        .animation(.spring(duration: 0.25), value: collisionAction)
    }

    private var actionDescription: String {
        switch collisionAction {
        case .askLater:          return ""
        case .overwrite:         return "The existing archive will be deleted before creating the new one."
        case .appendToExisting:  return "New files will be added into the existing archive (rar's default behavior)."
        case .autoRename:        return "A unique name has been picked. The existing archive stays untouched."
        }
    }

    @ViewBuilder private var compressionSection: some View {
        sectionHeader("Compression")
        HStack {
            Text("Level").frame(width: 90, alignment: .leading)
            Slider(value: Binding(get: { Double(opts.compressionLevel) },
                                   set: { opts.compressionLevel = Int($0) }), in: 0...5, step: 1)
            Text(compressionLabel).font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
        }
        Picker("Dictionary", selection: $opts.dictionarySize) {
            ForEach(CreateOptions.DictionarySize.allCases) { size in
                Text(size.label).tag(size)
            }
        }
        Toggle("Solid archive (better ratio, slower update)", isOn: $opts.solidArchive)
    }

    @ViewBuilder private var encryptionSection: some View {
        sectionHeader("Password (optional)")
        SecureField("Leave empty for no encryption", text: $opts.password)
            .textFieldStyle(.roundedBorder)
        Toggle("Encrypt file names too (header encryption)", isOn: $opts.encryptHeaders)
            .disabled(opts.password.isEmpty)
    }

    @ViewBuilder private var advancedSection: some View {
        sectionHeader("Advanced")
        HStack {
            Text("Recovery record").frame(width: 130, alignment: .leading)
            Slider(value: Binding(get: { Double(opts.recoveryRecordPercent) },
                                   set: { opts.recoveryRecordPercent = Int($0) }), in: 0...10, step: 1)
            Text(opts.recoveryRecordPercent == 0 ? "Off" : "\(opts.recoveryRecordPercent)%")
                .font(.caption).foregroundStyle(.secondary).frame(width: 50, alignment: .trailing)
        }
        Toggle("Self-extracting (.exe)", isOn: $opts.sfx)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text).font(.subheadline.bold()).foregroundStyle(.secondary).padding(.top, 4)
    }

    private var compressionLabel: String {
        ["Store", "Fastest", "Fast", "Normal", "Good", "Best"][opts.compressionLevel]
    }

    private var footer: some View {
        HStack {
            Text(destinationURL.path)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            Button(submitLabel) { start() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
        }
        .padding(16)
    }

    // MARK: - Submit gating

    private var canSubmit: Bool {
        guard !sources.isEmpty,
              !filename.trimmingCharacters(in: .whitespaces).isEmpty,
              model.runner.rarAvailable
        else { return false }
        // Only gate on explicit collision choice when the warning is actually
        // visible (i.e. user typed a colliding name). Default auto-named state
        // doesn't trigger the gate.
        if showCollisionUI && collisionAction == .askLater { return false }
        return true
    }

    private var submitLabel: String {
        if showCollisionUI && collisionAction == .appendToExisting { return "Append" }
        if showCollisionUI && collisionAction == .overwrite        { return "Overwrite" }
        return "Create"
    }

    private var destinationExists: Bool {
        FileManager.default.fileExists(atPath: destinationURL.path)
    }

    private func ensuredRarSuffix(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.lowercased().hasSuffix(".rar") { return trimmed }
        if trimmed.lowercased().hasSuffix(".exe") && opts.sfx { return trimmed }
        return trimmed + ".rar"
    }

    // MARK: - Pickers

    private func pickSources() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        if panel.runModal() == .OK {
            sources.append(contentsOf: panel.urls)
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = folder
        if panel.runModal() == .OK, let url = panel.url {
            folder = url
        }
    }

    private func applyAutoRename() {
        let ext = (filename as NSString).pathExtension.isEmpty ? "rar" : (filename as NSString).pathExtension
        let stem = (filename as NSString).deletingPathExtension
        filename = Self.uniqueName(stem: stem, ext: ext, in: folder)
        // The new unique name is no longer "user-edited toward collision".
        userEditedName = false
        collisionAction = .askLater
    }

    // MARK: - Submit

    private func start() {
        guard !sources.isEmpty else { return }

        let target = destinationURL
        if FileManager.default.fileExists(atPath: target.path), collisionAction == .overwrite {
            // Remove existing to guarantee a fresh archive (rar `a` would append).
            try? FileManager.default.removeItem(at: target)
        }

        let cmd = RarCommand.create(
            archive: target,
            sources: sources,
            compression: opts.compressionLevel,
            solid: opts.solidArchive,
            recoveryPercent: opts.recoveryRecordOrNil,
            volumeBytes: opts.volumeSizeBytes,
            password: opts.passwordOrNil,
            encryptHeaders: opts.encryptHeaders,
            sfx: opts.sfx,
            threads: opts.multiThreaded
        )
        model.startOperation(
            kind: .create(sources: sources, destination: target, options: opts),
            archive: nil,
            command: cmd
        )
        dismiss()
    }
}

/// Compact selectable chip used in CreateSheet's collision warning.
private struct CollisionChoiceChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(
                Capsule().fill(isSelected ? accent.opacity(0.2) : Color.clear)
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? accent : Color.secondary.opacity(0.3),
                                       lineWidth: isSelected ? 1.5 : 1)
            )
            .foregroundStyle(isSelected ? accent : .primary)
        }
        .buttonStyle(.plain)
    }
}
