import Foundation
import Testing
@testable import iFans
import Darwin

struct iFansTests {
    @Test func controlPresetClampsToDefaultAndMax() {
        let fan = FanDescriptor(id: "F0Ac", name: "风扇 1", defaultMinRPM: 1200, maxRPM: 5800, supportsManualControl: true)

        #expect(ControlPreset.targetRPM(for: .quiet, fan: fan) == 1200)
        #expect(ControlPreset.targetRPM(for: .balanced, fan: fan) == 3040)
        #expect(ControlPreset.targetRPM(for: .performance, fan: fan) == 5800)
        #expect(ControlPreset.targetRPM(for: .systemAuto, fan: fan) == nil)
    }

    @Test func safetyPolicyTripsOnHighTemperature() {
        let reason = SafetyPolicy.forceAutomaticReason(mode: .performance, hottestTemp: 96, consecutiveReadFailures: 0)
        #expect(reason != nil)
    }

    @Test func safetyPolicyTripsOnConsecutiveReadFailures() {
        let reason = SafetyPolicy.forceAutomaticReason(mode: .balanced, hottestTemp: nil, consecutiveReadFailures: 3)
        #expect(reason != nil)
    }

    @Test func fanCapabilityResolverReturnsReadOnlyWhenFanReadFails() {
        let capability = FanCapabilityResolver.resolve(
            fans: [],
            discoveryIssue: .readOnly("AppleSMC 风扇读取失败（0xe00002c2）。")
        )

        #expect(capability == .readOnly("AppleSMC 风扇读取失败（0xe00002c2）。"))
    }

    @Test func fanCapabilityResolverTreatsDetectedControllableFansAsControllable() {
        let fan = FanDescriptor(id: "F0Ac", name: "风扇 1", defaultMinRPM: 1200, maxRPM: 5800, supportsManualControl: true)
        let capability = FanCapabilityResolver.resolve(fans: [fan])

        #expect(capability == .controllable)
    }

    @Test func fanCapabilityResolverDoesNotMisclassifyDetectedFansAsUnsupported() {
        let fan = FanDescriptor(id: "F0Ac", name: "风扇 1", defaultMinRPM: 1200, maxRPM: 5800, supportsManualControl: false)
        let capability = FanCapabilityResolver.resolve(fans: [fan])

        #expect(capability != .unsupported(FanCapabilityResolver.noFanMessage))
        #expect(capability == .readOnly("已发现 1 个内建风扇，但当前机型未暴露可验证的控制 key。"))
    }

    @Test func helperProbeFailureResolverKeepsHelperChannelForRejectedProbe() {
        let resolution = HelperProbeFailureResolver.resolve(
            error: PrivilegedHelperClientError.helperRejected("风扇 2 写入验证失败。"),
            unavailableMessage: "helper 不可用"
        )

        #expect(resolution == HelperProbeFailureResolution(
            keepsHelperChannel: true,
            reason: "风扇 2 写入验证失败。"
        ))
    }

    @Test func helperProbeFailureResolverDropsHelperChannelWhenHelperIsUnavailable() {
        let resolution = HelperProbeFailureResolver.resolve(
            error: PrivilegedHelperClientError.helperUnavailable("底层 XPC 连接失败。"),
            unavailableMessage: "已发现 2 个可控制风扇，但当前没有可用的 \(AppBrand.helperControllerDisplayName)。"
        )

        #expect(resolution == HelperProbeFailureResolution(
            keepsHelperChannel: false,
            reason: "已发现 2 个可控制风扇，但当前没有可用的 \(AppBrand.helperControllerDisplayName)。"
        ))
    }

    @Test func helperProbeFailureResolverPreservesVersionMismatchReason() {
        let resolution = HelperProbeFailureResolver.resolve(
            error: PrivilegedHelperClientError.versionMismatch(
                PrivilegedHelperServiceDefinition.versionMismatchMessage()
            ),
            unavailableMessage: "helper 不可用"
        )

        #expect(resolution == HelperProbeFailureResolution(
            keepsHelperChannel: false,
            reason: PrivilegedHelperServiceDefinition.versionMismatchMessage()
        ))
    }

    @Test func privilegedHelperRequestDecodesLegacyPayloadWithDefaults() throws {
        let request = try JSONDecoder().decode(
            PrivilegedHelperRequest.self,
            from: #"{"action":"probe","fanIDs":["F0Ac"],"operations":[]}"#.data(using: .utf8)!
        )

        #expect(request.wireVersion == PrivilegedHelperServiceDefinition.legacyWireVersion)
        #expect(request.clientBuild == "legacy-client")
        #expect(request.action == .probe)
        #expect(request.fanIDs == ["F0Ac"])
    }

    @Test func privilegedHelperResponseDecodesLegacyPayloadWithDefaults() throws {
        let response = try JSONDecoder().decode(
            PrivilegedHelperResponse.self,
            from: #"{"success":false,"message":"legacy helper"}"#.data(using: .utf8)!
        )

        #expect(response.wireVersion == PrivilegedHelperServiceDefinition.legacyWireVersion)
        #expect(response.helperBuild == "legacy-helper")
        #expect(response.failureCode == nil)
        #expect(response.message == "legacy helper")
    }

    @Test func helperInstallActionUsesInstallForMissingHelperMessage() {
        let message = "当前没有可用的 \(AppBrand.helperControllerDisplayName)。请先执行 \(PrivilegedHelperServiceDefinition.reinstallCommand) 安装并启动辅助控件。"
        let action = PrivilegedHelperServiceDefinition.installAction(
            for: message,
            installedHelperPresent: false
        )

        #expect(action?.kind == .install)
        #expect(action?.reason == message)
    }

    @Test func helperInstallActionUsesReinstallForCompatibilityMessage() {
        let action = PrivilegedHelperServiceDefinition.installAction(
            for: PrivilegedHelperServiceDefinition.versionMismatchMessage(),
            installedHelperPresent: true
        )

        #expect(action?.kind == .reinstall)
        #expect(action?.reason == PrivilegedHelperServiceDefinition.versionMismatchMessage())
    }

    @Test func helperInstallActionUsesReinstallForPostInstallVerificationFailure() {
        let message = "\(AppBrand.helperDisplayName) 安装命令已执行，但安装后仍未建立控制通道。请重新执行 \(PrivilegedHelperServiceDefinition.reinstallCommand) 查看完整输出。"
        let action = PrivilegedHelperServiceDefinition.installAction(
            for: message,
            installedHelperPresent: true
        )

        #expect(action?.kind == .reinstall)
        #expect(action?.reason == message)
    }

    @Test func locateInstallerScriptURLPrefersExplicitEnvironmentOverride() throws {
        let fileManager = FileManager.default
        let scriptDirectory = fileManager.temporaryDirectory.appendingPathComponent(
            "iFansTests-\(UUID().uuidString)",
            isDirectory: true
        )
        let scriptURL = scriptDirectory.appendingPathComponent("install_helper.sh")

        try fileManager.createDirectory(at: scriptDirectory, withIntermediateDirectories: true)
        try "#!/bin/zsh\nexit 0\n".write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptURL.path
        )

        let environmentName = "IFANS_HELPER_INSTALL_SCRIPT"
        let previousValue = getenv(environmentName).map { String(cString: $0) }
        setenv(environmentName, scriptURL.path, 1)

        defer {
            if let previousValue {
                setenv(environmentName, previousValue, 1)
            } else {
                unsetenv(environmentName)
            }
            try? fileManager.removeItem(at: scriptDirectory)
        }

        #expect(PrivilegedHelperServiceDefinition.locateInstallerScriptURL() == scriptURL)
    }

    @Test func zeroRPMIsValidForAppleSiliconFanReadings() {
        let reading = FanReading(id: "F0Ac", currentRPM: 0, targetRPM: nil)
        #expect(reading.currentRPM == 0)
    }

    @MainActor
    @Test func sandboxBuildSurfacesUnsupportedCapability() async {
        let runtimeEnvironment = AppRuntimeEnvironment(isSandboxed: true, machineIdentifier: "MacBookPro18,3")
        let provider = UnsupportedHardwareProvider(message: runtimeEnvironment.sandboxUnsupportedMessage)
        let defaults = UserDefaults(suiteName: "iFansTests-\(UUID().uuidString)")!
        let model = AppModel(provider: provider, defaults: defaults, runtimeEnvironment: runtimeEnvironment)

        await model.loadInitialState(applyStoredMode: false)

        #expect(model.buildModeDescription == "沙盒构建")
        #expect(model.inventory?.capability == .unsupported(runtimeEnvironment.sandboxUnsupportedMessage))
    }

    @MainActor
    @Test func appModelDisablesControlWhenHardwareIsReadOnly() async {
        let provider = MockHardwareProvider(capability: .readOnly("只读"))
        let defaults = UserDefaults(suiteName: "iFansTests-\(UUID().uuidString)")!
        let model = AppModel(provider: provider, defaults: defaults)

        await model.loadInitialState(applyStoredMode: false)

        #expect(model.canControl == false)
        #expect(model.inventory?.capability == .readOnly("只读"))
    }

    @MainActor
    @Test func appModelSurfacesHelperInstallActionForCompatibilityMismatch() async {
        let provider = MockHardwareProvider(
            capability: .readOnly(PrivilegedHelperServiceDefinition.versionMismatchMessage())
        )
        let defaults = UserDefaults(suiteName: "iFansTests-\(UUID().uuidString)")!
        let model = AppModel(provider: provider, defaults: defaults)

        await model.loadInitialState(applyStoredMode: false)

        #expect(model.helperInstallAction?.kind == .reinstall)
        #expect(model.helperInstallStatusText == PrivilegedHelperServiceDefinition.versionMismatchMessage())
    }

    @MainActor
    @Test func appModelSurfacesInstallerDiagnosticsAfterFailedHelperInstall() async {
        let provider = MockHardwareProvider(
            capability: .readOnly(
                "当前没有可用的 \(AppBrand.helperControllerDisplayName)。请先执行 \(PrivilegedHelperServiceDefinition.reinstallCommand) 安装并启动辅助控件。"
            )
        )
        let defaults = UserDefaults(suiteName: "iFansTests-\(UUID().uuidString)")!
        let failureMessage = "\(AppBrand.helperDisplayName) 安装命令已执行，但安装后仍未建立控制通道。请重新执行 \(PrivilegedHelperServiceDefinition.reinstallCommand) 查看完整输出。"
        let model = AppModel(
            provider: provider,
            defaults: defaults,
            helperInstaller: MockPrivilegedHelperInstaller(failureMessage: failureMessage)
        )

        await model.loadInitialState(applyStoredMode: false)
        await model.installPrivilegedHelper()

        #expect(model.statusMessage == failureMessage)
        #expect(model.isInstallingHelper == false)
    }

    @MainActor
    @Test func loadInitialStateReloadsStoredModeWrittenAfterInitialization() async {
        let provider = MockHardwareProvider(capability: .controllable)
        let defaults = UserDefaults(suiteName: "iFansTests-\(UUID().uuidString)")!
        let model = AppModel(provider: provider, defaults: defaults)

        defaults.set(FanMode.balanced.rawValue, forKey: AppPreferenceKey.selectedFanMode)

        await model.loadInitialState(applyStoredMode: true)

        #expect(model.selectedMode == .balanced)
        #expect(await provider.appliedMode() == .balanced)
    }

    @MainActor
    @Test func loadInitialStateRetriesStoredModeUntilControlChannelRecovers() async {
        let provider = MockHardwareProvider(
            capability: .readOnly("helper 启动中"),
            discoverCapabilities: [
                .readOnly("helper 启动中"),
                .controllable
            ]
        )
        let defaults = UserDefaults(suiteName: "iFansTests-\(UUID().uuidString)")!
        defaults.set(FanMode.performance.rawValue, forKey: AppPreferenceKey.selectedFanMode)
        let model = AppModel(
            provider: provider,
            defaults: defaults,
            startupControlRetryAttempts: 2,
            startupControlRetryDelay: .zero
        )

        await model.loadInitialState(applyStoredMode: true)

        #expect(model.inventory?.capability == .controllable)
        #expect(await provider.appliedMode() == .performance)
    }

    @MainActor
    @Test func appModelFallsBackToAutoAfterRepeatedFailures() async {
        let provider = MockHardwareProvider(capability: .controllable, failSnapshotsAfterFirstSuccess: true)
        let defaults = UserDefaults(suiteName: "iFansTests-\(UUID().uuidString)")!
        defaults.set(FanMode.performance.rawValue, forKey: AppPreferenceKey.selectedFanMode)
        let model = AppModel(provider: provider, defaults: defaults)

        await model.loadInitialState(applyStoredMode: false)
        await model.setMode(.performance)
        await model.refreshNow()
        await model.refreshNow()
        await model.refreshNow()

        #expect(model.selectedMode == .systemAuto)
    }

    @MainActor
    @Test func firstWriteFailureFallsBackToReadOnly() async {
        let provider = MockHardwareProvider(capability: .controllable, failApply: true)
        let defaults = UserDefaults(suiteName: "iFansTests-\(UUID().uuidString)")!
        let model = AppModel(provider: provider, defaults: defaults)

        await model.loadInitialState(applyStoredMode: false)
        await model.setMode(.balanced)

        #expect(model.selectedMode == .systemAuto)
        #expect(model.inventory?.capability == .readOnly("风扇写入验证失败，已恢复系统自动。"))
        #expect(model.lastHardwareErrorMessage == "风扇写入验证失败，已恢复系统自动。")
    }

    @MainActor
    @Test func successfulWriteKeepsControllableState() async {
        let provider = MockHardwareProvider(capability: .controllable)
        let defaults = UserDefaults(suiteName: "iFansTests-\(UUID().uuidString)")!
        let model = AppModel(provider: provider, defaults: defaults)

        await model.loadInitialState(applyStoredMode: false)
        await model.setMode(.balanced)

        #expect(model.selectedMode == .balanced)
        #expect(model.inventory?.capability == .controllable)
    }

    @MainActor
    @Test func selectingSystemAutoDoesNotLeaveErrorStatusMessage() async {
        let provider = MockHardwareProvider(capability: .controllable)
        let defaults = UserDefaults(suiteName: "iFansTests-\(UUID().uuidString)")!
        let model = AppModel(provider: provider, defaults: defaults)

        await model.loadInitialState(applyStoredMode: false)
        await model.setMode(.performance)
        await model.setMode(.systemAuto)

        #expect(model.selectedMode == .systemAuto)
        #expect(model.statusMessage == nil)
        #expect(model.inventory?.capability == .controllable)
    }

    @MainActor
    @Test func prepareForTerminationRestoresAutomaticAndClearsPersistedMode() async {
        let provider = MockHardwareProvider(capability: .controllable)
        let defaults = UserDefaults(suiteName: "iFansTests-\(UUID().uuidString)")!
        defaults.set(FanMode.performance.rawValue, forKey: AppPreferenceKey.selectedFanMode)
        let model = AppModel(provider: provider, defaults: defaults)

        await model.loadInitialState(applyStoredMode: false)
        await model.setMode(.performance)
        await model.prepareForTermination(timeout: .milliseconds(50))

        #expect(model.selectedMode == .systemAuto)
        #expect(defaults.string(forKey: AppPreferenceKey.selectedFanMode) == FanMode.systemAuto.rawValue)
        #expect(model.statusMessage == nil)
        #expect(await provider.restoreCallCount() == 1)
    }

    @MainActor
    @Test func prepareForTerminationSurfacesRestoreFailure() async {
        let provider = MockHardwareProvider(
            capability: .controllable,
            restoreResult: .failed("helper restore failed")
        )
        let defaults = UserDefaults(suiteName: "iFansTests-\(UUID().uuidString)")!
        defaults.set(FanMode.balanced.rawValue, forKey: AppPreferenceKey.selectedFanMode)
        let model = AppModel(provider: provider, defaults: defaults)

        await model.loadInitialState(applyStoredMode: false)
        await model.prepareForTermination(timeout: .milliseconds(50))

        #expect(model.selectedMode == .systemAuto)
        #expect(defaults.string(forKey: AppPreferenceKey.selectedFanMode) == FanMode.systemAuto.rawValue)
        #expect(model.statusMessage == "退出时恢复系统自动模式失败：helper restore failed")
        #expect(model.lastHardwareErrorMessage == "helper restore failed")
    }

    @MainActor
    @Test func prepareForTerminationTimesOutWithoutBlockingExit() async {
        let provider = MockHardwareProvider(
            capability: .controllable,
            restoreDelay: .seconds(1)
        )
        let defaults = UserDefaults(suiteName: "iFansTests-\(UUID().uuidString)")!
        defaults.set(FanMode.quiet.rawValue, forKey: AppPreferenceKey.selectedFanMode)
        let model = AppModel(provider: provider, defaults: defaults)
        let clock = ContinuousClock()

        await model.loadInitialState(applyStoredMode: false)

        let elapsed = await clock.measure {
            await model.prepareForTermination(timeout: .milliseconds(50))
        }

        #expect(model.selectedMode == .systemAuto)
        #expect(defaults.string(forKey: AppPreferenceKey.selectedFanMode) == FanMode.systemAuto.rawValue)
        #expect(model.statusMessage == "退出时恢复系统自动模式超时，将继续退出。")
        #expect(model.lastHardwareErrorMessage == "退出时恢复系统自动模式超时，将继续退出。")
        #expect(elapsed < .seconds(1))
    }
}

actor MockHardwareProvider: HardwareProvider {
    private var currentCapability: HardwareCapability
    private var discoverCapabilities: [HardwareCapability]
    private let failSnapshotsAfterFirstSuccess: Bool
    private let failApply: Bool
    private let restoreDelay: Duration
    private let restoreResult: RestoreAutomaticResult
    private var snapshotCount = 0
    private var lastSMCError: String?
    private var lastAppliedMode: FanMode?
    private var restoreCalls = 0

    init(
        capability: HardwareCapability,
        discoverCapabilities: [HardwareCapability] = [],
        failSnapshotsAfterFirstSuccess: Bool = false,
        failApply: Bool = false,
        restoreDelay: Duration = .zero,
        restoreResult: RestoreAutomaticResult = .restored
    ) {
        self.currentCapability = capability
        self.discoverCapabilities = discoverCapabilities
        self.failSnapshotsAfterFirstSuccess = failSnapshotsAfterFirstSuccess
        self.failApply = failApply
        self.restoreDelay = restoreDelay
        self.restoreResult = restoreResult
    }

    func discover() async throws -> HardwareInventory {
        if !discoverCapabilities.isEmpty {
            currentCapability = discoverCapabilities.removeFirst()
        }

        return HardwareInventory(
            fans: [
                FanDescriptor(
                    id: "F0Ac",
                    name: "风扇 1",
                    defaultMinRPM: 1200,
                    maxRPM: 5800,
                    supportsManualControl: currentCapability.allowsControl
                )
            ],
            sensors: [SensorDescriptor(id: "perf", name: "性能簇 1", kind: .performanceCPU, rawKey: "PMU TP0s")],
            capability: currentCapability
        )
    }

    func snapshot() async throws -> ThermalSnapshot {
        snapshotCount += 1
        if failSnapshotsAfterFirstSuccess, snapshotCount > 1 {
            lastSMCError = "读失败"
            throw HardwareControlError.readFailed("读失败")
        }

        return ThermalSnapshot(
            timestamp: .now,
            hottestTemp: 52,
            fans: [FanReading(id: "F0Ac", currentRPM: 1300, targetRPM: 1800)],
            sensors: [SensorReading(id: "perf", celsius: 52)],
            capability: currentCapability
        )
    }

    func apply(_ mode: FanMode) async throws {
        if failApply {
            let message = "风扇写入验证失败，已恢复系统自动。"
            currentCapability = .readOnly(message)
            lastSMCError = message
            throw HardwareControlError.denied(message)
        }

        if !currentCapability.allowsControl {
            lastSMCError = currentCapability.message
            throw HardwareControlError.unsupported(currentCapability.message)
        }

        lastAppliedMode = mode
        lastSMCError = nil
    }

    func restoreAutomatic() async -> RestoreAutomaticResult {
        restoreCalls += 1
        try? await Task.sleep(for: restoreDelay)

        if case let .failed(message) = restoreResult {
            lastSMCError = message
        }

        return restoreResult
    }

    func diagnostics() async -> HardwareDiagnostics {
        HardwareDiagnostics(fanCount: 1, lastError: lastSMCError)
    }

    func appliedMode() -> FanMode? {
        lastAppliedMode
    }

    func restoreCallCount() -> Int {
        restoreCalls
    }
}

struct MockPrivilegedHelperInstaller: PrivilegedHelperInstalling {
    let failureMessage: String?

    nonisolated func installPrivilegedHelper() async throws {
        if let failureMessage {
            throw PrivilegedHelperInstallerError.installationFailed(failureMessage)
        }
    }
}
