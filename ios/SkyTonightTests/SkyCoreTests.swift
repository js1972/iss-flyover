import XCTest
import JavaScriptCore
import SwiftUI
import WidgetKit
@testable import SkyTonight

final class SkyCoreTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1791964800) // 2026-10-14, fixed rather than test-machine clock.
    func testOfflineForecastAndChart() async throws {
        let result = try await SkyCalculator.shared.forecast(location: .perth, now: now, eveningFirst: true, orbit: nil)
        XCTAssertEqual(result.nights.count, 7)
        XCTAssertFalse(result.events.isEmpty)
        XCTAssertTrue(result.events.allSatisfy { $0.kind != "iss" && $0.focus >= now && $0.elevation > 0 })
        XCTAssertNotNil(result.night(at: now))
        let pick = try XCTUnwrap(result.ranked(at: now).first)
        XCTAssertFalse(pick.isMorning)
        let chart = try await SkyCalculator.shared.chart(location: .perth, time: pick.focus, orbit: nil)
        let object = try XCTUnwrap(chart.first { $0.name == pick.body })
        XCTAssertEqual(object.azimuth, pick.azimuth, accuracy: 0.01)
        XCTAssertEqual(object.elevation, pick.elevation, accuracy: 0.01)
    }
    func testLocationCalendarHandlesDSTAndPreDawn() async throws {
        let ny = ObservingLocation(id: "ny", name: "New York", latitude: 40.7128, longitude: -74.006, timeZoneID: "America/New_York")
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-01T08:00:00Z"))
        let days = SkyCalculator.days(location: ny, now: date)
        let beforeDST = try XCTUnwrap(days.first { $0.id == "2026-10-31" })
        XCTAssertEqual(beforeDST.nextNoon.timeIntervalSince(beforeDST.noon), 25 * 3600)
        let result = try await SkyCalculator.shared.forecast(location: ny, now: date, eveningFirst: true, orbit: nil)
        XCTAssertEqual(result.night(at: date)?.id, "2026-10-31")
        XCTAssertTrue(result.nights.allSatisfy { $0.end > $0.start })
    }
    func testPolarForecastDoesNotInventSunset() async throws {
        let loc = ObservingLocation(id: "polar", name: "Tromsø", latitude: 69.65, longitude: 18.96, timeZoneID: "Europe/Oslo")
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-06-21T12:00:00Z"))
        let result = try await SkyCalculator.shared.forecast(location: loc, now: date, eveningFirst: true, orbit: nil)
        XCTAssertTrue(result.nights.allSatisfy(\.polar))
        XCTAssertTrue(result.events.isEmpty)
    }
    func testSGP4AgainstValladoReferenceAndEarthShadow() throws {
        let ctx = try XCTUnwrap(JSContext())
        let url = try XCTUnwrap(Bundle.main.url(forResource: "SkyEngine", withExtension: "js"))
        ctx.evaluateScript(try String(contentsOf: url, encoding: .utf8))
        let result = ctx.evaluateScript("""
        (() => {
          const s = satellite.twoline2satrec('1 00005U 58002B   00179.78495062  .00000023  00000-0  28098-4 0  4753','2 00005  34.2682 348.7242 1859667 331.7664  19.3264 10.82419157413667');
          const p = satellite.propagate(s, new Date((s.jdsatepoch-2440587.5)*86400000)).position;
          return [p.x,p.y,p.z,satellite.shadowFraction({x:1,y:0,z:0},{x:-6800,y:0,z:0}),satellite.shadowFraction({x:1,y:0,z:0},{x:6800,y:0,z:0})];
        })()
        """)
        XCTAssertNil(ctx.exception)
        let values = try XCTUnwrap(result?.toArray() as? [Double])
        XCTAssertEqual(values[0],7022.46529266,accuracy:0.02)
        XCTAssertEqual(values[1],-1400.08296755,accuracy:0.02)
        XCTAssertEqual(values[2],0.03995155,accuracy:0.02)
        XCTAssertEqual(values[3],1)
        XCTAssertEqual(values[4],0)
    }
    func testWeatherExpiryCoverageAndMissingData() {
        let hour = WeatherHour(time: now, cloud: 10, precipitation: 0, wind: 5)
        let weather = WeatherForecast(hours: [hour], fetchedAt: now)
        XCTAssertNotNil(weather.sample(at: now, now: now))
        XCTAssertNil(weather.sample(at: now.addingTimeInterval(7200), now: now))
        XCTAssertNil(weather.sample(at: now, now: now.addingTimeInterval(7 * 3600)))
    }
    func testTimelineIncludesExpiryAndRemovesPastEvents() async throws {
        let snapshot = try await SkyCalculator.shared.forecast(location: .perth, now: now, eveningFirst: true, orbit: nil)
        let dates = SkyTimeline.dates(snapshot: snapshot, now: now)
        XCTAssertEqual(dates.first,now)
        XCTAssertEqual(dates.last,snapshot.validUntil)
        XCTAssertTrue(snapshot.ranked(at: snapshot.validUntil).isEmpty)
        XCTAssertEqual(Set(dates).count, dates.count)
        XCTAssertLessThan(dates.count,160)
        let data = try SkyJSON.encoder().encode(snapshot)
        let decoded = try SkyJSON.decoder().decode(SkySnapshot.self,from:data)
        XCTAssertEqual(decoded.events,snapshot.events)
    }
    func testExpiredOrbitNeverGeneratesISS() async throws {
        let orbit = OrbitData(line1: "invalid", line2: "invalid", epoch: now.addingTimeInterval(-8*86400), fetchedAt:now,source:"Test")
        let result = try await SkyCalculator.shared.forecast(location: .perth, now: now, eveningFirst: true, orbit: orbit)
        XCTAssertNil(result.orbit)
        XCTAssertFalse(result.events.contains { $0.kind == "iss" })
    }
}

extension SkyCoreTests {
    @MainActor func testColdEventLinkRestoresTimeAndLocation() async throws {
        let model = AppModel()
        let eventTime = Date().addingTimeInterval(3600)
        let url = try XCTUnwrap(URL(string: "skytonight://event?id=missing&location=perth&time=\(eventTime.timeIntervalSince1970)"))
        await model.open(url)
        XCTAssertEqual(model.selectedTab,1)
        XCTAssertEqual(try XCTUnwrap(model.previewTime).timeIntervalSince1970,eventTime.timeIntervalSince1970,accuracy:0.01)
        XCTAssertFalse(model.chart.isEmpty)
    }
    func testSunlitISSWindowsAndOrbitEpochLimit() async throws {
        let omm = """
        {"OBJECT_NAME":"ISS (ZARYA)","OBJECT_ID":"1998-067A","EPOCH":"2026-10-14T00:00:00.000000","MEAN_MOTION":15.5,"ECCENTRICITY":0.0005,"INCLINATION":51.64,"RA_OF_ASC_NODE":100,"ARG_OF_PERICENTER":30,"MEAN_ANOMALY":330,"EPHEMERIS_TYPE":0,"CLASSIFICATION_TYPE":"U","NORAD_CAT_ID":25544,"ELEMENT_SET_NO":999,"REV_AT_EPOCH":40000,"BSTAR":0.0001,"MEAN_MOTION_DOT":0.00001,"MEAN_MOTION_DDOT":0}
        """
        let epoch = try XCTUnwrap(SkyRepository.epoch("2026-10-14T00:00:00.000000"))
        let orbit = OrbitData(omm:omm,epoch:epoch,fetchedAt:now,source:"Synthetic test orbit")
        let result = try await SkyCalculator.shared.forecast(location:.perth,now:now,eveningFirst:true,orbit:orbit)
        let passes = result.events.filter { $0.kind == "iss" }
        XCTAssertFalse(passes.isEmpty)
        for pass in passes {
            XCTAssertGreaterThanOrEqual(pass.elevation,20)
            XCTAssertGreaterThanOrEqual(pass.end.timeIntervalSince(pass.start),60)
            XCTAssertLessThanOrEqual(pass.end,epoch.addingTimeInterval(7*86400))
            XCTAssertTrue(pass.points.allSatisfy { $0.sunlit && $0.elevation > 0 })
        }
    }
    func testCacheRefusesAnOlderConcurrentPublication() async throws {
        var snapshot = try await SkyCalculator.shared.forecast(location:.perth,now:now,eveningFirst:true,orbit:nil)
        snapshot.location.id = "test-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(at: SkyStore.snapshotURL(snapshot.location)) }
        var newer = snapshot; newer.generatedAt = now.addingTimeInterval(60)
        try SkyStore.write(newer)
        try SkyStore.write(snapshot)
        XCTAssertEqual(SkyStore.read(snapshot.location)?.generatedAt,newer.generatedAt)
    }
}

extension SkyCoreTests {
    func testMeteorPreviewIncludesRadiant() async throws {
        let snapshot = try await SkyCalculator.shared.forecast(location:.perth,now:now,eveningFirst:false,orbit:nil)
        let event = try XCTUnwrap(snapshot.events.first { $0.kind == "meteor" })
        let chart = try await SkyCalculator.shared.chart(location:.perth,time:event.focus,orbit:nil,target:event)
        let radiant = try XCTUnwrap(chart.first { $0.id == event.id })
        XCTAssertEqual(radiant.elevation,event.elevation,accuracy:0.01)
    }
    @MainActor func testISSIconAvailable() {
        XCTAssertNotNil(UIImage(systemName:"point.topleft.down.to.point.bottomright.curvepath"))
    }
}


extension SkyCoreTests {
    @MainActor func testPlanetArtworkAssetsAndLayouts() async throws {
        var snapshot = try await SkyCalculator.shared.forecast(location: .perth, now: now, eveningFirst: true, orbit: nil)
        let template = try XCTUnwrap(snapshot.ranked(at: now).first { $0.kind == "planet" })
        let extensionURL = try XCTUnwrap(Bundle.main.builtInPlugInsURL?.appendingPathComponent("SkyWidgets.appex"))
        let widgetBundle = try XCTUnwrap(Bundle(url: extensionURL))
        XCTAssertNotNil(UIImage(named: "WidgetISS"))
        XCTAssertNotNil(UIImage(named: "WidgetISS", in: widgetBundle, compatibleWith: nil))
        for planet in WidgetPlanet.allCases {
            XCTAssertNotNil(UIImage(named: planet.assetName), "Missing app preview asset: \(planet)")
            XCTAssertNotNil(UIImage(named: planet.assetName, in: widgetBundle, compatibleWith: nil), "Missing widget asset: \(planet)")
            var event = template; event.body = planet.rawValue; event.title = planet.rawValue
            XCTAssertEqual(WidgetPlanet(event: event), planet)
            snapshot.events = [event]
            let entry = SkyEntry(date: now, snapshot: snapshot, location: .perth)
            for family in [WidgetFamily.systemSmall, .systemMedium] {
                var rendered: [Data] = []
                for scheme in [ColorScheme.light, .dark] {
                    let view = SkyWidgetView(previewFamily: family, entry: entry, issOnly: false)
                        .padding(16).frame(width: family == .systemSmall ? 170 : 350, height: 170)
                        .background(Color(red: 0.07, green: 0.13, blue: 0.22))
                        .environment(\.widgetRenderingMode, .fullColor).environment(\.colorScheme, scheme)
                    let renderer = ImageRenderer(content: view); renderer.scale = 3
                    let image = try XCTUnwrap(renderer.uiImage)
                    rendered.append(try XCTUnwrap(image.pngData()))
                    if scheme == .light {
                        let attachment = XCTAttachment(image: image)
                        attachment.name = "\(planet.rawValue) - \(family)"; attachment.lifetime = .keepAlways; add(attachment)
                    }
                }
                XCTAssertEqual(rendered[0], rendered[1], "\(planet) / \(family): appearance changed")
            }
        }
        var unsupported = template; unsupported.body = "Neptune"
        XCTAssertNil(WidgetPlanet(event: unsupported))
        unsupported.body = "Saturn"; unsupported.kind = "iss"
        XCTAssertNil(WidgetPlanet(event: unsupported))
    }

    @MainActor func testHomeWidgetRenderingMatchesAcrossLightAndDarkAppearance() async throws {
        var snapshot = try await SkyCalculator.shared.forecast(location: .perth, now: now, eveningFirst: true, orbit: nil)
        // A valid orbit with no ISS event exercises the same empty state as the reported screenshot.
        snapshot.orbit = OrbitData(epoch: now, fetchedAt: now, source: "Rendering fixture")
        let populated = SkyEntry(date: now, snapshot: snapshot, location: .perth)
        let unavailable = SkyEntry(date: now, snapshot: nil, location: .perth)
        for family in [WidgetFamily.systemSmall, .systemMedium] {
            for (name, entry, issOnly) in [("Tonight", populated, false), ("No ISS pass", populated, true), ("Unavailable", unavailable, true)] {
                func render(_ scheme: ColorScheme) throws -> UIImage {
                    let content = SkyWidgetView(previewFamily: family, entry: entry, issOnly: issOnly)
                        .padding(16).frame(width: family == .systemSmall ? 170 : 350, height: 170)
                        .background(Color(red: 0.07, green: 0.13, blue: 0.22))
                        .environment(\.widgetRenderingMode, .fullColor)
                        .environment(\.colorScheme, scheme)
                    let renderer = ImageRenderer(content: content); renderer.scale = 2
                    return try XCTUnwrap(renderer.uiImage)
                }
                let light = try render(.light), dark = try render(.dark)
                let lightBytes = try XCTUnwrap(light.pngData()), darkBytes = try XCTUnwrap(dark.pngData())
                XCTAssertTrue(lightBytes == darkBytes, "\(name) / \(family): dark-card content changed with the phone appearance")
                let attachment = XCTAttachment(image: light)
                attachment.name = "\(name) - \(family) - light appearance"
                attachment.lifetime = .keepAlways; add(attachment)
            }
        }
    }
}
