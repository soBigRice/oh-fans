import Dispatch
import Foundation

enum PrivilegedHelperServiceDefinition {
    nonisolated static let machServiceName = "com.sobigrice.iFans.helper"
    nonisolated static let helperBinaryPath = "/Library/PrivilegedHelperTools/com.sobigrice.iFans.helper"
    nonisolated static let helperLaunchDaemonPath = "/Library/LaunchDaemons/com.sobigrice.iFans.helper.plist"
    nonisolated static let reinstallCommand = "./script/install_helper.sh"
    private nonisolated static let installerRelativePaths = [
        "HelperInstaller/install_helper.sh",
        "install_helper.sh",
        "script/install_helper.sh"
    ]
    nonisolated static let legacyWireVersion = 0
    nonisolated static let currentWireVersion = 1

    nonisolated static func currentClientBuild() -> String {
        buildLabel(defaultIdentifier: Bundle.main.bundleIdentifier ?? "com.sobigrice.iFans")
    }

    nonisolated static func currentHelperBuild() -> String {
        buildLabel(defaultIdentifier: machServiceName)
    }

    nonisolated static func isInstalledHelperPresent() -> Bool {
        FileManager.default.fileExists(atPath: helperBinaryPath)
            || FileManager.default.fileExists(atPath: helperLaunchDaemonPath)
    }

    nonisolated static func installAction(
        for message: String,
        installedHelperPresent: Bool
    ) -> PrivilegedHelperInstallAction? {
        guard isInstallationGuidanceMessage(message) else {
            return nil
        }

        let kind: PrivilegedHelperInstallKind
        if isCompatibilityReinstallMessage(message) || installedHelperPresent {
            kind = .reinstall
        } else {
            kind = .install
        }

        return PrivilegedHelperInstallAction(kind: kind, reason: message)
    }

    nonisolated static func installAction(for message: String) -> PrivilegedHelperInstallAction? {
        installAction(for: message, installedHelperPresent: isInstalledHelperPresent())
    }

    nonisolated static func installAction(
        statusMessage: String?,
        capability: HardwareCapability?,
        lastError: String?
    ) -> PrivilegedHelperInstallAction? {
        var messages = [String]()

        if let statusMessage, !statusMessage.isEmpty {
            messages.append(statusMessage)
        }
        if let capability {
            messages.append(capability.message)
        }
        if let lastError, !lastError.isEmpty {
            messages.append(lastError)
        }

        for message in messages {
            if let action = installAction(for: message) {
                return action
            }
        }

        return nil
    }

    nonisolated static func versionMismatchMessage() -> String {
        "检测到旧版 \(AppBrand.helperDisplayName)，请重新执行 \(reinstallCommand) 安装当前版本后再试。"
    }

    nonisolated static func isCompatibilityReinstallMessage(_ message: String) -> Bool {
        message.contains("旧版 \(AppBrand.helperDisplayName)") || message.contains("协议不兼容")
    }

    nonisolated static func installerUnavailableMessage() -> String {
        "当前构建没有找到可执行的 helper 安装器。请回到工程目录后执行 \(reinstallCommand)，或者使用带内置安装器的发行版。"
    }

    nonisolated static func locateInstallerScriptURL() -> URL? {
        let fileManager = FileManager.default
        let candidates = installerCandidateURLs()

        var seen = Set<String>()
        for candidate in candidates {
            let path = candidate.standardizedFileURL.path
            guard seen.insert(path).inserted else {
                continue
            }

            if fileManager.isExecutableFile(atPath: path) || fileManager.fileExists(atPath: path) {
                return candidate.standardizedFileURL
            }
        }

        return nil
    }

    private nonisolated static func buildLabel(defaultIdentifier: String) -> String {
        let bundle = Bundle.main
        let identifier = bundle.bundleIdentifier ?? defaultIdentifier
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let executablePath = bundle.executableURL?.path ?? CommandLine.arguments.first
        let executableStamp = executablePath.flatMap { fileModificationStamp(atPath: $0) }

        var parts = [identifier]
        if let shortVersion, !shortVersion.isEmpty {
            parts.append(shortVersion)
        }
        if let buildVersion, !buildVersion.isEmpty, buildVersion != shortVersion {
            parts.append("(\(buildVersion))")
        }
        if let executableStamp {
            parts.append("@\(executableStamp)")
        }

        return parts.joined(separator: " ")
    }

    private nonisolated static func fileModificationStamp(atPath path: String) -> String? {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: path),
            let date = attributes[.modificationDate] as? Date
        else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private nonisolated static func isInstallationGuidanceMessage(_ message: String) -> Bool {
        message.contains("helper") && message.contains(reinstallCommand)
    }

    private nonisolated static func installerCandidateURLs() -> [URL] {
        var candidates = [URL]()

        if let explicitPath = ProcessInfo.processInfo.environment["IFANS_HELPER_INSTALL_SCRIPT"],
           !explicitPath.isEmpty {
            candidates.append(URL(fileURLWithPath: explicitPath))
        }

        for directory in installerCandidateDirectories() {
            for relativePath in installerRelativePaths {
                candidates.append(directory.appendingPathComponent(relativePath))
            }
        }

        return candidates
    }

    private nonisolated static func installerCandidateDirectories() -> [URL] {
        [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
            Bundle.main.resourceURL,
            Bundle.main.sharedSupportURL
        ]
        .compactMap { $0?.standardizedFileURL }
    }
}

nonisolated enum PrivilegedHelperInstallKind: Equatable, Sendable {
    case install
    case reinstall

    var title: String {
        switch self {
        case .install:
            "安装 helper"
        case .reinstall:
            "重装 helper"
        }
    }

    var inProgressTitle: String {
        switch self {
        case .install:
            "安装中…"
        case .reinstall:
            "重装中…"
        }
    }

    var systemImage: String {
        switch self {
        case .install:
            "arrow.down.circle.fill"
        case .reinstall:
            "arrow.clockwise.circle.fill"
        }
    }

    var progressMessage: String {
        switch self {
        case .install:
            "正在安装 \(AppBrand.helperDisplayName)，安装期间会请求管理员授权。"
        case .reinstall:
            "正在重装 \(AppBrand.helperDisplayName)，安装期间会请求管理员授权。"
        }
    }
}

nonisolated struct PrivilegedHelperInstallAction: Sendable {
    let kind: PrivilegedHelperInstallKind
    let reason: String
}

nonisolated enum PrivilegedHelperInstallerError: LocalizedError, Sendable {
    case installerUnavailable(String)
    case cancelled
    case installationFailed(String)

    var errorDescription: String? {
        switch self {
        case let .installerUnavailable(message), let .installationFailed(message):
            return message
        case .cancelled:
            return "已取消 \(AppBrand.helperDisplayName) 安装。"
        }
    }
}

protocol PrivilegedHelperInstalling: Sendable {
    nonisolated func installPrivilegedHelper() async throws
}

struct LivePrivilegedHelperInstaller: PrivilegedHelperInstalling {
    nonisolated init() {}

    nonisolated func installPrivilegedHelper() async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    guard let scriptURL = PrivilegedHelperServiceDefinition.locateInstallerScriptURL() else {
                        throw PrivilegedHelperInstallerError.installerUnavailable(
                            PrivilegedHelperServiceDefinition.installerUnavailableMessage()
                        )
                    }
                    try Self.executePrivilegedInstall(scriptURL: scriptURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private nonisolated static func executePrivilegedInstall(scriptURL: URL) throws {
        let command = "/bin/zsh -lc \(shellQuoted(scriptURL.path))"
        let appleScript = "do shell script \(appleScriptLiteral(command)) with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let output = String(
            data: stdout.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let errorOutput = String(
            data: stderr.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            let combinedOutput = [errorOutput, output]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")

            if combinedOutput.localizedCaseInsensitiveContains("user canceled")
                || combinedOutput.contains("(-128)")
            {
                throw PrivilegedHelperInstallerError.cancelled
            }

            throw PrivilegedHelperInstallerError.installationFailed(
                combinedOutput.isEmpty
                    ? "\(AppBrand.helperDisplayName) 安装失败，请稍后重试。"
                    : combinedOutput
            )
        }
    }

    private nonisolated static func shellQuoted(_ string: String) -> String {
        "'\(string.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private nonisolated static func appleScriptLiteral(_ string: String) -> String {
        let escaped = string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

nonisolated struct FanControlOperation: Codable, Sendable {
    let fanID: String
    let targetRPM: Int
}

nonisolated enum PrivilegedHelperAction: String, Codable, Sendable {
    case handshake
    case probe
    case apply
    case restoreAutomatic
}

nonisolated enum PrivilegedHelperFailureCode: String, Codable, Sendable {
    case unsupportedWireVersion
    case invalidRequest
    case helperRejected
    case smcUnavailable
}

nonisolated struct PrivilegedHelperRequest: Codable, Sendable {
    let wireVersion: Int
    let clientBuild: String
    let action: PrivilegedHelperAction
    let fanIDs: [String]
    let operations: [FanControlOperation]

    init(
        wireVersion: Int = PrivilegedHelperServiceDefinition.currentWireVersion,
        clientBuild: String = PrivilegedHelperServiceDefinition.currentClientBuild(),
        action: PrivilegedHelperAction,
        fanIDs: [String],
        operations: [FanControlOperation]
    ) {
        self.wireVersion = wireVersion
        self.clientBuild = clientBuild
        self.action = action
        self.fanIDs = fanIDs
        self.operations = operations
    }

    private enum CodingKeys: String, CodingKey {
        case wireVersion
        case clientBuild
        case action
        case fanIDs
        case operations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wireVersion = try container.decodeIfPresent(Int.self, forKey: .wireVersion)
            ?? PrivilegedHelperServiceDefinition.legacyWireVersion
        clientBuild = try container.decodeIfPresent(String.self, forKey: .clientBuild) ?? "legacy-client"
        action = try container.decode(PrivilegedHelperAction.self, forKey: .action)
        fanIDs = try container.decodeIfPresent([String].self, forKey: .fanIDs) ?? []
        operations = try container.decodeIfPresent([FanControlOperation].self, forKey: .operations) ?? []
    }
}

nonisolated struct PrivilegedHelperResponse: Codable, Sendable {
    let wireVersion: Int
    let helperBuild: String
    let success: Bool
    let message: String?
    let failureCode: PrivilegedHelperFailureCode?

    init(
        wireVersion: Int = PrivilegedHelperServiceDefinition.currentWireVersion,
        helperBuild: String = PrivilegedHelperServiceDefinition.currentHelperBuild(),
        success: Bool,
        message: String?,
        failureCode: PrivilegedHelperFailureCode? = nil
    ) {
        self.wireVersion = wireVersion
        self.helperBuild = helperBuild
        self.success = success
        self.message = message
        self.failureCode = failureCode
    }

    private enum CodingKeys: String, CodingKey {
        case wireVersion
        case helperBuild
        case success
        case message
        case failureCode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wireVersion = try container.decodeIfPresent(Int.self, forKey: .wireVersion)
            ?? PrivilegedHelperServiceDefinition.legacyWireVersion
        helperBuild = try container.decodeIfPresent(String.self, forKey: .helperBuild) ?? "legacy-helper"
        success = try container.decode(Bool.self, forKey: .success)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        failureCode = try container.decodeIfPresent(PrivilegedHelperFailureCode.self, forKey: .failureCode)
    }
}

@objc protocol IFansPrivilegedHelperXPCProtocol {
    nonisolated func handle(_ requestData: NSData, withReply reply: @escaping (NSData?) -> Void)
}

nonisolated enum PrivilegedHelperClientError: LocalizedError, Sendable {
    case helperUnavailable(String)
    case versionMismatch(String)
    case invalidReply
    case helperRejected(String)

    var errorDescription: String? {
        switch self {
        case let .helperUnavailable(message), let .versionMismatch(message), let .helperRejected(message):
            return message
        case .invalidReply:
            return "\(AppBrand.helperControllerDisplayName) 返回了无法解析的数据。"
        }
    }
}

final class PrivilegedHelperClient: @unchecked Sendable {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    nonisolated init() {}

    nonisolated func handshake() async throws -> String {
        let response = try await perform(
            PrivilegedHelperRequest(action: .handshake, fanIDs: [], operations: []),
            unavailableMessage: missingHelperMessage(),
            rejectionMessage: "\(AppBrand.helperControllerDisplayName) 未返回握手状态。"
        )
        return response.helperBuild
    }

    nonisolated func probe(fans: [FanDescriptor]) async throws {
        let response = try await perform(
            PrivilegedHelperRequest(
                action: .probe,
                fanIDs: fans.filter(\.supportsManualControl).map(\.id),
                operations: []
            ),
            unavailableMessage: unavailableMessage(for: fans.count),
            rejectionMessage: unavailableMessage(for: fans.count)
        )
        guard response.success else { return }
    }

    nonisolated func apply(operations: [FanControlOperation]) async throws {
        let response = try await perform(
            PrivilegedHelperRequest(
                action: .apply,
                fanIDs: [],
                operations: operations
            ),
            unavailableMessage: missingHelperMessage(),
            rejectionMessage: "特权控制助手未完成风扇写入。"
        )
        guard response.success else { return }
    }

    nonisolated func restoreAutomatic(fanIDs: [String]) async throws {
        let response = try await perform(
            PrivilegedHelperRequest(
                action: .restoreAutomatic,
                fanIDs: fanIDs,
                operations: []
            ),
            unavailableMessage: missingHelperMessage(),
            rejectionMessage: "特权控制助手未能恢复系统自动模式。"
        )
        guard response.success else { return }
    }

    nonisolated func unavailableMessage(for fanCount: Int) -> String {
        "已发现 \(fanCount) 个可控制风扇，但当前没有可用的 \(AppBrand.helperControllerDisplayName)。请先执行 \(PrivilegedHelperServiceDefinition.reinstallCommand) 安装并启动当前 helper。"
    }

    private nonisolated func missingHelperMessage() -> String {
        "当前没有可用的 \(AppBrand.helperControllerDisplayName)。请先执行 \(PrivilegedHelperServiceDefinition.reinstallCommand) 安装并启动当前 helper。"
    }

    private nonisolated func perform(
        _ request: PrivilegedHelperRequest,
        unavailableMessage: String,
        rejectionMessage: String
    ) async throws -> PrivilegedHelperResponse {
        do {
            let response = try await send(request)
            return try validateResponse(response, rejectionMessage: rejectionMessage)
        } catch let error as PrivilegedHelperClientError {
            throw classifyTransportError(error, unavailableMessage: unavailableMessage)
        }
    }

    private nonisolated func validateResponse(
        _ response: PrivilegedHelperResponse,
        rejectionMessage: String
    ) throws -> PrivilegedHelperResponse {
        guard response.wireVersion == PrivilegedHelperServiceDefinition.currentWireVersion else {
            throw PrivilegedHelperClientError.versionMismatch(
                PrivilegedHelperServiceDefinition.versionMismatchMessage()
            )
        }

        guard response.success else {
            if response.failureCode == .unsupportedWireVersion {
                throw PrivilegedHelperClientError.versionMismatch(
                    PrivilegedHelperServiceDefinition.versionMismatchMessage()
                )
            }

            throw PrivilegedHelperClientError.helperRejected(
                response.message ?? rejectionMessage
            )
        }

        return response
    }

    private nonisolated func classifyTransportError(
        _ error: PrivilegedHelperClientError,
        unavailableMessage: String
    ) -> PrivilegedHelperClientError {
        switch error {
        case .helperRejected, .versionMismatch:
            return error
        case .invalidReply:
            return .versionMismatch(PrivilegedHelperServiceDefinition.versionMismatchMessage())
        case .helperUnavailable:
            if PrivilegedHelperServiceDefinition.isInstalledHelperPresent() {
                return .versionMismatch(PrivilegedHelperServiceDefinition.versionMismatchMessage())
            }
            return .helperUnavailable(unavailableMessage)
        }
    }

    private nonisolated func send(_ request: PrivilegedHelperRequest) async throws -> PrivilegedHelperResponse {
        let payload = try encoder.encode(request)

        return try await withCheckedThrowingContinuation { continuation in
            let connection = NSXPCConnection(
                machServiceName: PrivilegedHelperServiceDefinition.machServiceName,
                options: .privileged
            )
            connection.remoteObjectInterface = NSXPCInterface(with: IFansPrivilegedHelperXPCProtocol.self)
            connection.resume()

            let fail: (Error) -> Void = { error in
                connection.invalidate()
                let message = "\(AppBrand.helperControllerDisplayName) 不可用。请先安装并启动 helper。底层错误：\(error.localizedDescription)"
                continuation.resume(
                    throwing: PrivilegedHelperClientError.helperUnavailable(message)
                )
            }

            guard
                let proxy = connection.remoteObjectProxyWithErrorHandler(fail)
                    as? IFansPrivilegedHelperXPCProtocol
            else {
                fail(PrivilegedHelperClientError.invalidReply)
                return
            }

            proxy.handle(payload as NSData) { responseData in
                defer {
                    connection.invalidate()
                }

                guard let responseData else {
                    continuation.resume(throwing: PrivilegedHelperClientError.invalidReply)
                    return
                }

                do {
                    let response = try self.decoder.decode(
                        PrivilegedHelperResponse.self,
                        from: responseData as Data
                    )
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: PrivilegedHelperClientError.invalidReply)
                }
            }
        }
    }
}
