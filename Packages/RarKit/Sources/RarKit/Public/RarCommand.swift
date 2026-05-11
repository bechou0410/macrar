import Foundation

/// A typed builder for a single rar/unrar invocation.
public struct RarCommand: Sendable {
    public enum Tool: Sendable { case rar, unrar }

    public enum Action: Sendable, Equatable {
        case extract(keepPaths: Bool)   // x (paths) / e (flat)
        case create                     // a
        case test                       // t
        case list(technical: Bool)      // l / lt
        case repair                     // r (unrar)
        case lock                       // k (rar)
        case readComment                // cw
        case writeComment(filePath: String)  // c -z<file>
        case rename(from: String, to: String) // rn
        case delete(entries: [String])  // d
        case convertToSFX               // s
        case removeSFX                  // s-
        case addRecoveryRecord(percent: Int) // rr<N>p
        case version                    // (no command — `rar` with no args prints banner)
    }

    public enum Switch: Sendable, Equatable {
        case assumeYes                  // -y
        case overwriteAll               // -o+
        case overwriteNone              // -o-
        case renameOld                  // -or
        case renameNew                  // -oR
        case password(String)           // -p<pwd>
        case passwordHeader(String)     // -hp<pwd>
        case include(String)            // -n<mask>
        case exclude(String)            // -x<mask>
        case recurse                    // -r
        case noPaths                    // -ep
        case stripBasePath              // -ep1
        case recoveryRecord(percent: Int) // -rr<N>p
        case volumeBytes(Int64)         // -v<n>b
        case sfxModule                  // -sfx
        case compression(level: Int)    // -m0..-m5
        case dictionarySize(MB: Int)    // -md<N>m
        case solid                      // -s
        case threads(Int)               // -mt<N>
        case silent                     // -inul
        case suppressCopyrightBanner    // -idq
        case raw(String)                // arbitrary passthrough
    }

    public let tool: Tool
    public let action: Action
    public let archive: URL
    public let files: [String]
    public let switches: [Switch]
    public let workingDirectory: URL?

    public init(
        tool: Tool,
        action: Action,
        archive: URL,
        files: [String] = [],
        switches: [Switch] = [],
        workingDirectory: URL? = nil
    ) {
        self.tool = tool
        self.action = action
        self.archive = archive
        self.files = files
        self.switches = switches
        self.workingDirectory = workingDirectory
    }
}

// MARK: - Common factory helpers

public extension RarCommand {
    /// Extract an archive using bundled `unrar`.
    static func extract(
        archive: URL,
        to dest: URL,
        keepPaths: Bool = true,
        overwrite: Overwrite = .ask,
        password: String? = nil,
        includes: [String] = [],
        excludes: [String] = []
    ) -> RarCommand {
        var sw: [Switch] = [.assumeYes]
        switch overwrite {
        case .ask:        break
        case .always:     sw.append(.overwriteAll)
        case .never:      sw.append(.overwriteNone)
        case .renameOld:  sw.append(.renameOld)
        case .renameNew:  sw.append(.renameNew)
        }
        if let p = password { sw.append(.password(p)) }
        includes.forEach { sw.append(.include($0)) }
        excludes.forEach { sw.append(.exclude($0)) }
        return RarCommand(
            tool: .unrar,
            action: .extract(keepPaths: keepPaths),
            archive: archive,
            switches: sw,
            workingDirectory: dest
        )
    }

    /// List archive contents using bundled `unrar`.
    static func list(archive: URL, technical: Bool = false, password: String? = nil) -> RarCommand {
        var sw: [Switch] = [.assumeYes]
        if let p = password { sw.append(.password(p)) }
        return RarCommand(tool: .unrar, action: .list(technical: technical), archive: archive, switches: sw)
    }

    /// Test archive integrity using bundled `unrar`.
    static func test(archive: URL, password: String? = nil) -> RarCommand {
        var sw: [Switch] = [.assumeYes]
        if let p = password { sw.append(.password(p)) }
        return RarCommand(tool: .unrar, action: .test, archive: archive, switches: sw)
    }

    /// Create a new archive using external `rar`.
    ///
    /// Sources are stored relative to their longest common parent directory so
    /// the resulting archive contains clean entries (e.g. `oc.jpg`) instead of
    /// full absolute paths (`/Users/chou/Downloads/oc.jpg`).
    static func create(
        archive: URL,
        sources: [URL],
        compression: Int = 3,
        solid: Bool = false,
        recoveryPercent: Int? = nil,
        volumeBytes: Int64? = nil,
        password: String? = nil,
        encryptHeaders: Bool = false,
        sfx: Bool = false,
        threads: Int? = nil,
        recurse: Bool = true
    ) -> RarCommand {
        var sw: [Switch] = [.assumeYes, .compression(level: compression)]
        if recurse { sw.append(.recurse) }
        if solid { sw.append(.solid) }
        if let r = recoveryPercent, r > 0 { sw.append(.recoveryRecord(percent: r)) }
        if let v = volumeBytes, v > 0 { sw.append(.volumeBytes(v)) }
        if encryptHeaders, let p = password {
            sw.append(.passwordHeader(p))
        } else if let p = password {
            sw.append(.password(p))
        }
        if sfx { sw.append(.sfxModule) }
        if let t = threads { sw.append(.threads(t)) }

        let (workingDir, relFiles) = relativePaths(for: sources)
        return RarCommand(
            tool: .rar,
            action: .create,
            archive: archive,
            files: relFiles,
            switches: sw,
            workingDirectory: workingDir
        )
    }

    /// Returns (common-parent, source-paths relative to that parent).
    /// Falls back to absolute paths if sources span across volumes.
    private static func relativePaths(for sources: [URL]) -> (URL?, [String]) {
        guard let first = sources.first else { return (nil, []) }
        let firstParent = first.deletingLastPathComponent().standardizedFileURL.pathComponents
        var common = firstParent
        for src in sources.dropFirst() {
            let parts = src.deletingLastPathComponent().standardizedFileURL.pathComponents
            var match = 0
            for i in 0..<min(common.count, parts.count) {
                if common[i] == parts[i] { match = i + 1 } else { break }
            }
            common = Array(common.prefix(match))
        }
        guard common.count >= 1 else { return (nil, sources.map(\.path)) }
        // Rebuild URL: pathComponents starts with "/" then segments
        let base: URL
        if common.first == "/" {
            base = URL(fileURLWithPath: "/" + common.dropFirst().joined(separator: "/"))
        } else {
            base = URL(fileURLWithPath: common.joined(separator: "/"))
        }
        let baseLen = base.path.hasSuffix("/") ? base.path.count : base.path.count + 1
        let rel = sources.map { url -> String in
            let p = url.standardizedFileURL.path
            if p.hasPrefix(base.path) && p.count > baseLen {
                return String(p.dropFirst(baseLen))
            }
            return p
        }
        return (base, rel)
    }

    enum Overwrite: Sendable {
        case ask, always, never, renameOld, renameNew
    }
}
