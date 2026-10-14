import Foundation
import UserNotifications

enum SkyReminders {
    static func request(event: SkyEvent, location: ObservingLocation, now: Date = Date()) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Look up: \(event.title)"
        content.body = "\(location.name) · \(location.time(event.start)) · \(event.detail)"
        content.sound = .default
        content.userInfo = ["url": event.link(location: location).absoluteString, "location": location.id, "event": event.id, "kind": event.kind, "focus": event.focus.timeIntervalSince1970]
        let interval = max(5, event.start.addingTimeInterval(-600).timeIntervalSince(now))
        return UNNotificationRequest(identifier: "\(location.id):\(event.id)", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false))
    }
    static func reconcile(_ snapshot: SkySnapshot, now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        for request in await center.pendingNotificationRequests() {
            let info = request.content.userInfo
            guard info["location"] as? String == snapshot.location.id else { continue }
            let kind = info["kind"] as? String
            let oldFocus = (info["focus"] as? Double).map(Date.init(timeIntervalSince1970:))
            let event = snapshot.events.first { $0.id == info["event"] as? String } ?? snapshot.events.first {
                kind == "iss" && $0.kind == "iss" && abs($0.focus.timeIntervalSince(oldFocus ?? .distantPast)) < 600
            }
            // Do not trust a vanished pass when fresh orbital elements are unavailable.
            if kind == "iss" && snapshot.orbit?.fresh(at: now) != true { center.removePendingNotificationRequests(withIdentifiers: [request.identifier]); continue }
            center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
            if let event, event.start > now.addingTimeInterval(60) { try? await center.add(Self.request(event: event, location: snapshot.location, now: now)) }
        }
    }
}
