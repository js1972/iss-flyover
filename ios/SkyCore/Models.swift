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
struct LunarSample: Codable, Sendable, Equatable {
    var timestamp: Date
    var azimuth: Double
    var elevation: Double
}
struct LunarDetails: Codable, Sendable, Equatable {
    var fullMoonAt: Date
    var moonrise: Date?
    var moonset: Date?
    var isPrimary: Bool
    var midnight: Date
    var samples: [LunarSample]
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
    var lunar: LunarDetails?
    var symbol: String {
        switch kind { case "iss": "point.topleft.down.to.point.bottomright.curvepath"; case "moon": "moonphase.full.moon"; case "planet": "sparkle"; case "meteor": "sparkles"; case "deepSky": "binoculars.fill"; default: "star.fill" }
    }
    func lunarTiming(location: ObservingLocation) -> String? {
        guard let lunar else { return nil }
        let phase = "Full phase \(location.day(lunar.fullMoonAt)), \(location.time(lunar.fullMoonAt))"
        let rise = lunar.moonrise.map { " · Moonrise \(location.time($0))" } ?? ""
        return "View \(location.time(start))–\(location.time(end))\(rise)\n\(phase)"
    }
    // A full-Moon window lasts hours. Advance cached recommendations to a future
    // calculated position instead of advertising a viewing time that has passed.
    func forDisplay(at now: Date) -> Self {
        guard let lunar, focus < now, end > now,
              let sample = lunar.samples.first(where: { $0.timestamp >= now }) else { return self }
        var event = self
        event.focus = sample.timestamp; event.azimuth = sample.azimuth; event.elevation = sample.elevation
        event.isMorning = sample.timestamp >= lunar.midnight
        return event
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
    var schema = 2
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
    func ranked(at now: Date, issOnly: Bool = false, nightID: String? = nil) -> [SkyEvent] {
        let selectedNight = nightID ?? night(at: now)?.id
        return events.filter { $0.end > now && (issOnly ? $0.kind == "iss" && (nightID == nil || $0.nightID == nightID) : $0.nightID == selectedNight) && ($0.kind != "iss" || orbit?.usable(at: now) == true) }
            .map { $0.forDisplay(at: now) }
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
