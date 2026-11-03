import XCTest
@testable import SkyTonight

final class WatchTransferTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1791964800)
    func package() async throws -> WatchPackage {
        let snapshot = try await SkyCalculator.shared.forecast(location: .perth, now: now, eveningFirst: true, orbit: nil)
        return WatchPackage(revision: 10, sentAt: now, locations: [.perth], selectedID: "perth", eveningFirst: true, weatherEnabled: false, snapshots: [snapshot], reminders: [], results: [])
    }
    func testRejectsOldDuplicateAndUnsupportedTransfers() async throws {
        let current = try await package()
        var incoming = current
        XCTAssertFalse(incoming.accepts(after: current))
        incoming.revision = 9; XCTAssertFalse(incoming.accepts(after: current))
        incoming.revision = 11; XCTAssertTrue(incoming.accepts(after: current))
        incoming.schema = 2; XCTAssertFalse(incoming.accepts(after: current))
        incoming.schema = 1; incoming.selectedID = "deleted"; XCTAssertFalse(incoming.accepts(after: current))
        incoming.selectedID = "perth"; incoming.locations.append(.perth); XCTAssertFalse(incoming.accepts(after: current))
    }
    func testCompressedForecastRoundTripAndCorruptPayload() async throws {
        let original = try await package()
        let data = try SkyJSON.encoder().encode(original)
        let compressed = try WatchWire.compress(data)
        XCTAssertLessThan(compressed.count, data.count)
        let decoded = try SkyJSON.decoder().decode(WatchPackage.self, from: WatchWire.expand(compressed))
        XCTAssertEqual(decoded.snapshots[0].events, original.snapshots[0].events)
        XCTAssertThrowsError(try WatchWire.expand(Data("invalid".utf8)))
    }
    func testMovedDeletedAndExpiredPlacesCannotReuseForecast() async throws {
        var transfer = try await package()
        XCTAssertNotNil(transfer.snapshot(for: "perth", at: now))
        transfer.locations[0].latitude = 40
        XCTAssertNil(transfer.snapshot(for: "perth", at: now))
        transfer.locations = []
        XCTAssertNil(transfer.snapshot(for: "perth", at: now))
        transfer.locations = [.perth]
        XCTAssertNil(transfer.snapshot(for: "perth", at: transfer.snapshots[0].validUntil))
    }
    func testSampledDirectionsMatchCalculationAndSurviveTransfer() async throws {
        let transfer = try await package()
        let sampled = try await SkyCalculator.shared.watchSnapshot(transfer.snapshots[0])
        XCTAssertFalse(sampled.events.isEmpty)
        let event = try XCTUnwrap(sampled.events.first { $0.kind == "planet" })
        XCTAssertGreaterThan(event.points.count, 2)
        let date = event.start.addingTimeInterval(150)
        let point = try XCTUnwrap(WatchObservation.point(in: event, at: date))
        let chart = try await SkyCalculator.shared.chart(location: sampled.location, time: date, orbit: nil)
        let reference = try XCTUnwrap(chart.first { $0.name == event.body })
        XCTAssertEqual(point.azimuth, reference.azimuth, accuracy: 0.2)
        XCTAssertEqual(point.elevation, reference.elevation, accuracy: 0.2)
        var payload = transfer; payload.snapshots = [sampled]
        let decoded = try SkyJSON.decoder().decode(WatchPackage.self, from: SkyJSON.encoder().encode(payload))
        XCTAssertEqual(decoded.snapshots[0].events, sampled.events)
    }
    func testInterpolationCrossesNorthAndDoesNotExtrapolateOrBridgeGaps() async throws {
        let transfer = try await package()
        var event = try XCTUnwrap(transfer.snapshots[0].events.first)
        event.kind = "iss"
        event.points = [SkyPoint(timestamp: now, azimuth: 359, elevation: 20, sunlit: true),
                        SkyPoint(timestamp: now.addingTimeInterval(10), azimuth: 1, elevation: 30, sunlit: true)]
        let middle = try XCTUnwrap(WatchObservation.point(in: event, at: now.addingTimeInterval(5)))
        XCTAssertEqual(middle.azimuth, 0, accuracy: 0.001)
        XCTAssertEqual(middle.elevation, 25)
        XCTAssertNil(WatchObservation.point(in: event, at: now.addingTimeInterval(-1)))
        XCTAssertNil(WatchObservation.point(in: event, at: now.addingTimeInterval(11)))
        event.points[1].timestamp = now.addingTimeInterval(120)
        XCTAssertNil(WatchObservation.point(in: event, at: now.addingTimeInterval(60)))
    }
    func testTimelineContainsExactPassAndOrbitalExpiryBoundaries() async throws {
        var snapshot = try await package().snapshots[0]
        var event = try XCTUnwrap(snapshot.events.first)
        event.kind = "iss"; event.start = now.addingTimeInterval(120); event.end = now.addingTimeInterval(240)
        snapshot.events = [event]
        snapshot.orbit = OrbitData(epoch: now.addingTimeInterval(-7 * 86400 + 180), fetchedAt: now, source: "Test")
        let dates = WatchObservation.timelineDates(snapshot: snapshot, now: now)
        XCTAssertTrue(dates.contains(event.start)); XCTAssertTrue(dates.contains(event.end))
        XCTAssertTrue(dates.contains(now.addingTimeInterval(180))); XCTAssertTrue(dates.contains(snapshot.validUntil))
        XCTAssertFalse(WatchObservation.event(event, usableIn: snapshot, at: now))
        XCTAssertEqual(WatchObservation.countdown(to: now.addingTimeInterval(134), now: now), "02:14")
    }
    func testDelayedReminderRejectsStartedChangedAndStalePasses() async throws {
        var snapshot = try await package().snapshots[0]
        var event = try XCTUnwrap(snapshot.events.first)
        event.kind = "iss"; event.start = now.addingTimeInterval(600); event.end = now.addingTimeInterval(900)
        snapshot.events = [event]
        snapshot.orbit = OrbitData(epoch: now, fetchedAt: now, source: "Test")
        var action = WatchAction(createdAt: now, location: .perth, eventID: event.id, enabled: true)
        XCTAssertNotNil(WatchObservation.reminderEvent(for: action, in: snapshot, now: now))
        action.location.latitude += 1
        XCTAssertNil(WatchObservation.reminderEvent(for: action, in: snapshot, now: now))
        action.location = .perth
        XCTAssertNil(WatchObservation.reminderEvent(for: action, in: snapshot, now: event.start))
        action.eventID = "removed"; XCTAssertNil(WatchObservation.reminderEvent(for: action, in: snapshot, now: now))
        action.eventID = event.id; snapshot.orbit?.epoch = now.addingTimeInterval(-4 * 86400)
        XCTAssertNil(WatchObservation.reminderEvent(for: action, in: snapshot, now: now))
        snapshot.orbit?.epoch = now; action.createdAt = now.addingTimeInterval(-86401)
        XCTAssertNil(WatchObservation.reminderEvent(for: action, in: snapshot, now: now))
    }
    @MainActor func testHandoffKeepsRequestedEventTimeAndOpensSettings() async throws {
        let snapshot = try await package().snapshots[0]
        var event = try XCTUnwrap(snapshot.events.first)
        event.focus = event.start.addingTimeInterval(120)
        let model = AppModel(); model.location = .perth; model.snapshot = snapshot
        await model.open(event.link(location: .perth))
        XCTAssertEqual(model.previewTime, event.focus)
        XCTAssertEqual(model.selectedTab, 1)
        await model.open(URL(string: "skytonight://settings")!)
        XCTAssertEqual(model.selectedTab, 3)
    }
}
