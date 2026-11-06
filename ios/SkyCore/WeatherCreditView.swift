import SwiftUI
import UIKit

/// Apple's unmodified mark travels with cached conditions, including in widgets.
struct WeatherCreditView: View {
    @Environment(\.colorScheme) private var colorScheme
    var credit: WeatherCredit
    var compact = false
    var body: some View {
        #if os(watchOS)
        // watchOS cannot open this provider's legal webpage. Keep its mark as
        // a small credit; the paired iPhone retains the working sources link.
        mark.accessibilityElement(children: .ignore)
            .accessibilityLabel("Apple Weather. Data sources available in the iPhone app.")
            .accessibilityIdentifier("appleWeatherCredit")
        #else
        Link(destination: credit.legalURL) {
            mark
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("Apple Weather data sources and legal attribution")
            .accessibilityIdentifier("appleWeatherCredit")
        #endif
    }
    @ViewBuilder private var mark: some View {
        if let image = UIImage(data: colorScheme == .dark ? credit.darkMark : credit.lightMark) {
            Image(uiImage: image).resizable().scaledToFit()
                .frame(width: compact ? 47 : 88, height: compact ? 12 : 22)
        }
    }
}
