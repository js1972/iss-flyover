#if DEBUG
import SwiftUI
import WidgetKit
struct WidgetPreview: View {
    @EnvironmentObject var model: AppModel
    @State private var appearance: ColorScheme = .light
    @State private var planet: WidgetPlanet? = nil
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Widget previews").font(.title.bold())
                Picker("Widget appearance", selection: $appearance) {
                    Text("Light").tag(ColorScheme.light)
                    Text("Dark").tag(ColorScheme.dark)
                }.pickerStyle(.segmented)
                Picker("Artwork sample", selection: $planet) {
                    Text("Live forecast").tag(nil as WidgetPlanet?)
                    ForEach(WidgetPlanet.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                }
                if planet != nil { Text("Sample artwork · forecast times retained").font(.caption).foregroundStyle(.secondary) }
                if let snapshot = model.snapshot {
                    let entry = SkyEntry(date: Date(), snapshot: sample(snapshot), location: model.location)
                    Group {
                        SkyWidgetView(previewFamily: .systemSmall, entry: entry, issOnly: false).padding(16).frame(width:170,height:170).background(Color.skyPanel).clipShape(RoundedRectangle(cornerRadius:24))
                        SkyWidgetView(previewFamily: .systemMedium, entry: entry, issOnly: false).padding(16).frame(width:350,height:170).background(Color.skyPanel).clipShape(RoundedRectangle(cornerRadius:24))
                        SkyWidgetView(previewFamily: .systemSmall, entry: entry, issOnly: true).padding(16).frame(width:170,height:170).background(Color.skyPanel).clipShape(RoundedRectangle(cornerRadius:24))
                        SkyWidgetView(previewFamily: .accessoryRectangular, entry: entry, issOnly: false).frame(width:180,height:80)
                            .background(appearance == .light ? Color.white : Color.black, in: RoundedRectangle(cornerRadius:12))
                    }.environment(\.colorScheme, appearance)
                } else { ProgressView() }
            }.padding()
        }.background(Color.skyBase)
    }
    private func sample(_ snapshot: SkySnapshot) -> SkySnapshot {
        guard let planet, var event = snapshot.ranked(at: Date()).first else { return snapshot }
        var sample = snapshot
        event.kind = "planet"; event.body = planet.rawValue; event.title = planet.rawValue
        sample.events = [event] + snapshot.events.filter { $0.id != event.id }
        return sample
    }
}
#endif
