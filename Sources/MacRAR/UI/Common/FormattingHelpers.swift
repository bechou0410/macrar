import Foundation

public enum FormattingHelpers {
    public static func bytes(_ count: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return f.string(fromByteCount: count)
    }

    public static func percent(_ ratio: Double, decimals: Int = 0) -> String {
        let v = max(0, min(1, ratio)) * 100
        return String(format: "%.\(decimals)f%%", v)
    }

    public static func date(_ d: Date?) -> String {
        guard let d else { return "—" }
        return d.formatted(.dateTime.year().month().day().hour().minute())
    }
}
