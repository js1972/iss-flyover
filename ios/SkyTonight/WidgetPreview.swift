#if DEBUG
import SwiftUI
import WidgetKit
struct WidgetPreview: View {
    @EnvironmentObject var model: AppModel
    @State private var appearance: ColorScheme = .light
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Widget previews").font(.title.bold())
                Picker("Widget appearance", selection: $appearance) {
                    Text("Light").tag(ColorScheme.light)
                    Text("Dark").tag(ColorScheme.dark)
                }.pickerStyle(.segmented)
                if let snapshot = model.snapshot {
                    let entry = SkyEntry(date: Date(), snapshot: snapshot, location: model.location)
                    Group {
                        SkyWidgetView(previewFamily: .systemSmall, entry: entry, issOnly: false).padding(16).frame(width:170,height:170).background(Color.skyPanel,in:RoundedRectangle(cornerRadius:24))
                        SkyWidgetView(previewFamily: .systemMedium, entry: entry, issOnly: false).padding(16).frame(width:350,height:170).background(Color.skyPanel,in:RoundedRectangle(cornerRadius:24))
                        SkyWidgetView(previewFamily: .systemSmall, entry: entry, issOnly: true).padding(16).frame(width:170,height:170).background(Color.skyPanel,in:RoundedRectangle(cornerRadius:24))
                        SkyWidgetView(previewFamily: .accessoryRectangular, entry: entry, issOnly: false).frame(width:180,height:80)
                            .background(appearance == .light ? Color.white : Color.black, in: RoundedRectangle(cornerRadius:12))
                    }.environment(\.colorScheme, appearance)
                } else { ProgressView() }
            }.padding()
        }.background(Color.skyBase)
    }
}
#endif
