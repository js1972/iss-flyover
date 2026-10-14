import Foundation

// Shared with tests: every timeline includes an expiry state, even when the system defers a reload.
enum SkyTimeline {
    static func dates(snapshot: SkySnapshot?, now: Date) -> [Date] {
        guard let snapshot else { return [now, now.addingTimeInterval(3600)] }
        let horizon = min(snapshot.validUntil, now.addingTimeInterval(2 * 86400))
        var dates = [now]
        var cursor = now.addingTimeInterval(1800)
        while cursor < horizon { dates.append(cursor); cursor.addTimeInterval(1800) }
        dates.append(contentsOf: snapshot.nights.flatMap { [$0.start, $0.end] }.filter { $0 > now && $0 < horizon })
        dates.append(contentsOf: snapshot.events.flatMap { [$0.start, $0.end.addingTimeInterval(1)] }.filter { $0 > now && $0 < horizon })
        dates.append(max(now.addingTimeInterval(300), horizon))
        // The exact transition remains system-controlled; five-minute spacing avoids excessive entries.
        var result = [now]
        for date in Set(dates).sorted() where date.timeIntervalSince(result.last!) >= 300 { result.append(date) }
        if snapshot.validUntil > result.last! { result.append(snapshot.validUntil) }
        return result
    }
}
