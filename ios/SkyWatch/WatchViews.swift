import SwiftUI
import WatchKit

extension Color {
    static let watchMint = Color(red: 0.36, green: 0.91, blue: 0.81)
    static let watchButton = Color(red: 0.15, green: 0.16, blue: 0.27)
}

struct WatchRootView: View {
    @EnvironmentObject private var model: WatchModel
    var body: some View {
        NavigationStack(path: $model.route) {
            GeometryReader { geometry in
                // Account for native header and rounded bottom clearance, and
                // leave a strip below the primary action for the page dots.
                let faceSize = CGSize(width: geometry.size.width,
                    height: max(100, WKInterfaceDevice.current().screenBounds.height
                        - geometry.frame(in: .global).minY - (geometry.size.width < 180 ? 12 : 18)))
                // The pager and its scroll views have stable lifetimes. Only live labels tick.
                TabView(selection: $model.page) {
                    WatchTonightPage(size: faceSize, selected: model.page == 0).tag(0)
                    WatchISSPage(size: faceSize, selected: model.page == 1).tag(1)
                }.tabViewStyle(.page(indexDisplayMode: .always))
            }
            .background { WatchFaceBackground() }
            .navigationTitle("")
            .toolbar { ToolbarItem(placement: .topBarLeading) {
                Text(model.page == 0 ? "Tonight" : "Next ISS").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.watchMint).offset(y: -9)
            } }
            .toolbarTitleDisplayMode(.inline)
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
    @Environment(\.scenePhase) private var phase
    @State private var now = Date()
    var size: CGSize
    var selected: Bool
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let snapshot = model.snapshot(at: model.displayDate(now)) {
                    let events = snapshot.ranked(at: model.displayDate(now))
                    if let event = events.first {
                        WatchTonightFace(event: event, size: size)
                        VStack(spacing: 4) {
                            Text("At \(snapshot.location.time(event.focus))").font(.caption).foregroundStyle(.secondary)
                            WatchPlaceFooter(compact: true)
                            #if DEBUG
                            if ProcessInfo.processInfo.arguments.contains("--stress-sync") {
                                Text("Sync revision \(model.package?.revision ?? 0)").accessibilityIdentifier("stressSync")
                            }
                            #endif
                            if events.count > 1 {
                                Text("More tonight").font(.caption.weight(.semibold)).foregroundStyle(Color.watchMint)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                ForEach(Array(events.dropFirst().prefix(4))) { other in
                                    WatchEventCard(title: other.title,
                                        detail: "\(snapshot.location.time(other.focus)) · \(other.direction)", destination: other.id)
                                }
                            }
                        }
                    } else {
                        WatchEmptyView(title: "A quiet sky", detail: "No remaining highlights for this observing night.")
                        WatchPlaceFooter()
                    }
                    NavigationLink("Moon & conditions", value: "moon").accessibilityIdentifier("moonDetails")
                } else if model.loading { ProgressView("Loading your sky") }
                else { WatchSetupView() }
            }.padding(.horizontal, 10).padding(.bottom, 20)
        }.scrollIndicators(.hidden).contentMargins(.top, -10, for: .scrollContent)
            .modifier(WatchPageRefresh(date: $now, active: selected && phase == .active))
    }
}

private struct WatchTonightFace: View {
    var event: SkyEvent
    var size: CGSize
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .title2) private var titleSize = 28.0
    @ScaledMetric(relativeTo: .body) private var subtitleSize = 16.0
    private var compact: Bool { size.width < 180 }
    var body: some View {
        let height = max(100, size.height * (textSize.isAccessibilitySize ? 1 : 0.65))
        NavigationLink(value: event.id) {
            ZStack(alignment: .topLeading) {
                if let asset = event.artworkAsset {
                    GeometryReader { geometry in
                        Image(asset).resizable().scaledToFit()
                            .frame(width: geometry.size.width * (event.body == "Saturn" ? 1.7 : 1.05),
                                   height: event.body == "Saturn" ? nil : geometry.size.height * 0.8)
                            .rotationEffect(.degrees(event.body == "Saturn" ? -12 : 0))
                            .position(x: geometry.size.width * 0.72,
                                      y: geometry.size.height * (event.body == "Saturn" ? 0.67 : 0.56))
                            .blendMode(.screen)
                    }.accessibilityHidden(true).allowsHitTesting(false)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title).font(.system(size: titleSize * (compact ? 0.84 : 1), weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(event.direction) · \(Int(event.elevation.rounded()))°")
                        .font(.system(size: subtitleSize * (compact ? 0.9 : 1), weight: .medium)).foregroundStyle(.white.opacity(0.76))
                    Spacer(minLength: compact ? 34 : 60)
                }
            }.frame(minHeight: height, alignment: .top)
                .clipped()
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel("\(event.title), \(event.direction), \(Int(event.elevation.rounded())) degrees")
            .accessibilityHint(event.kind == "iss" ? "Opens the ISS path" : "Opens guidance to find this object")
            .accessibilityIdentifier("findIt")
    }
}

struct WatchISSPage: View {
    @EnvironmentObject private var model: WatchModel
    @Environment(\.scenePhase) private var phase
    @State private var now = Date()
    var size: CGSize
    var selected: Bool
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if let snapshot = model.snapshot(at: model.displayDate(now)) {
                    let passes = snapshot.ranked(at: model.displayDate(now), issOnly: true)
                    if let event = passes.first, WatchObservation.event(event, usableIn: snapshot, at: model.displayDate(now)) {
                        WatchISSFace(event: event, size: size, active: selected)
                        VStack(spacing: 12) {
                            Text("\(snapshot.location.day(event.start)) · \(snapshot.location.time(event.start))").font(.caption).foregroundStyle(.secondary)
                            WatchPlaceFooter()
                            #if DEBUG
                            if ProcessInfo.processInfo.arguments.contains("--stress-sync") {
                                Text("Sync revision \(model.package?.revision ?? 0)").accessibilityIdentifier("stressSync")
                            }
                            #endif
                            if let notice = snapshot.orbitMessage { Text(notice).font(.caption).foregroundStyle(.secondary) }
                            ForEach(Array(passes.dropFirst().prefix(3))) { pass in
                                WatchEventCard(title: snapshot.location.day(pass.start),
                                    detail: "\(snapshot.location.time(pass.start)) · \(pass.direction)", destination: pass.id)
                            }
                        }
                    } else {
                        WatchEmptyView(title: snapshot.orbit?.usable(at: now) == true ? "No visible pass" : "ISS data unavailable",
                            detail: snapshot.orbit?.usable(at: now) == true ? "No sunlit pass meets the viewing criteria in this forecast." : "Refresh from iPhone for current orbital data.")
                        WatchPlaceFooter()
                        Button("Refresh") { model.requestRefresh(force: true) }
                    }
                } else if model.loading { ProgressView("Loading your sky") }
                else { WatchSetupView() }
            }.padding(.horizontal, 10).padding(.bottom, 20)
        }.scrollIndicators(.hidden).contentMargins(.top, -10, for: .scrollContent)
            .modifier(WatchPageRefresh(date: $now, active: selected && phase == .active))
    }
}

private struct WatchISSFace: View {
    @EnvironmentObject private var model: WatchModel
    @Environment(\.dynamicTypeSize) private var textSize
    var event: SkyEvent
    var size: CGSize
    var active: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize = 56.0
    @ScaledMetric(relativeTo: .body) private var bodySize = 16.0
    var body: some View {
        let compact = size.width < 180
        VStack(alignment: .leading, spacing: compact ? 1 : 2) {
            Image("WidgetISS").renderingMode(.template).resizable().scaledToFit()
                .frame(width: 42, height: compact ? 14 : 22).foregroundStyle(Color.watchMint).accessibilityHidden(true)
            WatchLiveClock(active: active) { tick in
                let now = model.displayDate(tick)
                let live = now >= event.start && now < event.end
                VStack(alignment: .leading, spacing: 2) {
                    Text(live ? "Visible now" : WatchObservation.countdown(to: event.start, now: now))
                        .font(.system(size: countdownSize * (compact ? 0.76 : 1) * (live ? 0.65 : 1), weight: .bold))
                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(height: countdownSize * (compact ? 0.76 : 1) * 0.9)
                        .accessibilityIdentifier("issCountdown")
                    Text(live ? "above the horizon" : "until visible").font(.system(size: bodySize * (compact ? 0.77 : 0.88))).foregroundStyle(.white.opacity(0.74))
                    let bearing = live ? WatchObservation.point(in: event, at: now)?.azimuth : event.points.first?.azimuth
                    Text("Look \(WatchBearing.name(bearing ?? event.azimuth).lowercased())")
                        .font(.system(size: bodySize * (compact ? 0.88 : 1), weight: .medium)).padding(.top, compact ? 2 : 4)
                    // Fill during the final three minutes before visibility, then track the live pass.
                    let progress = live ? now.timeIntervalSince(event.start) / max(1, event.end.timeIntervalSince(event.start)) : 1 - event.start.timeIntervalSince(now) / 180
                    GeometryReader { geometry in
                        Capsule().fill(Color.white.opacity(0.18))
                        Capsule().fill(Color.watchMint).frame(width: geometry.size.width * min(1, max(0, progress)))
                    }.frame(height: 4).accessibilityElement(children: .ignore)
                        .accessibilityLabel(live ? "Pass progress" : "Final three minutes until visible")
                        .accessibilityValue("\(Int(min(1, max(0, progress)) * 100)) percent")
                        .padding(.top, compact ? 3 : 5)

                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 3)
            NavigationLink(value: event.id) { Text("View path").frame(maxWidth: .infinity) }
                .buttonStyle(WatchPrimaryStyle()).accessibilityIdentifier("viewPath")
        }.frame(minHeight: max(100, size.height) * (textSize.isAccessibilitySize ? 1.25 : 1), alignment: .topLeading)
    }
}

/// Timer state belongs to the live leaf, never to the pager, scroll view or navigation stack.
struct WatchLiveClock<Content: View>: View {
    @Environment(\.scenePhase) private var phase
    @Environment(\.isLuminanceReduced) private var dimmed
    @State private var date = Date()
    var active = true
    @ViewBuilder var content: (Date) -> Content
    var body: some View {
        content(date).task(id: active && phase == .active && !dimmed) {
            guard active && phase == .active && !dimmed else { return }
            while !Task.isCancelled {
                date = Date()
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }
}

private struct WatchPageRefresh: ViewModifier {
    @Binding var date: Date
    var active: Bool
    func body(content: Content) -> some View {
        content.task(id: active) {
            guard active else { return }
            while !Task.isCancelled {
                date = Date()
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
    }
}

struct WatchFaceBackground: View {
    var horizon = false
    var body: some View {
        GeometryReader { geometry in
            Image(horizon ? "WatchHorizon" : "WatchMidnight").resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(horizon ? 1.12 : 1, anchor: .bottom).clipped()
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct WatchPrimaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.headline, weight: .semibold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(Color.watchButton.opacity(configuration.isPressed ? 0.65 : 1), in: Capsule())
            .contentShape(Capsule())
    }
}

struct WatchBackButton: View {
    @EnvironmentObject private var model: WatchModel
    var title: String
    var body: some View {
        Button { if !model.route.isEmpty { model.route.removeLast() } } label: {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                Text(title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
            }.frame(minHeight: 32)
        }.buttonStyle(.plain).foregroundStyle(Color.watchMint)
            .offset(y: -9).accessibilityLabel("Back").accessibilityIdentifier("watchBack")
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
