import SwiftUI

struct LocationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = AppViewModel.shared
    @StateObject private var languageManager = LanguageManager.shared
    @State private var searchQuery = ""
    @State private var searchResults: [LocationData] = []
    @State private var isSearching = false
    @State private var searchError: String? = nil
    @State private var searchWorkItem: DispatchWorkItem? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.opacity(0.92).ignoresSafeArea()

                VStack(spacing: 16) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .accessibilityHidden(true)

                        TextField(tr("search_city_placeholder"), text: $searchQuery)
                            .foregroundColor(.white)
                            .autocorrectionDisabled()
                            .onChange(of: searchQuery) { newValue in
                                scheduleSearch(for: newValue)
                            }

                        if !searchQuery.isEmpty {
                            Button(action: {
                                searchQuery = ""
                                searchResults = []
                                searchError = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel(tr("clear_search"))
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    if isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(.top, 40)
                        Spacer()
                    } else if let searchError = searchError {
                        // An offline device and a genuinely unknown city are different
                        // problems; saying so is the difference between a dead end and
                        // an actionable message.
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 34))
                                .foregroundColor(.gray)
                                .accessibilityHidden(true)
                            Text(searchError)
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !searchResults.isEmpty {
                        // Search Results List
                        List(searchResults) { location in
                            Button(action: {
                                viewModel.addLocation(location)
                                dismiss()
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(location.name)
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    Text(location.country)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundColor(.gray)
                                }
                                .accessibilityElement(children: .combine)
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                        }
                        .listStyle(PlainListStyle())
                    } else {
                        // Saved Locations List
                        VStack(alignment: .leading, spacing: 8) {
                            Text(tr("saved_locations"))
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                                .padding(.top, 10)

                            List {
                                // Always available — previously this lived inside the
                                // non-empty branch, so deleting every saved location
                                // left no way to re-detect.
                                Button(action: {
                                    viewModel.detectCurrentLocation()
                                    dismiss()
                                }) {
                                    HStack {
                                        Image(systemName: "location.fill")
                                            .foregroundColor(.amberColor)
                                            .accessibilityHidden(true)
                                        Text(tr("use_current_location"))
                                            .font(.system(.body, design: .rounded))
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                        Spacer()
                                        if viewModel.isDetectingLocation {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        }
                                    }
                                }
                                .listRowBackground(Color.white.opacity(0.05))
                                .disabled(viewModel.isDetectingLocation)
                                .accessibilityLabel(tr("use_current_location"))

                                if viewModel.savedLocations.isEmpty {
                                    Text(tr("no_saved_locations"))
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(.gray)
                                        .listRowBackground(Color.clear)
                                } else {
                                    ForEach(viewModel.savedLocations) { location in
                                        let isActive = viewModel.activeLocation?.id == location.id

                                        Button(action: {
                                            viewModel.selectLocation(location)
                                            dismiss()
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(location.name)
                                                        .font(.system(.body, design: .rounded))
                                                        .fontWeight(isActive ? .bold : .semibold)
                                                        .foregroundColor(isActive ? .amberColor : .white)
                                                    Text(location.country)
                                                        .font(.system(.caption, design: .rounded))
                                                        .foregroundColor(.gray)
                                                }
                                                Spacer()
                                                if isActive {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.amberColor)
                                                        .accessibilityHidden(true)
                                                }
                                            }
                                        }
                                        .listRowBackground(isActive ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                                        .accessibilityElement(children: .combine)
                                        .accessibilityValue(isActive ? tr("active") : "")
                                    }
                                    .onDelete(perform: viewModel.removeLocation)
                                }
                            }
                            .listStyle(PlainListStyle())
                        }
                    }
                }
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
                .navigationTitle(tr("location_management"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { dismiss() }) {
                            Text(tr("close"))
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .locationFailureAlert(viewModel: viewModel)
    }

    // MARK: - Debounced search

    /// Waits 300ms after the last keystroke before hitting the network, matching the
    /// Android side. Each new keystroke cancels both the pending debounce and any
    /// request already in flight.
    private func scheduleSearch(for query: String) {
        searchWorkItem?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 2 else {
            LocationManager.shared.cancelSearch()
            searchResults = []
            searchError = nil
            // The old code returned here without clearing this, so a late response
            // could repopulate results for a query the user had already deleted.
            isSearching = false
            return
        }

        let work = DispatchWorkItem { runSearch(trimmed) }
        searchWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func runSearch(_ query: String) {
        isSearching = true
        searchError = nil
        LocationManager.shared.searchCity(query: query) { result in
            // Drop a response the user has already moved past.
            guard query == searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            isSearching = false
            switch result {
            case .success(let results):
                searchResults = results
                searchError = results.isEmpty ? tr("search_no_results") : nil
            case .failure(let failure):
                searchResults = []
                searchError = failure.localizedMessage
            }
        }
    }
}

/// Shared presentation for a failed location lookup, so onboarding and the location
/// sheet explain a denial the same way instead of silently doing nothing.
struct LocationFailureAlert: ViewModifier {
    @ObservedObject var viewModel: AppViewModel

    func body(content: Content) -> some View {
        content.alert(item: $viewModel.locationAlert) { alert in
            if alert.showsSettings {
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text(tr("open_settings"))) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    },
                    secondaryButton: .cancel(Text(tr("close")))
                )
            }
            return Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(tr("ok")))
            )
        }
    }
}

extension View {
    func locationFailureAlert(viewModel: AppViewModel) -> some View {
        modifier(LocationFailureAlert(viewModel: viewModel))
    }
}

struct LocationView_Previews: PreviewProvider {
    static var previews: some View {
        LocationView()
    }
}
