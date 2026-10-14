import SwiftUI
import WidgetKit
import AppIntents

struct PlaceEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Observing place"
    static var defaultQuery = PlaceQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}
struct PlaceQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PlaceEntity] { SkyStore.locations.filter { identifiers.contains($0.id) }.map { PlaceEntity(id:$0.id,name:$0.name) } }
    func suggestedEntities() async throws -> [PlaceEntity] { SkyStore.locations.map { PlaceEntity(id:$0.id,name:$0.name) } }
    func defaultResult() async -> PlaceEntity? { PlaceEntity(id:SkyStore.selected.id,name:SkyStore.selected.name) }
}
struct SkyConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Sky Tonight"
    static var description = IntentDescription("Choose a saved observing location.")
    @Parameter(title: "Observing place") var place: PlaceEntity?
}
struct SkyProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SkyEntry { SkyEntry(date: Date(), snapshot: nil, location: .perth) }
    func snapshot(for configuration: SkyConfiguration, in context: Context) async -> SkyEntry {
        let loc = location(configuration)
        return SkyEntry(date: Date(), snapshot: SkyStore.read(loc), location: loc)
    }
    func location(_ configuration: SkyConfiguration) -> ObservingLocation { SkyStore.locations.first { $0.id == configuration.place?.id } ?? SkyStore.selected }
    func timeline(for configuration: SkyConfiguration, in context: Context) async -> Timeline<SkyEntry> {
        let loc = location(configuration), now = Date()
        var snapshot = SkyStore.read(loc)
        if snapshot == nil || now.timeIntervalSince(snapshot!.generatedAt) > 3600 || snapshot?.eveningFirst != SkyStore.eveningFirst {
            do { snapshot = try await SkyRepository.shared.refresh(location: loc, eveningFirst: SkyStore.eveningFirst, now: now) } catch { /* Keep a valid saved forecast when offline. */ }
        }
        if snapshot?.weather == nil || now.timeIntervalSince(snapshot!.weather!.fetchedAt) > 3600 {
            snapshot = await SkyRepository.shared.refreshWeather(location: loc) ?? snapshot
        }
        let dates = SkyTimeline.dates(snapshot: snapshot, now: now)
        return Timeline(entries: dates.map { SkyEntry(date: $0, snapshot: snapshot, location: loc) }, policy: .after(now.addingTimeInterval(3600)))
    }
}
struct TonightWidget: Widget {
    let kind = "SkyTonight"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SkyConfiguration.self, provider: SkyProvider()) { SkyWidgetView(entry: $0, issOnly: false) }
            .configurationDisplayName("Sky Tonight").description("The best things to see from your observing place.")
            .supportedFamilies([.systemSmall,.systemMedium,.accessoryInline,.accessoryCircular,.accessoryRectangular])
    }
}
struct ISSWidget: Widget {
    let kind = "NextISSPass"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SkyConfiguration.self, provider: SkyProvider()) { SkyWidgetView(entry: $0, issOnly: true) }
            .configurationDisplayName("Next ISS Pass").description("Your next sunlit ISS flyover, with time and direction.")
            .supportedFamilies([.systemSmall,.systemMedium,.accessoryRectangular])
    }
}
@main
struct SkyWidgets: WidgetBundle { var body: some Widget { TonightWidget(); ISSWidget() } }
