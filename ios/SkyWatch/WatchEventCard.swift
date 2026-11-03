import SwiftUI

/// Secondary recommendations need growing rectangular rows, not watchOS's
/// default capsule button, whose curved ends crowd multiline event names.
struct WatchEventCard: View {
    var title: String
    var detail: String
    var destination: String

    var body: some View {
        NavigationLink(value: destination) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("eventTitle-\(destination)")
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        detailText.fixedSize()
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.watchMint).accessibilityHidden(true)
                    }
                    // At larger text sizes, give the viewing details the whole row.
                    detailText.fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .buttonStyle(WatchEventCardStyle())
        .accessibilityIdentifier("eventCard-\(destination)")
    }
    private var detailText: some View {
        Text(detail).font(.caption2).foregroundStyle(.white.opacity(0.7))
            .accessibilityIdentifier("eventDetail-\(destination)")
    }

}

private struct WatchEventCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.watchButton.opacity(configuration.isPressed ? 1 : 0.72),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(configuration.isPressed ? 0.18 : 0.08), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
