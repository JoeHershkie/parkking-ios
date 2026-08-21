import SwiftUI

struct LocationSheet: View {
    @Bindable var viewModel: ParkingMapViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchClient = MapKitSearchClient()
    @State private var query = ""
    @State private var resolveError: String?

    var body: some View {
        NavigationStack {
            List {
                if let message = resolveError ?? searchClient.errorMessage {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .listRowSeparator(.hidden)
                        .accessibilityAddTraits(.isStaticText)
                }

                if searchClient.isSearching {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Searching…")
                            .foregroundStyle(.secondary)
                    }
                    .listRowSeparator(.hidden)
                    .accessibilityElement(children: .combine)
                }

                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    recentsSection
                } else if !searchClient.isSearching {
                    resultsSection
                }
            }
            .listStyle(.plain)
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search Toronto address")
            .onChange(of: query) { _, value in
                resolveError = nil
                searchClient.updateQuery(value)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .frame(minHeight: 44)
                }
            }
        }
    }

    @ViewBuilder
    private var recentsSection: some View {
        Section {
            if viewModel.recents.isEmpty {
                Text("No recent locations yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.recents) { recent in
                    HStack(spacing: 12) {
                        Button {
                            pickRecent(recent)
                        } label: {
                            Label(recent.label, systemImage: "clock")
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(recent.label)
                        .accessibilityHint("Use this recent location")

                        Button(role: .destructive) {
                            viewModel.removeRecent(id: recent.id)
                        } label: {
                            Image(systemName: "trash")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(recent.label) from recent")
                    }
                }
            }
        } header: {
            HStack {
                Text("Recent")
                Spacer()
                if !viewModel.recents.isEmpty {
                    Button("Clear history") {
                        viewModel.clearRecents()
                    }
                    .font(.caption.weight(.semibold))
                    .accessibilityLabel("Clear recent locations")
                }
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if searchClient.completions.isEmpty {
            ContentUnavailableView(
                "No Toronto places found",
                systemImage: "mappin.slash",
                description: Text("Try a different address inside Toronto.")
            )
            .listRowSeparator(.hidden)
        } else {
            ForEach(searchClient.completions) { completion in
                Button {
                    Task { await pickCompletion(completion) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(completion.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        if !completion.subtitle.isEmpty {
                            Text(completion.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(completion.title)
                .accessibilityValue(completion.subtitle)
            }
        }
    }

    private func pickRecent(_ recent: SavedLocation) {
        resolveError = nil
        _ = viewModel.selectSearchResult(
            label: recent.label,
            coordinate: recent.coordinate,
            source: .recent
        )
        dismiss()
    }

    private func pickCompletion(_ completion: PlaceCompletion) async {
        resolveError = nil
        do {
            let place = try await searchClient.resolve(completion)
            let accepted = viewModel.selectSearchResult(
                label: place.label,
                coordinate: place.coordinate,
                source: .search
            )
            if accepted {
                dismiss()
            } else {
                resolveError = MapKitSearchError.outOfCoverage.localizedDescription
            }
        } catch {
            resolveError = error.localizedDescription
        }
    }
}
