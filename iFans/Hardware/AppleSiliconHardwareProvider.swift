import Foundation
import IOKit
import IOKit.hid
import IOKit.hidsystem

private enum HIDBridge {
    @_silgen_name("IOHIDEventSystemClientCreate")
    nonisolated static func eventSystemClientCreate(_ allocator: CFAllocator?) -> IOHIDEventSystemClient

    @_silgen_name("IOHIDEventSystemClientSetMatching")
    nonisolated static func eventSystemClientSetMatching(_ client: IOHIDEventSystemClient, _ matching: CFDictionary)

    @_silgen_name("IOHIDServiceClientCopyEvent")
    nonisolated static func serviceClientCopyEvent(
        _ service: IOHIDServiceClient,
        _ eventType: Int64,
        _ options: Int32,
        _ timeout: Int64
    ) -> CFTypeRef?

    @_silgen_name("IOHIDEventGetFloatValue")
    nonisolated static func eventGetFloatValue(_ event: CFTypeRef, _ field: Int32) -> Double

    nonisolated static let temperatureEventType: Int64 = 15
    nonisolated static let temperatureFieldBase: Int32 = 15 << 16
}

struct HelperProbeFailureResolution: Equatable, Sendable {
    let keepsHelperChannel: Bool
    let reason: String
}

enum HelperProbeFailureResolver {
    nonisolated static func resolve(error: Error, unavailableMessage: String) -> HelperProbeFailureResolution {
        switch error {
        case let helperError as PrivilegedHelperClientError:
            switch helperError {
            case .helperUnavailable:
                return HelperProbeFailureResolution(
                    keepsHelperChannel: false,
                    reason: unavailableMessage
                )
            case let .versionMismatch(message):
                return HelperProbeFailureResolution(
                    keepsHelperChannel: false,
                    reason: message
                )
            case .helperRejected:
                return HelperProbeFailureResolution(
                    keepsHelperChannel: true,
                    reason: helperError.localizedDescription
                )
            case .invalidReply:
                return HelperProbeFailureResolution(
                    keepsHelperChannel: false,
                    reason: PrivilegedHelperServiceDefinition.versionMismatchMessage()
                )
            }
        default:
            return HelperProbeFailureResolution(
                keepsHelperChannel: true,
                reason: error.localizedDescription
            )
        }
    }
}

private struct HIDSensorService {
    let descriptor: SensorDescriptor
    nonisolated(unsafe) let service: IOHIDServiceClient
}

private struct SMCTemperatureProbe: Sendable {
    let key: String
    let name: String
    let kind: SensorKind
}

private enum SMCTemperatureCatalog {
    nonisolated static let probes: [SMCTemperatureProbe] = [
        SMCTemperatureProbe(key: "TC0P", name: "CPU", kind: .performanceCPU),
        SMCTemperatureProbe(key: "TC0E", name: "CPU 核心", kind: .performanceCPU),
        SMCTemperatureProbe(key: "TG0P", name: "GPU", kind: .gpu),
        SMCTemperatureProbe(key: "TG0D", name: "GPU 核心", kind: .gpu),
        SMCTemperatureProbe(key: "TB1T", name: "电池", kind: .battery),
        SMCTemperatureProbe(key: "Tm0P", name: "内存", kind: .memory),
        SMCTemperatureProbe(key: "Tm0S", name: "内存控制器", kind: .memory),
        SMCTemperatureProbe(key: "Ts0P", name: "SSD", kind: .storage),
        SMCTemperatureProbe(key: "Ts0S", name: "SSD 控制器", kind: .storage),
        SMCTemperatureProbe(key: "TW0P", name: "Wi-Fi", kind: .wireless),
        SMCTemperatureProbe(key: "TW0T", name: "无线模块", kind: .wireless),
        SMCTemperatureProbe(key: "TA0P", name: "环境", kind: .ambient)
    ]
}

private final class AppleSiliconTemperatureReader: @unchecked Sendable {
    nonisolated(unsafe) private let client: IOHIDEventSystemClient
    nonisolated(unsafe) private var services: [HIDSensorService] = []

    nonisolated init() {
        client = HIDBridge.eventSystemClientCreate(nil)
        let matching = [
            kIOHIDPrimaryUsagePageKey: NSNumber(value: 65280),
            kIOHIDPrimaryUsageKey: NSNumber(value: 5)
        ] as NSDictionary
        HIDBridge.eventSystemClientSetMatching(client, matching)
        refreshServices()
    }

    nonisolated func refreshServices() {
        let rawServices = (IOHIDEventSystemClientCopyServices(client) as? [IOHIDServiceClient]) ?? []
        var nameCounts: [String: Int] = [:]

        services = rawServices.compactMap { service in
            let rawName = (IOHIDServiceClientCopyProperty(service, kIOHIDProductKey as CFString) as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let baseName = rawName?.isEmpty == false ? rawName! : "Unknown Sensor"
            let count = nameCounts[baseName, default: 0]
            nameCounts[baseName] = count + 1
            let identifier = count == 0 ? baseName : "\(baseName)-\(count)"
            return HIDSensorService(
                descriptor: SensorDescriptor(
                    id: identifier,
                    name: displayName(for: baseName, ordinal: count + 1),
                    kind: sensorKind(for: baseName),
                    rawKey: baseName
                ),
                service: service
            )
        }
        .sorted { lhs, rhs in
            sensorPriority(lhs.descriptor.kind) < sensorPriority(rhs.descriptor.kind)
        }
    }

    nonisolated func sensorDescriptors() -> [SensorDescriptor] {
        services.map(\.descriptor)
    }

    nonisolated func sensorReadings() -> [SensorReading] {
        services.compactMap { sensor in
            guard
                let event = HIDBridge.serviceClientCopyEvent(sensor.service, HIDBridge.temperatureEventType, 0, 0)
            else {
                return nil
            }

            let value = HIDBridge.eventGetFloatValue(event, HIDBridge.temperatureFieldBase)
            guard value.isFinite, value > -40, value < 140 else {
                return nil
            }

            return SensorReading(id: sensor.descriptor.id, celsius: value)
        }
    }

    private nonisolated func sensorKind(for product: String) -> SensorKind {
        let lowered = product.lowercased()
        let normalized = lowered.replacingOccurrences(of: "_", with: " ")

        if normalized.contains("gpu") || product.contains("TP1g") || product.contains("TP2g") || product.contains("TP3g") {
            return .gpu
        }
        if normalized.contains("performance core")
            || normalized.contains("p-core")
            || normalized.contains("pcore")
            || product.contains("TP0s")
            || product.contains("TP1s")
        {
            return .performanceCPU
        }
        if normalized.contains("efficiency core")
            || normalized.contains("e-core")
            || normalized.contains("ecore")
            || product.contains("TP2s")
        {
            return .efficiencyCPU
        }
        if normalized.contains("cpu core average")
            || normalized.contains("cpu average")
            || normalized.contains("cpu")
        {
            return .performanceCPU
        }
        if lowered.contains("battery") {
            return .battery
        }
        if lowered.contains("airport") || lowered.contains("wifi") || lowered.contains("wlan") || lowered.contains("wireless") {
            return .wireless
        }
        if lowered.contains("ssd") || lowered.contains("nand") || lowered.contains("storage") || lowered.contains("nvme") {
            return .storage
        }
        if lowered.contains("dram") || lowered.contains("memory") || lowered.contains("mem") {
            return .memory
        }
        if product.contains("tcal") {
            return .ambient
        }
        return .raw
    }

    private nonisolated func displayName(for product: String, ordinal: Int) -> String {
        let lowered = product.lowercased()

        if lowered.contains("cpu core average") || lowered.contains("cpu average") {
            return "CPU 平均"
        }
        if lowered.contains("performance core") || lowered.contains("p-core") || lowered.contains("pcore") {
            return "性能核 \(ordinal)"
        }
        if lowered.contains("efficiency core") || lowered.contains("e-core") || lowered.contains("ecore") {
            return "效率核 \(ordinal)"
        }

        switch sensorKind(for: product) {
        case .performanceCPU:
            return "性能簇 \(ordinal)"
        case .efficiencyCPU:
            return "效率簇"
        case .gpu:
            return "GPU 簇 \(ordinal)"
        case .battery:
            return ordinal == 1 ? "电池" : "电池 \(ordinal)"
        case .memory:
            return ordinal == 1 ? "内存" : "内存 \(ordinal)"
        case .storage:
            return ordinal == 1 ? "SSD" : "SSD \(ordinal)"
        case .wireless:
            return ordinal == 1 ? "Wi-Fi" : "Wi-Fi \(ordinal)"
        case .ambient:
            return "环境 / 校准"
        case .raw:
            return product
        }
    }

    private nonisolated func sensorPriority(_ kind: SensorKind) -> Int {
        switch kind {
        case .performanceCPU:
            0
        case .efficiencyCPU:
            1
        case .gpu:
            2
        case .battery:
            3
        case .memory:
            4
        case .storage:
            5
        case .wireless:
            6
        case .ambient:
            7
        case .raw:
            8
        }
    }
}

actor AppleSiliconHardwareProvider: HardwareProvider {
    private enum ControlTransport: Sendable {
        case direct
        case privilegedHelper

        var description: String {
            switch self {
            case .direct:
                "主进程直连 AppleSMC"
            case .privilegedHelper:
                "辅助控件"
            }
        }
    }

    private let smc = SMCBridge()
    private let helper = PrivilegedHelperClient()
    private let temperatureReader = AppleSiliconTemperatureReader()
    private var cachedInventory: HardwareInventory?
    private var controlTransport: ControlTransport?
    private var controlTransportReason: String?
    private var discoveryIssue: HardwareCapability?
    private var lastHardwareError: String?

    func discover() async throws -> HardwareInventory {
        temperatureReader.refreshServices()
        let sensors = mergedSensorDescriptors(
            primary: temperatureReader.sensorDescriptors(),
            secondary: discoverSMCTemperatureDescriptors()
        )
        let fans = try discoverFans(using: sensors)
        await ensureControlTransportResolved(using: fans)
        let capability = FanCapabilityResolver.resolve(
            fans: fans,
            discoveryIssue: discoveryIssue,
            forcedReadOnlyReason: controlTransportReason
        )
        let inventory = HardwareInventory(fans: fans, sensors: sensors, capability: capability)
        cachedInventory = inventory
        return inventory
    }

    func snapshot() async throws -> ThermalSnapshot {
        let inventory = try await inventory()
        let readings: [FanReading]
        do {
            readings = try inventory.fans.map { fan in
                try smc?.fanReading(for: fan) ?? FanReading(id: fan.id, currentRPM: 0, targetRPM: nil)
            }
        } catch let error as HardwareControlError {
            lastHardwareError = error.localizedDescription
            throw error
        } catch {
            let message = "AppleSMC 风扇读取失败，已自动降级为监控模式。"
            lastHardwareError = message
            throw HardwareControlError.readFailed(message)
        }
        let sensors = mergedSensorReadings(
            primary: temperatureReader.sensorReadings(),
            secondary: readSMCTemperatureReadings()
        )
        let hottest = hottestRealtimeTemperature(
            from: sensors,
            descriptors: inventory.sensors
        )

        return ThermalSnapshot(
            timestamp: .now,
            hottestTemp: hottest,
            fans: readings,
            sensors: sensors,
            capability: FanCapabilityResolver.resolve(
                fans: inventory.fans,
                discoveryIssue: discoveryIssue,
                forcedReadOnlyReason: controlTransportReason
            )
        )
    }

    func apply(_ mode: FanMode) async throws {
        let inventory = try await inventory()
        await ensureControlTransportResolved(using: inventory.fans)
        let capability = FanCapabilityResolver.resolve(
            fans: inventory.fans,
            discoveryIssue: discoveryIssue,
            forcedReadOnlyReason: controlTransportReason
        )
        let controllableFans = inventory.fans.filter(\.supportsManualControl)
        guard capability.allowsControl, !controllableFans.isEmpty else {
            throw HardwareControlError.unsupported(capability.message)
        }

        guard let transport = controlTransport else {
            throw HardwareControlError.unsupported(capability.message)
        }

        if mode == .systemAuto {
            _ = await restoreAutomatic()
            return
        }

        do {
            let operations = controllableFans.compactMap { fan in
                ControlPreset.targetRPM(for: mode, fan: fan).map {
                    (fan, FanControlOperation(fanID: fan.id, targetRPM: $0))
                }
            }

            switch transport {
            case .direct:
                guard let smc else {
                    throw HardwareControlError.unsupported("当前设备没有可用的 AppleSMC 风扇控制接口。")
                }
                try applyDirect(
                    operations.map { ($0.0, $0.1.targetRPM) },
                    using: smc
                )
            case .privilegedHelper:
                try await helper.apply(operations: operations.map(\.1))
            }

            lastHardwareError = nil
        } catch {
            lastHardwareError = error.localizedDescription
            _ = await restoreAutomatic()
            controlTransport = nil
            controlTransportReason = nil
            await ensureControlTransportResolved(using: inventory.fans, force: true)
            if let error = error as? HardwareControlError {
                throw error
            }
            throw HardwareControlError.denied("风扇写入验证失败，已恢复系统自动。")
        }
    }

    func restoreAutomatic() async -> RestoreAutomaticResult {
        guard let inventory = cachedInventory else {
            return .skipped
        }

        let controllableFans = inventory.fans.filter(\.supportsManualControl)
        guard !controllableFans.isEmpty else {
            lastHardwareError = nil
            return .skipped
        }

        if controlTransport == nil {
            await ensureControlTransportResolved(using: inventory.fans, force: true)
        }

        do {
            switch controlTransport {
            case .direct:
                guard let smc else {
                    let message = "当前设备没有可用的 AppleSMC 风扇控制接口。"
                    lastHardwareError = message
                    return .failed(message)
                }
                for fan in controllableFans {
                    try smc.restoreAutomatic(for: fan)
                }
            case .privilegedHelper:
                try await helper.restoreAutomatic(fanIDs: controllableFans.map(\.id))
            case nil:
                return .skipped
            }

            return .restored
        } catch {
            let message = error.localizedDescription
            lastHardwareError = message
            return .failed(message)
        }
    }

    func diagnostics() async -> HardwareDiagnostics {
        HardwareDiagnostics(
            fanCount: cachedInventory?.fans.count,
            controlChannel: controlTransport?.description,
            lastError: lastHardwareError
        )
    }

    private func inventory() async throws -> HardwareInventory {
        if let cachedInventory {
            return cachedInventory
        }
        return try await discover()
    }

    private func ensureControlTransportResolved(
        using fans: [FanDescriptor],
        force: Bool = false
    ) async {
        if !force,
           controlTransportReason == nil,
           controlTransport != nil,
           cachedInventory?.fans == fans
        {
            return
        }

        await resolveControlTransport(using: fans)
    }

    private func discoverSMCTemperatureDescriptors() -> [SensorDescriptor] {
        guard let smc else {
            return []
        }

        return SMCTemperatureCatalog.probes.compactMap { probe in
            guard
                let value = try? smc.read(key: probe.key),
                normalizedTemperature(from: value) != nil
            else {
                return nil
            }

            return SensorDescriptor(
                id: "smc-\(probe.key)",
                name: probe.name,
                kind: probe.kind,
                rawKey: probe.key
            )
        }
    }

    private func readSMCTemperatureReadings() -> [SensorReading] {
        guard let smc else {
            return []
        }

        return SMCTemperatureCatalog.probes.compactMap { probe in
            guard
                let value = try? smc.read(key: probe.key),
                let celsius = normalizedTemperature(from: value)
            else {
                return nil
            }

            return SensorReading(id: "smc-\(probe.key)", celsius: celsius)
        }
    }

    private func normalizedTemperature(from value: SMCDecodedValue) -> Double? {
        if let floatValue = value.floatValue {
            let temperature = Double(floatValue)
            guard temperature.isFinite, temperature > -40, temperature < 140 else {
                return nil
            }
            return temperature
        }

        if let intValue = value.intValue {
            let temperature = Double(intValue)
            guard temperature.isFinite, temperature > -40, temperature < 140 else {
                return nil
            }
            return temperature
        }

        return nil
    }

    private func mergedSensorDescriptors(
        primary: [SensorDescriptor],
        secondary: [SensorDescriptor]
    ) -> [SensorDescriptor] {
        var merged = primary
        var knownIDs = Set(primary.map(\.id))

        for descriptor in secondary where !knownIDs.contains(descriptor.id) {
            merged.append(descriptor)
            knownIDs.insert(descriptor.id)
        }

        return merged
    }

    private func mergedSensorReadings(
        primary: [SensorReading],
        secondary: [SensorReading]
    ) -> [SensorReading] {
        var merged = primary
        var knownIDs = Set(primary.map(\.id))

        for reading in secondary where !knownIDs.contains(reading.id) {
            merged.append(reading)
            knownIDs.insert(reading.id)
        }

        return merged
    }

    private func hottestRealtimeTemperature(
        from readings: [SensorReading],
        descriptors: [SensorDescriptor]
    ) -> Double? {
        guard !readings.isEmpty else {
            return nil
        }

        let descriptorByID = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.id, $0) })
        let realtimeReadings = readings.filter { reading in
            guard let descriptor = descriptorByID[reading.id] else {
                return true
            }

            if descriptor.kind == .ambient {
                return false
            }

            let rawKey = descriptor.rawKey?.lowercased() ?? ""
            if rawKey.contains("tcal") || rawKey.contains("calibration") {
                return false
            }

            return true
        }

        return realtimeReadings.map(\.celsius).max() ?? readings.map(\.celsius).max()
    }

    private func discoverFans(using sensors: [SensorDescriptor]) throws -> [FanDescriptor] {
        guard let smc else {
            let message = sensors.isEmpty
                ? "当前设备没有可用的 AppleSMC 风扇读取接口。"
                : "AppleSMC 风扇读取接口不可用，已自动降级为监控模式。"
            lastHardwareError = message
            discoveryIssue = sensors.isEmpty ? .unsupported(message) : .readOnly(message)
            return []
        }

        do {
            let fans = try smc.fanDescriptors()
            lastHardwareError = nil
            discoveryIssue = nil
            return fans
        } catch let error as HardwareControlError {
            lastHardwareError = error.localizedDescription
            discoveryIssue = .readOnly(error.localizedDescription)
            return []
        } catch {
            let message = "AppleSMC 风扇读取失败，已自动降级为监控模式。"
            lastHardwareError = message
            discoveryIssue = .readOnly(message)
            return []
        }
    }

    private func resolveControlTransport(using fans: [FanDescriptor]) async {
        let controllableFans = fans.filter(\.supportsManualControl)
        guard !controllableFans.isEmpty else {
            controlTransport = nil
            controlTransportReason = nil
            return
        }

        let helperUnavailableMessage = helper.unavailableMessage(for: controllableFans.count)
        var helperFallbackReason: String?
        do {
            _ = try await helper.handshake()
            try await helper.probe(fans: controllableFans)
            controlTransport = .privilegedHelper
            controlTransportReason = nil
            lastHardwareError = nil
            return
        } catch {
            let resolution = HelperProbeFailureResolver.resolve(
                error: error,
                unavailableMessage: helperUnavailableMessage
            )
            if resolution.keepsHelperChannel {
                controlTransport = .privilegedHelper
                controlTransportReason = resolution.reason
                lastHardwareError = error.localizedDescription
                return
            }
            helperFallbackReason = resolution.reason
        }

        if let smc {
            do {
                for fan in controllableFans {
                    try smc.probeWriteAccess(for: fan)
                }
                controlTransport = .direct
                controlTransportReason = nil
                lastHardwareError = nil
                return
            } catch let error as HardwareControlError {
                lastHardwareError = error.localizedDescription
            } catch {
                lastHardwareError = error.localizedDescription
            }
        }

        controlTransport = nil
        controlTransportReason = helperFallbackReason ?? helperUnavailableMessage
    }

    private func applyDirect(
        _ operations: [(FanDescriptor, Int)],
        using smc: SMCBridge
    ) throws {
        for (fan, targetRPM) in operations {
            try smc.apply(targetRPM: targetRPM, to: fan)
            guard try smc.verifyManualControl(for: fan, expectedTargetRPM: targetRPM) else {
                throw HardwareControlError.denied("风扇写入验证失败，已恢复系统自动。")
            }
        }
    }
}
