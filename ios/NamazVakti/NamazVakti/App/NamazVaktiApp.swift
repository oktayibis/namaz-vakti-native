import SwiftUI
import BackgroundTasks
import WidgetKit

@main
struct NamazVaktiApp: App {
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var viewModel = AppViewModel.shared

    static let refreshTaskId = "com.oktay.NamazVakti.refresh"

    init() {
        // Customize appearance for dark UI
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).overrideUserInterfaceStyle = .dark

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
            print("Failed to submit background refresh: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Refresh data when app returns to foreground
                    viewModel.updateTimes()
                    if let active = viewModel.activeLocation {
                        NotificationManager.shared.scheduleAllNotifications(for: active)
                    }
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        viewModel.updateTimes()
                        if let active = viewModel.activeLocation {
                            NotificationManager.shared.scheduleAllNotifications(for: active)
                        }
                    } else if newPhase == .background {
                        Self.scheduleAppRefresh()
                    }
                }
        }
    }
}
