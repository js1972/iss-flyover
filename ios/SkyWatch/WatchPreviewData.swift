#if DEBUG
import Foundation

enum WatchPreviewData {
    static func package() -> WatchPackage? {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--empty-watch") { return nil }
        let now = Date()
        let night = ObservingNight(id: "demo", start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(86400), moonPercent: 42, moonPhase: 0.22, polar: false)
        let saturn = SkyEvent(id: "demo-saturn", kind: "planet", title: "Saturn", start: now.addingTimeInterval(900), end: now.addingTimeInterval(3300), focus: now.addingTimeInterval(1200), azimuth: 45, elevation: 42, score: 200, detail: "A steady golden point. Rings require a telescope.", body: "Saturn", points: [], nightID: "demo", isMorning: false)
        let start = now.addingTimeInterval(args.contains("--active-pass") ? -120 : 134)
        let points = (0...30).map { index in
            SkyPoint(timestamp: start.addingTimeInterval(Double(index) * 10), azimuth: (315 + Double(index) * 6).truncatingRemainder(dividingBy: 360), elevation: 12 + sin(Double(index) / 30 * .pi) * 40, sunlit: true)
        }
        let iss = SkyEvent(id: "demo-iss", kind: "iss", title: "ISS", start: start, end: start.addingTimeInterval(300), focus: start.addingTimeInterval(150), azimuth: 45, elevation: 52, score: 150, detail: "Sunlit pass while your sky is dark.", body: "ISS", points: points, nightID: "demo", isMorning: false)
        var snapshot = SkySnapshot(location: .perth, generatedAt: now, eveningFirst: true, nights: [night], events: [saturn, iss], orbit: OrbitData(epoch: now, fetchedAt: now, source: "Sample"))
        if args.contains("--expired-watch") { snapshot.nights[0].end = now.addingTimeInterval(-60) }
        if args.contains("--no-iss") { snapshot.events = [saturn] }
        if args.contains("--no-orbit") { snapshot.orbit = nil }
        return WatchPackage(revision: 1, sentAt: now, locations: [.perth], selectedID: "perth", eveningFirst: true, weatherEnabled: false, snapshots: [snapshot], reminders: [], results: [])
    }
}
#endif
