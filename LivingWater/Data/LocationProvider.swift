import CoreLocation
import Observation

// Asks the phone roughly where it is, once, and only when the person chooses
// "Use my location". The answer is used to sort a list on this phone.
// It is never saved and never sent anywhere.

@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    enum Status {
        case idle
        case asking
        case found(CLLocationCoordinate2D)
        case denied
        case failed
    }

    private(set) var status = Status.idle

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        // City-level is plenty for "which country is closest".
        manager.desiredAccuracy = kCLLocationAccuracyReduced
    }

    func request() {
        switch manager.authorizationStatus {
        case .notDetermined:
            status = .asking
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            status = .asking
            manager.requestLocation()
        default:
            status = .denied
        }

        // Don't leave someone watching a spinner: give up after 12 seconds.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(12))
            if let self, case .asking = self.status {
                self.status = .failed
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard case .asking = status else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            status = .denied
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            status = .found(location.coordinate)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if case .asking = status {
            status = .failed
        }
    }
}

/// A part of the world someone can pick instead of sharing their location.
struct WorldRegion: Identifiable, Hashable {
    let name: String
    let latitude: Double
    let longitude: Double

    var id: String { name }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Each region is measured from a point near its middle.
    static let all: [WorldRegion] = [
        WorldRegion(name: "North America", latitude: 39, longitude: -98),
        WorldRegion(name: "Central America and the Caribbean", latitude: 15, longitude: -85),
        WorldRegion(name: "South America", latitude: -12, longitude: -60),
        WorldRegion(name: "Europe", latitude: 50, longitude: 15),
        WorldRegion(name: "West Africa", latitude: 11, longitude: 0),
        WorldRegion(name: "Central Africa", latitude: 2, longitude: 20),
        WorldRegion(name: "East Africa", latitude: 0, longitude: 37),
        WorldRegion(name: "Southern Africa", latitude: -20, longitude: 26),
        WorldRegion(name: "Middle East", latitude: 28, longitude: 45),
        WorldRegion(name: "South Asia", latitude: 22, longitude: 78),
        WorldRegion(name: "East Asia", latitude: 35, longitude: 115),
        WorldRegion(name: "Southeast Asia", latitude: 5, longitude: 110),
        WorldRegion(name: "Australia and the Pacific", latitude: -25, longitude: 140),
    ]
}
