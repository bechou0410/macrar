import SwiftUI

/// Reusable drop-destination modifier accepting file URLs from Finder.
public extension View {
    func acceptArchiveDrop(onDrop: @escaping ([URL]) -> Void) -> some View {
        self.dropDestination(for: URL.self) { urls, _ in
            onDrop(urls)
            return true
        }
    }
}
