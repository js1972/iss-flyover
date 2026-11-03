import Foundation

/// Forecasts can contain thousands of trajectory samples. Decode and atomic writes
/// run away from the main actor, so WatchConnectivity cannot interrupt a gesture.
actor WatchForecastStore {
    func load() -> (WatchPackage?, [WatchAction]) {
        (WatchCache.package, WatchCache.load([WatchAction].self, name: "actions.json") ?? [])
    }
    func decode(_ data: Data) throws -> WatchPackage {
        try SkyJSON.decoder().decode(WatchPackage.self, from: data)
    }
    func save(_ package: WatchPackage) throws {
        try WatchCache.save(package, name: "forecast.json")
    }
    #if DEBUG
    func saveStress(_ package: WatchPackage) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("watch-stress-forecast.json")
        try SkyJSON.encoder().encode(package).write(to: url, options: .atomic)
    }
    func stressData(_ base: WatchPackage, revision: Int) throws -> Data {
        var update = base
        update.revision = Int64(revision)
        update.sentAt = Date()
        if let original = update.snapshots.first?.events.first(where: { $0.kind == "iss" }) {
            // A deliberately dense payload exercises decode, ranking and path drawing.
            let dense = (0...600).map { index in
                SkyPoint(timestamp: original.start.addingTimeInterval(Double(index) / 2),
                         azimuth: (315 + Double(index) * 0.3).truncatingRemainder(dividingBy: 360),
                         elevation: 12 + sin(Double(index) / 600 * .pi) * 36, sunlit: true)
            }
            for index in 0..<40 {
                var event = original
                event.id = "stress-\(index)"
                event.score = 1
                event.points = dense
                update.snapshots[0].events.append(event)
            }
        }
        return try SkyJSON.encoder().encode(update)
    }
    #endif
}
