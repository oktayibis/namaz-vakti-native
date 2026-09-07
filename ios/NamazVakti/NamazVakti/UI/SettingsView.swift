import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    private var appViewModel = AppViewModel.shared
    
    @State private var selectedMethod = 13
    @State private var selectedMadhab = 0
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
                    // Language Settings Section
                    Section(header: Text(tr("app_language")).foregroundColor(.gray)) {
                        Picker(tr("app_language"), selection: Binding(
                            get: { languageManager.currentLanguage },
                            set: { newValue in
                                appViewModel.setAppLanguage(newValue)
                            }
                        )) {
                            Text(tr("language_system")).tag("system")
                            Text("Türkçe").tag("tr")
                            Text("English").tag("en")
                            Text("Deutsch").tag("de")
                            Text("العربية").tag("ar")
                            Text("Français").tag("fr")
                        }
                        .foregroundColor(.white)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    
                    // Notification permission banner
                    if !notificationManager.isPermissionGranted {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "bell.badge.fill")
                                        .foregroundColor(.red)
                                    Text(tr("notification_permission_required"))
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                Text(tr("notification_permission_desc"))
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
                                    Text(tr("open_settings"))
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
                    Section(header: Text(tr("prayer_notifications")).foregroundColor(.gray)) {
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
                                    Text(prayer.localizedName(for: languageManager.effectiveLanguageCode))
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    
                    // Reminder offsets list (max 3)
                    Section(
                        header: Text(tr("reminder_times")).foregroundColor(.gray),
                        footer: Text(tr("reminder_times_footer")).foregroundColor(.gray)
                    ) {
                        ForEach(reminderOffsets, id: \.self) { offset in
                            HStack {
                                Text(offset == 0 ? tr("exact_time") : tr("mins_before", offset))
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
                                    Text(tr("add_reminder"))
                                        .font(.system(.body, design: .rounded))
                                }
                                .foregroundColor(.amberColor)
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    
                    // Calculation Parameters Section
                    Section(
                        header: Text(tr("calculation_settings")).foregroundColor(.gray),
                        footer: Text(tr("calculation_method_desc")).foregroundColor(.gray)
                    ) {
                        Picker(tr("calculation_method"), selection: Binding(
                            get: { selectedMethod },
                            set: { newValue in
                                selectedMethod = newValue
                                appViewModel.setCalculationMethod(newValue)
                                selectedMadhab = appViewModel.getAsrMadhab()
                            }
                        )) {
                            ForEach(CalculationMethodRegistry.methods) { method in
                                Text("\(method.name) (\(method.region))").tag(method.id)
                            }
                        }
                        .foregroundColor(.white)
                        
                        Picker(tr("asr_madhab"), selection: Binding(
                            get: { selectedMadhab },
                            set: { newValue in
                                selectedMadhab = newValue
                                appViewModel.setAsrMadhab(newValue)
                            }
                        )) {
                            Text(tr("madhab_standard")).tag(0)
                            Text(tr("madhab_hanafi")).tag(1)
                        }
                        .foregroundColor(.white)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    
                    // About Section
                    Section(header: Text(tr("about")).foregroundColor(.gray)) {
                        Text(tr("about_desc"))
                            .font(.system(.footnote, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(tr("settings"))
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
            .sheet(isPresented: $showingAddReminderSheet) {
                NavigationView {
                    ZStack {
                        Color.black.opacity(0.92).ignoresSafeArea()
                        VStack(spacing: 24) {
                            Text(tr("new_reminder_duration"))
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.top)
                            
                            Picker(tr("notification_timing"), selection: $selectedOffsetToAdd) {
                                Text(tr("exact_time")).tag(0)
                                ForEach(offsetOptions, id: \.self) { min in
                                    Text(tr("mins_before", min)).tag(min)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(height: 150)
                            
                            Button(action: {
                                addOffset(selectedOffsetToAdd)
                                showingAddReminderSheet = false
                            }) {
                                Text(tr("add"))
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
                                Button(tr("cancel")) { showingAddReminderSheet = false }
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .presentationDetents([.height(320)])
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
        selectedMadhab = appViewModel.getAsrMadhab()
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
