import Foundation

private final class PrivilegedHelperService: NSObject, IFansPrivilegedHelperXPCProtocol, NSXPCListenerDelegate {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let smc = SMCBridge()
    private let helperBuild = PrivilegedHelperServiceDefinition.currentHelperBuild()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: IFansPrivilegedHelperXPCProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    func handle(_ requestData: NSData, withReply reply: @escaping (NSData?) -> Void) {
        let response: PrivilegedHelperResponse

        do {
            let request = try decoder.decode(PrivilegedHelperRequest.self, from: requestData as Data)
            response = try perform(request)
        } catch let error as HardwareControlError {
            response = makeResponse(
                success: false,
                message: error.localizedDescription,
                failureCode: .helperRejected
            )
        } catch {
            response = makeResponse(
                success: false,
                message: error.localizedDescription,
                failureCode: .invalidRequest
            )
        }

        reply(try? encoder.encode(response) as NSData)
    }

    private func perform(_ request: PrivilegedHelperRequest) throws -> PrivilegedHelperResponse {
        guard request.wireVersion == PrivilegedHelperServiceDefinition.legacyWireVersion
            || request.wireVersion == PrivilegedHelperServiceDefinition.currentWireVersion
        else {
            return makeResponse(
                success: false,
                message: "当前安装的 \(AppBrand.helperDisplayName) 与此 app 的通信协议不兼容，请重新安装当前 helper。",
                failureCode: .unsupportedWireVersion
            )
        }

        if request.action == .handshake {
            return makeResponse(success: true)
        }

        guard let smc else {
            return makeResponse(
                success: false,
                message: "特权 helper 无法打开 AppleSMC。",
                failureCode: .smcUnavailable
            )
        }

        let fans = try smc.fanDescriptors()
        let fansByID = Dictionary(uniqueKeysWithValues: fans.map { ($0.id, $0) })

        switch request.action {
        case .handshake:
            return makeResponse(success: true)
        case .probe:
            let probeFans = request.fanIDs.compactMap { fansByID[$0] }
            guard !probeFans.isEmpty else {
                return makeResponse(
                    success: false,
                    message: "没有可验证的风扇控制对象。",
                    failureCode: .helperRejected
                )
            }
            for fan in probeFans {
                try smc.probeWriteAccess(for: fan)
            }
            return makeResponse(success: true)
        case .apply:
            for operation in request.operations {
                guard let fan = fansByID[operation.fanID], fan.supportsManualControl else {
                    return makeResponse(
                        success: false,
                        message: "风扇 \(operation.fanID) 不支持手动控制。",
                        failureCode: .helperRejected
                    )
                }
                try smc.apply(targetRPM: operation.targetRPM, to: fan)
                guard try smc.verifyManualControl(for: fan, expectedTargetRPM: operation.targetRPM) else {
                    throw HardwareControlError.denied("风扇 \(fan.name) 写入验证失败。")
                }
            }
            return makeResponse(success: true)
        case .restoreAutomatic:
            for fanID in request.fanIDs {
                guard let fan = fansByID[fanID], fan.supportsManualControl else {
                    continue
                }
                try smc.restoreAutomatic(for: fan)
            }
            return makeResponse(success: true)
        }
    }

    private func makeResponse(
        success: Bool,
        message: String? = nil,
        failureCode: PrivilegedHelperFailureCode? = nil
    ) -> PrivilegedHelperResponse {
        PrivilegedHelperResponse(
            wireVersion: PrivilegedHelperServiceDefinition.currentWireVersion,
            helperBuild: helperBuild,
            success: success,
            message: message,
            failureCode: failureCode
        )
    }
}

@main
struct IFansPrivilegedHelperMain {
    static func main() {
        let delegate = PrivilegedHelperService()
        let listener = NSXPCListener(
            machServiceName: PrivilegedHelperServiceDefinition.machServiceName
        )
        listener.delegate = delegate
        listener.resume()
        RunLoop.current.run()
    }
}
