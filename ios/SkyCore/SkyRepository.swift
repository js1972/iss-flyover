import Foundation

actor SkyRepository {
    static let shared = SkyRepository()
    private let session: URLSession
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 8
        session = URLSession(configuration: config)
    }
    private func fetch(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else { throw SkyError.message("The data service is temporarily unavailable.") }
        return data
    }
    static func epoch(_ value: String) -> Date? {
        let normalized = value.hasSuffix("Z") ? value : value + "Z"
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: normalized) ?? ISO8601DateFormatter().date(from: normalized)
    }
    private func orbit(now: Date) async throws -> OrbitData {
        if let cached = SkyStore.orbit, cached.fresh(at: now) { return cached }
        do {
            let data = try await fetch(URL(string: "https://celestrak.org/NORAD/elements/gp.php?CATNR=25544&FORMAT=JSON")!)
            guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], let row = rows.first,
                  let rawEpoch = row["EPOCH"] as? String, let epoch = Self.epoch(rawEpoch),
                  (row["NORAD_CAT_ID"] as? NSNumber)?.intValue == 25544,
                  let motion = row["MEAN_MOTION"] as? NSNumber, motion.doubleValue > 0 else { throw SkyError.message("Invalid orbital elements.") }
            let json = try JSONSerialization.data(withJSONObject: row)
            let orbit = OrbitData(omm: String(decoding: json, as: UTF8.self), epoch: epoch, fetchedAt: now, source: "CelesTrak")
            guard orbit.usable(at: now) else { throw SkyError.message("The orbital elements have expired.") }
            SkyStore.orbit = orbit
            return orbit
        } catch {
            let data = try await fetch(URL(string: "https://api.wheretheiss.at/v1/satellites/25544/tles")!)
            struct TLE: Decodable { var line1: String; var line2: String }
            let tle = try JSONDecoder().decode(TLE.self, from: data)
            guard tle.line1.count >= 69, tle.line2.count >= 69, tle.line1.hasPrefix("1 25544"), tle.line2.hasPrefix("2 25544") else { throw SkyError.message("Invalid backup orbital elements.") }
            let chars = Array(tle.line1)
            guard let year = Int(String(chars[18..<20])), let day = Double(String(chars[20..<32])) else { throw SkyError.message("Invalid orbit epoch.") }
            var c = Calendar(identifier: .gregorian); c.timeZone = .gmt
            guard let jan = c.date(from: DateComponents(year: year < 57 ? 2000 + year : 1900 + year, month: 1, day: 1)) else { throw SkyError.message("Invalid orbit date.") }
            let orbit = OrbitData(line1: tle.line1, line2: tle.line2, epoch: jan.addingTimeInterval((day - 1) * 86400), fetchedAt: now, source: "Where the ISS at")
            guard orbit.usable(at: now) else { throw SkyError.message("The backup orbital elements have expired.") }
            SkyStore.orbit = orbit
            return orbit
        }
    }
    func refresh(location: ObservingLocation, eveningFirst: Bool, now: Date = Date()) async throws -> SkySnapshot {
        var orbital: OrbitData?
        var message: String?
        do { orbital = try await orbit(now: now) }
        catch {
            orbital = SkyStore.orbit
            message = orbital?.usable(at: now) == true ? "Orbit refresh failed. ISS times use saved orbital elements." : "ISS forecast unavailable. Planet and Moon predictions still work offline."
        }
        var snapshot = try await SkyCalculator.shared.forecast(location: location, now: now, eveningFirst: eveningFirst, orbit: orbital)
        snapshot.orbitMessage = message ?? (orbital?.fresh(at: now) == false ? "Older orbital elements: ISS times are approximate." : nil)
        snapshot.weather = SkyStore.read(location)?.weather
        try SkyStore.write(snapshot)
        return snapshot
    }
    func weather(location: ObservingLocation, now: Date = Date()) async throws -> WeatherForecast {
        if let cached = SkyStore.read(location)?.weather, now.timeIntervalSince(cached.fetchedAt) < 1800 { return cached }
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [URLQueryItem(name: "latitude", value: String(location.latitude)), URLQueryItem(name: "longitude", value: String(location.longitude)), URLQueryItem(name: "hourly", value: "cloud_cover,precipitation_probability,wind_speed_10m"), URLQueryItem(name: "forecast_days", value: "7"), URLQueryItem(name: "timeformat", value: "unixtime"), URLQueryItem(name: "timezone", value: "UTC")]
        struct Response: Decodable {
            struct Hourly: Decodable { var time: [Double]; var cloud_cover: [Double?]; var precipitation_probability: [Double?]; var wind_speed_10m: [Double?] }
            var hourly: Hourly
        }
        let response = try JSONDecoder().decode(Response.self, from: await fetch(c.url!))
        let h = response.hourly
        guard h.time.count == h.cloud_cover.count, h.time.count == h.precipitation_probability.count, h.time.count == h.wind_speed_10m.count else { throw SkyError.message("Incomplete weather response.") }
        let hours = h.time.indices.compactMap { index -> WeatherHour? in
            guard let cloud = h.cloud_cover[index], let rain = h.precipitation_probability[index], let wind = h.wind_speed_10m[index] else { return nil }
            return WeatherHour(time: Date(timeIntervalSince1970: h.time[index]), cloud: cloud, precipitation: rain, wind: wind)
        }
        guard !hours.isEmpty else { throw SkyError.message("Weather is unavailable.") }
        return WeatherForecast(hours: hours, fetchedAt: now)
    }
    func refreshWeather(location: ObservingLocation) async -> SkySnapshot? {
        var weather: WeatherForecast?
        var message: String?
        do { weather = try await self.weather(location: location) }
        catch { message = "Weather could not refresh. Check conditions before heading out." }
        guard var snapshot = SkyStore.read(location) else { return nil }
        if let weather { snapshot.weather = weather }
        snapshot.weatherMessage = message
        try? SkyStore.write(snapshot)
        return snapshot
    }
}
