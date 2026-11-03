import SwiftUI
import WatchKit

extension Color { static let watchMint = Color(red: 0.34, green: 0.9, blue: 0.76) }

struct WatchRootView: View {
    @EnvironmentObject private var model: WatchModel
    @Environment(\.scenePhase) private var phase
    @Environment(\.isLuminanceReduced) private var dimmed
    var body: some View {
        NavigationStack(path: $model.route) {
            GeometryReader { geometry in
                TimelineView(.periodic(from: .now, by: dimmed || phase != .active ? 60 : 1)) { context in
                    TabView(selection: $model.page) {
                        WatchTonightPage(now: context.date, compact: geometry.size.width < 180).tag(0)
                        WatchISSPage(now: context.date, compact: geometry.size.width < 180).tag(1)
                    }.tabViewStyle(.page(indexDisplayMode: .always))
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(model.page == 0 ? "Tonight" : "Next ISS").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white).lineLimit(1).offset(y: -9)
                }
            }
            .navigationDestination(for: String.self) { route in
                if route == "places" { WatchPlacesView() }
                else if route == "moon" { WatchMoonView() }
                else { WatchEventView(eventID: route) }
            }
            .alert("Sky Tonight", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
                Button("OK") { model.message = nil }
            } message: { Text(model.message ?? "") }
        }
    }
}

struct WatchTonightPage: View {
    @EnvironmentObject private var model: WatchModel
    var now: Date
    var compact = false
    @ScaledMetric(relativeTo: .largeTitle) private var largeType = 72.0
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let snapshot = model.snapshot(at: now) {
                    let events = snapshot.ranked(at: now)
                    if let event = events.first {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 4) {
                                WatchArtwork(event: event, prominent: true).frame(width: compact ? 72 : 94, height: compact ? 32 : 42)
                                Text(event.title).font(.system(size: (compact ? 19 : 23) * textScale, weight: .bold))
                                    .fixedSize(horizontal: true, vertical: true)
                            }
                            VStack(spacing: 4) {
                                WatchArtwork(event: event, prominent: true).frame(width: 94, height: 42)
                                Text(event.title).font(.system(size: (compact ? 19 : 23) * textScale, weight: .bold))
                                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                            }
                        }.frame(maxWidth: .infinity)
                        Text(event.direction).lineLimit(1).minimumScaleFactor(0.5).fixedSize(horizontal: false, vertical: true).font(.system(size: largeType * (compact ? 0.78 : 1), weight: .bold, design: .rounded)).foregroundStyle(Color.watchMint)
                            .frame(height: largeType * (compact ? 0.78 : 1) * 0.94)
                        Text("\(Int(event.elevation.rounded()))° high").font(.system(size: (compact ? 21 : 24) * textScale, weight: .semibold)).padding(.bottom, compact ? 3 : 6)
                        NavigationLink(value: event.id) {
                            Label(event.kind == "iss" ? "View path" : "Find it", systemImage: "location.fill").frame(maxWidth: .infinity, minHeight: 30)
                        }.buttonStyle(WatchPrimaryStyle()).accessibilityIdentifier("findIt")
                        .padding(.horizontal, compact ? 4 : 10)
                        Text("At \(snapshot.location.time(event.focus))").font(.caption).foregroundStyle(.secondary).padding(.top, 28)
                        WatchPlaceFooter(now: now)
                        if events.count > 1 {
                            Divider().padding(.vertical, 8)
                            Text("MORE TONIGHT").font(.caption2).foregroundStyle(.secondary)
                            ForEach(Array(events.dropFirst().prefix(4))) { event in
                                NavigationLink(value: event.id) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(event.title).font(.headline)
                                        Text("\(snapshot.location.time(event.focus)) · \(event.direction)").font(.caption).foregroundStyle(.secondary)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    } else {
                        WatchEmptyView(title: "A quiet sky", detail: "No remaining highlights for this observing night.")
                        WatchPlaceFooter(now: now)
                    }
                    NavigationLink("Moon & conditions", value: "moon").accessibilityIdentifier("moonDetails")
                } else { WatchSetupView() }
            }.padding(.horizontal, 4).padding(.bottom, 24)
        // Reclaim the unused second-title row while retaining the system clock inset.
        }.contentMargins(.top, -18, for: .scrollContent).watchScrollEdges()
    }
}

struct WatchISSPage: View {
    @EnvironmentObject private var model: WatchModel
    var now: Date
    var compact = false
    @ScaledMetric(relativeTo: .largeTitle) private var largeType = 58.0
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let snapshot = model.snapshot(at: now) {
                    if let event = snapshot.ranked(at: now, issOnly: true).first,
                       WatchObservation.event(event, usableIn: snapshot, at: now) {
                        let live = now >= event.start && now < event.end
                        WatchArtwork(event: event).frame(height: compact ? 46 : 62)
                        Text(live ? "Visible now" : WatchObservation.countdown(to: event.start, now: now))
                            .font(.system(size: (live ? largeType * 0.65 : largeType) * (compact ? 0.78 : 1), weight: .bold, design: .rounded))
                            .monospacedDigit().minimumScaleFactor(0.6).lineLimit(1).fixedSize(horizontal: false, vertical: true).foregroundStyle(Color.watchMint)
                            .frame(height: largeType * (compact ? 0.78 : 1) * 0.83)
                        if !live { Text("until visible").font(.system(size: (compact ? 12 : 14) * textScale)).foregroundStyle(.white) }
                        let bearing = live ? WatchObservation.point(in: event, at: now)?.azimuth : event.points.first?.azimuth
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up").rotationEffect(.degrees(bearing ?? event.azimuth)).foregroundStyle(Color.watchMint).accessibilityHidden(true)
                            Text(WatchBearing.name(bearing ?? event.azimuth))
                        }.font(.system(size: (compact ? 17 : 21) * textScale, weight: .bold))
                        NavigationLink(value: event.id) {
                            Label(live ? "Track now" : "View path", systemImage: "point.topleft.down.to.point.bottomright.curvepath").frame(maxWidth: .infinity, minHeight: 30)
                        }.buttonStyle(WatchPrimaryStyle()).accessibilityIdentifier("viewPath")
                        .padding(.horizontal, compact ? 4 : 10)
                        Text("\(snapshot.location.day(event.start)) · \(snapshot.location.time(event.start))").font(.caption).foregroundStyle(.secondary).padding(.top, 28)
                        WatchPlaceFooter(now: now)
                        if let notice = snapshot.orbitMessage { Text(notice).font(.caption).foregroundStyle(.secondary) }
                        ForEach(Array(snapshot.ranked(at: now, issOnly: true).dropFirst().prefix(3))) { pass in
                            NavigationLink(value: pass.id) {
                                Text("\(snapshot.location.day(pass.start)) · \(snapshot.location.time(pass.start))").font(.caption)
                            }
                        }
                    } else {
                        WatchEmptyView(title: snapshot.orbit?.usable(at: now) == true ? "No visible pass" : "ISS data unavailable",
                            detail: snapshot.orbit?.usable(at: now) == true ? "No sunlit pass meets the viewing criteria in this forecast." : "Refresh from iPhone for current orbital data.")
                        WatchPlaceFooter(now: now)
                        Button("Refresh") { model.requestRefresh(force: true) }
                    }
                } else { WatchSetupView() }
            }.padding(.horizontal, 4).padding(.bottom, 24)
        }.contentMargins(.top, -24, for: .scrollContent).watchScrollEdges()
    }
}

/// Keep the first face crisp; restore the system fade as details scroll beneath the header.
private struct WatchScrollEdgeModifier: ViewModifier {
    @State private var isAtTop = true
    @ViewBuilder func body(content: Content) -> some View {
        if #available(watchOS 26.0, *) {
            content
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top <= 1
                } action: { _, atTop in isAtTop = atTop }
                .scrollEdgeEffectHidden(isAtTop, for: .top)
        } else { content }
    }
}

extension View {
    func watchScrollEdges() -> some View { modifier(WatchScrollEdgeModifier()) }
}

/// Compact title/back control leaves room for the system clock without a second header row.
struct WatchBackButton: View {
    @EnvironmentObject private var model: WatchModel
    var title: String
    var body: some View {
        Button { if !model.route.isEmpty { model.route.removeLast() } } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                Text(title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
            }.frame(minHeight: 32).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(.white).offset(y: -9)
            .accessibilityLabel("Back").accessibilityIdentifier("watchBack")
    }
}

enum WatchBearing {
    static func name(_ azimuth: Double) -> String {
        guard azimuth.isFinite else { return "Direction unavailable" }
        let names = ["North", "Northeast", "East", "Southeast", "South", "Southwest", "West", "Northwest"]
        let normalized = (azimuth.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return names[Int((normalized / 45).rounded()) % names.count]
    }
}

struct WatchPrimaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.headline, design: .default, weight: .semibold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.white.opacity(configuration.isPressed ? 0.25 : 0.14), in: Capsule())
    }
}

struct WatchPlaceFooter: View {
    @EnvironmentObject private var model: WatchModel
    var now: Date
    var body: some View {
        VStack(spacing: 5) {
            NavigationLink(value: "places") { Label(model.location?.name ?? "Observing place", systemImage: "mappin.and.ellipse").font(.caption) }
                .buttonStyle(.plain).padding(.vertical, 8).accessibilityIdentifier("observingPlace")
            if model.isPreview { Text("Sample data").font(.caption2).foregroundStyle(.secondary) }
            else if let sent = model.package?.sentAt {
                Text("Synced \(sent, style: .relative) ago").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
struct WatchEmptyView: View {
    var title: String
    var detail: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.stars").font(.largeTitle).foregroundStyle(Color.watchMint)
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }.multilineTextAlignment(.center).padding(.vertical, 12)
    }
}
struct WatchSetupView: View {
    @EnvironmentObject private var model: WatchModel
    var body: some View {
        WatchEmptyView(title: model.package == nil ? "Your sky, on your wrist" : "Forecast needs a refresh",
                       detail: model.package == nil ? "Open Sky Tonight on your paired iPhone and choose an observing place. Its forecast will appear here." : "Open Sky Tonight on iPhone to refresh this place. Saved events won't be shown as current after they expire.")
        Button("Request forecast") { model.requestRefresh(force: true) }.accessibilityIdentifier("requestForecast")
        if model.package != nil { NavigationLink("Observing places", value: "places") }
    }
}
struct WatchArtwork: View {
    var event: SkyEvent
    var prominent = false
    var body: some View {
        if let asset = event.artworkAsset { Image(asset).resizable().scaledToFit()
            .scaleEffect(prominent && event.body == "Saturn" ? 1.45 : 1)
            .clipped().accessibilityHidden(true) }
        else { Image(systemName: event.symbol).font(.title2).foregroundStyle(Color.watchMint).accessibilityHidden(true) }
    }
}
struct WatchPlacesView: View {
    @EnvironmentObject private var model: WatchModel
    @State private var setupHandoff = false
    var body: some View {
        List {
            ForEach(model.package?.locations ?? []) { location in
                Button { model.select(location.id) } label: {
                    HStack { Text(location.name); Spacer(); if location.id == model.selectedID { Image(systemName: "checkmark").foregroundStyle(Color.watchMint) } }
                }
            }
            Text("Add or edit places on iPhone. Directions are calculated for the selected place.").font(.caption).foregroundStyle(.secondary)
            Text(model.package?.eveningFirst == true ? "Evening-first recommendations" : "All-night recommendations").font(.caption)
            Button("Refresh from iPhone") { model.requestRefresh(force: true) }
            Button("Set up on iPhone") { setupHandoff = true }
            if setupHandoff { Text("Open the Sky Tonight Handoff suggestion in your iPhone's app switcher to see settings and enable reminders.").font(.caption) }
            if !model.pending.isEmpty {
                Text("\(model.pending.count) reminder request(s) awaiting iPhone confirmation.").font(.caption)
            }
            Section("About") {
                Link("Privacy", destination: URL(string: "https://iss-flyover.pages.dev/privacy.html")!)
                Link("Support", destination: URL(string: "https://iss-flyover.pages.dev/support.html")!)
                Text("Artwork: NASA; Jupiter: NASA / JPL-Caltech / SwRI / MSSS / Kevin M. Gill (CC BY). Images are illustrative spacecraft views.").font(.caption2)
            }
        }.navigationTitle("Places")
            .userActivity(WatchObservation.activityType, isActive: setupHandoff) { activity in
                activity.title = "Sky Tonight settings"
                activity.userInfo = ["url": "skytonight://settings"]
                activity.isEligibleForHandoff = true
            }
            .onDisappear { setupHandoff = false }
    }
}
struct WatchMoonView: View {
    @EnvironmentObject private var model: WatchModel
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let snapshot = model.snapshot(), let night = snapshot.night(at: Date()) {
                    Image(systemName: WatchObservation.moonSymbol(night.moonPhase)).font(.system(size: 48)).foregroundStyle(Color.watchMint).accessibilityHidden(true)
                    Text("\(night.moonPercent)% lit").font(.title2.bold())
                    Text(night.moonName).font(.headline)
                    Text(snapshot.location.day(night.start)).font(.caption).foregroundStyle(.secondary)
                    if let dark = night.dark { Text("Dark from \(snapshot.location.time(dark))").font(.caption) }
                    if let dawn = night.dawn { Text("Dawn \(snapshot.location.time(dawn))").font(.caption) }
                    Divider()
                    if model.package?.weatherEnabled == true,
                       let weather = snapshot.weather, let sample = weather.sample(at: Date(), now: Date()), let credit = weather.credit {
                        Text("\(Int(sample.cloud))% cloud").font(.headline)
                        Text("Wind \(Int(sample.wind)) km/h").font(.caption)
                        WeatherCreditView(credit: credit)
                    } else {
                        Text(model.package?.weatherEnabled == true ? "Current weather unavailable" : "Optional weather can be enabled on iPhone").font(.caption).foregroundStyle(.secondary)
                    }
                    WatchPlaceFooter(now: Date())
                } else { WatchSetupView() }
            }.padding(.horizontal, 4)
        }.navigationTitle("Moon")
    }
}
