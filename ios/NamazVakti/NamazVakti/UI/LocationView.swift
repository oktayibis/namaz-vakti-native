import SwiftUI

struct LocationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = AppViewModel.shared
    @State private var searchQuery = ""
    @State private var searchResults: [LocationData] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.opacity(0.92).ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Şehir Ara...", text: $searchQuery)
                            .foregroundColor(.white)
                            .autocorrectionDisabled()
                            .onChange(of: searchQuery) { newValue in
                                performSearch(query: newValue)
                            }
                        
                        if !searchQuery.isEmpty {
                            Button(action: {
                                searchQuery = ""
                                searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
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
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                        }
                        .listStyle(PlainListStyle())
                    } else {
                        // Saved Locations List
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Kaydedilen Konumlar")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                                .padding(.top, 10)
                            
                            if viewModel.savedLocations.isEmpty {
                                VStack(spacing: 16) {
                                    Spacer()
                                    Image(systemName: "mappin.slash")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("Henüz kaydedilmiş bir konum yok.")
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                List {
                                    // Use Current Location Button inside list
                                    Button(action: {
                                        viewModel.detectCurrentLocation()
                                        dismiss()
                                    }) {
                                        HStack {
                                            Image(systemName: "location.fill")
                                                .foregroundColor(.amberColor)
                                            Text("Mevcut Konumu Kullan")
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
                                                }
                                            }
                                        }
                                        .listRowBackground(isActive ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                                    }
                                    .onDelete(perform: viewModel.removeLocation)
                                }
                                .listStyle(PlainListStyle())
                            }
                        }
                    }
                }
                .navigationTitle("Konum Yönetimi")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { dismiss() }) {
                            Text("Kapat")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // Throttled / Debounced Search
    private func performSearch(query: String) {
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        
        isSearching = true
        LocationManager.shared.searchCity(query: query) { results in
            self.searchResults = results
            self.isSearching = false
        }
    }
}

struct LocationView_Previews: PreviewProvider {
    static var previews: some View {
        LocationView()
    }
}
