import CoreLocation
import SwiftUI

@MainActor
final class WatchCompass: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published var heading: Double?
    @Published var status = "Use the direction shown to orient yourself."
    @Published var enabled = false
    private let manager = CLLocationManager()
    private var location: ObservingLocation?
    override init() { super.init(); manager.delegate = self; manager.headingFilter = 3; manager.desiredAccuracy = kCLLocationAccuracyKilometer }
    func start(at place: ObservingLocation) {
        guard CLLocationManager.headingAvailable() else { status = "Compass unavailable. Use the cardinal direction shown."; return }
        location = place; enabled = true; status = "Checking your position…"
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        else { authorize() }
    }
    private func authorize() {
        guard enabled else { return }
        guard manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways else {
            stop(); status = "Location permission is off. Use cardinal directions."; return
        }
        manager.requestLocation()
    }
    func stop() { manager.stopUpdatingHeading(); manager.stopUpdatingLocation(); heading = nil; enabled = false }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { if manager.authorizationStatus != .notDetermined { authorize() } }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard enabled else { return } // A late one-shot location must not restart sensors after leaving the screen.
        guard let current = locations.last, let location, abs(current.timestamp.timeIntervalSinceNow) < 120,
              current.horizontalAccuracy >= 0, current.horizontalAccuracy < 5000 else {
            stop(); status = "Position uncertain. Use cardinal directions."; return
        }
        guard current.distance(from: CLLocation(latitude: location.latitude, longitude: location.longitude)) < 20000 else {
            stop(); status = "You're away from this observing place. Choose a nearby place on iPhone."; return
        }
        manager.startUpdatingHeading(); status = "Waiting for a true-north heading…"
    }
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard enabled else { return }
        guard newHeading.headingAccuracy >= 0, newHeading.headingAccuracy <= 25, newHeading.trueHeading >= 0 else {
            heading = nil; status = "Heading uncertain. Move away from magnetic objects."; return
        }
        heading = newHeading.trueHeading; status = "Compass aligned · true north"
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { stop(); status = "Compass position unavailable. Use cardinal directions." }
}
