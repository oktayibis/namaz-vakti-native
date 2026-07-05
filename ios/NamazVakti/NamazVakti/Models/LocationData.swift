import Foundation

struct LocationData: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let name: String
    let country: String
    let latitude: Double
    let longitude: Double
    let timezoneIdentifier: String
    
    // Helper to check if two locations are the same based on coordinates
    func isSameLocation(as other: LocationData) -> Bool {
        return abs(self.latitude - other.latitude) < 0.001 &&
               abs(self.longitude - other.longitude) < 0.001
    }
}
