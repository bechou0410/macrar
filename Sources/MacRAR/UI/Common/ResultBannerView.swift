import SwiftUI
import AppKit

/// Floating toast-style banner that auto-dismisses after a few seconds.
/// Hovers in the top-right of the window; user can hover to pause auto-hide.
struct ResultBannerView: View {
    let banner: AppModel.ResultBanner
    let onDismiss: () -> Void

    @State private var visible = false
    @State private var hovering = false

    private var autoHideSeconds: Double {
        switch banner.kind {
        case .success: 5
        case .failure: 12
        case .info:    4
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            Text(banner.message)
                .lineLimit(2)
                .font(.callout)
            if let url = banner.detailURL {
                Button("Show") { reveal(url) }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .foregroundStyle(.tint)
            }
            Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.4), lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .padding(.top, 10)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : -12)
        .onHover { hovering = $0 }
        .onAppear {
            withAnimation(.spring(duration: 0.35)) { visible = true }
            scheduleAutoHide()
        }
    }

    private func scheduleAutoHide() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(autoHideSeconds))
            // Defer dismiss while hovering — give user time to read
            while hovering {
                try? await Task.sleep(for: .seconds(1))
            }
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) { visible = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            onDismiss()
        }
    }

    private var icon: String {
        switch banner.kind {
        case .success: "checkmark.circle.fill"
        case .failure: "xmark.octagon.fill"
        case .info:    "info.circle.fill"
        }
    }

    private var color: Color {
        switch banner.kind {
        case .success: .green
        case .failure: .red
        case .info:    .secondary
        }
    }

    private func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
