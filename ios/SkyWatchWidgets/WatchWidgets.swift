import SwiftUI
import WidgetKit

enum WatchWidgetKind { case tonight, iss, moon, next }
struct WatchEntry: TimelineEntry {
    var date: Date
    var snapshot: SkySnapshot?
    var location: ObservingLocation?
    var kind: WatchWidgetKind
    var event: SkyEvent? {
        guard let snapshot, snapshot.validUntil > date else { return nil }
        switch kind {
        case .iss: return snapshot.ranked(at: date, issOnly: true).first
        case .tonight: return snapshot.ranked(at: date).first
        case .next: return snapshot.ranked(at: date).min { max($0.start, date) < max($1.start, date) }
        case .moon: return nil
        }
    }
    var night: ObservingNight? { (snapshot?.validUntil ?? .distantPast) > date ? snapshot?.night(at: date) : nil }
    var url: URL {
        if let event, let location { return event.link(location: location) }
        var components = URLComponents(); components.scheme = "skytonight"
        components.host = kind == .moon ? "moon" : kind == .iss ? "iss" : "tonight"
        if let location { components.queryItems = [.init(name: "location", value: location.id)] }
        return components.url!
    }
}
struct WatchProvider: TimelineProvider {
    var kind: WatchWidgetKind
    func entry(at date: Date) -> WatchEntry {
        let package = WatchCache.package
        let id = package?.locations.contains(where: { $0.id == WatchCache.selectedID }) == true ? WatchCache.selectedID : package?.selectedID ?? ""
        return WatchEntry(date: date, snapshot: package?.snapshot(for: id, at: date),
                          location: package?.locations.first { $0.id == id }, kind: kind)
    }
    func placeholder(in context: Context) -> WatchEntry { WatchEntry(date: Date(), kind: kind) }
    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) { completion(entry(at: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        let now = Date(), current = entry(at: Date())
        let dates = WatchObservation.timelineDates(snapshot: current.snapshot, now: now)
        completion(Timeline(entries: dates.map { date in
            var item = current; item.date = date; return item
        }, policy: .after(now.addingTimeInterval(1800))))
    }
}
struct WatchComplicationView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WatchEntry
    private let mint = Color(red: 0.43, green: 0.9, blue: 0.78)
    private var title: String {
        if entry.kind == .moon, let night = entry.night { return night.moonName }
        if let event = entry.event { return event.kind == "iss" ? "ISS" : event.title }
        if entry.snapshot == nil { return "Refresh on iPhone" }
        return entry.kind == .iss ? "No visible ISS pass" : "No more highlights"
    }
    private var symbol: String { entry.kind == .moon ? WatchObservation.moonSymbol(entry.night?.moonPhase ?? 0) : entry.event?.symbol ?? "moon.stars" }
    private var compactValue: String {
        if entry.kind == .moon, let night = entry.night { return "\(night.moonPercent)%" }
        if let event = entry.event { return entry.location?.time(event.kind == "iss" ? event.start : event.focus) ?? "—" }
        return "—"
    }
    @ViewBuilder private var value: some View {
        if let event = entry.event, event.kind == "iss", event.start > entry.date {
            Text(event.start, style: .relative).monospacedDigit()
        } else if let event = entry.event, event.kind == "iss", event.end > entry.date {
            Text("Visible now")
        } else { Text(compactValue) }
    }
    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                if entry.kind == .moon { Label("Moon \(compactValue)", systemImage: symbol) }
                else { Label("\(title) · \(compactValue)", systemImage: symbol) }
            case .accessoryCircular:
                VStack(spacing: 1) {
                    Image(systemName: symbol).widgetAccentable()
                    if entry.snapshot == nil { Text("Sync").font(.caption2) }
                    else { value.font(.caption2).minimumScaleFactor(0.7).lineLimit(1) }
                }.containerBackground(for: .widget) { AccessoryWidgetBackground() }
            case .accessoryCorner:
                Image(systemName: symbol).font(.title3).widgetAccentable().widgetLabel { Text("\(title) · \(compactValue)") }
            default:
                VStack(alignment: .leading, spacing: 3) {
                    Label(title, systemImage: symbol).font(.headline).widgetAccentable().lineLimit(1)
                    HStack {
                        value.font(.title3.bold())
                        Spacer(minLength: 2)
                        if let event = entry.event { Text("\(event.direction) · \(Int(event.elevation))°").font(.caption) }
                    }
                    Text(entry.location?.name ?? "Open Sky Tonight on iPhone").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }.containerBackground(for: .widget) { Color.black }
            }
        }.widgetURL(entry.url).tint(mint)
    }
}
struct WatchTonightWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchTonight", provider: WatchProvider(kind: .tonight)) { WatchComplicationView(entry: $0) }
            .configurationDisplayName("Tonight's Highlight").description("The best target for your selected observing place.")
            .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular, .accessoryCorner])
    }
}
struct WatchISSWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchISS", provider: WatchProvider(kind: .iss)) { WatchComplicationView(entry: $0) }
            .configurationDisplayName("Next ISS Pass").description("A countdown to your next visible ISS pass.")
            .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular, .accessoryCorner])
    }
}
struct WatchMoonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchMoon", provider: WatchProvider(kind: .moon)) { WatchComplicationView(entry: $0) }
            .configurationDisplayName("Moon").description("Tonight's Moon phase and illumination.")
            .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular, .accessoryCorner])
    }
}
struct WatchNextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchNext", provider: WatchProvider(kind: .next)) { WatchComplicationView(entry: $0) }
            .configurationDisplayName("Next to Observe").description("The next observing opportunity, ready for your Smart Stack.")
            .supportedFamilies([.accessoryRectangular])
    }
}
@main struct SkyWatchWidgets: WidgetBundle {
    var body: some Widget { WatchTonightWidget(); WatchISSWidget(); WatchMoonWidget(); WatchNextWidget() }
}
