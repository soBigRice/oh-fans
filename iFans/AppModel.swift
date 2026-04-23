import Darwin
import Foundation
import Observation
import Security

enum AppAppearanceStyle: String, CaseIterable, Identifiable, Sendable {
    case highTransparency
    case normal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highTransparency:
            return "高透"
        case .normal:
            return "正常"
        }
    }
}

struct AppRuntimeEnvironment: Sendable {
    let isSandboxed: Bool
    let machineIdentifier: String

    nonisolated var buildModeTitle: String {
        isSandboxed ? "沙盒构建" : "非沙盒侧载构建"
    }

    nonisolated var sandboxUnsupportedMessage: String {
        "当前构建启用了 App Sandbox，AppleSMC 在该分发模式下不可用；请使用侧载直连构建。"
    }

    nonisolated static func current() -> AppRuntimeEnvironment {
        AppRuntimeEnvironment(
            isSandboxed: detectSandbox(),
            machineIdentifier: currentMachineIdentifier()
        )
    }

    private nonisolated static func detectSandbox() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else {
            return false
        }

        let entitlement = SecTaskCopyValueForEntitlement(
            task,
            "com.apple.security.app-sandbox" as CFString,
            nil
        )
        return (entitlement as? Bool) == true
    }

    private nonisolated static func currentMachineIdentifier() -> String {
        var size: size_t = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 1 else {
            return Host.current().localizedName ?? "Unknown Mac"
        }

        var value = [CChar](repeating: 0, count: Int(size))
        guard sysctlbyname("hw.model", &value, &size, nil, 0) == 0 else {
            return Host.current().localizedName ?? "Unknown Mac"
        }

        return String(cString: value)
    }
}

@MainActor
@Observable
final class AppModel {
    private enum TerminationRestoreOutcome {
        case completed(RestoreAutomaticResult)
        case timedOut
    }

    private enum DefaultsKey {
        nonisolated static let selectedMode = "selectedFanMode"
        nonisolated static let appearanceStyle = "panelAppearanceStyle"
    }

    private let provider: any HardwareProvider
    let runtimeEnvironment: AppRuntimeEnvironment
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let helperInstaller: any PrivilegedHelperInstalling
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private let startupControlRetryAttempts: Int
    @ObservationIgnored private let startupControlRetryDelay: Duration
    @ObservationIgnored private var isPreparingForTermination = false

    var inventory: HardwareInventory?
    var hardwareDiagnostics = HardwareDiagnostics()
    var latestSnapshot: ThermalSnapshot?
    var selectedMode: FanMode
    var statusMessage: String?
    var isLoading = true
    var isInstallingHelper = false
    var consecutiveReadFailures = 0
    var appearanceStyle: AppAppearanceStyle

    init(
        provider: any HardwareProvider,
        defaults: UserDefaults = .standard,
        runtimeEnvironment: AppRuntimeEnvironment = .current(),
        helperInstaller: any PrivilegedHelperInstalling = LivePrivilegedHelperInstaller(),
        startupControlRetryAttempts: Int = 4,
        startupControlRetryDelay: Duration = .milliseconds(250)
    ) {
        self.provider = provider
        self.runtimeEnvironment = runtimeEnvironment
        self.defaults = defaults
        self.helperInstaller = helperInstaller
        self.startupControlRetryAttempts = startupControlRetryAttempts
        self.startupControlRetryDelay = startupControlRetryDelay
        self.selectedMode = Self.persistedSelectedMode(using: defaults)
        self.appearanceStyle = Self.persistedAppearanceStyle(using: defaults)
    }

    deinit {
        pollTask?.cancel()
    }

    var canControl: Bool {
        inventory?.capability.allowsControl ?? false
    }

    var capabilityMessage: String {
        inventory?.capability.message ?? "正在探测硬件能力…"
    }

    var buildModeDescription: String {
        runtimeEnvironment.buildModeTitle
    }

    var machineIdentifier: String {
        runtimeEnvironment.machineIdentifier
    }

    var detectedFanCount: Int {
        inventory?.fans.count ?? hardwareDiagnostics.fanCount ?? 0
    }

    var controlChannelDescription: String {
        hardwareDiagnostics.controlChannel ?? "未建立"
    }

    var lastHardwareErrorMessage: String {
        hardwareDiagnostics.lastError ?? "无"
    }

    var helperInstallAction: PrivilegedHelperInstallAction? {
        PrivilegedHelperServiceDefinition.installAction(
            statusMessage: statusMessage,
            capability: inventory?.capability,
            lastError: hardwareDiagnostics.lastError
        )
    }

    var helperInstallStatusText: String {
        if isInstallingHelper, let helperInstallAction {
            return helperInstallAction.kind.progressMessage
        }

        if let helperInstallAction {
            return helperInstallAction.reason
        }

        if canControl {
            return "当前辅助控件已就绪，可直接切换风扇模式。"
        }

        if runtimeEnvironment.isSandboxed {
            return runtimeEnvironment.sandboxUnsupportedMessage
        }

        return "当前没有需要安装或重装辅助控件的问题。"
    }

    var helperInstallDetailText: String {
        guard let helperInstallAction else {
            return "只有在辅助控件缺失或版本不匹配时，风扇控制才会退回监控模式。"
        }

        switch helperInstallAction.kind {
        case .install:
            return "点击后会请求管理员授权，并执行当前 app 内置的辅助控件安装流程；安装完成后会立刻验证控制通道是否已上线。未安装前只能监控，不能切换风扇模式。"
        case .reinstall:
            return "点击后会请求管理员授权，并重装当前版本的辅助控件；安装完成后会立刻验证控制通道是否已上线。旧版或异常辅助控件会让 app 退回监控模式。"
        }
    }

    var menuBarLabel: String {
        if let hottest = latestSnapshot?.hottestTemp {
            return "\(AppBrand.displayName) \(Int(hottest.rounded()))°"
        }
        return AppBrand.displayName
    }

    var menuBarSymbol: String {
        switch inventory?.capability {
        case .controllable:
            return selectedMode == .systemAuto ? "fanblades" : "fanblades.fill"
        case .readOnly:
            return "fan"
        case .unsupported:
            return "thermometer.medium"
        case nil:
            return "fan"
        }
    }

    func start() {
        guard pollTask == nil else { return }

        pollTask = Task {
            await loadInitialState(applyStoredMode: true)
            while !Task.isCancelled {
                await refreshNow()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func loadInitialState(applyStoredMode: Bool) async {
        selectedMode = Self.persistedSelectedMode(using: defaults)
        do {
            inventory = try await provider.discover()
            await refreshDiagnostics()
            isLoading = false

            if applyStoredMode, selectedMode != .systemAuto {
                do {
                    try await applyStoredModeIfPossible()
                } catch {
                    await forceAutomatic(statusMessage: error.localizedDescription)
                }
            }

            await refreshNow()
        } catch {
            await refreshDiagnostics()
            isLoading = false
            statusMessage = error.localizedDescription
        }
    }

    func refreshNow() async {
        do {
            let snapshot = try await provider.snapshot()
            consecutiveReadFailures = 0
            latestSnapshot = snapshot
            inventory?.capability = snapshot.capability
            await refreshDiagnostics()

            if let reason = SafetyPolicy.forceAutomaticReason(
                mode: selectedMode,
                hottestTemp: snapshot.hottestTemp,
                consecutiveReadFailures: consecutiveReadFailures
            ) {
                await forceAutomatic(statusMessage: reason)
            }
        } catch {
            consecutiveReadFailures += 1
            statusMessage = error.localizedDescription
            await refreshDiagnostics()

            if let reason = SafetyPolicy.forceAutomaticReason(
                mode: selectedMode,
                hottestTemp: latestSnapshot?.hottestTemp,
                consecutiveReadFailures: consecutiveReadFailures
            ) {
                await forceAutomatic(statusMessage: reason)
            }
        }
    }

    func setMode(_ mode: FanMode) async {
        guard mode != selectedMode else { return }

        if mode == .systemAuto {
            await forceAutomatic(statusMessage: nil, preserveModeSelection: false)
            return
        }

        selectedMode = mode
        persistSelectedMode()
        statusMessage = nil

        do {
            try await provider.apply(mode)
            Task { @MainActor in
                await refreshNow()
            }
        } catch {
            await forceAutomatic(statusMessage: error.localizedDescription)
        }
    }

    func installPrivilegedHelper() async {
        guard !isInstallingHelper, let helperInstallAction else {
            return
        }

        isInstallingHelper = true
        statusMessage = helperInstallAction.kind.progressMessage

        defer {
            isInstallingHelper = false
        }

        do {
            try await helperInstaller.installPrivilegedHelper()
            statusMessage = nil
            await loadInitialState(applyStoredMode: true)
        } catch {
            statusMessage = error.localizedDescription
            await refreshDiagnostics()
        }
    }

    func prepareForTermination(timeout: Duration = .seconds(2)) async {
        guard !isPreparingForTermination else { return }
        isPreparingForTermination = true
        defer { isPreparingForTermination = false }

        pollTask?.cancel()

        selectedMode = .systemAuto
        persistSelectedMode()

        let outcome = await restoreAutomaticForTermination(timeout: timeout)

        switch outcome {
        case let .completed(result):
            await refreshDiagnostics()
            switch result {
            case .restored, .skipped:
                statusMessage = nil
            case let .failed(message):
                let failureMessage = "退出时恢复系统自动模式失败：\(message)"
                statusMessage = failureMessage
                hardwareDiagnostics.lastError = message
                NSLog("%@", failureMessage)
            }
        case .timedOut:
            let timeoutMessage = "退出时恢复系统自动模式超时，将继续退出。"
            statusMessage = timeoutMessage
            hardwareDiagnostics.lastError = timeoutMessage
            NSLog("%@", timeoutMessage)
        }
    }

    func setAppearanceStyle(_ style: AppAppearanceStyle) {
        guard appearanceStyle != style else { return }
        appearanceStyle = style
        defaults.set(style.rawValue, forKey: DefaultsKey.appearanceStyle)
    }

    private func persistSelectedMode() {
        defaults.set(selectedMode.rawValue, forKey: DefaultsKey.selectedMode)
    }

    private nonisolated static func persistedSelectedMode(using defaults: UserDefaults) -> FanMode {
        FanMode(rawValue: defaults.string(forKey: DefaultsKey.selectedMode) ?? "") ?? .systemAuto
    }

    private nonisolated static func persistedAppearanceStyle(using defaults: UserDefaults) -> AppAppearanceStyle {
        AppAppearanceStyle(rawValue: defaults.string(forKey: DefaultsKey.appearanceStyle) ?? "")
            ?? .highTransparency
    }

    private func applyStoredModeIfPossible() async throws {
        guard selectedMode != .systemAuto else {
            return
        }

        if !canControl {
            let recovered = await retryStoredModeControlRecovery()
            guard recovered else {
                return
            }
        }

        try await provider.apply(selectedMode)
    }

    private func retryStoredModeControlRecovery() async -> Bool {
        guard startupControlRetryAttempts > 0 else {
            return canControl
        }

        for _ in 0..<startupControlRetryAttempts where !canControl {
            try? await Task.sleep(for: startupControlRetryDelay)

            do {
                inventory = try await provider.discover()
                await refreshDiagnostics()
            } catch {
                await refreshDiagnostics()
                statusMessage = error.localizedDescription
                return false
            }
        }

        return canControl
    }

    private func forceAutomatic(statusMessage message: String?, preserveModeSelection: Bool = false) async {
        let restoreResult = await provider.restoreAutomatic()
        selectedMode = preserveModeSelection ? selectedMode : .systemAuto
        persistSelectedMode()
        statusMessage = mergedStatusMessage(baseMessage: message, restoreResult: restoreResult)
        do {
            let snapshot = try await provider.snapshot()
            latestSnapshot = snapshot
            inventory?.capability = snapshot.capability
            await refreshDiagnostics()
        } catch {
            inventory?.capability = .readOnly("恢复系统自动模式后无法重新获取快照，请稍后重试。")
            await refreshDiagnostics()
        }
    }

    private func refreshDiagnostics() async {
        hardwareDiagnostics = await provider.diagnostics()
    }

    private func mergedStatusMessage(
        baseMessage: String?,
        restoreResult: RestoreAutomaticResult
    ) -> String? {
        switch restoreResult {
        case .restored, .skipped:
            return baseMessage
        case let .failed(message):
            let failureMessage = "恢复系统自动模式失败：\(message)"
            guard let baseMessage, !baseMessage.isEmpty, baseMessage != failureMessage else {
                return failureMessage
            }
            return "\(baseMessage) \(failureMessage)"
        }
    }

    private func restoreAutomaticForTermination(timeout: Duration) async -> TerminationRestoreOutcome {
        let provider = self.provider

        return await withTaskGroup(of: TerminationRestoreOutcome.self) { group in
            group.addTask {
                let result = await provider.restoreAutomatic()
                return .completed(result)
            }

            group.addTask {
                try? await Task.sleep(for: timeout)
                return .timedOut
            }

            let outcome = await group.next() ?? .completed(.skipped)
            group.cancelAll()
            return outcome
        }
    }
}
