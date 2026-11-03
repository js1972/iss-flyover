import Foundation

enum WatchWire {
    static func compress(_ data: Data) throws -> Data { try (data as NSData).compressed(using: .zlib) as Data }
    static func expand(_ data: Data) throws -> Data { try (data as NSData).decompressed(using: .zlib) as Data }
    static let contextBudget = 48 * 1024 // Leave space for the property-list envelope.
}

/// Versioned wire format. App Groups share files on one device; WCSession moves them between devices.
struct WatchPackage: Codable, Sendable {
    var schema = 1
    var revision: Int64
    var sentAt: Date
    var locations: [ObservingLocation]
    var selectedID: String
    var eveningFirst: Bool
    var weatherEnabled: Bool
    var snapshots: [SkySnapshot]
    var reminders: Set<String>
    var results: [WatchActionResult]

    func snapshot(for id: String, at now: Date) -> SkySnapshot? {
        guard let location = locations.first(where: { $0.id == id }),
              let snapshot = snapshots.first(where: { $0.location == location }),
              snapshot.schema == 2, snapshot.validUntil > now else { return nil }
        return snapshot
    }
    func accepts(after current: Self?) -> Bool {
        schema == 1 && revision > (current?.revision ?? -1) &&
        !locations.isEmpty && locations.allSatisfy(\.isValid) &&
        Set(locations.map(\.id)).count == locations.count && locations.contains { $0.id == selectedID }
    }
}

struct WatchAction: Codable, Identifiable, Sendable {
    var id = UUID().uuidString
    var createdAt = Date()
    var location: ObservingLocation
    var locationID: String { location.id }
    var eventID: String
    var enabled: Bool
    var reminderID: String { "\(locationID):\(eventID)" }
}
struct WatchActionResult: Codable, Sendable {
    var id: String
    var message: String
    var succeeded: Bool
}

enum WatchObservation {
    static func moonSymbol(_ phase: Double) -> String {
        let names = ["moonphase.new.moon", "moonphase.waxing.crescent", "moonphase.first.quarter", "moonphase.waxing.gibbous", "moonphase.full.moon", "moonphase.waning.gibbous", "moonphase.last.quarter", "moonphase.waning.crescent"]
        guard phase.isFinite else { return names[0] }
        return names[((Int((phase * 8).rounded()) % 8) + 8) % 8]
    }
    /// Interpolate only within a sampled interval, including the shortest route across north.
    /// Never extrapolate an ISS position or bridge gaps in a sampled path.
    static func point(in event: SkyEvent, at date: Date) -> SkyPoint? {
        let points = event.points
        guard let first = points.first, let last = points.last,
              date >= first.timestamp, date <= last.timestamp else { return nil }
        if date == last.timestamp { return last }
        guard let index = points.firstIndex(where: { $0.timestamp >= date }) else { return nil }
        if points[index].timestamp == date { return points[index] }
        guard index > 0 else { return first }
        let a = points[index - 1], b = points[index]
        let span = b.timestamp.timeIntervalSince(a.timestamp)
        guard span > 0, span <= (event.kind == "iss" ? 60 : 1200) else { return nil }
        let fraction = date.timeIntervalSince(a.timestamp) / span
        let delta = (b.azimuth - a.azimuth + 540).truncatingRemainder(dividingBy: 360) - 180
        return SkyPoint(timestamp: date,
                        azimuth: (a.azimuth + delta * fraction + 360).truncatingRemainder(dividingBy: 360),
                        elevation: a.elevation + (b.elevation - a.elevation) * fraction,
                        sunlit: a.sunlit && b.sunlit)
    }
    static func event(_ event: SkyEvent, usableIn snapshot: SkySnapshot, at now: Date) -> Bool {
        snapshot.validUntil > now && (event.kind != "iss" ||
            (snapshot.orbit?.usable(at: now) == true && snapshot.orbit?.usable(at: event.end) == true))
    }
    static func reminderEvent(for action: WatchAction, in snapshot: SkySnapshot, now: Date) -> SkyEvent? {
        guard abs(action.createdAt.timeIntervalSince(now)) < 86400,
              action.location == snapshot.location, snapshot.validUntil > now,
              let event = snapshot.events.first(where: { $0.id == action.eventID }),
              event.start > now.addingTimeInterval(60),
              event.kind != "iss" || snapshot.orbit?.fresh(at: now) == true else { return nil }
        return event
    }
    static func countdown(to date: Date, now: Date) -> String {
        let seconds = max(0, Int(ceil(date.timeIntervalSince(now))))
        if seconds >= 86400 { return "\(seconds / 86400)d \((seconds % 86400) / 3600)h" }
        if seconds >= 3600 { return "\(seconds / 3600)h \((seconds % 3600) / 60)m" }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    static func timelineDates(snapshot: SkySnapshot?, now: Date) -> [Date] {
        guard let snapshot, snapshot.validUntil > now else { return [now] }
        let horizon = min(snapshot.validUntil, now.addingTimeInterval(86400))
        var dates = [now, horizon, snapshot.validUntil]
        for event in snapshot.events {
            dates += [event.start, event.end].filter { $0 > now && $0 <= horizon }
        }
        dates += snapshot.nights.flatMap { [$0.start, $0.end] }.filter { $0 > now && $0 <= horizon }
        if let orbit = snapshot.orbit {
            let expiry = orbit.epoch.addingTimeInterval(7 * 86400)
            if expiry > now { dates.append(expiry) }
        }
        return Array(Set(dates)).sorted()
    }
    static let activityType = "com.js1972.skytonight.observing"
}
