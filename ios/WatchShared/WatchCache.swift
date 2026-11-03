import Foundation

enum WatchCache {
    static let groupID = "group.com.js1972.skytonight.watch"
    static var root: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SkyWatch")
    }
    static var defaults: UserDefaults { UserDefaults(suiteName: groupID) ?? .standard }
    static var selectedID: String {
        get { defaults.string(forKey: "selectedPlace") ?? "" }
        set { defaults.set(newValue, forKey: "selectedPlace") }
    }
    static func load<T: Decodable>(_ type: T.Type, name: String) -> T? {
        guard let data = try? Data(contentsOf: root.appendingPathComponent(name)) else { return nil }
        return try? SkyJSON.decoder().decode(type, from: data)
    }
    static func save<T: Encodable>(_ value: T, name: String) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try SkyJSON.encoder().encode(value).write(to: root.appendingPathComponent(name), options: .atomic)
    }
    static var package: WatchPackage? { load(WatchPackage.self, name: "forecast.json") }
}
