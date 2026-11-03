import SwiftUI
import WatchConnectivity
import WidgetKit
import WatchKit
import UserNotifications

@MainActor
final class WatchModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var loading = false
    @Published var package: WatchPackage?
    @Published var selectedID = WatchCache.selectedID
    @Published var pending: [WatchAction] = []
    @Published var message: String?
    @Published var page = 0
    @Published var route: [String] = []
    @Published var reachable = false
    @Published var handoff = false
    private let forecastStore = WatchForecastStore()
    private var receiveTask: Task<Void, Never>?
    private var processingUpdates = 0
    private var requestedAt = Date.distantPast
    private var pendingURL: URL?
    private var backgroundTasks: [WKWatchConnectivityRefreshBackgroundTask] = []
    private var contentObservation: NSKeyValueObservation?
    var isPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--watch-preview")
        #else
        false
        #endif
    }
    override init() {
        super.init()
        WatchRuntime.model = self
        #if DEBUG
        if isPreview {
            package = WatchPreviewData.package()
            selectedID = "perth"
            if ProcessInfo.processInfo.arguments.contains("--iss-page") { page = 1 }
            if ProcessInfo.processInfo.arguments.contains("--active-pass") { page = 1; route = ["demo-iss"] }
        }
        #endif
        if isPreview {
            normalizeSelection()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--stress-sync"), let base = package {
                Task { [weak self] in
                    for revision in 2...90 {
                        guard let self else { return }
                        do {
                            let data = try await forecastStore.stressData(base, revision: revision)
                            receive(data)
                            try await Task.sleep(for: .seconds(2))
                        } catch { return }
                    }
                }
            }
            #endif
            return
        }
        loading = true
        receiveTask = Task { [weak self] in
            guard let self else { return }
            let (cached, actions) = await forecastStore.load()
            package = cached
            pending = actions.filter { action in cached?.results.contains { $0.id == action.id } != true }
            loading = false
            normalizeSelection()
            sendPending()
            if let url = pendingURL { pendingURL = nil; open(url) }
        }
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            contentObservation = WCSession.default.observe(\.hasContentPending, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.completeBackgroundTasks() }
            }
            WCSession.default.activate()
        }
    }
    func displayDate(_ date: Date) -> Date {
        #if DEBUG
        if isPreview && ProcessInfo.processInfo.arguments.contains("--design-capture") { return WatchPreviewData.referenceDate }
        #endif
        return date
    }
    var location: ObservingLocation? { package?.locations.first { $0.id == selectedID } }
    func snapshot(at date: Date = Date()) -> SkySnapshot? { package?.snapshot(for: selectedID, at: date) }
    func normalizeSelection() {
        if package?.locations.contains(where: { $0.id == selectedID }) != true { selectedID = package?.selectedID ?? "" }
        if !isPreview { WatchCache.selectedID = selectedID }
    }
    func select(_ id: String) {
        guard package?.locations.contains(where: { $0.id == id }) == true else { return }
        selectedID = id; route = []; handoff = false
        if !isPreview { WatchCache.selectedID = id; WidgetCenter.shared.reloadAllTimelines() }
        requestRefresh(force: true)
    }
    func receive(_ data: Data) {
        processingUpdates += 1
        let previous = receiveTask
        receiveTask = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            await apply(data)
            processingUpdates -= 1
            completeBackgroundTasks()
        }
    }
    private func apply(_ data: Data) async {
        do {
            let incoming = try await forecastStore.decode(data)
            guard incoming.schema == 1 else { message = "Update Sky Tonight on both devices to sync."; return }
            guard incoming.accepts(after: package) else { return }
            #if DEBUG
            if isPreview { try await forecastStore.saveStress(incoming) }
            else { try await forecastStore.save(incoming) }
            #else
            try await forecastStore.save(incoming)
            #endif
            if incoming.selectedID != package?.selectedID { selectedID = incoming.selectedID; route = [] }
            let receipts = incoming.results.filter { result in pending.contains { $0.id == result.id } }
            pending.removeAll { action in incoming.results.contains { $0.id == action.id } }
            if !isPreview { try WatchCache.save(pending, name: "actions.json") }
            package = incoming
            if let receipt = receipts.last { message = receipt.message }
            normalizeSelection()
            if !isPreview { WidgetCenter.shared.reloadAllTimelines() }
            if let url = pendingURL { pendingURL = nil; open(url) }
        } catch { message = "The update could not be read. Your saved forecast is still available." }
    }
    func requestRefresh(force: Bool = false) {
        guard !isPreview, WCSession.default.activationState == .activated,
              force || Date().timeIntervalSince(requestedAt) > 1800 else { return }
        requestedAt = Date()
        let session = WCSession.default
        reachable = session.isReachable
        let request: [String: Any] = ["refresh": true, "location": selectedID]
        if session.isReachable {
            session.sendMessage(request, replyHandler: nil) { _ in
                session.transferUserInfo(request)
            }
        } else if !session.outstandingUserInfoTransfers.contains(where: { $0.userInfo["refresh"] as? Bool == true }) {
            session.transferUserInfo(request)
        }
        if force { message = reachable ? "Refresh requested from iPhone." : "Refresh queued. Open Sky Tonight on your paired iPhone when nearby." }
    }
    func resume() {
        guard !isPreview else { return }
        sendPending(); requestRefresh()
    }
    func queueReminder(_ event: SkyEvent) {
        guard let location, event.start > Date().addingTimeInterval(60),
              !pending.contains(where: { $0.reminderID == "\(location.id):\(event.id)" }) else { return }
        guard !isPreview else { message = "Reminders are disabled for sample events."; return }
        let action = WatchAction(location: location, eventID: event.id,
                                 enabled: package?.reminders.contains("\(location.id):\(event.id)") != true)
        do {
            var next = pending; next.append(action)
            try WatchCache.save(next, name: "actions.json")
            pending = next
            sendPending()
            message = "Request queued. It is confirmed only when your iPhone saves the change."
        } catch { message = "Could not save the request. Please try again." }
    }
    private func sendPending() {
        guard WCSession.default.activationState == .activated else { return }
        let session = WCSession.default
        let queued = Set(session.outstandingUserInfoTransfers.compactMap { $0.userInfo["actionID"] as? String })
        for action in pending {
            if let data = try? SkyJSON.encoder().encode(action) {
                let info: [String: Any] = ["action": data, "actionID": action.id]
                if !queued.contains(action.id) { session.transferUserInfo(info) }
                // A desired state has a stable ID; duplicate foreground/background delivery is safe.
                if session.isReachable { session.sendMessage(info, replyHandler: nil, errorHandler: { _ in }) }
            }
        }
    }
    func open(_ url: URL) {
        guard url.scheme == "skytonight", let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        guard let package else { pendingURL = url; requestRefresh(force: true); return }
        let query = components.queryItems ?? []
        if let id = query.first(where: { $0.name == "location" })?.value {
            guard package.locations.contains(where: { $0.id == id }) else { message = "That observing place is no longer saved."; return }
            selectedID = id; normalizeSelection()
        }
        route = []; handoff = false
        if url.host == "moon" { route = ["moon"]; return }
        if url.host == "iss" { page = 1; return }
        guard let id = query.first(where: { $0.name == "id" })?.value else { page = 0; return }
        guard let event = snapshot()?.events.first(where: { $0.id == id }), event.end > Date() else {
            message = "This event has ended or needs a refreshed forecast."; return
        }
        page = event.kind == "iss" ? 1 : 0; route = [id]
    }
    func retain(_ task: WKWatchConnectivityRefreshBackgroundTask) {
        backgroundTasks.append(task); completeBackgroundTasks()
    }
    private func completeBackgroundTasks() {
        guard processingUpdates == 0, WCSession.default.activationState == .activated, !WCSession.default.hasContentPending else { return }
        backgroundTasks.forEach { $0.setTaskCompletedWithSnapshot(false) }; backgroundTasks = []
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.reachable = session.isReachable
            self.sendPending(); self.requestRefresh(); self.completeBackgroundTasks()
        }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.reachable = session.isReachable; self.sendPending(); self.requestRefresh() }
    }
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // WCSession deletes this temporary URL when the delegate returns.
        let data = try? Data(contentsOf: file.fileURL)
        Task { @MainActor in if let data { self.receive(data) }; self.completeBackgroundTasks() }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let data = (applicationContext["compressed"] as? Data).flatMap { try? WatchWire.expand($0) }
        Task { @MainActor in if let data { self.receive(data) }; self.completeBackgroundTasks() }
    }
}

final class WatchDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching() { UNUserNotificationCenter.current().delegate = self }
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let connectivity = task as? WKWatchConnectivityRefreshBackgroundTask {
                Task { @MainActor in WatchRuntime.model?.retain(connectivity) }
            } else { task.setTaskCompletedWithSnapshot(false) }
        }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let raw = response.notification.request.content.userInfo["url"] as? String, let url = URL(string: raw) {
            await MainActor.run { WatchRuntime.model?.open(url) }
        }
    }
}
@MainActor enum WatchRuntime { static weak var model: WatchModel? }
