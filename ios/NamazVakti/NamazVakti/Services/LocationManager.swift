import CoreLocation
import Foundation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastKnownLocation: CLLocation?
    @Published var currentCityName: String = ""
    @Published var currentCountryName: String = ""
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    private var completionHandler: ((LocationData?) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func getCurrentLocation(completion: @escaping (LocationData?) -> Void) {
        self.completionHandler = completion
        self.isLoading = true
        
        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        } else if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            // Denied or restricted
            self.isLoading = false
            completion(nil)
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            completionHandler?(nil)
            completionHandler = nil
            isLoading = false
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastKnownLocation = location
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            self.isLoading = false
            
            let city = placemarks?.first?.locality ?? 
                       placemarks?.first?.subAdministrativeArea ?? 
                       placemarks?.first?.administrativeArea ?? 
                       "Mevcut Konum"
            let country = placemarks?.first?.country ?? ""
            let timezone = placemarks?.first?.timeZone?.identifier ?? TimeZone.current.identifier
            
            self.currentCityName = city
            self.currentCountryName = country
            
            let locData = LocationData(
                name: city,
                country: country,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timezoneIdentifier: timezone
            )
            
            self.completionHandler?(locData)
            self.completionHandler = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = error
        self.isLoading = false
        self.completionHandler?(nil)
        self.completionHandler = nil
    }
    
    // Search city from Open-Meteo
    func searchCity(query: String, completion: @escaping ([LocationData]) -> Void) {
        guard !query.isEmpty else {
            completion([])
            return
        }
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encodedQuery)&count=10&language=tr&format=json") else {
            completion([])
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Open-Meteo Geocoding search error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                let locations = response.results?.map { result in
                    LocationData(
                        name: result.name,
                        country: result.country ?? "",
                        latitude: result.latitude,
                        longitude: result.longitude,
                        timezoneIdentifier: result.timezone ?? TimeZone.current.identifier
                    )
                } ?? []
                
                DispatchQueue.main.async {
                    completion(locations)
                }
            } catch {
                print("Failed to decode Open-Meteo: \(error)")
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
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
