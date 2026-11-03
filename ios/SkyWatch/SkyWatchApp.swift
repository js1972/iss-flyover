import SwiftUI
import WatchKit

@main
struct SkyWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchDelegate.self) var delegate
    @StateObject private var model = WatchModel()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            WatchRootView().environmentObject(model).tint(.watchMint)
                .task { WatchRuntime.model = model }
                .onOpenURL { model.open($0) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.resume() }
                }
        }
    }
}
