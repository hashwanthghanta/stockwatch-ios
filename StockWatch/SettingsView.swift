import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(LanguageManager.preferredLanguageKey) private var lang: String = ""

    var body: some View {
        NavigationStack {
            Form {
                heroSection

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
                    LabeledContent {
                        Text("Yahoo Finance")
                    } label: {
                        Text("Data source")
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("StockWatch · A small SwiftUI watchlist demo. Live quotes via Yahoo Finance.")
                }

                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("G. Hashwanth")
                                .font(.callout).bold()
                            Text("Designed and developed by")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("Designed and developed by G. Hashwanth"))
                } header: {
                    Text("Credits")
                } footer: {
                    Text("Built while learning Swift and SwiftUI as part of a transition from C# / Unity to iOS.")
                }
            }
            .navigationTitle(Text("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Text("Done").bold() }
                }
            }
        }
    }

    /// Top banner with the app icon and tagline — gives Settings a small "team / product" face.
    private var heroSection: some View {
        Section {
            HStack(spacing: 16) {
                Image("AppIconImage")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.10), radius: 3, x: 0, y: 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text("StockWatch")
                        .font(.title3).bold()
                    Text("Watchlist · Live quotes · Insights")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("StockWatch — Watchlist with live quotes and insights"))
        }
    }
}

#Preview {
    SettingsView()
}
