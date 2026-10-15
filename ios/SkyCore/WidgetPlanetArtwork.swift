import SwiftUI

enum WidgetPlanet: String, CaseIterable {
    case mercury = "Mercury", venus = "Venus", mars = "Mars"
    case jupiter = "Jupiter", saturn = "Saturn"

    init?(event: SkyEvent) {
        guard event.kind == "planet" else { return nil }
        self.init(rawValue: event.body)
    }

    var assetName: String { "Planet" + rawValue }
}

struct WidgetArtworkBackground: View {
    var assetName: String
    var isISS: Bool
    var small: Bool

    var body: some View {
        GeometryReader { geometry in
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: isISS ? .fit : .fill)
                .frame(width: isISS ? (small ? 210 : 260) : (small ? 270 : 320), height: isISS ? 150 : (small ? 190 : 210))
                .position(x: geometry.size.width * (small ? 0.88 : 0.80), y: geometry.size.height * 0.47)
        }
        // Let the subject extend to the card edge and behind the labels. Fade the
        // left and lower edges to retain a dark reading surface for all text sizes.
        .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .white.opacity(0.2), location: 0.25), .init(color: .white, location: 0.85)], startPoint: .leading, endPoint: .trailing)
                .mask { LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .white, location: 0.25), .init(color: .white, location: 0.55), .init(color: .clear, location: 0.95)], startPoint: .top, endPoint: .bottom) }
        }
        .opacity(isISS ? 0.7 : 0.85)
        .blendMode(.screen)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
