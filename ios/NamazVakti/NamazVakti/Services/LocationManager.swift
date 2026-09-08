import CoreLocation
import Foundation

/// Why a location lookup could not produce a result. The UI needs to tell these apart:
/// a denial is permanent until the user visits Settings, everything else is retryable.
enum LocationFailure: Error {
    case permissionDenied
    case unavailable
}

/// Why a city search could not produce results. "No matches" is *not* a failure —
/// it is `.success([])` — so that the UI can word the two cases differently.
enum CitySearchFailure: Error {
    case offline
    case failed
}

extension CitySearchFailure {
    var localizedMessage: String {
        switch self {
        case .offline: return tr("search_error_offline")
        case .failed:  return tr("search_error_failed")
        }
    }
}

/// A presentable explanation of a failed location lookup. `showsSettings` gates the
/// deep link, which is only useful when the block is a permission the user can grant.
struct LocationAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let showsSettings: Bool

    init(_ failure: LocationFailure) {
        switch failure {
        case .permissionDenied:
            title = tr("location_permission_denied_title")
            message = tr("location_permission_denied_desc")
            showsSettings = true
        case .unavailable:
            title = tr("location_unavailable_title")
            message = tr("location_unavailable_desc")
            showsSettings = false
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    /// Bare URLSession.shared waits the default 60s before giving up, which leaves the
    /// search spinner hanging for a full minute on a flaky connection.
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// Retained so a newer keystroke can cancel the previous request; without this an
    /// older, slower response can land last and overwrite newer results.
    private var searchTask: URLSessionDataTask?

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastKnownLocation: CLLocation?
    @Published var currentCityName: String = ""
    @Published var currentCountryName: String = ""
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private var completionHandler: ((Result<LocationData, LocationFailure>) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func getCurrentLocation(completion: @escaping (Result<LocationData, LocationFailure>) -> Void) {
        self.completionHandler = completion
        setLoading(true)

        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        } else if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            finish(.failure(.permissionDenied))
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        onMain { self.authorizationStatus = status }

        // Only act on an authorization change we actually asked for. Firing
        // requestLocation() on every transition burns a GPS fix and a geocode when the
        // user merely returns from Settings with no request pending.
        guard completionHandler != nil else { return }

        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        } else if status == .denied || status == .restricted {
            finish(.failure(.permissionDenied))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        onMain { self.lastKnownLocation = location }

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("Reverse geocode failed: \(error.localizedDescription)")
                #endif
            }

            let placemark = placemarks?.first
            let city = placemark?.locality
                ?? placemark?.subAdministrativeArea
                ?? placemark?.administrativeArea
                ?? tr("current_location")
            let country = placemark?.country ?? ""

            // Prefer the timezone of the coordinate itself. Falling back to the device's
            // zone is only correct while the user is in it, but it beats refusing to
            // resolve a location at all — CLGeocoder is aggressively rate limited.
            let timezone = placemark?.timeZone?.identifier ?? TimeZone.current.identifier

            let locData = LocationData(
                name: city,
                country: country,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timezoneIdentifier: timezone
            )

            self.onMain {
                self.currentCityName = city
                self.currentCountryName = country
            }
            self.finish(.success(locData))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onMain { self.error = error }
        finish(.failure(.unavailable))
    }

    // MARK: - City search (Open-Meteo)

    /// `.success([])` means the query matched nothing; a `.failure` means we never got a
    /// usable answer. Collapsing both into an empty list is what made an offline device
    /// look like "no such city".
    func searchCity(query: String, completion: @escaping (Result<[LocationData], CitySearchFailure>) -> Void) {
        searchTask?.cancel()

        guard !query.isEmpty else {
            completion(.success([]))
            return
        }

        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encodedQuery)&count=10&language=\(Self.geocodingLanguage)&format=json") else {
            completion(.failure(.failed))
            return
        }

        let task = session.dataTask(with: url) { data, response, error in
            if let error = error as NSError? {
                // A cancelled task is a superseded keystroke, not a failure to report.
                guard error.code != NSURLErrorCancelled else { return }
                #if DEBUG
                print("Open-Meteo geocoding error: \(error.localizedDescription)")
                #endif
                let offline = [NSURLErrorNotConnectedToInternet,
                               NSURLErrorNetworkConnectionLost,
                               NSURLErrorTimedOut,
                               NSURLErrorCannotFindHost,
                               NSURLErrorDataNotAllowed].contains(error.code)
                DispatchQueue.main.async { completion(.failure(offline ? .offline : .failed)) }
                return
            }

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                #if DEBUG
                print("Open-Meteo geocoding HTTP \(http.statusCode)")
                #endif
                DispatchQueue.main.async { completion(.failure(.failed)) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(.failed)) }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                let locations = (decoded.results ?? []).map { result in
                    LocationData(
                        name: result.name,
                        country: result.country ?? "",
                        latitude: result.latitude,
                        longitude: result.longitude,
                        timezoneIdentifier: result.timezone ?? TimeZone.current.identifier
                    )
                }
                DispatchQueue.main.async { completion(.success(locations)) }
            } catch {
                #if DEBUG
                print("Failed to decode Open-Meteo response: \(error)")
                #endif
                DispatchQueue.main.async { completion(.failure(.failed)) }
            }
        }
        searchTask = task
        task.resume()
    }

    func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
    }

    /// Open-Meteo localizes city names, but only for a fixed set of languages — Arabic
    /// is not among them, so fall back to English rather than sending an unsupported code.
    private static var geocodingLanguage: String {
        let supported = ["en", "de", "fr", "es", "it", "pt", "ru", "tr"]
        let code = LanguageManager.shared.effectiveLanguageCode
        return supported.contains(code) ? code : "en"
    }

    // MARK: - Helpers

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    private func setLoading(_ value: Bool) {
        onMain { self.isLoading = value }
    }

    private func finish(_ result: Result<LocationData, LocationFailure>) {
        let handler = completionHandler
        completionHandler = nil
        onMain {
            self.isLoading = false
            handler?(result)
        }
    }
}

struct OpenMeteoResponse: Codable {
    let results: [OpenMeteoCity]?
}

struct OpenMeteoCity: Codable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let timezone: String?
}
