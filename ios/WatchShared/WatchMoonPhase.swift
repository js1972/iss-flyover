import SwiftUI

/// SF Symbols' first Moon-phase layer is the shadow, not the illuminated part.
/// Use explicit palette colours instead of the default monochrome/hierarchical tint.
struct WatchMoonPhase: View {
    var phase: Double
    var latitude: Double? = nil
    var size: CGFloat = 48

    var body: some View {
        Image(systemName: WatchObservation.moonSymbol(phase))
            .symbolRenderingMode(.palette)
            .font(.system(size: size))
            .foregroundStyle(Color(white: 0.18), .white)
            // Rotate the schematic phase diagram for southern observing places.
            .rotationEffect(.degrees((latitude ?? 0) < 0 ? 180 : 0))
            .frame(width: size, height: size)
    }
}
