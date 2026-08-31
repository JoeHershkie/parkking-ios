import SwiftUI

struct SearchSheet: View {
    @Bindable var viewModel: ParkingMapViewModel
    @Binding var detent: PresentationDetent
    @State private var searchClient = MapKitSearchClient()
    @State private var query = ""
    @State private var resolveError: String?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)

            if detent != .height(76) || isSearchFocused {
                contentList
            }
        }
        .onChange(of: query) { _, value in
            resolveError = nil
            searchClient.updateQuery(value)
        }
        .onChange(of: isSearchFocused) { _, isFocused in
            if isFocused {
                detent = .large
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                TextField("Search Toronto address", text: $query)
                    .font(.system(size: 16, weight: .regular))
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)

                if !query.isEmpty {
                    Button {
                        query = ""
                        resolveError = nil
                        searchClient.updateQuery("")
                        viewModel.clearSearchPin()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search text")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(uiColor: .tertiarySystemFill), in: Capsule(style: .continuous))

            TimeMenuButton(viewModel: viewModel, style: .searchCapsule)
        }
    }

    private var contentList: some View {
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
        .scrollDismissesKeyboard(.interactively)
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
                            HStack(spacing: 12) {
                                Image(systemName: "clock")
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recent.label)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    if let subtitle = recent.subtitle, !subtitle.isEmpty {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(recent.label)
                        .accessibilityValue(recent.subtitle ?? "")
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
        isSearchFocused = false
        detent = .height(76)
        _ = viewModel.selectSearchResult(
            title: recent.label,
            subtitle: recent.subtitle,
            coordinate: recent.coordinate,
            source: .recent
        )
    }

    private func pickCompletion(_ completion: PlaceCompletion) async {
        resolveError = nil
        do {
            let place = try await searchClient.resolve(completion)
            let accepted = viewModel.selectSearchResult(
                title: place.title,
                subtitle: place.subtitle,
                coordinate: place.coordinate,
                source: .search
            )
            if accepted {
                query = ""
                searchClient.updateQuery("")
                isSearchFocused = false
                detent = .height(76)
            } else {
                resolveError = MapKitSearchError.outOfCoverage.localizedDescription
            }
        } catch {
            resolveError = error.localizedDescription
        }
    }
}

typealias LocationSheet = SearchSheet

#Preview {
    SearchSheet(
        viewModel: ParkingMapViewModel(startsClock: false),
        detent: .constant(.medium)
    )
}
