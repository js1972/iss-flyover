import Foundation

struct ObservingLocation: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var latitude: Double
    var longitude: Double
    var timeZoneID: String
    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .gmt }
    var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = timeZone; return c }
    var isValid: Bool { latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude) && TimeZone(identifier: timeZoneID) != nil }
    static let perth = Self(id: "perth", name: "Perth", latitude: -31.9523, longitude: 115.8613, timeZoneID: "Australia/Perth")
    func time(_ date: Date) -> String {
        let f = DateFormatter(); f.timeZone = timeZone; f.dateFormat = "HH:mm"; return f.string(from: date)
    }
    func day(_ date: Date) -> String {
        let f = DateFormatter(); f.timeZone = timeZone; f.dateFormat = "EEE d MMM"; return f.string(from: date)
    }
}
struct SkyPoint: Codable, Sendable, Equatable {
    var timestamp: Date
    var azimuth: Double
    var elevation: Double
    var sunlit: Bool
}
struct SkyEvent: Codable, Identifiable, Sendable, Equatable {
    var id: String
    var kind: String
    var title: String
    var start: Date
    var end: Date
    var focus: Date
    var azimuth: Double
    var elevation: Double
    var score: Double
    var detail: String
    var body: String
    var points: [SkyPoint]
    var nightID: String
    var isMorning: Bool
    var ra: Double?
    var dec: Double?
    var symbol: String {
        switch kind { case "iss": "point.topleft.down.to.point.bottomright.curvepath"; case "planet": "sparkle"; case "meteor": "sparkles"; case "deepSky": "binoculars.fill"; default: "star.fill" }
    }
    var direction: String { Self.direction(azimuth) }
    static func direction(_ angle: Double) -> String {
        guard angle.isFinite else { return "—" }
        let names = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        return names[((Int((angle / 22.5).rounded()) % 16) + 16) % 16]
    }
    func link(location: ObservingLocation) -> URL {
        var c = URLComponents(); c.scheme = "skytonight"; c.host = "event"
        c.queryItems = [URLQueryItem(name: "id", value: id), URLQueryItem(name: "location", value: location.id), URLQueryItem(name: "time", value: String(focus.timeIntervalSince1970))]
        return c.url!
    }
}
struct ObservingNight: Codable, Identifiable, Sendable, Equatable {
    var id: String
    var start: Date
    var end: Date
    var sunset: Date?
    var sunrise: Date?
    var dark: Date?
    var dawn: Date?
    var moonPercent: Int
    var moonPhase: Double
    var polar: Bool
    var moonName: String {
        switch moonPhase { case ..<0.04: "New Moon"; case ..<0.22: "Waxing crescent"; case ..<0.28: "First quarter"; case ..<0.47: "Waxing gibbous"; case ..<0.53: "Full Moon"; case ..<0.72: "Waning gibbous"; case ..<0.78: "Last quarter"; case ..<0.96: "Waning crescent"; default: "New Moon" }
    }
}
struct OrbitData: Codable, Sendable {
    var omm: String?
    var line1: String?
    var line2: String?
    var epoch: Date
    var fetchedAt: Date
    var source: String
    func usable(at date: Date) -> Bool { abs(date.timeIntervalSince(epoch)) < 7 * 86400 }
    func fresh(at date: Date) -> Bool { usable(at: date) && date.timeIntervalSince(fetchedAt) < 6 * 3600 && abs(date.timeIntervalSince(epoch)) < 3 * 86400 }
}
struct WeatherHour: Codable, Sendable, Equatable {
    var time: Date
    var cloud: Double
    var precipitation: Double
    var wind: Double
}
struct WeatherForecast: Codable, Sendable {
    var hours: [WeatherHour]
    var fetchedAt: Date
    // Missing on pre-WeatherKit caches: never relabel those forecasts as Apple data.
    var credit: WeatherCredit?
    func sample(at date: Date, now: Date) -> WeatherHour? {
        guard now.timeIntervalSince(fetchedAt) < 6 * 3600,
              let sample = hours.min(by: { abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date)) }), abs(sample.time.timeIntervalSince(date)) <= 3600 else { return nil }
        return sample
    }
}
struct WeatherCredit: Codable, Sendable {
    var legalURL: URL
    var lightMark: Data
    var darkMark: Data
}
struct SkySnapshot: Codable, Sendable {
    var schema = 1
    var location: ObservingLocation
    var generatedAt: Date
    var eveningFirst: Bool
    var nights: [ObservingNight]
    var events: [SkyEvent]
    var orbit: OrbitData?
    var weather: WeatherForecast?
    var orbitMessage: String?
    var weatherMessage: String?
    func night(at now: Date) -> ObservingNight? { nights.first { $0.end > now } }
    func ranked(at now: Date, issOnly: Bool = false) -> [SkyEvent] {
        let nightID = night(at: now)?.id
        return events.filter { $0.end > now && (issOnly ? $0.kind == "iss" : $0.nightID == nightID) && ($0.kind != "iss" || orbit?.usable(at: now) == true) }
            .sorted { a,b in
                if issOnly { return a.start < b.start }
                if eveningFirst && a.isMorning != b.isMorning { return !a.isMorning }
                return a.score == b.score ? a.focus < b.focus : a.score > b.score
            }
    }
    var validUntil: Date { nights.last?.end ?? generatedAt }
}
struct ChartObject: Codable, Identifiable, Sendable {
    var id: String
    var name: String
    var kind: String
    var azimuth: Double
    var elevation: Double
}
enum SkyJSON {
    static func encoder() -> JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .secondsSince1970; return e }
    static func decoder() -> JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .secondsSince1970; return d }
}
