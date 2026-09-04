import SwiftUI

struct SettingsSheet: View {
    @Bindable var viewModel: ParkingMapViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $viewModel.showHydrantsOnMap) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show Fire Hydrants")
                                    .font(.body)
                                Text("Display 3m setback icons on the map")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("Map Overlays")
                } footer: {
                    Text("When enabled, fire hydrant locations and their corresponding 3-meter parking setbacks are shown as map pins when zoomed in.")
                }

                Section {
                    Toggle(
                        isOn: Binding(
                            get: { viewModel.snowEmergencyClient.isDeclared },
                            set: { viewModel.setSnowEmergencyDeclared($0) }
                        )
                    ) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Major Snow Storm Condition")
                                    .font(.body)
                                Text(viewModel.snowEmergencyClient.isDeclared ? "Active (72h snow route ban)" : "Inactive")
                                    .font(.caption)
                                    .foregroundStyle(viewModel.snowEmergencyClient.isDeclared ? .red : .secondary)
                            }
                        } icon: {
                            Image(systemName: "snowflake")
                                .foregroundStyle(viewModel.snowEmergencyClient.isDeclared ? .red : .blue)
                        }
                    }
                } header: {
                    Text("Winter & Emergency Conditions")
                } footer: {
                    Text("Simulates an official declaration under Toronto Municipal Code Chapter 950 § 950-406. Snow routes forbid parking during declarations.")
                }

                Section {
                    Picker("Map View Style", selection: Binding(
                        get: { viewModel.mapStyle },
                        set: { viewModel.setMapStyle($0) }
                    )) {
                        ForEach(MapViewStyle.allCases) { style in
                            Label(style.title, systemImage: style.iconName)
                                .tag(style)
                        }
                    }
                } header: {
                    Text("Map Style")
                }

                Section {
                    HStack {
                        Text("Bylaw Jurisdiction")
                        Spacer()
                        Text("City of Toronto")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Bylaw Code")
                        Spacer()
                        Text("TMC Chapter 950")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Dataset")
                        Spacer()
                        Text("Toronto Open Data")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("Parkking evaluates Toronto on-street parking bylaws, signs, and seasonal regulations in real time.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        viewModel.isSettingsPresented = false
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
