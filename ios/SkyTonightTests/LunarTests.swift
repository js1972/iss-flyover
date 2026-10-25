import XCTest
import SwiftUI
import WidgetKit
import UserNotifications
import Combine
@testable import SkyTonight

final class LunarTests: XCTestCase {
    private let evening = Date(timeIntervalSince1970: 1793008800) // 26 Oct 2026 18:00 Perth
    private func forecast(_ date: Date? = nil, location: ObservingLocation = .perth, eveningFirst: Bool = true) async throws -> SkySnapshot {
        try await SkyCalculator.shared.forecast(location: location, now: date ?? evening, eveningFirst: eveningFirst, orbit: nil)
    }
    func testDaytimeFullMoonLeadsTonightAndUpcomingOffline() async throws {
        let snapshot = try await forecast()
        let event = try XCTUnwrap(snapshot.ranked(at: evening).first)
        XCTAssertEqual(event.title, "Full Moon")
        XCTAssertEqual(event.kind, "moon")
        XCTAssertEqual(event.body, "Moon")
        let lunar = try XCTUnwrap(event.lunar)
        // Independent reference: Perth Observatory 26 Oct 2026, 12:11 AWST (minute precision).
        XCTAssertEqual(lunar.fullMoonAt.timeIntervalSince1970, 1792987860, accuracy: 120)
        XCTAssertLessThan(lunar.fullMoonAt, evening)
        XCTAssertGreaterThan(event.start, evening)
        XCTAssertGreaterThan(event.end.timeIntervalSince(event.start), 8 * 3600)
        XCTAssertGreaterThanOrEqual(event.elevation, 10)
        XCTAssertFalse(event.isMorning)
        XCTAssertEqual(snapshot.ranked(at: evening, nightID: event.nightID).first, event)
        XCTAssertTrue(snapshot.ranked(at: evening, issOnly: true).isEmpty)
        XCTAssertEqual(snapshot.events.filter { $0.lunar?.isPrimary == true }.count, 1)
        XCTAssertTrue(event.lunarTiming(location: .perth)?.contains("Moonrise 18:56") == true)
    }
    func testAdjacentNightsAreNearlyFullAndOrdinaryNightsHaveNoLunarEvent() async throws {
        for offset in [-1, 1] {
            let date = evening.addingTimeInterval(Double(offset) * 86400)
            let snapshot = try await forecast(date)
            let moon = try XCTUnwrap(snapshot.ranked(at: date).first { $0.kind == "moon" })
            XCTAssertEqual(moon.title, "Nearly full Moon")
            XCTAssertFalse(try XCTUnwrap(moon.lunar).isPrimary)
            XCTAssertNotEqual(snapshot.ranked(at: date).first?.kind, "moon")
        }
        let ordinary = evening.addingTimeInterval(3 * 86400)
        let snapshot = try await forecast(ordinary)
        XCTAssertFalse(snapshot.ranked(at: ordinary).contains { $0.kind == "moon" })
    }
    func testCachedMoonAdvancesToVisiblePositionAndExpiresAtWindowEnd() async throws {
        let snapshot = try await forecast()
        let original = try XCTUnwrap(snapshot.ranked(at: evening).first)
        let later = evening.addingTimeInterval(8 * 3600) // 02:00; same observing night
        let event = try XCTUnwrap(snapshot.ranked(at: later).first { $0.kind == "moon" })
        XCTAssertEqual(event.id, original.id)
        XCTAssertTrue(event.isMorning)
        XCTAssertGreaterThanOrEqual(event.focus, later)
        XCTAssertLessThan(event.focus.timeIntervalSince(later), 301)
        let chart = try await SkyCalculator.shared.chart(location: .perth, time: event.focus, orbit: nil, target: event)
        let moon = try XCTUnwrap(chart.first { $0.id == "Moon" })
        XCTAssertEqual(moon.elevation, event.elevation, accuracy: 0.001)
        XCTAssertEqual(moon.azimuth, event.azimuth, accuracy: 0.001)
        XCTAssertGreaterThan(moon.elevation, 5)
        XCTAssertFalse(snapshot.ranked(at: event.end).contains { $0.id == event.id })
        let refreshed = try await forecast(later)
        XCTAssertEqual(refreshed.ranked(at: later).first { $0.kind == "moon" }?.id, original.id)
        XCTAssertEqual(refreshed.ranked(at: later).first { $0.kind == "moon" }?.start, original.start)
    }
    func testMidnightPhaseBelongsToPreviousObservingNightAndPolarDayIsExcluded() async throws {
        let september = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-26T10:00:00Z"))
        let snapshot = try await forecast(september)
        let event = try XCTUnwrap(snapshot.ranked(at: september).first { $0.lunar?.isPrimary == true })
        XCTAssertEqual(event.nightID, "2026-09-26")
        XCTAssertEqual(ObservingLocation.perth.calendar.component(.day, from: try XCTUnwrap(event.lunar).fullMoonAt), 27)
        let polar = ObservingLocation(id: "polar-moon", name: "Tromsø", latitude: 69.65, longitude: 18.96, timeZoneID: "Europe/Oslo")
        let summerFullMoon = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-06-29T12:00:00Z"))
        let polarSnapshot = try await forecast(summerFullMoon, location: polar)
        XCTAssertFalse(polarSnapshot.events.contains { $0.kind == "moon" })
    }
    func testFullMoonWithDSTAndBothHemispheres() async throws {
        let locations = [
            ObservingLocation(id: "ny-moon", name: "New York", latitude: 40.7128, longitude: -74.006, timeZoneID: "America/New_York"),
            ObservingLocation(id: "sydney-moon", name: "Sydney", latitude: -33.8688, longitude: 151.2093, timeZoneID: "Australia/Sydney")
        ]
        // Full Moon 2 April, across Sydney's 5 April DST transition.
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-04-01T00:00:00Z"))
        for location in locations {
            let snapshot = try await forecast(date, location: location)
            let moon = try XCTUnwrap(snapshot.events.first { $0.lunar?.isPrimary == true })
            XCTAssertEqual(snapshot.events.filter { $0.lunar?.isPrimary == true }.count, 1)
            XCTAssertGreaterThan(moon.start, date)
            XCTAssertLessThan(moon.focus, moon.end)
            let objects = try await SkyCalculator.shared.chart(location: location, time: moon.focus, orbit: nil)
            XCTAssertGreaterThan(try XCTUnwrap(objects.first { $0.kind == "moon" }).elevation, 5)
        }
    }
    func testRankingKeepsExceptionalEventsAndEveningPreference() async throws {
        var snapshot = try await forecast()
        let moon = try XCTUnwrap(snapshot.ranked(at: evening).first)
        var exceptional = moon
        exceptional.id = "exceptional"; exceptional.kind = "meteor"; exceptional.lunar = nil
        exceptional.score = 200
        snapshot.events.append(exceptional)
        XCTAssertEqual(snapshot.ranked(at: evening).first?.id, exceptional.id)
        XCTAssertEqual(snapshot.ranked(at: evening)[1].id, moon.id)
        snapshot.events[snapshot.events.count-1].isMorning = true
        XCTAssertEqual(snapshot.ranked(at: evening).first?.id, moon.id)
        snapshot.eveningFirst = false
        XCTAssertEqual(snapshot.ranked(at: evening).first?.id, exceptional.id)
    }
    func testMoonReminderUsesViewingWindowAndCacheRejectsPreLunarForecast() async throws {
        var snapshot = try await forecast()
        let moon = try XCTUnwrap(snapshot.ranked(at: evening).first)
        let request = SkyReminders.request(event: moon, location: .perth, now: evening)
        let trigger = try XCTUnwrap(request.trigger as? UNTimeIntervalNotificationTrigger)
        XCTAssertEqual(trigger.timeInterval, moon.start.addingTimeInterval(-600).timeIntervalSince(evening), accuracy: 0.01)
        XCTAssertGreaterThan(trigger.timeInterval, 0)
        let decoded = try SkyJSON.decoder().decode(SkySnapshot.self, from: SkyJSON.encoder().encode(snapshot))
        XCTAssertEqual(snapshot.events, decoded.events)
        snapshot.location.id = "moon-migration-\(UUID().uuidString)"
        defer { SkyStore.removeForecast(snapshot.location) }
        snapshot.schema = 1
        try SkyStore.write(snapshot)
        XCTAssertNil(SkyStore.read(snapshot.location))
        snapshot.schema = 2
        try SkyStore.write(snapshot)
        XCTAssertNotNil(SkyStore.read(snapshot.location))
    }
    @MainActor func testMoonPreviewAndWidgetArtwork() async throws {
        let snapshot = try await forecast()
        let event = try XCTUnwrap(snapshot.ranked(at: evening).first)
        let model = AppModel(); model.snapshot = snapshot; model.location = .perth
        let ready = expectation(description: "Moon preview calculated")
        let observation = model.$chart.filter { $0.contains { $0.kind == "moon" } }.first().sink { _ in ready.fulfill() }
        model.preview(event)
        await fulfillment(of: [ready], timeout: 5)
        withExtendedLifetime(observation) {}
        XCTAssertEqual(model.selectedTab, 1)
        XCTAssertEqual(model.selectedEvent?.body, "Moon")
        XCTAssertEqual(model.previewTime, event.focus)
        XCTAssertNotNil(model.chart.first { $0.kind == "moon" && $0.elevation > 0 })
        model.selectedTab = 0; model.selectedEvent = nil
        await model.open(event.link(location: .perth))
        XCTAssertEqual(model.selectedTab, 1)
        XCTAssertEqual(model.selectedEvent?.body, "Moon")
        XCTAssertEqual(event.artworkAsset, "FullMoon")
        XCTAssertNotNil(UIImage(systemName: event.symbol))
        XCTAssertNotNil(UIImage(named: "FullMoon"))
        let widgetURL = try XCTUnwrap(Bundle.main.builtInPlugInsURL?.appendingPathComponent("SkyWidgets.appex"))
        XCTAssertNotNil(UIImage(named: "FullMoon", in: try XCTUnwrap(Bundle(url: widgetURL)), compatibleWith: nil))
        let entry = SkyEntry(date: evening, snapshot: snapshot, location: .perth)
        for family in [WidgetFamily.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular] {
            let home = family == .systemSmall || family == .systemMedium
            let width: CGFloat = family == .systemSmall ? 170 : family == .accessoryCircular ? 80 : family == .accessoryRectangular ? 180 : 350
            let height: CGFloat = home ? 170 : family == .accessoryInline ? 50 : 80
            var images: [Data] = []
            for scheme in [ColorScheme.light, .dark] {
                let view = SkyWidgetView(previewFamily: family, entry: entry, issOnly: false)
                    .padding(home ? 16 : 0).frame(width: width, height: height)
                    .background(home ? Color.skyPanel : scheme == .light ? Color.white : Color.black)
                    .environment(\.widgetRenderingMode, .fullColor).environment(\.colorScheme, scheme)
                let renderer = ImageRenderer(content: view); renderer.scale = 2
                let image = try XCTUnwrap(renderer.uiImage)
                images.append(try XCTUnwrap(image.pngData()))
                let attachment = XCTAttachment(image: image)
                attachment.name = "Full Moon widget - \(family) - \(scheme)"
                attachment.lifetime = .keepAlways; add(attachment)
            }
            if home { XCTAssertEqual(images[0], images[1]) }
        }
        for size in [DynamicTypeSize.large, .accessibility3] {
            let view = TonightPickCard(allowMotion: false, event: event).padding(20).frame(width: 390)
                .background(Color.skyBase).environmentObject(model).environment(\.dynamicTypeSize, size)
                .environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: view); renderer.scale = 2
            let attachment = XCTAttachment(image: try XCTUnwrap(renderer.uiImage))
            attachment.name = "Full Moon Tonight - \(size)"; attachment.lifetime = .keepAlways; add(attachment)
        }
        let plot = SkyPlot(objects: model.chart, path: [], rotation: 0, selected: "Moon").frame(width: 350, height: 350).background(Color.skyBase)
        let renderer = ImageRenderer(content: plot); renderer.scale = 2
        let attachment = XCTAttachment(image: try XCTUnwrap(renderer.uiImage))
        attachment.name = "Full Moon selected on observation chart"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
