import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var notificationManager = NotificationManager.shared
    private var appViewModel = AppViewModel.shared
    
    @State private var selectedMethod = 13
    @State private var enabledPrayers: Set<PrayerType> = []
    @State private var reminderOffsets: [Int] = []
    @State private var showingAddReminderSheet = false
    @State private var selectedOffsetToAdd = 15 // Default choice to add
    
    // Available offset options in minutes
    let offsetOptions = [5, 10, 15, 20, 30, 45, 60]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.opacity(0.92).ignoresSafeArea()
                
                Form {
                    // Notification permission banner
                    if !notificationManager.isPermissionGranted {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "bell.badge.fill")
                                        .foregroundColor(.red)
                                    Text("Bildirim İzni Devre Dışı")
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                Text("Namaz vakitlerinde hatırlatıcı alabilmek için lütfen ayarlardan bildirim izni verin.")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.gray)
                                
                                Button(action: {
                                    notificationManager.requestPermission { granted in
                                        if !granted {
                                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                                UIApplication.shared.open(url)
                                            }
                                        }
                                    }
                                }) {
                                    Text("Sistem Ayarlarını Aç")
                                        .font(.system(.subheadline, design: .rounded))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.amberColor)
                                }
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                    
                    // Toggle per prayer time
                    Section(header: Text("Vakit Seçimi").foregroundColor(.gray)) {
                        ForEach([PrayerType.fajr, .dhuhr, .asr, .maghrib, .isha], id: \.self) { prayer in
                            Toggle(isOn: Binding(
                                get: { enabledPrayers.contains(prayer) },
                                set: { isEnabled in
                                    if isEnabled {
                                        enabledPrayers.insert(prayer)
                                    } else {
                                        enabledPrayers.remove(prayer)
                                    }
                                    saveChanges()
                                }
                            )) {
                                HStack(spacing: 12) {
                                    Image(systemName: prayer.iconName)
                                        .foregroundColor(.amberColor)
                                        .frame(width: 24)
                                    Text(prayer.turkishName)
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    
                    // Reminder offsets list (max 3)
                    Section(
                        header: Text("Hatırlatıcı Zamanları").foregroundColor(.gray),
                        footer: Text("En fazla 3 farklı hatırlatıcı ekleyebilirsiniz. (Örn: 30 dk önce ve Namaz vaktinde)").foregroundColor(.gray)
                    ) {
                        ForEach(reminderOffsets, id: \.self) { offset in
                            HStack {
                                Text(offset == 0 ? "Namaz Vaktinde" : "\(offset) dakika önce")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                                Button(action: {
                                    removeOffset(offset)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red.opacity(0.8))
                                }
                            }
                        }
                        
                        if reminderOffsets.count < 3 {
                            Button(action: { showingAddReminderSheet = true }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Hatırlatıcı Ekle")
                                        .font(.system(.body, design: .rounded))
                                }
                                .foregroundColor(.amberColor)
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    
                    // Calculation Parameters Section
                    Section(header: Text("Hesaplama Ayarları").foregroundColor(.gray)) {
                        Picker("Hesaplama Metodu", selection: Binding(
                            get: { selectedMethod },
                            set: { newValue in
                                selectedMethod = newValue
                                appViewModel.setCalculationMethod(newValue)
                            }
                        )) {
                            Text("Kum Leva Enstitüsü (Caferi)").tag(0)
                            Text("Karaçi (İslami İlimler)").tag(1)
                            Text("ISNA (Kuzey Amerika)").tag(2)
                            Text("Muslim World League").tag(3)
                            Text("Umm Al-Qura (Mekke)").tag(4)
                            Text("Mısır Genel Araştırma").tag(5)
                            Text("Tahran Üniversitesi (Şii)").tag(7)
                            Text("Körfez Bölgesi").tag(8)
                            Text("Kuveyt").tag(9)
                            Text("Katar").tag(10)
                            Text("Singapur (MUIS)").tag(11)
                            Text("Fransa (UOIF)").tag(12)
                            Text("Türkiye (Diyanet)").tag(13)
                            Text("Rusya").tag(14)
                            Text("Moonsighting Committee").tag(15)
                            Text("Dubai").tag(16)
                            Text("Malezya (JAKIM)").tag(17)
                            Text("Tunus").tag(18)
                            Text("Cezayir").tag(19)
                            Text("Endonezya (KEMENAG)").tag(20)
                            Text("Fas").tag(21)
                            Text("Portekiz (Lizbon)").tag(22)
                            Text("Ürdün").tag(23)
                        }
                        .foregroundColor(.white)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                .scrollContentBackground(.hidden) // Removes standard Form background on iOS 16+
            }
            .navigationTitle("Bildirim Ayarları")
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
            .sheet(isPresented: $showingAddReminderSheet) {
                NavigationView {
                    ZStack {
                        Color.black.opacity(0.92).ignoresSafeArea()
                        VStack(spacing: 24) {
                            Text("Yeni Hatırlatıcı Süresi")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.top)
                            
                            Picker("Süre", selection: $selectedOffsetToAdd) {
                                Text("Namaz Vaktinde").tag(0)
                                ForEach(offsetOptions, id: \.self) { min in
                                    Text("\(min) dakika önce").tag(min)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(height: 150)
                            
                            Button(action: {
                                addOffset(selectedOffsetToAdd)
                                showingAddReminderSheet = false
                            }) {
                                Text("Ekle")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.amberColor)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            
                            Spacer()
                        }
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("İptal") { showingAddReminderSheet = false }
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .presentationDetents([.height(320)]) // Half-sheet in iOS 16
                .preferredColorScheme(.dark)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadSettings()
            notificationManager.checkPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            notificationManager.checkPermission()
        }
    }
    
    private func loadSettings() {
        enabledPrayers = notificationManager.getEnabledPrayers()
        reminderOffsets = notificationManager.getReminderOffsets()
        selectedMethod = appViewModel.getCalculationMethod()
    }
    
    private func addOffset(_ offset: Int) {
        if !reminderOffsets.contains(offset) {
            reminderOffsets.append(offset)
            saveChanges()
        }
    }
    
    private func removeOffset(_ offset: Int) {
        reminderOffsets.removeAll(where: { $0 == offset })
        saveChanges()
    }
    
    private func saveChanges() {
        notificationManager.setEnabledPrayers(enabledPrayers)
        notificationManager.setReminderOffsets(reminderOffsets)
        
        // Reschedule notifications for the active location
        if let active = appViewModel.activeLocation {
            notificationManager.scheduleAllNotifications(for: active)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
