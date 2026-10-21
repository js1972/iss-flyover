import SwiftUI

extension Color {
    static let skyBase = Color(red: 0.035, green: 0.065, blue: 0.12)
    static let skyPanel = Color(red: 0.07, green: 0.11, blue: 0.18)
    static let skyMint = Color(red: 0.43, green: 0.9, blue: 0.78)
}
struct Panel: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.skyPanel, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.07)))
    }
}
extension View { func skyPanel() -> some View { modifier(Panel()) } }
struct RootView: View {
    @EnvironmentObject var model: AppModel
    @ViewBuilder var home: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--widget-preview") { WidgetPreview() } else { TonightView() }
        #else
        TonightView()
        #endif
    }
    var body: some View {
        TabView(selection: $model.selectedTab) {
            home.tabItem { Label("Tonight", systemImage: "moon.stars.fill") }.tag(0)
            SkyChartScreen().tabItem { Label("Sky", systemImage: "sparkles") }.tag(1)
            UpcomingView().tabItem { Label("Upcoming", systemImage: "calendar") }.tag(2)
            SettingsView().tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(3)
        }
        .tint(.skyMint)
        .alert("Sky Tonight", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("OK") { model.message = nil }
        } message: { Text(model.message ?? "") }
    }
}
struct TonightView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let wide = geometry.size.width >= 900 && !typeSize.isAccessibilitySize
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        TonightHeader()
                        if let snapshot = model.snapshot {
                            let picks = snapshot.ranked(at: Date())
                            if wide {
                                HStack(alignment: .top, spacing: 28) {
                                    VStack(alignment: .leading, spacing: 22) { featured(picks); conditions(snapshot); nightAhead(snapshot, picks: picks) }
                                        .frame(maxWidth: .infinity)
                                    VStack(alignment: .leading, spacing: 22) { recommendations(picks) }
                                        .frame(maxWidth: .infinity)
                                }
                            } else {
                                featured(picks)
                                conditions(snapshot)
                                recommendations(picks)
                                nightAhead(snapshot, picks: picks)
                            }
                            if let message = snapshot.orbitMessage { Label(message, systemImage: "point.topleft.down.to.point.bottomright.curvepath").font(.footnote).foregroundStyle(.secondary) }
                            Text("Times in \(model.location.timeZoneID) · Calculated \(model.location.time(snapshot.generatedAt))").font(.caption).foregroundStyle(.secondary)
                        } else {
                            ProgressView("Calculating your sky…").frame(maxWidth: .infinity).padding(.vertical, 80)
                        }
                    }.padding(geometry.size.width >= 600 ? 32 : 20)
                        .frame(maxWidth: 1180).frame(maxWidth: .infinity)
                }.refreshable { await model.refresh() }
            }.background(Color.skyBase).toolbar(.hidden, for: .navigationBar)
        }
    }
    @ViewBuilder private func featured(_ picks: [SkyEvent]) -> some View {
        if let best = picks.first { TonightPickCard(event: best) }
        else { ContentUnavailableView("A quiet sky", systemImage: "moon.stars", description: Text("No remaining highlights in this observing window. Browse Upcoming for the next night.")) }
    }
    @ViewBuilder private func conditions(_ snapshot: SkySnapshot) -> some View {
        if let night = snapshot.night(at: Date()) { ConditionsView(snapshot: snapshot, night: night) }
    }
    @ViewBuilder private func recommendations(_ picks: [SkyEvent]) -> some View {
        if picks.count > 1 {
            Text("Worth stepping outside for").font(.title3.bold())
            ForEach(Array(picks.dropFirst().prefix(4))) { event in EventRow(event: event) }
        }
    }
    @ViewBuilder private func nightAhead(_ snapshot: SkySnapshot, picks: [SkyEvent]) -> some View {
        if let night = snapshot.night(at: Date()) {
            VStack(alignment: .leading, spacing: 14) {
                Text("THE NIGHT AHEAD").font(.caption.weight(.bold)).tracking(1).foregroundStyle(Color.skyMint)
                if let sunset = night.sunset { MomentRow(time: model.location.time(sunset), title: "Sunset", symbol: "sunset.fill") }
                if let dark = night.dark { MomentRow(time: model.location.time(dark), title: "Astronomical dark", symbol: "moon.stars.fill") }
                ForEach(Array(picks.prefix(3)).sorted { $0.focus < $1.focus }) { event in
                    Button { model.preview(event) } label: { MomentRow(time: model.location.time(event.focus), title: event.title, symbol: event.symbol) }.buttonStyle(.plain)
                }
                if let sunrise = night.sunrise { MomentRow(time: model.location.time(sunrise), title: "Sunrise", symbol: "sunrise.fill") }
                if night.polar { Text("This location has no usual sunrise or sunset in this period.").font(.footnote).foregroundStyle(.secondary) }
            }.skyPanel()
        }
    }
}
struct MomentRow: View {
    var time: String; var title: String; var symbol: String
    var body: some View { HStack(spacing: 14) { Text(time).font(.subheadline.monospacedDigit()).foregroundStyle(Color.skyMint).frame(width: 52, alignment: .leading); Image(systemName: symbol).frame(width: 20); Text(title).font(.subheadline); Spacer() } }
}
struct ConditionsView: View {
    @EnvironmentObject private var model: AppModel
    var snapshot: SkySnapshot
    var night: ObservingNight
    var body: some View {
        let sample = snapshot.weather?.sample(at: snapshot.ranked(at: Date()).first?.focus ?? max(Date(), night.start), now: Date())
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) { moon; weather(sample) }
                VStack(alignment: .leading, spacing: 20) { moon; weather(sample) }
            }
            if let weather = snapshot.weather, sample != nil, let credit = weather.credit {
                HStack { WeatherCreditView(credit: credit); Spacer(); Text("Data sources ↗").font(.caption).foregroundStyle(.secondary).accessibilityHidden(true) }
            } else if !model.weatherEnabled {
                Button("Add Apple Weather") { model.selectedTab = 3 }
                    .font(.subheadline).accessibilityIdentifier("enableWeatherSettings")
            } else {
                Text(snapshot.weatherMessage ?? "Weather will appear after a successful refresh.").font(.caption).foregroundStyle(.secondary)
            }
        }.skyPanel()
    }
    private var moon: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("MOONLIGHT", systemImage: "moon.fill").font(.caption2.weight(.bold)).foregroundStyle(Color.skyMint)
            Text("\(night.moonPercent)% lit").font(.title2.bold())
            Text(night.moonName).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func weather(_ sample: WeatherHour?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("CLOUD COVER", systemImage: "cloud.fill").font(.caption2.weight(.bold)).foregroundStyle(Color.skyMint)
            Text(sample.map { "\(Int($0.cloud))%" } ?? "—").font(.title2.bold())
            Text(sample.map { "Wind \(Int($0.wind)) km/h" } ?? (model.weatherEnabled ? "Unavailable" : "Weather is off")).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct EventRow: View {
    @EnvironmentObject var model: AppModel
    var event: SkyEvent
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { model.preview(event) } label: {
                HStack(alignment: .top, spacing: 14) {
                    if event.artworkAsset != nil {
                        EventArtwork(event: event).frame(width: 52, height: 52).clipped().blendMode(.screen)
                    } else {
                        Image(systemName: event.symbol).font(.title2).foregroundStyle(Color.skyMint).frame(width: 52, height: 52)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(event.title).font(.headline).foregroundStyle(.white)
                        Text("\(model.location.time(event.focus)) · \(event.direction) · \(Int(event.elevation))° high\(event.isMorning ? " · Before dawn" : "")").font(.subheadline).foregroundStyle(Color.skyMint)
                        Text(event.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Preview \(event.title) at \(model.location.time(event.focus))")
            HStack {
                if let weather = model.snapshot?.weather, let sample = weather.sample(at: event.focus, now: Date()), let credit = weather.credit {
                    VStack(alignment: .leading, spacing: 6) { Text("\(Int(sample.cloud))% cloud").font(.caption).foregroundStyle(.secondary); WeatherCreditView(credit: credit, compact: true) }
                }
                Spacer()
                let saved = model.reminderIDs.contains("\(model.location.id):\(event.id)")
                Button { Task { await model.reminder(event) } } label: { Label(saved ? "Reminder set" : "Remind me", systemImage: saved ? "bell.badge.fill" : "bell") }.font(.caption).disabled(event.start <= Date())
            }
        }.skyPanel()
    }
}
struct UpcomingView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var issOnly = false
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let wide = geometry.size.width >= 850 && !typeSize.isAccessibilitySize
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Picker("Events", selection: $issOnly) { Text("All sky highlights").tag(false); Text("ISS passes").tag(true) }.pickerStyle(.segmented).frame(maxWidth: 600)
                        if let snapshot = model.snapshot {
                            if issOnly {
                                Text("The ISS shines by reflected sunlight. We show passes while it is sunlit and your sky is dark, reaching at least 20° with a visible window of 1 minute or longer. Flyovers in Earth’s shadow are not visible.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: wide ? 2 : 1), alignment: .leading, spacing: 28) {
                                ForEach(snapshot.nights) { night in
                                    VStack(alignment: .leading, spacing: 16) {
                                        let events = snapshot.events.filter { $0.nightID == night.id && $0.end > Date() && (!issOnly || $0.kind == "iss") }.sorted { issOnly ? $0.start < $1.start : $0.score > $1.score }
                                        Text(model.location.day(night.start)).font(.title3.bold())
                                        if events.isEmpty { Text(issOnly ? (snapshot.orbit == nil ? "ISS data unavailable. Refresh to try again." : "No visible ISS pass meets these criteria this night.") : "No remaining highlights.").font(.subheadline).foregroundStyle(.secondary) }
                                        ForEach(Array(events.prefix(issOnly ? 12 : 5))) { EventRow(event: $0) }
                                    }.frame(maxWidth: .infinity, alignment: .topLeading)
                                }
                            }
                        }
                    }.padding(geometry.size.width >= 600 ? 32 : 20).frame(maxWidth: 1180).frame(maxWidth: .infinity)
                }.refreshable { await model.refresh() }
            }.background(Color.skyBase).navigationTitle("Next 7 nights")
        }
    }
}
