import Foundation

enum SampleData {
    static func haitianParking(into store: CasePackStore) throws -> CaseSource {
        try SampleCaseLoader.loadHaitianParking(into: store)
    }
}
