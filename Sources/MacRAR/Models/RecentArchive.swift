import Foundation

/// Persistable record of an archive the user has opened recently.
public struct RecentArchive: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let url: URL
    public let openedAt: Date
    public let entryCount: Int?
    public let totalBytes: Int64?

    public init(
        id: UUID = UUID(),
        url: URL,
        openedAt: Date = .now,
        entryCount: Int? = nil,
        totalBytes: Int64? = nil
    ) {
        self.id = id
        self.url = url
        self.openedAt = openedAt
        self.entryCount = entryCount
        self.totalBytes = totalBytes
    }
}
