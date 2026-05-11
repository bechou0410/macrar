import SwiftUI
import RarKit

struct PasswordPromptSheet: View {
    let archiveName: String
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var password: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title.bold())
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Password required").font(.headline)
                    Text(archiveName)
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { submit() }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Unlock", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear { focused = true }
    }

    private func submit() {
        guard !password.isEmpty else { return }
        onSubmit(password)
    }
}
