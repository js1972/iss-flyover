import Foundation

// Stable production identity. App and widget are signed by the same paid team.
enum SkyStore {
    static let groupID = "group.com.js1972.skytonight"
    static var root: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SkyTonight")
    }
    private static var defaults: UserDefaults { UserDefaults(suiteName: groupID) ?? .standard }
    static var locations: [ObservingLocation] {
        get { guard let data = defaults.data(forKey: "locations.v1"), let items = try? SkyJSON.decoder().decode([ObservingLocation].self, from: data) else { return [.perth] }; return items.filter(\.isValid) }
        set { defaults.set(try? SkyJSON.encoder().encode(newValue), forKey: "locations.v1") }
    }
    static var selectedID: String {
        get { defaults.string(forKey: "selectedLocation") ?? "perth" }
        set { defaults.set(newValue, forKey: "selectedLocation") }
    }
    static var selected: ObservingLocation { locations.first { $0.id == selectedID } ?? locations.first ?? .perth }
    static var eveningFirst: Bool {
        get { defaults.object(forKey: "eveningFirst") == nil ? true : defaults.bool(forKey: "eveningFirst") }
        set { defaults.set(newValue, forKey: "eveningFirst") }
    }
    static var weatherEnabled: Bool {
        get { defaults.bool(forKey: "appleWeatherEnabled.v1") }
        set { defaults.set(newValue, forKey: "appleWeatherEnabled.v1") }
    }
    static var dataRevision: Int {
        get { defaults.integer(forKey: "dataRevision") }
        set { defaults.set(newValue, forKey: "dataRevision") }
    }
    static func clearCachedData() {
        let files = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.lastPathComponent.hasPrefix("forecast-") || url.lastPathComponent == "orbit.json" {
            NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: nil) { try? FileManager.default.removeItem(at: $0) }
        }
    }
    static func snapshotURL(_ location: ObservingLocation) -> URL {
        // IDs never become path components directly; coordinates/time zone also invalidate old forecasts.
        let key = Data("\(location.id)|\(location.latitude)|\(location.longitude)|\(location.timeZoneID)".utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
        return root.appendingPathComponent("forecast-\(key).json")
    }
    static func read(_ location: ObservingLocation) -> SkySnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL(location)), var snapshot = try? SkyJSON.decoder().decode(SkySnapshot.self, from: data), snapshot.schema == 1, snapshot.location == location else { return nil }
        if !weatherEnabled || snapshot.weather?.credit == nil { snapshot.weather = nil }
        return snapshot
    }
    static func removeForecast(_ location: ObservingLocation) {
        let url = snapshotURL(location)
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: nil) { try? FileManager.default.removeItem(at: $0) }
    }
    static func write(_ snapshot: SkySnapshot) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = snapshotURL(snapshot.location)
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { coordinatedURL in
            do {
                // A slower app/widget refresh must never replace a newer calculation.
                if let data = try? Data(contentsOf: coordinatedURL),
                   let existing = try? SkyJSON.decoder().decode(SkySnapshot.self, from: data),
                   existing.generatedAt > snapshot.generatedAt { return }
                try SkyJSON.encoder().encode(snapshot).write(to: coordinatedURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            } catch { writeError = error }
        }
        if let error = coordinationError ?? writeError as NSError? { throw error }
    }
    static var orbit: OrbitData? {
        get { guard let data = try? Data(contentsOf: root.appendingPathComponent("orbit.json")) else { return nil }; return try? SkyJSON.decoder().decode(OrbitData.self, from: data) }
        set { guard let newValue else { return }; try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true); try? SkyJSON.encoder().encode(newValue).write(to: root.appendingPathComponent("orbit.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
    }
}
