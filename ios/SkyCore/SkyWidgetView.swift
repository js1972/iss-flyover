import SwiftUI
import WidgetKit

struct SkyEntry: TimelineEntry {
    var date: Date
    var snapshot: SkySnapshot?
    var location: ObservingLocation
    var relevance: TimelineEntryRelevance? {
        guard let event = snapshot?.ranked(at: date).first else { return nil }
        let upcoming = event.start.timeIntervalSince(date)
        return TimelineEntryRelevance(score: upcoming >= 0 && upcoming < 3600 ? 100 : 20)
    }
}
struct SkyWidgetView: View {
    @Environment(\.widgetFamily) private var systemFamily
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    var previewFamily: WidgetFamily? = nil
    var family: WidgetFamily { previewFamily ?? systemFamily }
    var entry: SkyEntry
    var issOnly: Bool
    var events: [SkyEvent] { guard let snapshot = entry.snapshot, snapshot.validUntil > entry.date else { return [] }; return snapshot.ranked(at: entry.date, issOnly: issOnly) }
    var body: some View {
        let event = events.first
        let url = event?.link(location: entry.location) ?? URL(string: "skytonight://tonight?location=\(entry.location.id)")!
        Group {
            if family == .accessoryInline {
                Text(event.map { "\(entry.location.time(issOnly ? $0.start : $0.focus)) \($0.title)" } ?? "Open Sky Tonight")
            } else if family == .accessoryCircular {
                VStack(spacing: 2) { Image(systemName: event?.symbol ?? "moon.stars"); Text(event.map { entry.location.time(issOnly ? $0.start : $0.focus) } ?? "Sky").font(.caption.bold()) }
            } else if family == .accessoryRectangular {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event?.title ?? "Sky Tonight").font(.headline)
                    Text(event.map { "\(entry.location.time(issOnly ? $0.start : $0.focus)) · \($0.direction) · \(Int($0.elevation))°" } ?? "Open app for your forecast").font(.caption)
                    Text(entry.location.name).font(.caption2)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Label(issOnly ? "NEXT ISS" : "SKY TONIGHT", systemImage: issOnly ? "point.topleft.down.to.point.bottomright.curvepath" : "moon.stars.fill").font(.system(size: 10, weight: .bold)).tracking(1); Spacer(); if family == .systemMedium { Text(entry.location.name).font(.caption2).lineLimit(1) } }.foregroundStyle(Color.mint)
                    if let event {
                        if let planet = artworkPlanet(event) {
                            if family == .systemMedium {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 6) { headline(event) }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    WidgetPlanetArtwork(planet: planet).frame(width: 128, height: 62)
                                }
                                HStack(spacing: 16) {
                                    ForEach(Array(events.dropFirst().prefix(2))) { next in
                                        Link(destination: next.link(location: entry.location)) {
                                            HStack(spacing: 4) {
                                                Text(next.title).fontWeight(.semibold)
                                                Text(entry.location.time(next.focus)).foregroundStyle(.secondary)
                                            }.font(.system(size: 10)).lineLimit(1).foregroundStyle(Color.primary)
                                        }
                                    }
                                }
                            } else {
                                HStack(spacing: 0) {
                                    Text(event.title).font(.headline).lineLimit(1).minimumScaleFactor(0.85)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    WidgetPlanetArtwork(planet: planet).frame(width: 74, height: 52)
                                }
                                eventTime(event)
                            }
                        } else if family == .systemMedium {
                            HStack(alignment: .top, spacing: 16) {
                                VStack(alignment: .leading, spacing: 6) { headline(event); Text(event.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2) }.frame(maxWidth: .infinity, alignment: .leading)
                                if !issOnly {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(Array(events.dropFirst().prefix(2))) { next in
                                            Link(destination: next.link(location: entry.location)) { VStack(alignment: .leading, spacing: 2) { Text(next.title).font(.caption.bold()); Text("\(entry.location.time(next.focus)) · \(next.direction)").font(.caption2).foregroundStyle(.secondary) }.foregroundStyle(Color.primary) }
                                        }
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        } else { headline(event) }
                        Spacer(minLength: 0)
                        HStack(spacing: 5) {
                            if let weather = entry.snapshot?.weather?.sample(at: event.focus, now: entry.date) { Image(systemName: "cloud"); Text("\(Int(weather.cloud))% cloud") }
                            else { Text("Weather unavailable") }
                            if family == .systemMedium, let night = entry.snapshot?.night(at: entry.date) { Spacer(); Text("Moon \(night.moonPercent)%") }
                        }.font(.system(size: 10)).foregroundStyle(.secondary)
                        if issOnly { Text("\(entry.location.name) · \(entry.location.day(event.start))").font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1) }
                        else if family == .systemSmall { Text(entry.location.name).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1) }
                    } else {
                        Text(emptyTitle).font(.headline)
                        Text(emptyDetail).font(.caption).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Text(entry.location.name).font(.caption2)
                    }
                }
                // The full-colour card is always navy, even when the phone uses light mode.
                // Keep semantic primary/secondary text light on that surface. Let the system
                // choose contrast for tinted, vibrant, and background-free presentations.
                .environment(\.colorScheme, renderingMode == .fullColor && (showsBackground || previewFamily != nil) ? .dark : colorScheme)
            }
        }.widgetURL(url)
            .containerBackground(for: .widget) { LinearGradient(colors: [Color(red:0.07,green:0.13,blue:0.22),Color(red:0.025,green:0.055,blue:0.1)], startPoint: .topLeading, endPoint: .bottomTrailing) }
    }
    @ViewBuilder func headline(_ event: SkyEvent) -> some View {
        Text(event.title).font(.headline).lineLimit(2).minimumScaleFactor(0.85)
        eventTime(event)
    }
    func eventTime(_ event: SkyEvent) -> some View {
        Text("\(entry.location.time(issOnly ? event.start : event.focus)) · \(event.direction)").font(.system(.title3, design: .rounded).weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
    }
    func artworkPlanet(_ event: SkyEvent) -> WidgetPlanet? {
        guard !issOnly, renderingMode == .fullColor,
              showsBackground || previewFamily != nil else { return nil }
        return WidgetPlanet(event: event)
    }
    var emptyTitle: String {
        guard let snapshot = entry.snapshot, snapshot.validUntil > entry.date else { return "Refresh your sky" }
        if issOnly && snapshot.orbit?.usable(at: entry.date) != true { return "ISS data unavailable" }
        return issOnly ? "No visible ISS pass" : "A quiet night"
    }
    var emptyDetail: String { entry.snapshot?.validUntil ?? .distantPast <= entry.date ? "Open Sky Tonight for a fresh forecast." : "Tap to explore upcoming nights." }
}
