import Foundation

enum RestoreAutomaticResult: Equatable, Sendable {
    case skipped
    case restored
    case failed(String)
}

protocol HardwareProvider: Sendable {
    func discover() async throws -> HardwareInventory
    func snapshot() async throws -> ThermalSnapshot
    func apply(_ mode: FanMode) async throws
    func restoreAutomatic() async -> RestoreAutomaticResult
    func diagnostics() async -> HardwareDiagnostics
}

actor UnsupportedHardwareProvider: HardwareProvider {
    private let capability: HardwareCapability
    private let diagnosticsState: HardwareDiagnostics

    init(message: String) {
        self.capability = .unsupported(message)
        self.diagnosticsState = HardwareDiagnostics(
            fanCount: nil,
            controlChannel: nil,
            lastError: message
        )
    }

    func discover() async throws -> HardwareInventory {
        HardwareInventory(fans: [], sensors: [], capability: capability)
    }

    func snapshot() async throws -> ThermalSnapshot {
        ThermalSnapshot(
            timestamp: .now,
            hottestTemp: nil,
            fans: [],
            sensors: [],
            capability: capability
        )
    }

    func apply(_ mode: FanMode) async throws {
        throw HardwareControlError.unsupported(capability.message)
    }

    func restoreAutomatic() async -> RestoreAutomaticResult {
        .skipped
    }

    func diagnostics() async -> HardwareDiagnostics {
        diagnosticsState
    }
}
