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
            Capsule()
                .fill(Color(uiColor: .tertiaryLabel))
                .frame(width: 54, height: 5)
                .padding(.top, (detent == .height(76) && !isSearchFocused) ? 1 : 6)

            searchBar
                .padding(.horizontal, 16)
                .padding(.top, (detent == .height(76) && !isSearchFocused) ? 3 : 6)
                .padding(.bottom, 8)

            if detent != .height(76) || isSearchFocused {
                contentList
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSearchFocused)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: detent)
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
                if message == MapKitSearchError.outOfCoverage.localizedDescription {
                    ContentUnavailableView {
                        Label("Outside Toronto Coverage", systemImage: "mappin.slash")
                    } description: {
                        Text("Parkking covers street parking bylaws within the City of Toronto.")
                    } actions: {
                        Button("Recenter on Toronto") {
                            viewModel.recenterToronto()
                            resolveError = nil
                            query = ""
                            searchClient.updateQuery("")
                            isSearchFocused = false
                            detent = .height(76)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .listRowSeparator(.hidden)
                } else {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .listRowSeparator(.hidden)
                        .accessibilityAddTraits(.isStaticText)
                }
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
                if !viewModel.favorites.isEmpty {
                    favoritesSection
                }
                recentsSection
            } else if !searchClient.isSearching {
                resultsSection
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var favoritesSection: some View {
        Section {
            ForEach(viewModel.favorites) { favorite in
                HStack(spacing: 12) {
                    Button {
                        pickFavorite(favorite)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(favorite.label)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                if let subtitle = favorite.subtitle, !subtitle.isEmpty {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(favorite.label)
                    .accessibilityValue(favorite.subtitle ?? "")
                    .accessibilityHint("Use this favorite location")

                    Button(role: .destructive) {
                        viewModel.removeFavorite(id: favorite.id)
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(favorite.label) from favorites")
                }
            }
        } header: {
            Text("Favorites")
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
                    Button("Clear") {
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

    private func pickFavorite(_ favorite: SavedLocation) {
        resolveError = nil
        isSearchFocused = false
        detent = .height(76)
        _ = viewModel.selectSearchResult(
            title: favorite.label,
            subtitle: favorite.subtitle,
            coordinate: favorite.coordinate,
            source: .recent
        )
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
