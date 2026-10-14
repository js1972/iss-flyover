import SwiftUI
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var name = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var zone = TimeZone.current.identifier
    @State private var searching = false
    @State private var diagnostics = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Observing location") {
                    ForEach(model.locations) { location in
                        Button { model.select(location) } label: {
                            HStack { VStack(alignment: .leading) { Text(location.name).foregroundStyle(.primary); Text(location.timeZoneID).font(.caption).foregroundStyle(.secondary) }; Spacer(); if model.location.id == location.id { Image(systemName: "checkmark.circle.fill") } }
                        }
                    }
                    Button { model.useDeviceLocation() } label: { Label(model.locating ? "Finding your location…" : "Use my location", systemImage: "location.circle") }.disabled(model.locating)
                    Text("Perth is the starting location. Choose your own place here; each widget can use a different saved place.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Add a place") {
                    TextField("City or place name", text: $name).accessibilityIdentifier("placeName")
                    Button(searching ? "Searching…" : "Find place") {
                        searching = true
                        Task {
                            defer { searching = false }
                            do {
                                guard let place = try await CLGeocoder().geocodeAddressString(name).first, let coordinate = place.location?.coordinate, let timeZone = place.timeZone else { model.message = "Place not found. Enter coordinates and a time zone below."; return }
                                latitude = String(format: "%.5f", coordinate.latitude); longitude = String(format: "%.5f", coordinate.longitude); zone = timeZone.identifier
                                name = place.locality ?? place.name ?? name
                            } catch { model.message = "Place search is unavailable. You can enter coordinates manually." }
                        }
                    }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || searching)
                    TextField("Latitude (−90 to 90)", text: $latitude).keyboardType(.numbersAndPunctuation)
                    TextField("Longitude (−180 to 180)", text: $longitude).keyboardType(.numbersAndPunctuation)
                    TextField("Time zone, e.g. Australia/Perth", text: $zone).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Save observing place") {
                        guard let lat = Double(latitude), let lon = Double(longitude), !name.trimmingCharacters(in: .whitespaces).isEmpty else { model.message = "Enter a name and numeric coordinates."; return }
                        let loc = ObservingLocation(id: UUID().uuidString, name: name, latitude: lat, longitude: lon, timeZoneID: zone)
                        guard loc.isValid else { model.message = "Check the coordinates and time zone."; return }
                        model.save(loc); name = ""; latitude = ""; longitude = ""
                    }
                }
                Section("Viewing preferences") {
                    Toggle("Prefer evening highlights", isOn: Binding(get: { model.eveningFirst }, set: { model.changePreference($0) }))
                    Text("Evening picks appear before pre-dawn events. All event times use the observing place’s time zone.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Home & Lock Screen widgets") {
                    Text("Touch and hold your Home Screen, choose Edit → Add Widget, then search for Sky Tonight. Choose Sky Tonight or Next ISS Pass. Edit a widget to choose a saved observing place.")
                    Text("Lock Screen: touch and hold the Lock Screen, choose Customize, then add a Sky Tonight widget below the clock.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Data & privacy") {
                    Text("Astronomy is calculated on this device. Coordinates are sent to Open-Meteo for weather and to Apple when you search for or name a place. No account is needed and no analytics are included.").font(.footnote)
                    Link("Weather data by Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                    Link("Orbital elements: CelesTrak", destination: URL(string: "https://celestrak.org/")!)
                    Link("Astronomy Engine", destination: URL(string: "https://github.com/cosinekitty/astronomy")!)
                    Text("Also uses satellite.js and SunCalc. This initial release uses Open-Meteo’s non-commercial service.").font(.caption).foregroundStyle(.secondary)
                    NavigationLink("Open-source acknowledgements") { ScrollView { Text((try? String(contentsOf: Bundle.main.url(forResource: "Acknowledgements", withExtension: "txt") ?? URL(fileURLWithPath: "/missing"), encoding: .utf8)) ?? "Astronomy Engine · satellite.js · SunCalc").font(.caption).padding() }.navigationTitle("Acknowledgements") }
                }
                Section {
                    DisclosureGroup("Diagnostics", isExpanded: $diagnostics) {
                        Text("Version 1.0 (1)")
                        Text("Location: \(model.location.latitude), \(model.location.longitude)")
                        Text("Orbit: \(model.snapshot?.orbit?.source ?? "Unavailable")")
                        if let orbit = model.snapshot?.orbit { Text("Orbit epoch: \(orbit.epoch.formatted())") }
                        if let message = model.snapshot?.weatherMessage { Text(message) }
                        Text("Saved forecasts expire after seven observing nights. Weather expires after six hours.")
                    }.font(.footnote)
                }
            }.navigationTitle("Settings").scrollContentBackground(.hidden).background(Color.skyBase)
        }
    }
}
