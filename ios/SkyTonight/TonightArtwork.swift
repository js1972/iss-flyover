import SwiftUI

extension SkyEvent {
    var artworkAsset: String? {
        kind == "iss" ? "WidgetISS" : WidgetPlanet(event: self)?.assetName
    }
}

/// Decorative spacecraft imagery; observing times and directions come from the forecast.
struct EventArtwork: View {
    var event: SkyEvent
    var body: some View {
        if let asset = event.artworkAsset {
            Image(asset).resizable().scaledToFill()
                .accessibilityHidden(true).allowsHitTesting(false)
        }
    }
}

struct TonightHeader: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text("YOUR EVENING, UNDER THE STARS")
                    .font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(Color.skyMint)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Sky Tonight").font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Label(model.location.name, systemImage: "location.fill")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button { model.refreshSoon() } label: {
                Group {
                    if model.refreshing { ProgressView() }
                    else { Image(systemName: "arrow.clockwise").font(.title3) }
                }.frame(width: 44, height: 44)
            }.disabled(model.refreshing).accessibilityLabel("Refresh forecast")
        }
    }
}

private struct TonightSkyScene: View {
    var event: SkyEvent?
    var animated: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !animated)) { timeline in
            let time = animated ? timeline.date.timeIntervalSinceReferenceDate : 0
            GeometryReader { geometry in
                ZStack {
                    LinearGradient(colors: [Color.skyPanel, Color.skyBase], startPoint: .topTrailing, endPoint: .bottomLeading)
                    Canvas { context, size in
                        for index in 0..<46 {
                            let x = Double((index * 73 + 19) % 997) / 997 * size.width
                            let y = Double((index * 137 + 41) % 991) / 991 * size.height
                            let radius = index.isMultiple(of: 9) ? 1.25 : 0.7
                            let brightness = 0.32 + 0.13 * sin(time * 0.45 + Double(index))
                            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)), with: .color(.white.opacity(brightness)))
                        }
                        // A brief decorative meteor, well apart from the slow star twinkle.
                        let phase = time.truncatingRemainder(dividingBy: 18)
                        if animated && phase < 1.4 {
                            let progress = phase / 1.4
                            let head = CGPoint(x: size.width * (0.35 + progress * 0.6), y: size.height * (0.05 + progress * 0.5))
                            var trail = Path(); trail.move(to: CGPoint(x: head.x - 42, y: head.y - 23)); trail.addLine(to: head)
                            context.stroke(trail, with: .linearGradient(Gradient(colors: [.clear, .white.opacity(sin(progress * .pi) * 0.6)]), startPoint: CGPoint(x: head.x - 42, y: head.y - 23), endPoint: head), lineWidth: 1)
                        }
                    }
                    if let event, event.artworkAsset != nil {
                        EventArtwork(event: event)
                            .frame(width: geometry.size.width * 1.1, height: geometry.size.height)
                            .position(x: geometry.size.width * 0.86 + sin(time / 12) * 5,
                                      y: geometry.size.height * 0.40 + cos(time / 14) * 3)
                            .mask {
                                LinearGradient(stops: [.init(color: .clear, location: 0.15), .init(color: .white, location: 0.85)], startPoint: .leading, endPoint: .trailing)
                                    .mask { LinearGradient(colors: [.white, .white, .clear], startPoint: .top, endPoint: .bottom) }
                            }
                            .opacity(0.8).blendMode(.screen)
                    }
                }
            }
        }.accessibilityHidden(true).allowsHitTesting(false)
    }
}

struct TonightPickCard: View {
    var allowMotion = true
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    var event: SkyEvent
    private var motionEnabled: Bool {
        let preview = ProcessInfo.processInfo.arguments.contains("--animate-preview")
        return allowMotion && !reduceMotion && scenePhase == .active && model.selectedTab == 0 && visible && (!model.isTesting || preview)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) { pickLabel; viewingPeriod }
                } else {
                    HStack { pickLabel; Spacer(); viewingPeriod }
                }
            }.foregroundStyle(Color.skyMint)
            Text(event.title).font(.system(.largeTitle, design: .rounded).bold())
                .fixedSize(horizontal: false, vertical: true)
            Text("\(model.location.time(event.focus))  ·  \(event.direction)  ·  \(Int(event.elevation))° high")
                .font(.title3.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            Text(event.detail).font(.subheadline).foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Button { model.preview(event) } label: {
                Label("Show me where", systemImage: "scope").fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 6)
            }.buttonStyle(.borderedProminent).tint(.skyMint).foregroundStyle(Color.skyBase)
                .accessibilityIdentifier("tonightPreview")
        }
        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
        .background { TonightSkyScene(event: event, animated: motionEnabled) }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.07)))
        .onScrollVisibilityChange(threshold: 0.1) { visible = $0 }
    }
    private var pickLabel: some View {
        Label("TONIGHT’S PICK", systemImage: event.symbol).font(.caption.weight(.bold)).tracking(1)
            .fixedSize(horizontal: false, vertical: true)
    }
    private var viewingPeriod: some View { Text(event.isMorning ? "Before dawn" : "After dusk").font(.caption) }
}
