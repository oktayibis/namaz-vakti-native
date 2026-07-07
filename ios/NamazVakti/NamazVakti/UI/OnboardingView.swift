import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: AppViewModel
    var onFinished: () -> Void
    
    @State private var currentStep = 1 // 1: Location, 2: Parameters
    @State private var searchQuery = ""
    @State private var searchResults: [LocationData] = []
    @State private var isSearching = false
    
    @State private var selectedMethod = 13
    
    let calculationMethods = [
        (0, "Kum Leva Enstitüsü (Caferi)"),
        (1, "Karaçi (İslami İlimler)"),
        (2, "ISNA (Kuzey Amerika)"),
        (3, "Muslim World League"),
        (4, "Umm Al-Qura (Mekke)"),
        (5, "Mısır Genel Araştırma"),
        (7, "Tahran Üniversitesi (Şii)"),
        (8, "Körfez Bölgesi"),
        (9, "Kuveyt"),
        (10, "Katar"),
        (11, "Singapur (MUIS)"),
        (12, "Fransa (UOIF)"),
        (13, "Türkiye (Diyanet)"),
        (14, "Rusya"),
        (15, "Moonsighting Committee"),
        (16, "Dubai"),
        (17, "Malezya (JAKIM)"),
        (18, "Tunus"),
        (19, "Cezayir"),
        (20, "Endonezya (KEMENAG)"),
        (21, "Fas"),
        (22, "Portekiz (Lizbon)"),
        (23, "Ürdün")
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            
            if viewModel.onboardingLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .amberColor))
                        .scaleEffect(1.5)
                    
                    Text("Namaz takvimi hazırlanıyor...\nTüm yıl çevrimdışı kullanım için indiriliyor.")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                VStack(spacing: 24) {
                    // Header progress indicator
                    HStack {
                        Text("Kurulum Sihirbazı")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(currentStep) / 2")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.amberColor)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    if currentStep == 1 {
                        // Step 1: Choose Location
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Namaz vakitlerini hesaplamak için bir konum seçin.")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            if let detected = viewModel.detectedLocation {
                                // Selected location card
                                HStack {
                                    Image(systemName: "location.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.amberColor)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(detected.name)
                                            .font(.system(.headline, design: .rounded))
                                            .foregroundColor(.white)
                                        Text(detected.country)
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Button(action: { viewModel.detectedLocation = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                            .font(.title2)
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(16)
                                .padding(.horizontal)
                                .onAppear {
                                    // Auto-preselect parameters
                                    let defaults = viewModel.determineDefaultParameters(for: detected)
                                    selectedMethod = defaults.0
                                }
                                
                                Spacer()
                                
                                Button(action: { currentStep = 2 }) {
                                    Text("Devam Et")
                                        .font(.system(.headline, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.amberColor)
                                        .cornerRadius(16)
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                            } else {
                                // Use GPS Location Button
                                Button(action: {
                                    viewModel.detectLocationForOnboarding()
                                }) {
                                    HStack {
                                        if viewModel.isDetectingLocation {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        } else {
                                            Image(systemName: "location.fill")
                                            Text("Mevcut Konumu Kullan")
                                        }
                                    }
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(16)
                                }
                                .disabled(viewModel.isDetectingLocation)
                                .padding(.horizontal)
                                
                                Text("veya şehir arayın:")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 8)
                                
                                // Search bar
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.gray)
                                    TextField("Şehir Ara...", text: $searchQuery)
                                        .foregroundColor(.white)
                                        .autocorrectionDisabled()
                                    if !searchQuery.isEmpty {
                                        Button(action: { searchQuery = "" }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(12)
                                .padding(.horizontal)
                                .onChange(of: searchQuery) { query in
                                    if query.count >= 2 {
                                        isSearching = true
                                        LocationManager.shared.searchCity(query: query) { results in
                                            DispatchQueue.main.async {
                                                self.searchResults = results
                                                self.isSearching = false
                                            }
                                        }
                                    } else {
                                        self.searchResults = []
                                    }
                                }
                                
                                // Search results list
                                if isSearching {
                                    Spacer()
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .amberColor))
                                        .frame(maxWidth: .infinity)
                                    Spacer()
                                } else {
                                    List(searchResults) { location in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(location.name)
                                                .font(.system(.body, design: .rounded))
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                            Text(location.country)
                                                .font(.system(.footnote, design: .rounded))
                                                .foregroundColor(.gray)
                                        }
                                        .listRowBackground(Color.white.opacity(0.02))
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            viewModel.detectedLocation = location
                                        }
                                    }
                                    .listStyle(PlainListStyle())
                                }
                            }
                        }
                    } else {
                        // Step 2: Settings Configuration
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Konumunuza göre varsayılan hesaplama ayarları seçildi. Dilerseniz düzenleyebilirsiniz:")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 20) {
                                    Text("Hesaplama Metodu (Kaynak)")
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                    
                                    VStack(spacing: 0) {
                                        ForEach(calculationMethods, id: \.0) { item in
                                            HStack {
                                                Text(item.1)
                                                    .font(.system(.body, design: .rounded))
                                                    .foregroundColor(.white)
                                                Spacer()
                                                if selectedMethod == item.0 {
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(.amberColor)
                                                }
                                            }
                                            .padding()
                                            .background(Color.white.opacity(selectedMethod == item.0 ? 0.08 : 0.02))
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                selectedMethod = item.0
                                            }
                                            
                                            Divider().background(Color.white.opacity(0.05))
                                        }
                                    }
                                    .cornerRadius(16)
                                    .padding(.horizontal)
                                }
                            }
                            
                            HStack(spacing: 16) {
                                Button(action: { currentStep = 1 }) {
                                    Text("Geri")
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding()
                                }
                                
                                Button(action: {
                                    if let loc = viewModel.detectedLocation {
                                        viewModel.completeOnboarding(location: loc, methodId: selectedMethod) {
                                            onFinished()
                                        }
                                    }
                                }) {
                                    Text("Başlayalım")
                                        .font(.system(.headline, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.amberColor)
                                        .cornerRadius(16)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
