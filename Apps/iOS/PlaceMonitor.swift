import CoreLocation
import HubCore
import Observation

// Privacy rule: coordinates stay on the device; CoreLocation does the matching.
/// Watches the gym and office geofences and turns arrivals and departures into mode triggers.
@MainActor
@Observable
final class PlaceMonitor {
    static let name = "lifehub-places"

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var task: Task<Void, Never>?

    /// Last failure, for the UI to show.
    private(set) var lastError: String?

    // Called at launch too: after a geofence wakes the app in the background, iterating the
    // events of the monitor with the same name delivers the event that woke it.
    /// Watches `settings` and calls `onTrigger` for each event.
    func start(_ settings: PlaceSettings, onTrigger: @escaping @MainActor (ModeTrigger) -> Void) {
        task?.cancel()
        lastError = nil
        task = Task {
            let monitor = await CLMonitor(Self.name)
            let wanted = Set(settings.places.map(\.kind.rawValue))
            for identifier in await monitor.identifiers where !wanted.contains(identifier) {
                await monitor.remove(identifier)
            }
            for place in settings.places {
                let center = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
                let condition = CLMonitor.CircularGeographicCondition(center: center, radius: place.radius)
                await monitor.add(condition, identifier: place.kind.rawValue)
            }
            do {
                for try await event in await monitor.events {
                    guard let kind = HubPlace.Kind(rawValue: event.identifier) else { continue }
                    let entered: Bool
                    switch event.state {
                    case .satisfied: entered = true
                    case .unsatisfied: entered = false
                    default: continue
                    }
                    if let trigger = kind.trigger(entered: entered) {
                        onTrigger(trigger)
                    }
                }
            } catch {
                lastError = "地点监测停了：\(error.localizedDescription)"
            }
        }
    }

    // iOS first grants "While Using" with provisional Always, then asks to keep Always later.
    /// Asks for "Always" location access, which geofences need to work while the app is closed.
    func requestAlways() {
        manager.requestAlwaysAuthorization()
    }

    /// The device's current location.
    /// - Throws: CoreLocation errors, or `CLError(.denied)` when access is off.
    func currentLocation() async throws -> CLLocation {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        for try await update in CLLocationUpdate.liveUpdates() {
            if update.authorizationDenied || update.authorizationDeniedGlobally {
                throw CLError(.denied)
            }
            if let location = update.location {
                return location
            }
        }
        throw CLError(.locationUnknown)
    }
}
