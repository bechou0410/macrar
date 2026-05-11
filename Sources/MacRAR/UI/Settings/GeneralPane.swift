import SwiftUI

struct GeneralPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Extraction") {
                Picker("Default destination", selection: $model.preferences.defaultExtractDestination) {
                    ForEach(Preferences.ExtractDestinationMode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
            }
            Section("Compression") {
                Picker("Default level", selection: $model.preferences.defaultCompressionLevel) {
                    ForEach(0...5, id: \.self) { i in
                        Text(["Store", "Fastest", "Fast", "Normal", "Good", "Best"][i]).tag(i)
                    }
                }
            }
            Section("Appearance") {
                Picker("Liquid Glass", selection: $model.preferences.liquidGlassMode) {
                    Text("Auto (Tahoe only)").tag(Preferences.LiquidGlassMode.auto)
                    Text("Always on").tag(Preferences.LiquidGlassMode.alwaysOn)
                    Text("Always off").tag(Preferences.LiquidGlassMode.alwaysOff)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: model.preferences) { _, _ in
            model.savePreferences()
        }
    }
}
