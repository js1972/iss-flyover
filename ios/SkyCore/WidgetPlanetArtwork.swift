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

struct WidgetPlanetArtwork: View {
    var planet: WidgetPlanet

    var body: some View {
        GeometryReader { geometry in
            Image(planet.assetName)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        // NASA's black-space backgrounds blend into the navy card without a photo box.
        // Only used on full-colour cards; tinted and Lock Screen layouts stay semantic.
        .blendMode(.screen)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
