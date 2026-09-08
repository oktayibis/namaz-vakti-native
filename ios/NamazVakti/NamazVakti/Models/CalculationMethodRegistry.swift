import Foundation

struct CalculationMethodInfo: Identifiable, Hashable {
    let id: Int
    /// The issuing authority's own name. Institution names are proper nouns and stay
    /// untranslated; only the region descriptor below is localized.
    let name: String
    private let regionKey: String

    init(id: Int, name: String, regionKey: String) {
        self.id = id
        self.name = name
        self.regionKey = regionKey
    }

    var region: String { tr(regionKey) }
}

enum CalculationMethodRegistry {
    static let methods: [CalculationMethodInfo] = [
        CalculationMethodInfo(id: 13, name: "Türkiye (Diyanet)", regionKey: "region_tr_eu"),
        CalculationMethodInfo(id: 3, name: "Muslim World League (MWL)", regionKey: "region_global"),
        CalculationMethodInfo(id: 4, name: "Umm Al-Qura (Makkah)", regionKey: "region_gulf"),
        CalculationMethodInfo(id: 2, name: "ISNA", regionKey: "region_north_america"),
        CalculationMethodInfo(id: 15, name: "Moonsighting Committee", regionKey: "region_na_uk"),
        CalculationMethodInfo(id: 1, name: "Karachi (Univ. of Islamic Sciences)", regionKey: "region_south_asia"),
        CalculationMethodInfo(id: 5, name: "Egyptian General Authority", regionKey: "region_egypt"),
        CalculationMethodInfo(id: 16, name: "Dubai (Islamic Affairs)", regionKey: "region_uae"),
        CalculationMethodInfo(id: 11, name: "Singapore (MUIS)", regionKey: "region_sea"),
        CalculationMethodInfo(id: 9, name: "Kuwait", regionKey: "region_kuwait"),
        CalculationMethodInfo(id: 10, name: "Qatar", regionKey: "region_qatar")
    ]

    static func getMethodName(for id: Int) -> String {
        guard let method = methods.first(where: { $0.id == id }) else {
            return "Muslim World League (MWL)"
        }
        return "\(method.name) (\(method.region))"
    }
}
