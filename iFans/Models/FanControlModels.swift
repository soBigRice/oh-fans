import Foundation

enum AppBrand {
    nonisolated static let displayName = "oh fans"
    nonisolated static let helperDisplayName = "\(displayName) 辅助控件"
    nonisolated static let helperControllerDisplayName = helperDisplayName
    nonisolated static let menuBarAccessibilityLabel = "\(displayName) 菜单栏"
    nonisolated static let authorName = "soBigRice"
    nonisolated static let authorProfileURL = URL(string: "https://github.com/soBigRice")!
    nonisolated static let githubRepositoryURL = URL(string: "https://github.com/soBigRice/oh-fans")!
    nonisolated static let githubReleasesURL = URL(string: "https://github.com/soBigRice/oh-fans/releases/tag/v1.0")!
    nonisolated static let githubLatestReleaseAPIURL = URL(string: "https://api.github.com/repos/soBigRice/oh-fans/releases/latest")!

    nonisolated static func versionDescription(bundle: Bundle = .main) -> String {
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, buildVersion) {
        case let (shortVersion?, buildVersion?) where shortVersion != buildVersion:
            return "\(shortVersion) (\(buildVersion))"
        case let (shortVersion?, _):
            return shortVersion
        case let (_, buildVersion?):
            return buildVersion
        default:
            return "未知"
        }
    }
}

enum WindowIdentifier: String {
    case main
}

enum AppPreferenceKey {
    nonisolated static let selectedFanMode = "selectedFanMode"
    nonisolated static let panelAppearanceStyle = "panelAppearanceStyle"
    nonisolated static let launchAtLoginEnabled = "launchAtLoginEnabled"
    nonisolated static let dockIconHidden = "dockIconHidden"
}

enum FanMode: String, CaseIterable, Identifiable, Sendable {
    case systemAuto
    case quiet
    case balanced
    case performance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemAuto:
            "系统自动"
        case .quiet:
            "安静"
        case .balanced:
            "均衡"
        case .performance:
            "性能"
        }
    }

    var symbol: String {
        switch self {
        case .systemAuto:
            "aqi.low"
        case .quiet:
            "moon.zzz.fill"
        case .balanced:
            "circle.lefthalf.filled"
        case .performance:
            "bolt.fill"
        }
    }

    var detail: String {
        switch self {
        case .systemAuto:
            "恢复系统热管理。"
        case .quiet:
            "保持 Apple 默认最小转速。"
        case .balanced:
            "提高到风扇可用区间的 40%。"
        case .performance:
            "直接拉到风扇最大转速。"
        }
    }
}

enum SensorKind: String, Sendable {
    case performanceCPU
    case efficiencyCPU
    case gpu
    case battery
    case memory
    case storage
    case wireless
    case ambient
    case raw
}

enum HardwareCapability: Equatable, Sendable {
    case controllable
    case readOnly(String)
    case unsupported(String)

    nonisolated var allowsControl: Bool {
        if case .controllable = self {
            return true
        }
        return false
    }

    nonisolated var message: String {
        switch self {
        case .controllable:
            "已验证风扇控制通道，可切换预设模式。"
        case let .readOnly(reason), let .unsupported(reason):
            reason
        }
    }
}

struct FanCapabilityResolver {
    nonisolated static let noFanMessage = "当前设备没有可发现的内建风扇，已自动降级为监控模式。"

    nonisolated static func resolve(
        fans: [FanDescriptor],
        discoveryIssue: HardwareCapability? = nil,
        forcedReadOnlyReason: String? = nil
    ) -> HardwareCapability {
        if let forcedReadOnlyReason {
            return .readOnly(forcedReadOnlyReason)
        }

        if let discoveryIssue {
            return discoveryIssue
        }

        guard !fans.isEmpty else {
            return .unsupported(noFanMessage)
        }

        if fans.contains(where: \.supportsManualControl) {
            return .controllable
        }

        return .readOnly("已发现 \(fans.count) 个内建风扇，但当前机型未暴露可验证的控制 key。")
    }
}

struct FanDescriptor: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let defaultMinRPM: Int
    let maxRPM: Int
    let supportsManualControl: Bool
}

struct FanReading: Identifiable, Equatable, Sendable {
    let id: String
    let currentRPM: Int
    let targetRPM: Int?
}

struct SensorDescriptor: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let kind: SensorKind
    let rawKey: String?
}

struct SensorReading: Identifiable, Equatable, Sendable {
    let id: String
    let celsius: Double
}

struct ThermalSnapshot: Sendable {
    let timestamp: Date
    let hottestTemp: Double?
    let fans: [FanReading]
    let sensors: [SensorReading]
    let capability: HardwareCapability
}

struct HardwareInventory: Sendable {
    var fans: [FanDescriptor]
    var sensors: [SensorDescriptor]
    var capability: HardwareCapability
}

struct HardwareDiagnostics: Equatable, Sendable {
    var fanCount: Int?
    var controlChannel: String?
    var lastError: String?
}

struct ControlPreset {
    nonisolated static func targetRPM(for mode: FanMode, fan: FanDescriptor) -> Int? {
        switch mode {
        case .systemAuto:
            nil
        case .quiet:
            clamp(fan.defaultMinRPM, for: fan)
        case .balanced:
            clamp(
                fan.defaultMinRPM + Int(Double(fan.maxRPM - fan.defaultMinRPM) * 0.40),
                for: fan
            )
        case .performance:
            fan.maxRPM
        }
    }

    private nonisolated static func clamp(_ rpm: Int, for fan: FanDescriptor) -> Int {
        max(fan.defaultMinRPM, min(fan.maxRPM, rpm))
    }
}

enum HardwareControlError: LocalizedError, Sendable {
    case unsupported(String)
    case denied(String)
    case readFailed(String)

    var errorDescription: String? {
        switch self {
        case let .unsupported(message), let .denied(message), let .readFailed(message):
            message
        }
    }
}

enum SafetyPolicy {
    static let emergencyTemperature = 95.0
    static let maxConsecutiveReadFailures = 3

    static func forceAutomaticReason(
        mode: FanMode,
        hottestTemp: Double?,
        consecutiveReadFailures: Int
    ) -> String? {
        guard mode != .systemAuto else {
            return nil
        }

        if let hottestTemp, hottestTemp >= emergencyTemperature {
            return "检测到最高温度达到 \(Int(hottestTemp.rounded()))°C，已恢复系统自动控制。"
        }

        if consecutiveReadFailures >= maxConsecutiveReadFailures {
            return "连续 \(consecutiveReadFailures) 次读取硬件失败，已恢复系统自动控制。"
        }

        return nil
    }
}

extension Double {
    var temperatureText: String {
        String(format: "%.1f°C", self)
    }
}

extension Int {
    var rpmText: String {
        "\(self) RPM"
    }
}
