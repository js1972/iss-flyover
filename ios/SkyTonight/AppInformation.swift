import SwiftUI

struct AppInformation: Decodable {
    struct Section: Decodable, Identifiable {
        var title: String
        var text: String
        var id: String { title }
    }
    var developer: String
    var email: String
    var website: URL
    var updated: String
    var privacy: [Section]
    var support: [Section]
    static let shared: AppInformation? = {
        guard let url = Bundle.main.url(forResource: "AppInformation", withExtension: "json"), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AppInformation.self, from: data)
    }()
}

struct PrivacyPolicyView: View {
    var body: some View { InformationPage(isPrivacy: true) }
}
struct SupportView: View {
    var body: some View { InformationPage(isPrivacy: false) }
}
private struct InformationPage: View {
    var isPrivacy: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let information = AppInformation.shared {
                    Text("Sky Tonight · \(information.developer)").font(.subheadline).foregroundStyle(Color.skyMint)
                    if isPrivacy { Text("Updated \(information.updated)").font(.caption).foregroundStyle(.secondary) }
                    ForEach(isPrivacy ? information.privacy : information.support) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title).font(.headline)
                            Text(section.text).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                    Link("Email \(information.developer)", destination: URL(string: "mailto:\(information.email)")!)
                    Link(isPrivacy ? "View privacy policy online" : "View support online", destination: information.website.appendingPathComponent(isPrivacy ? "privacy.html" : "support.html"))
                    Link("Apple privacy policy", destination: URL(string: "https://www.apple.com/legal/privacy/")!)
                    Link("Location Services & privacy", destination: URL(string: "https://www.apple.com/legal/privacy/data/en/location-services/")!)
                } else {
                    Text("App information could not load. Contact js.dev.one@proton.me for help.")
                }
            }.padding(28).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
        }.background(Color.skyBase).navigationTitle(isPrivacy ? "Privacy policy" : "Help & support").navigationBarTitleDisplayMode(.inline)
    }
}
