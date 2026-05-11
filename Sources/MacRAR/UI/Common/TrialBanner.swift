import SwiftUI
import RarKit

struct TrialBanner: View {
    @Bindable var detector: RarStatusDetector
    @Binding var dismissed: Bool

    var body: some View {
        if case .trial = detector.licenseState, !dismissed {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 1) {
                    Text("RAR engine is in trial mode").font(.subheadline.bold())
                    Text("Install a RARLAB license key in Settings → License to remove reminders.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismissed = true } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.yellow.opacity(0.15))
            .overlay(Divider(), alignment: .bottom)
        }
    }
}
