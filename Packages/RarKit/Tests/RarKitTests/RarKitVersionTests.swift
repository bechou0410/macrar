import Testing
@testable import RarKit

@Test func versionExists() {
    #expect(!RarKit.version.isEmpty)
}
