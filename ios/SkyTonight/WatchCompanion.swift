import Foundation
import WatchConnectivity
import UserNotifications

/// The iPhone owns reminder scheduling. watchOS queues explicit desired states;
/// acknowledgement is sent only after the notification centre accepts the change.
@MainActor
final class WatchCompanion: NSObject, WCSessionDelegate {
    static let shared = WatchCompanion()
    private var publishTask: Task<Void, Never>?
    private var generation = 0
    private var actionTask: Task<Void, Never>?
    private var results: [WatchActionResult] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "watchActionResults") else { return [] }
            return (try? SkyJSON.decoder().decode([WatchActionResult].self, from: data)) ?? []
        }
        set { UserDefaults.standard.set(try? SkyJSON.encoder().encode(newValue), forKey: "watchActionResults") }
    }
    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
    func publish() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return }
        generation += 1
        let token = generation
        publishTask?.cancel()
        publishTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(350))
                let places = SkyStore.locations, pref = SkyStore.eveningFirst
                var snapshots: [SkySnapshot] = []
                for place in places {
                    try Task.checkCancellation()
                    if let saved = SkyStore.read(place), saved.validUntil > Date(), saved.eveningFirst == pref {
                        snapshots.append(try await SkyCalculator.shared.watchSnapshot(saved))
                    }
                }
                let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
                guard token == generation, !Task.isCancelled else { return }
                let defaults = UserDefaults.standard
                let revision = max(Int64(Date().timeIntervalSince1970 * 1000), Int64(defaults.double(forKey: "watchRevision")) + 1)
                let package = WatchPackage(revision: revision, sentAt: Date(), locations: places,
                    selectedID: SkyStore.selectedID, eveningFirst: pref, weatherEnabled: SkyStore.weatherEnabled,
                    snapshots: snapshots, reminders: Set(pending.map(\.identifier)), results: results)
                let data = try SkyJSON.encoder().encode(package)
                let compressed = try WatchWire.compress(data)
                let session = WCSession.default
                defaults.set(Double(revision), forKey: "watchRevision")
                for transfer in session.outstandingFileTransfers { transfer.cancel() }
                if compressed.count <= WatchWire.contextBudget {
                    // Latest-state delivery is quick, durable and supported by Simulator.
                    try session.updateApplicationContext(["revision": revision, "compressed": compressed])
                    return
                }
                let directory = SkyStore.root.appendingPathComponent("watch-transfers")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let url = directory.appendingPathComponent("\(revision).json")
                try data.write(to: url, options: .atomic)
                session.transferFile(url, metadata: ["revision": revision])
                // Large multi-place/weather snapshots use file delivery on physical devices.
                try session.updateApplicationContext(["revision": revision])
            } catch { /* Retain the previous delivered forecast; the next foreground refresh retries. */ }
        }
    }
    private func receive(_ info: [String: Any]) {
        if info["refresh"] as? Bool == true {
            Task {
                let loc = SkyStore.locations.first { $0.id == info["location"] as? String } ?? SkyStore.selected
                if let snapshot = try? await SkyRepository.shared.refresh(location: loc, eveningFirst: SkyStore.eveningFirst) {
                    await SkyReminders.reconcile(snapshot)
                }
                publish()
            }
        }
        guard let data = info["action"] as? Data,
              let action = try? SkyJSON.decoder().decode(WatchAction.self, from: data) else { return }
        // Serialize background deliveries so rapid set/cancel actions cannot race.
        let previous = actionTask
        actionTask = Task {
            await previous?.value
            if results.contains(where: { $0.id == action.id }) { publish(); return }
            let result = await apply(action)
            results = Array((results + [result]).suffix(256))
            NotificationCenter.default.post(name: .watchRemindersChanged, object: nil)
            publish()
        }
    }
    private func apply(_ action: WatchAction) async -> WatchActionResult {
        func result(_ text: String, _ success: Bool = false) -> WatchActionResult {
            WatchActionResult(id: action.id, message: text, succeeded: success)
        }
        guard abs(action.createdAt.timeIntervalSinceNow) < 86400,
              let place = SkyStore.locations.first(where: { $0 == action.location }) else {
            return result("The request expired or its observing place was removed.")
        }
        let center = UNUserNotificationCenter.current()
        if !action.enabled {
            center.removePendingNotificationRequests(withIdentifiers: [action.reminderID])
            return result("Reminder cancelled.", true)
        }
        guard let snapshot = SkyStore.read(place),
              let event = WatchObservation.reminderEvent(for: action, in: snapshot, now: Date()) else {
            return result("Refresh on iPhone: this event has changed, started, or needs fresh orbit data.")
        }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return result("On iPhone, open Sky Tonight → Settings → Apple Watch → Enable observing reminders, then try again.")
        }
        do {
            try await center.add(SkyReminders.request(event: event, location: place))
            return result("Reminder set on iPhone. Apple Watch delivery follows your notification settings.", true)
        } catch { return result("The reminder could not be saved. Try again on iPhone.") }
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.publish() }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) { Task { @MainActor in self.publish() } }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in self.receive(userInfo) }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.receive(message) }
    }
    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
    }
}
extension Notification.Name { static let watchRemindersChanged = Notification.Name("watchRemindersChanged") }
