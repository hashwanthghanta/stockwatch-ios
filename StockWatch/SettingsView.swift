import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(LanguageManager.preferredLanguageKey) private var lang: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $lang) {
                        Text("System").tag("")
                        Text("English").tag("en")
                        Text("Deutsch").tag("de")
                    } label: {
                        Label {
                            Text("Language")
                        } icon: {
                            Image(systemName: "globe")
                        }
                    }
                    .pickerStyle(.inline)
                    .onChange(of: lang) { _, newValue in
                        LanguageManager.apply(newValue.isEmpty ? nil : newValue)
                    }
                } header: {
                    Text("Language")
                } footer: {
                    Text("Changes take effect immediately. Choose System to follow your device locale.")
                }

                Section {
                    LabeledContent {
                        Text("1.0")
                    } label: {
                        Text("Version")
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("StockWatch · A small SwiftUI watchlist demo. Live quotes via Yahoo Finance.")
                }
            }
            .navigationTitle(Text("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done").bold()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
