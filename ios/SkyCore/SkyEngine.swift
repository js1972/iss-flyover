import Foundation
import JavaScriptCore

enum SkyError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let s): s } }
}
struct CalculationDay: Encodable {
    var id: String
    var monthDay: String
    var noon: Date
    var nextNoon: Date
    var midnight: Date
}
actor SkyCalculator {
    static let shared = SkyCalculator()
    private var context: JSContext?
    private func engine() throws -> JSContext {
        if let context { return context }
        guard let url = Bundle.main.url(forResource: "SkyEngine", withExtension: "js"), let ctx = JSContext() else { throw SkyError.message("The local sky engine could not load.") }
        ctx.evaluateScript(try String(contentsOf: url, encoding: .utf8))
        if let exception = ctx.exception { throw SkyError.message(exception.toString()) }
        context = ctx
        return ctx
    }
    private func call<Input: Encodable, Output: Decodable>(_ method: String, input: Input, as type: Output.Type) throws -> Output {
        let ctx = try engine(); ctx.exception = nil
        let json = String(decoding: try SkyJSON.encoder().encode(input), as: UTF8.self)
        let value = ctx.objectForKeyedSubscript("SkyEngine")?.invokeMethod(method, withArguments: [json])
        if let exception = ctx.exception { throw SkyError.message(exception.toString()) }
        guard let result = value?.toString(), let data = result.data(using: .utf8) else { throw SkyError.message("The sky calculation returned no data.") }
        return try SkyJSON.decoder().decode(type, from: data)
    }
    static func days(location: ObservingLocation, now: Date) -> [CalculationDay] {
        let c = location.calendar
        let start = c.startOfDay(for: now)
        let id = DateFormatter(); id.timeZone = location.timeZone; id.dateFormat = "yyyy-MM-dd"
        let md = DateFormatter(); md.timeZone = location.timeZone; md.dateFormat = "MM-dd"
        return (-1...7).compactMap { offset in
            guard let day = c.date(byAdding: .day, value: offset, to: start),
                  let noon = c.date(bySettingHour: 12, minute: 0, second: 0, of: day),
                  let next = c.date(byAdding: .day, value: 1, to: noon),
                  let midnight = c.date(byAdding: .day, value: 1, to: c.startOfDay(for: noon)) else { return nil }
            return CalculationDay(id: id.string(from: noon), monthDay: md.string(from: noon), noon: noon, nextNoon: next, midnight: midnight)
        }
    }
    func forecast(location: ObservingLocation, now: Date, eveningFirst: Bool, orbit: OrbitData?) throws -> SkySnapshot {
        guard location.isValid else { throw SkyError.message("Enter valid coordinates and a time zone.") }
        struct Input: Encodable { var location: ObservingLocation; var now: Date; var days: [CalculationDay]; var eveningFirst: Bool; var orbit: OrbitData? }
        struct Output: Decodable { var nights: [ObservingNight]; var events: [SkyEvent] }
        let usable = orbit?.usable(at: now) == true ? orbit : nil
        let output = try call("forecast", input: Input(location: location, now: now, days: Self.days(location: location, now: now), eveningFirst: eveningFirst, orbit: usable), as: Output.self)
        return SkySnapshot(location: location, generatedAt: now, eveningFirst: eveningFirst, nights: output.nights, events: output.events, orbit: usable)
    }
    func chart(location: ObservingLocation, time: Date, orbit: OrbitData?, target: SkyEvent? = nil) throws -> [ChartObject] {
        struct Input: Encodable { var location: ObservingLocation; var time: Date; var orbit: OrbitData?; var target: SkyEvent? }
        return try call("chart", input: Input(location: location, time: time, orbit: orbit?.usable(at: time) == true ? orbit : nil, target: target), as: [ChartObject].self)
    }
}
