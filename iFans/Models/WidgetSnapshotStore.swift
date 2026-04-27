import Foundation

struct WidgetSnapshotPayload: Codable, Sendable {
    let modeTitle: String
    let statusText: String
    let hottestTemperature: Double?
    let fanSummary: String
    let updatedAt: Date
}

struct WidgetSnapshotStore {
    static let appGroupIdentifier = "group.com.sobigrice.ohFans"
    static let defaultsKey = "widget.snapshot.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard) {
        self.defaults = defaults
    }

    func save(_ payload: WidgetSnapshotPayload) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(payload) else {
            return
        }

        defaults.set(data, forKey: Self.defaultsKey)
    }
}
