import Foundation

actor PreviewHardwareProvider: HardwareProvider {
    enum Scenario {
        case controllable
        case readOnly
        case helperInstallRequired
    }

    private let scenario: Scenario

    init(scenario: Scenario = .controllable) {
        self.scenario = scenario
    }

    private var fans: [FanDescriptor] {
        [
            FanDescriptor(
                id: "F0Ac",
                name: "左风扇",
                defaultMinRPM: 1200,
                maxRPM: 5800,
                supportsManualControl: scenario == .controllable
            ),
            FanDescriptor(
                id: "F1Ac",
                name: "右风扇",
                defaultMinRPM: 1200,
                maxRPM: 6200,
                supportsManualControl: scenario == .controllable
            )
        ]
    }

    private let sensors = [
        SensorDescriptor(id: "perf-1", name: "性能簇 1", kind: .performanceCPU, rawKey: "PMU TP0s"),
        SensorDescriptor(id: "gpu-1", name: "GPU 簇 1", kind: .gpu, rawKey: "PMU TP1g"),
        SensorDescriptor(id: "battery", name: "电池", kind: .battery, rawKey: "gas gauge battery")
    ]

    private var capability: HardwareCapability {
        switch scenario {
        case .controllable:
            return .controllable
        case .readOnly:
            return .readOnly("预览环境当前为监控模式，保留系统自动控制。")
        case .helperInstallRequired:
            return .readOnly(PrivilegedHelperServiceDefinition.versionMismatchMessage())
        }
    }

    func discover() async throws -> HardwareInventory {
        HardwareInventory(fans: fans, sensors: sensors, capability: capability)
    }

    func snapshot() async throws -> ThermalSnapshot {
        ThermalSnapshot(
            timestamp: .now,
            hottestTemp: scenario == .controllable ? 54.7 : 63.2,
            fans: [
                FanReading(
                    id: "F0Ac",
                    currentRPM: scenario == .controllable ? 1450 : 1320,
                    targetRPM: scenario == .controllable ? 1800 : nil
                ),
                FanReading(
                    id: "F1Ac",
                    currentRPM: scenario == .controllable ? 1520 : 1380,
                    targetRPM: scenario == .controllable ? 1800 : nil
                )
            ],
            sensors: [
                SensorReading(id: "perf-1", celsius: scenario == .controllable ? 54.7 : 63.2),
                SensorReading(id: "gpu-1", celsius: scenario == .controllable ? 48.2 : 56.8),
                SensorReading(id: "battery", celsius: 31.8)
            ],
            capability: capability
        )
    }

    func apply(_ mode: FanMode) async throws {
        guard scenario == .controllable else {
            throw HardwareControlError.unsupported(capability.message)
        }
    }

    func restoreAutomatic() async -> RestoreAutomaticResult {
        .skipped
    }

    func diagnostics() async -> HardwareDiagnostics {
        HardwareDiagnostics(
            fanCount: fans.count,
            controlChannel: scenario == .controllable ? "预览辅助控件" : "预览监控",
            lastError: scenario == .controllable ? nil : capability.message
        )
    }
}
