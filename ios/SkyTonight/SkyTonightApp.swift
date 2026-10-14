import SwiftUI
import UserNotifications
import BackgroundTasks
import WidgetKit

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.js1972.skytonight.refresh", using: nil) { task in
            let work = Task {
                defer { Self.schedule() }
                do {
                    let snapshot = try await SkyRepository.shared.refresh(location: SkyStore.selected, eveningFirst: SkyStore.eveningFirst)
                    await SkyReminders.reconcile(snapshot)
                    _ = await SkyRepository.shared.refreshWeather(location: SkyStore.selected)
                    WidgetCenter.shared.reloadAllTimelines(); task.setTaskCompleted(success: !Task.isCancelled)
                } catch { task.setTaskCompleted(success: false) }
            }
            task.expirationHandler = { work.cancel() }
        }
        return true
    }
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: "com.js1972.skytonight.refresh")
        request.earliestBeginDate = Date().addingTimeInterval(3600)
        try? BGTaskScheduler.shared.submit(request)
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let raw = response.notification.request.content.userInfo["url"] as? String, let url = URL(string: raw) {
            await MainActor.run { NotificationCenter.default.post(name: .skyLink, object: url) }
        }
    }
}
extension Notification.Name { static let skyLink = Notification.Name("skyLink") }
@main
struct SkyTonightApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model).preferredColorScheme(.dark)
                .task { await model.refresh() }
                .onOpenURL { url in Task { await model.open(url) } }
                .onReceive(NotificationCenter.default.publisher(for: .skyLink)) { notification in
                    if let url = notification.object as? URL { Task { await model.open(url) } }
                }
                .onChange(of: phase) { _, value in
                    if value == .active { model.onResume() }
                    else if value == .background { AppDelegate.schedule() }
                }
        }
    }
}
