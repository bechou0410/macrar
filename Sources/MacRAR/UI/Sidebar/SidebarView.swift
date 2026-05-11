import SwiftUI
import RarKit

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List(selection: $model.selectedSessionID) {
            if !model.sessions.isEmpty {
                Section("Open") {
                    ForEach(model.sessions) { session in
                        Label(session.archive.url.lastPathComponent, systemImage: "doc.zipper")
                            .tag(Optional(session.id))
                            .contextMenu {
                                Button("Close") {
                                    model.closeSession(id: session.id)
                                }
                            }
                    }
                }
            }
            if !model.recents.isEmpty {
                Section("Recent") {
                    ForEach(model.recents) { recent in
                        Button {
                            Task { await model.open(url: recent.url) }
                        } label: {
                            HStack {
                                Image(systemName: "archivebox")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(recent.url.lastPathComponent)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    if let count = recent.entryCount {
                                        Text("\(count) entries")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if model.sessions.isEmpty && model.recents.isEmpty {
                Text("No archives open yet").foregroundStyle(.secondary).font(.callout)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MacRAR")
        .frame(minWidth: 220, idealWidth: 240)
    }
}
