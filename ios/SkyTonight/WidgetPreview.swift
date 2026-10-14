#if DEBUG
import SwiftUI
import WidgetKit
struct WidgetPreview: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Widget previews").font(.title.bold())
                if let snapshot = model.snapshot {
                    let entry = SkyEntry(date: Date(), snapshot: snapshot, location: model.location)
                    SkyWidgetView(previewFamily: .systemSmall, entry: entry, issOnly: false).padding(16).frame(width:170,height:170).background(Color.skyPanel,in:RoundedRectangle(cornerRadius:24))
                    SkyWidgetView(previewFamily: .systemMedium, entry: entry, issOnly: false).padding(16).frame(width:350,height:170).background(Color.skyPanel,in:RoundedRectangle(cornerRadius:24))
                    SkyWidgetView(previewFamily: .systemSmall, entry: entry, issOnly: true).padding(16).frame(width:170,height:170).background(Color.skyPanel,in:RoundedRectangle(cornerRadius:24))
                    SkyWidgetView(previewFamily: .accessoryRectangular, entry: entry, issOnly: false).frame(width:180,height:80)
                } else { ProgressView() }
            }.padding()
        }.background(Color.skyBase)
    }
}
#endif
