import CoreLocation
import HubCore
import Observation

// Privacy rule: coordinates stay on the device; CoreLocation does the matching.
/// Watches the place geofences and reports each arrival and departure.
@MainActor
@Observable
final class PlaceMonitor {
    // CLMonitor throws on launch if the name has anything but letters and digits.
    static let name = "LifeHubPlaces"

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var task: Task<Void, Never>?
    // Held while places are set, so Core Location knows the geofences need "Always" in the background.
    @ObservationIgnored private var session: CLServiceSession?

    /// Last failure, for the UI to show.
    private(set) var lastError: String?
    /// Why geofences only work while the app is open, for the UI to show; `nil` when they work.
    private(set) var accessWarning: String?

    // Called at launch too: after a geofence wakes the app in the background, iterating the
    // events of the monitor with the same name delivers the event that woke it.
    /// Watches `settings` and calls `onEvent` with the place and whether Mike entered it.
    func start(_ settings: PlaceSettings, onEvent: @escaping @MainActor (HubPlace, Bool) -> Void) {
        task?.cancel()
        lastError = nil
        session = settings.places.isEmpty ? nil : CLServiceSession(authorization: .always)
        checkAccess(settings)
        task = Task {
            let monitor = await CLMonitor(Self.name)
            let wanted = Set(settings.places.map(\.id))
            for identifier in await monitor.identifiers where !wanted.contains(identifier) {
                await monitor.remove(identifier)
            }
            // Adding a condition again resets its state and fires "entered" while Mike is still
            // inside, so only new or moved places are added.
            for place in settings.places {
                let existing = await monitor.record(for: place.id)?.condition
                if let current = existing as? CLMonitor.CircularGeographicCondition, Self.matches(current, place) {
                    continue
                }
                let center = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
                let condition = CLMonitor.CircularGeographicCondition(center: center, radius: place.radius)
                await monitor.add(condition, identifier: place.id)
            }
            var lastState: [String: CLMonitor.Event.State] = [:]
            do {
                for try await event in await monitor.events {
                    Self.noteDiagnostics(event)
                    guard let place = settings.places.first(where: { $0.id == event.identifier }) else { continue }
                    guard lastState[event.identifier] != event.state else { continue }
                    lastState[event.identifier] = event.state
                    let entered: Bool
                    switch event.state {
                    case .satisfied: entered = true
                    case .unsatisfied: entered = false
                    default: continue
                    }
                    onEvent(place, entered)
                }
            } catch {
                lastError = "地点监测停了：\(error.localizedDescription)"
            }
        }
    }

    /// Sets `accessWarning` when places are set but location access isn't "Always".
    func checkAccess(_ settings: PlaceSettings) {
        let always = manager.authorizationStatus == .authorizedAlways
        accessWarning = settings.places.isEmpty || always ? nil : Self.notAlways
    }

    private static let notAlways = "位置权限不是「始终」：App 关着时不知道你到了或离开公司、家。到 设置 > Life Hub > 位置 选「始终」"

    // The background delivery problem Mike hit on 2026-10-05 left no trace; these flags say why.
    private static func noteDiagnostics(_ event: CLMonitor.Event) {
        var flags: [String] = []
        if event.authorizationDenied { flags.append("没授权") }
        if event.insufficientlyInUse { flags.append("不在使用中") }
        if event.serviceSessionRequired { flags.append("要会话") }
        guard !flags.isEmpty else { return }
        Dogfood.note("geofence", "\(event.identifier) 送达受限：\(flags.joined(separator: "、"))", at: event.date)
    }

    // iOS first grants "While Using" with provisional Always, then asks to keep Always later.
    /// Asks for "Always" location access, which geofences need to work while the app is closed.
    func requestAlways() {
        manager.requestAlwaysAuthorization()
    }

    /// The device's current location, accurate to about 50 m.
    /// - Throws: `CLError(.denied)` when access is off, `CLError(.locationUnknown)` when no fix is
    ///   good enough within 15 seconds, or other CoreLocation errors.
    func currentLocation() async throws -> CLLocation {
        let deadline = Date.now.addingTimeInterval(15)
        var best: CLLocation?
        for try await update in CLLocationUpdate.liveUpdates() {
            if update.authorizationDenied || update.authorizationDeniedGlobally {
                throw CLError(.denied)
            }
            if let location = update.location, location.horizontalAccuracy >= 0 {
                if location.horizontalAccuracy < best?.horizontalAccuracy ?? .infinity {
                    best = location
                }
                if location.horizontalAccuracy <= Self.goodAccuracy {
                    return location
                }
            }
            if Date.now >= deadline { break }
        }
        // A 100 m geofence still works with a fix this good.
        if let best, best.horizontalAccuracy <= HubPlace.defaultRadius {
            return best
        }
        throw CLError(.locationUnknown)
    }

    static let goodAccuracy: CLLocationAccuracy = 50

    private static func matches(_ condition: CLMonitor.CircularGeographicCondition, _ place: HubPlace) -> Bool {
        let center = condition.center
        let samePoint = center.latitude == place.latitude && center.longitude == place.longitude
        return samePoint && condition.radius == place.radius
    }
}
