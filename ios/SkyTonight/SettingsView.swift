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
    @State private var clearingData = false
    @State private var placeEditMode: EditMode = .inactive
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(model.locations) { location in
                        Button { model.select(location) } label: {
                            HStack { VStack(alignment: .leading) { Text(location.name).foregroundStyle(.primary); Text(location.timeZoneID).font(.caption).foregroundStyle(.secondary) }; Spacer(); if model.location.id == location.id { Image(systemName: "checkmark.circle.fill") } }
                        }
                    }.onDelete { model.removePlaces(at: $0) }
                    Button { model.useDeviceLocation() } label: { Label(model.locating ? "Finding your location…" : "Use my location", systemImage: "location.circle") }.disabled(model.locating)
                    Text("Perth is the starting location. Choose your own place here; each widget can use a different saved place.").font(.caption).foregroundStyle(.secondary)
                } header: {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Saved places")
                        Spacer(minLength: 12)
                        Button(placeEditMode.isEditing ? "Done" : "Edit places") {
                            withAnimation { placeEditMode = placeEditMode.isEditing ? .inactive : .active }
                        }.font(.subheadline).textCase(nil).buttonStyle(.borderless)
                            .frame(minHeight: 44)
                            .accessibilityHint("Show or hide controls for removing saved places")
                    }
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
                Section {
                    Toggle("Include Apple Weather", isOn: Binding(get: { model.weatherEnabled }, set: { model.changeWeather($0) }))
                        .accessibilityIdentifier("appleWeatherToggle")
                    Text("When enabled, this app and its widgets send the selected observing place’s coordinates to Apple for cloud, rain and wind forecasts, including background refreshes. Astronomy works with weather off. Turning this off stops new weather requests and removes saved conditions.").font(.footnote).foregroundStyle(.secondary)
                    if let credit = model.snapshot?.weather?.credit { WeatherCreditView(credit: credit) }
                } header: { Text("Weather") }
                Section("Home & Lock Screen widgets") {
                    Text("Touch and hold your Home Screen, choose Edit → Add Widget, then search for Sky Tonight. Choose Sky Tonight or Next ISS Pass. Edit a widget to choose a saved observing place.")
                    Text("Lock Screen: touch and hold the Lock Screen, choose Customize, then add a Sky Tonight widget below the clock.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Data & privacy") {
                    Text("Astronomy is calculated on this device. Apple handles optional weather, place searches and location naming. No account, advertising or analytics are included.").font(.footnote)
                    NavigationLink("Privacy policy") { PrivacyPolicyView() }
                    NavigationLink("Help & support") { SupportView() }
                    Link("Orbital elements: CelesTrak", destination: URL(string: "https://celestrak.org/")!)
                    Link("Astronomy Engine", destination: URL(string: "https://github.com/cosinekitty/astronomy")!)
                    Text("Also uses satellite.js and SunCalc.").font(.caption).foregroundStyle(.secondary)
                    NavigationLink("Open-source acknowledgements") { ScrollView { Text((try? String(contentsOf: Bundle.main.url(forResource: "Acknowledgements", withExtension: "txt") ?? URL(fileURLWithPath: "/missing"), encoding: .utf8)) ?? "Astronomy Engine · satellite.js · SunCalc").font(.caption).padding() }.navigationTitle("Acknowledgements") }
                }
                Section("Your saved data") {
                    Text("Use Edit places beside Saved places to remove a place. Clearing saved data removes all places, cached forecasts and reminders, turns weather off, and returns to the default Perth sky.").font(.footnote).foregroundStyle(.secondary)
                    Button("Clear saved data", role: .destructive) { clearingData = true }
                }
                Section {
                    DisclosureGroup("Diagnostics", isExpanded: $diagnostics) {
                        Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))")
                        Text("Location: \(model.location.latitude), \(model.location.longitude)")
                        Text("Orbit: \(model.snapshot?.orbit?.source ?? "Unavailable")")
                        if let orbit = model.snapshot?.orbit { Text("Orbit epoch: \(orbit.epoch.formatted())") }
                        if let message = model.snapshot?.weatherMessage { Text(message) }
                        Text("Saved forecasts expire after seven observing nights. Weather expires after six hours.")
                    }.font(.footnote)
                }
            }.environment(\.editMode, $placeEditMode)
                .navigationTitle("Settings").scrollContentBackground(.hidden).background(Color.skyBase)
                .onDisappear { placeEditMode = .inactive }
                .confirmationDialog("Clear all saved places, forecasts and reminders?", isPresented: $clearingData, titleVisibility: .visible) {
                    Button("Clear saved data", role: .destructive) { model.clearSavedData() }
                }
        }
    }
}
