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
    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        let current = entry(at: Date())
        recordRequest("snapshot", context: context, entry: current)
        completion(current)
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        let now = Date(), current = entry(at: Date())
        recordRequest("timeline", context: context, entry: current)
        let dates = WatchObservation.timelineDates(snapshot: current.snapshot, now: now)
        completion(Timeline(entries: dates.map { date in
            var item = current; item.date = date; return item
        }, policy: .after(now.addingTimeInterval(1800))))
    }
    private func recordRequest(_ request: String, context: Context, entry: WatchEntry) {
        guard !context.isPreview else { return }
        // One small, overwritten receipt per widget kind distinguishes an
        // installed app from the extension actually serving the watch face.
        // No location or forecast payload is written to this diagnostic file.
        let receipt = WatchWidgetReceipt(date: entry.date,
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            request: request, family: String(describing: context.family),
            artwork: entry.event?.artworkAsset)
        let folder = WatchCache.root.appendingPathComponent("Library/Application Support/WidgetDiagnostics", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? SkyJSON.encoder().encode(receipt).write(to: folder.appendingPathComponent("\(kind).json"), options: .atomic)
    }
}
private struct WatchWidgetReceipt: Codable {
    var date: Date
    var build: String
    var request: String
    var family: String
    var artwork: String?
}
struct WatchComplicationView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WatchEntry
    private let mint = Color(red: 0.43, green: 0.9, blue: 0.78)
    private var needsRefresh: Bool { (entry.snapshot?.validUntil ?? .distantPast) <= entry.date }
    private var title: String {
        if entry.kind == .moon, let night = entry.night { return night.moonName }
        if let event = entry.event { return event.kind == "iss" ? "ISS" : event.title }
        if needsRefresh { return "Refresh on iPhone" }
        return entry.kind == .iss ? "No visible ISS pass" : "No more highlights"
    }
    private var symbol: String { entry.kind == .moon ? WatchObservation.moonSymbol(entry.night?.moonPhase ?? 0) : entry.event?.symbol ?? "moon.stars" }
    private var compactTitle: String {
        if needsRefresh { return entry.snapshot == nil ? "Sync" : "Refresh" }
        if entry.kind == .moon { return "Moon" }
        guard let event = entry.event else { return "None" }
        if event.kind == "iss" { return "ISS" }
        if event.kind == "moon" { return event.title }
        return event.body.isEmpty ? event.title : event.body
    }
    @ViewBuilder private func artwork(size: CGFloat, width: CGFloat? = nil) -> some View {
        if let asset = entry.event?.artworkAsset, let image = ComplicationArtwork.images[asset] {
            Image(decorative: image, scale: 2)
                .resizable()
                .widgetAccentedRenderingMode(.desaturated)
                .scaledToFit()
                .frame(width: width ?? size, height: size)
                .accessibilityHidden(true)
        } else if entry.kind == .moon || entry.event?.kind == "moon" {
            WatchMoonPhase(phase: entry.night?.moonPhase ?? 0, latitude: entry.location?.latitude, size: size)
                .accessibilityHidden(true)
        } else {
            Image(systemName: symbol).resizable().scaledToFit()
                .frame(width: size, height: size).widgetAccentable()
                .accessibilityHidden(true)
        }
    }
    private var compactValue: String {
        if entry.kind == .moon, let night = entry.night { return "\(night.moonPercent)%" }
        if let event = entry.event { return entry.location?.time(event.kind == "iss" ? event.start : event.focus) ?? "—" }
        return "—"
    }
    private var circularValue: String {
        if let event = entry.event, event.kind == "iss", event.start <= entry.date, event.end > entry.date { return "Now" }
        return compactValue
    }
    private var backdrop: CGImage? {
        guard let asset = entry.event?.artworkAsset else { return nil }
        return family == .accessoryCircular
            ? ComplicationArtwork.circularBackdrops[asset]
            : ComplicationArtwork.rectangularBackdrops[asset]
    }
    private func backgroundImage(_ image: CGImage) -> some View {
        Image(decorative: image, scale: 2).resizable()
            .widgetAccentedRenderingMode(.desaturated)
            .accessibilityHidden(true)
    }
    @ViewBuilder private var value: some View {
        if let event = entry.event, event.kind == "iss", event.start > entry.date {
            Text(event.start, style: .timer).monospacedDigit()
        } else if let event = entry.event, event.kind == "iss", event.end > entry.date {
            Text("Visible now")
        } else { Text(compactValue) }
    }
    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                if entry.kind == .moon || entry.event?.kind == "moon" {
                    Label {
                        Text("\(entry.kind == .moon ? "Moon" : title) · \(compactValue)")
                    } icon: {
                        WatchMoonPhase(phase: entry.night?.moonPhase ?? 0, latitude: entry.location?.latitude, size: 12)
                    }
                }
                else { Label("\(title) · \(compactValue)", systemImage: symbol) }
            case .accessoryCircular:
                ZStack(alignment: .bottom) {
                    if let backdrop { backgroundImage(backdrop) }
                    VStack(spacing: 0) {
                        if backdrop == nil { artwork(size: 23, width: 36) }
                        Text(compactTitle).font(.system(size: entry.kind == .moon ? 9 : 12, weight: .semibold))
                            .minimumScaleFactor(0.7).lineLimit(1)
                        if entry.kind == .moon {
                            Text(compactValue).font(.system(size: 10)).minimumScaleFactor(0.7).lineLimit(1)
                        }
                    }.padding(.horizontal, 3).padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(Circle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(title) · \(circularValue)")
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
            case .accessoryCorner:
                artwork(size: 32, width: 40).widgetLabel { Text("\(title) · \(compactValue)") }
                    .accessibilityHidden(false)
                    .accessibilityLabel("\(title) · \(compactValue)")
            default:
                if let backdrop {
                    ZStack {
                        backgroundImage(backdrop)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                                .padding(.trailing, 40)
                            value.font(.system(size: 23, weight: .bold)).minimumScaleFactor(0.7).lineLimit(1)
                            Text(entry.location?.name ?? "").font(.system(size: 10)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8).padding(.vertical, 6)
                    }.overlay(alignment: .topTrailing) {
                        if let event = entry.event {
                            Text("\(event.direction) · \(Int(event.elevation))°").font(.system(size: 9)).lineLimit(1)
                                .padding(.top, 6).padding(.trailing, 8)
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
                        .containerBackground(for: .widget) { Color.black }
                } else {
                  VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        artwork(size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.headline).widgetAccentable().lineLimit(1)
                            HStack {
                                value.font(.title3.bold()).minimumScaleFactor(0.7).lineLimit(1)
                                Spacer(minLength: 2)
                                if let event = entry.event { Text("\(event.direction) · \(Int(event.elevation))°").font(.caption).lineLimit(1) }
                            }
                        }
                    }
                    Text(entry.location?.name ?? "Open Sky Tonight on iPhone").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                  }.padding(8).containerBackground(for: .widget) { Color.black }
                }
            }
        }.widgetURL(entry.url).tint(mint)
    }
}
struct WatchTonightWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchTonight", provider: WatchProvider(kind: .tonight)) { WatchComplicationView(entry: $0) }
            .configurationDisplayName("Tonight's Highlight").description("The best target for your selected observing place.")
            .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular, .accessoryCorner])
            .contentMarginsDisabled()
    }
}
struct WatchISSWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchISS", provider: WatchProvider(kind: .iss)) { WatchComplicationView(entry: $0) }
            .configurationDisplayName("Next ISS Pass").description("A countdown to your next visible ISS pass.")
            .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular, .accessoryCorner])
            .contentMarginsDisabled()
    }
}
struct WatchMoonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchMoon", provider: WatchProvider(kind: .moon)) { WatchComplicationView(entry: $0) }
            .configurationDisplayName("Moon").description("Tonight's Moon phase and illumination.")
            .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular, .accessoryCorner])
            .contentMarginsDisabled()
    }
}
struct WatchNextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchNext", provider: WatchProvider(kind: .next)) { WatchComplicationView(entry: $0) }
            .configurationDisplayName("Next to Observe").description("The next observing opportunity, ready for your Smart Stack.")
            .supportedFamilies([.accessoryRectangular])
            .contentMarginsDisabled()
    }
}
@main struct SkyWatchWidgets: WidgetBundle {
    var body: some Widget { WatchTonightWidget(); WatchISSWidget(); WatchMoonWidget(); WatchNextWidget() }
}
