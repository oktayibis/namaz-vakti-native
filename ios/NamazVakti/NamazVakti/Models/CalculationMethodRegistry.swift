import Foundation

struct CalculationMethodInfo: Identifiable, Hashable {
    let id: Int
    let name: String
    let region: String
}

enum CalculationMethodRegistry {
    static let methods: [CalculationMethodInfo] = [
        CalculationMethodInfo(id: 13, name: "Türkiye (Diyanet)", region: "Türkiye & Avrupa"),
        CalculationMethodInfo(id: 3, name: "Muslim World League (MWL)", region: "Europe & Global Default"),
        CalculationMethodInfo(id: 4, name: "Umm Al-Qura (Makkah)", region: "Saudi Arabia & Gulf"),
        CalculationMethodInfo(id: 2, name: "ISNA", region: "North America (USA & Canada)"),
        CalculationMethodInfo(id: 15, name: "Moonsighting Committee", region: "North America & UK"),
        CalculationMethodInfo(id: 1, name: "Karachi (Univ. of Islamic Sciences)", region: "Pakistan, India, Bangladesh"),
        CalculationMethodInfo(id: 5, name: "Egyptian General Authority", region: "Egypt & North Africa"),
        CalculationMethodInfo(id: 16, name: "Dubai (Islamic Affairs)", region: "United Arab Emirates"),
        CalculationMethodInfo(id: 11, name: "Singapore (MUIS)", region: "Singapore & SE Asia"),
        CalculationMethodInfo(id: 9, name: "Kuwait", region: "Kuwait"),
        CalculationMethodInfo(id: 10, name: "Qatar", region: "Qatar")
    ]

    static func getMethodName(for id: Int) -> String {
        guard let method = methods.first(where: { $0.id == id }) else {
            return "Muslim World League (MWL)"
        }
        return "\(method.name) (\(method.region))"
    }
}
