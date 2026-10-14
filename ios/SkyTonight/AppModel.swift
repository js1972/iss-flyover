import SwiftUI
import CoreLocation
import WidgetKit
import UserNotifications

@MainActor
final class AppModel: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published var location = SkyStore.selected
    @Published var locations = SkyStore.locations
    @Published var snapshot: SkySnapshot?
    @Published var eveningFirst = SkyStore.eveningFirst
    @Published var refreshing = false
    @Published var message: String?
    @Published var selectedTab = 0
    @Published var selectedEvent: SkyEvent?
    @Published var previewTime: Date?
    @Published var chart: [ChartObject] = []
    @Published var heading: Double = 0
    @Published var compass = false
    @Published var locating = false
    @Published var reminderIDs: Set<String> = []
    private let manager = CLLocationManager()
    private var revision = 0
    private var chartRevision = 0
    private var refreshTask: Task<Void, Never>?
    private var lastRefresh: Date = .distantPast
    var isTesting: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--uitesting")
        #else
        false
        #endif
    }
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        if isTesting { location = .perth; locations = [.perth]; eveningFirst = true }
        snapshot = isTesting ? nil : SkyStore.read(location)
    }
    func refresh() async {
        guard !refreshing else { return }
        refreshing = true; revision += 1
        let token = revision, loc = location, pref = eveningFirst
        defer { if token == revision { refreshing = false } }
        do {
            if snapshot == nil || snapshot?.validUntil ?? .distantPast < Date() {
                let local = try await SkyCalculator.shared.forecast(location: loc, now: Date(), eveningFirst: pref, orbit: isTesting ? nil : SkyStore.orbit)
                guard token == revision else { return }
                snapshot = local
            }
            await updateChart()
            if isTesting { return }
            let fresh = try await SkyRepository.shared.refresh(location: loc, eveningFirst: pref)
            guard token == revision else { return }
            snapshot = fresh; message = nil; lastRefresh = Date()
            await SkyReminders.reconcile(fresh)
            await loadReminders()
            WidgetCenter.shared.reloadAllTimelines()
            await updateChart()
            refreshing = false // Weather enriches an already usable app.
            let withWeather = await SkyRepository.shared.refreshWeather(location: loc)
            guard token == revision else { return }
            if let withWeather { snapshot = withWeather; WidgetCenter.shared.reloadAllTimelines() }
        } catch { if token == revision { message = error.localizedDescription } }
    }
    func refreshSoon() { refreshTask?.cancel(); refreshTask = Task { await refresh() } }
    func onResume() {
        if Date().timeIntervalSince(lastRefresh) > 1800 { refreshSoon() }
        Task { await updateChart(); await loadReminders() }
    }
    func select(_ loc: ObservingLocation) {
        revision += 1; refreshing = false; location = loc; SkyStore.selectedID = loc.id
        snapshot = SkyStore.read(loc); selectedEvent = nil; previewTime = nil
        refreshSoon()
    }
    func save(_ loc: ObservingLocation) {
        guard loc.isValid else { message = "Check the coordinates and time zone."; return }
        if let i = locations.firstIndex(where: { $0.id == loc.id }) { locations[i] = loc } else { locations.append(loc) }
        SkyStore.locations = locations; select(loc)
    }
    func changePreference(_ value: Bool) {
        eveningFirst = value; SkyStore.eveningFirst = value
        revision += 1; refreshing = false; snapshot = nil; refreshSoon()
    }
    func preview(_ event: SkyEvent) {
        selectedEvent = event; previewTime = event.focus; selectedTab = 1
        Task { await updateChart() }
    }
    func live() { selectedEvent = nil; previewTime = nil; Task { await updateChart() } }
    func updateChart() async {
        chartRevision += 1
        let token = chartRevision
        do {
            let value = try await SkyCalculator.shared.chart(location: location, time: previewTime ?? Date(), orbit: snapshot?.orbit, target: selectedEvent)
            if token == chartRevision { chart = value }
        } catch { if token == chartRevision { message = error.localizedDescription } }
    }
    func open(_ url: URL) async {
        guard url.scheme == "skytonight", let c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let items = c.queryItems ?? []
        if let id = items.first(where: { $0.name == "location" })?.value, let loc = locations.first(where: { $0.id == id }), loc != location { select(loc) }
        guard url.host == "event" else { selectedTab = 0; return }
        let id = items.first(where: { $0.name == "id" })?.value
        if let event = snapshot?.events.first(where: { $0.id == id }) { preview(event); return }
        if let raw = items.first(where: { $0.name == "time" })?.value, let time = Double(raw), time.isFinite, abs(time - Date().timeIntervalSince1970) < 14 * 86400 {
            selectedEvent = nil; previewTime = Date(timeIntervalSince1970: time); selectedTab = 1
            message = "Showing the saved viewing time. Refresh to check the latest event details."
            await updateChart()
        }
    }
    func useDeviceLocation() {
        locating = true
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: locating = false; message = "Location access is off. Choose a saved place or enter coordinates in Settings."
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard locating else { return }
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways { manager.requestLocation() }
        else if manager.authorizationStatus != .notDetermined { locating = false; message = "Location permission was not granted. Saved places still work." }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let position = locations.last, abs(position.timestamp.timeIntervalSinceNow) < 120, position.horizontalAccuracy >= 0 else { locating = false; return }
        Task {
            defer { locating = false }
            do {
                let place = try await CLGeocoder().reverseGeocodeLocation(position).first
                guard let zone = place?.timeZone else { message = "Could not determine this location’s time zone. Enter it manually in Settings."; return }
                save(.init(id: "device", name: place?.locality ?? "Current location", latitude: position.coordinate.latitude, longitude: position.coordinate.longitude, timeZoneID: zone.identifier))
            } catch { message = "Could not resolve your location. You can enter coordinates in Settings." }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { locating = false; message = "Location unavailable. Choose a saved place in Settings." }
    func toggleCompass() {
        guard CLLocationManager.headingAvailable() else { message = "A compass is unavailable on this device. Drag the sky chart to rotate it."; return }
        compass.toggle()
        if compass { manager.startUpdatingHeading() } else { manager.stopUpdatingHeading(); heading = 0 }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        guard heading.headingAccuracy >= 0 else { return }
        self.heading = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
    }
    func loadReminders() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        reminderIDs = Set(requests.map(\.identifier))
    }
    func reminder(_ event: SkyEvent) async {
        let id = "\(location.id):\(event.id)"
        let center = UNUserNotificationCenter.current()
        if reminderIDs.contains(id) { center.removePendingNotificationRequests(withIdentifiers: [id]); await loadReminders(); return }
        guard event.start > Date().addingTimeInterval(60) else { message = "This event is already starting."; return }
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else { message = "Enable notifications in iPhone Settings to receive reminders."; return }
            let interval = max(5, event.start.addingTimeInterval(-600).timeIntervalSinceNow)
            try await center.add(SkyReminders.request(event: event, location: location))
            await loadReminders(); message = "Reminder set for \(location.time(Date().addingTimeInterval(interval))). Check fresh conditions before observing."
        } catch { message = error.localizedDescription }
    }
}
