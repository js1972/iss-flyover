import SwiftUI
import UIKit

/// Apple's unmodified mark travels with cached conditions, including in widgets.
struct WeatherCreditView: View {
    @Environment(\.colorScheme) private var colorScheme
    var credit: WeatherCredit
    var compact = false
    var body: some View {
        Link(destination: credit.legalURL) {
            if let image = UIImage(data: colorScheme == .dark ? credit.darkMark : credit.lightMark) {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(width: compact ? 47 : 88, height: compact ? 12 : 22)
            }
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("Apple Weather data sources and legal attribution")
            .accessibilityIdentifier("appleWeatherCredit")
    }
}
