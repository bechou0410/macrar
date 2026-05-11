import SwiftUI

/// Inline banner shown in Create flows when `rar` isn't installed.
struct RarInstallBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("RAR CLI required").font(.subheadline.bold())
                Text("Extraction works out-of-the-box; creating archives needs the proprietary `rar` tool from RARLAB.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Install via Homebrew") { copyBrewCommand() }
                .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func copyBrewCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("brew install rar", forType: .string)
    }
}
