import SwiftUI

struct WatchPlaceFooter: View {
    @EnvironmentObject private var model: WatchModel
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
                    WatchPlaceFooter()
                } else { WatchSetupView() }
            }.padding(.horizontal, 4)
        }.navigationTitle("Moon")
    }
}
