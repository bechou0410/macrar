import Foundation

/// Detects multi-volume RAR archives and resolves the "first volume" URL that
/// should be passed to unrar.
///
/// Two naming patterns:
///   - Modern: `name.part01.rar`, `name.part02.rar`, … → first volume is `name.part01.rar`
///   - Legacy: `name.rar`, `name.r00`, `name.r01`, …   → first volume is `name.rar`
public enum MultipartDetector {
    public struct Result: Sendable, Equatable {
        public let isMultipart: Bool
        public let firstVolume: URL
        public let parts: [URL]
    }

    public static func detect(_ url: URL) -> Result {
        let dir = url.deletingLastPathComponent()
        let name = url.lastPathComponent

        // Modern: .partNN.rar
        if let m = matchPartPattern(name) {
            let firstName = "\(m.base).part\(String(repeating: "0", count: m.padding - 1))1.rar"
            let firstURL = dir.appendingPathComponent(firstName)
            let parts = scanModernParts(dir: dir, base: m.base, padding: m.padding)
            let resolved = parts.contains(firstURL) ? firstURL : url
            return Result(isMultipart: parts.count > 1, firstVolume: resolved, parts: parts)
        }

        // Legacy: .rNN siblings of .rar
        if name.hasSuffix(".rar") || matchLegacySplit(name) {
            let base = (name.hasSuffix(".rar"))
                ? String(name.dropLast(4))
                : (name as NSString).deletingPathExtension
            let primary = dir.appendingPathComponent("\(base).rar")
            let parts = scanLegacyParts(dir: dir, base: base)
            if parts.count > 1 {
                let first = FileManager.default.fileExists(atPath: primary.path) ? primary : url
                return Result(isMultipart: true, firstVolume: first, parts: parts)
            }
        }

        return Result(isMultipart: false, firstVolume: url, parts: [url])
    }

    // MARK: - Pattern matchers

    private struct PartMatch { let base: String; let index: Int; let padding: Int }

    /// Matches `<base>.part<digits>.rar`. Returns base + padding width.
    private static func matchPartPattern(_ name: String) -> PartMatch? {
        guard name.lowercased().hasSuffix(".rar") else { return nil }
        let withoutRar = String(name.dropLast(4))
        guard let dotPart = withoutRar.range(of: ".part", options: .backwards) else { return nil }
        let digits = String(withoutRar[dotPart.upperBound...])
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }
        let base = String(withoutRar[..<dotPart.lowerBound])
        return PartMatch(base: base, index: Int(digits) ?? 1, padding: digits.count)
    }

    /// Matches `<name>.r<NN>` (legacy split).
    private static func matchLegacySplit(_ name: String) -> Bool {
        let parts = name.split(separator: ".")
        guard let last = parts.last, last.count >= 2 else { return false }
        guard last.first == "r" || last.first == "R" else { return false }
        return last.dropFirst().allSatisfy(\.isNumber)
    }

    // MARK: - Sibling scanners

    private static func scanModernParts(dir: URL, base: String, padding: Int) -> [URL] {
        var found: [URL] = []
        let fm = FileManager.default
        var i = 1
        while i < 10000 {
            let n = String(i)
            let padded = String(repeating: "0", count: max(0, padding - n.count)) + n
            let candidate = dir.appendingPathComponent("\(base).part\(padded).rar")
            if fm.fileExists(atPath: candidate.path) {
                found.append(candidate)
                i += 1
            } else {
                break
            }
        }
        return found
    }

    private static func scanLegacyParts(dir: URL, base: String) -> [URL] {
        var found: [URL] = []
        let fm = FileManager.default
        let main = dir.appendingPathComponent("\(base).rar")
        if fm.fileExists(atPath: main.path) { found.append(main) }
        var i = 0
        while i < 1000 {
            let suffix = String(format: "r%02d", i)
            let candidate = dir.appendingPathComponent("\(base).\(suffix)")
            if fm.fileExists(atPath: candidate.path) {
                found.append(candidate)
                i += 1
            } else {
                break
            }
        }
        return found
    }
}
