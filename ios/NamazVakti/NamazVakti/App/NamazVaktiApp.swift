import SwiftUI
import BackgroundTasks
import WidgetKit
import FirebaseCore

@main
struct NamazVaktiApp: App {
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var viewModel = AppViewModel.shared
    @StateObject private var languageManager = LanguageManager.shared

    static let refreshTaskId = "com.okib.NamazVakti.refresh"

    init() {
        // Initialize Firebase Analytics and Crashlytics
        FirebaseApp.configure()

        // Customize appearance for dark UI
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).overrideUserInterfaceStyle = .dark

        // Instantiates the singleton, which registers the UNUserNotificationCenter
        // delegate so alerts are not suppressed while the app is foregrounded.
        NotificationManager.shared.activate()

        // Notifications are only scheduled a few days ahead (64-request limit), so a
        // periodic background refresh keeps the window rolling even if the user
        // doesn't open the app for a while.
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskId, using: nil) { task in
            Self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    static func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh()

        if let active = AppViewModel.shared.activeLocation {
            NotificationManager.shared.scheduleAllNotifications(for: active)
            WidgetCenter.shared.reloadAllTimelines()
        }
        task.setTaskCompleted(success: true)
    }

    static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            #if DEBUG
            print("Failed to submit background refresh: \(error)")
            #endif
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.locale, languageManager.currentLocale)
                .environment(\.layoutDirection, languageManager.layoutDirection)
                .preferredColorScheme(.dark)
                .id(languageManager.currentLanguage)
                // scenePhase is the single activation trigger. This previously also
                // listened for willEnterForegroundNotification, so every activation ran
                // the whole teardown-and-rebuild twice, and the second removeAll could
                // wipe requests the first pass had not finished adding.
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        viewModel.updateTimes()
                        rescheduleNotifications()
                    } else if newPhase == .background {
                        Self.scheduleAppRefresh()
                    }
                }
        }
    }

    /// Scheduling walks several days of solar math and issues up to 60 requests, so keep
    /// it off the main thread — it used to run synchronously on every activation.
    private func rescheduleNotifications() {
        guard let active = viewModel.activeLocation else { return }
        DispatchQueue.global(qos: .utility).async {
            NotificationManager.shared.scheduleAllNotifications(for: active)
        }
    }
}
