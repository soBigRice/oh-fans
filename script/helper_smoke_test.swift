import Foundation

@main
struct HelperSmokeTest {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            fputs(
                "usage: helper_smoke_test <handshake|probe|apply|apply-mode|restore|status|direct-probe|direct-apply|provider-discover|provider-apply-mode>\n",
                stderr
            )
            Foundation.exit(2)
        }

        let client = PrivilegedHelperClient()
        let fans = [
            FanDescriptor(id: "F0Ac", name: "风扇 1", defaultMinRPM: 0, maxRPM: 0, supportsManualControl: true),
            FanDescriptor(id: "F1Ac", name: "风扇 2", defaultMinRPM: 0, maxRPM: 0, supportsManualControl: true)
        ]

        do {
            switch command {
            case "handshake":
                let helperBuild = try await client.handshake()
                print("handshake: success helperBuild=\(helperBuild)")
            case "probe":
                try await client.probe(fans: fans)
                print("probe: success")
            case "apply":
                guard arguments.count >= 2, let rpm = Int(arguments[1]) else {
                    fputs("usage: helper_smoke_test apply <rpm>\n", stderr)
                    Foundation.exit(2)
                }
                try await client.apply(
                    operations: fans.map { FanControlOperation(fanID: $0.id, targetRPM: rpm) }
                )
                print("apply: success rpm=\(rpm)")
            case "apply-mode":
                guard arguments.count >= 2, let mode = FanMode(rawValue: arguments[1]) else {
                    fputs("usage: helper_smoke_test apply-mode <systemAuto|quiet|balanced|performance>\n", stderr)
                    Foundation.exit(2)
                }
                try await applyMode(mode, using: client)
            case "direct-probe":
                try directProbe()
                print("direct-probe: success")
            case "direct-apply":
                guard arguments.count >= 2, let rpm = Int(arguments[1]) else {
                    fputs("usage: helper_smoke_test direct-apply <rpm>\n", stderr)
                    Foundation.exit(2)
                }
                try directApply(rpm: rpm)
                print("direct-apply: success rpm=\(rpm)")
            case "provider-discover":
                try await providerDiscover()
            case "provider-apply-mode":
                guard arguments.count >= 2, let mode = FanMode(rawValue: arguments[1]) else {
                    fputs("usage: helper_smoke_test provider-apply-mode <systemAuto|quiet|balanced|performance>\n", stderr)
                    Foundation.exit(2)
                }
                try await providerApplyMode(mode)
            case "restore":
                try await client.restoreAutomatic(fanIDs: fans.map(\.id))
                print("restore: success")
            case "status":
                try printStatus()
            default:
                fputs("unknown command: \(command)\n", stderr)
                Foundation.exit(2)
            }
        } catch {
            fputs("\(command): failure: \(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }
    }

    private static func applyMode(_ mode: FanMode, using client: PrivilegedHelperClient) async throws {
        guard let smc = SMCBridge() else {
            throw HardwareControlError.readFailed("无法打开 AppleSMC。")
        }

        let fans = try smc.fanDescriptors().filter(\.supportsManualControl)
        guard !fans.isEmpty else {
            throw HardwareControlError.unsupported("没有可控制的风扇。")
        }

        if mode == .systemAuto {
            try await client.restoreAutomatic(fanIDs: fans.map(\.id))
            print("apply-mode: success mode=\(mode.rawValue) targets=auto")
            return
        }

        let operations = fans.compactMap { fan in
            ControlPreset.targetRPM(for: mode, fan: fan).map {
                FanControlOperation(fanID: fan.id, targetRPM: $0)
            }
        }

        guard !operations.isEmpty else {
            throw HardwareControlError.unsupported("当前模式没有可应用的风扇目标。")
        }

        try await client.apply(operations: operations)
        let targets = operations
            .map { "\($0.fanID)=\($0.targetRPM)" }
            .joined(separator: " ")
        print("apply-mode: success mode=\(mode.rawValue) targets=\(targets)")
    }

    private static func directProbe() throws {
        guard let smc = SMCBridge() else {
            throw HardwareControlError.readFailed("无法打开 AppleSMC。")
        }

        let fans = try smc.fanDescriptors().filter(\.supportsManualControl)
        guard !fans.isEmpty else {
            throw HardwareControlError.unsupported("没有可验证的风扇控制对象。")
        }

        for fan in fans {
            try smc.probeWriteAccess(for: fan)
        }
    }

    private static func directApply(rpm: Int) throws {
        guard let smc = SMCBridge() else {
            throw HardwareControlError.readFailed("无法打开 AppleSMC。")
        }

        let fans = try smc.fanDescriptors().filter(\.supportsManualControl)
        guard !fans.isEmpty else {
            throw HardwareControlError.unsupported("没有可控制的风扇。")
        }

        for fan in fans {
            try smc.apply(targetRPM: rpm, to: fan)
            guard try smc.verifyManualControl(for: fan, expectedTargetRPM: rpm) else {
                throw HardwareControlError.denied("风扇 \(fan.name) 写入验证失败。")
            }
        }
    }

    private static func printStatus() throws {
        guard let smc = SMCBridge() else {
            throw HardwareControlError.readFailed("无法打开 AppleSMC。")
        }

        let fans = try smc.fanDescriptors()
        guard !fans.isEmpty else {
            print("status: no fans")
            return
        }

        for fan in fans {
            let reading = try smc.fanReading(for: fan)
            let index = fan.id.dropFirst().prefix { $0.isNumber }
            let modeKeys = ["F\(index)Md", "F\(index)md"]
            let modeValue = modeKeys.compactMap { key in
                (try? smc.read(key: key).intValue).map { "\(key)=\($0)" }
            }.first ?? "mode=unavailable"
            let target = reading.targetRPM.map(String.init) ?? "nil"
            print(
                "\(fan.name) id=\(fan.id) min=\(fan.defaultMinRPM) max=\(fan.maxRPM) " +
                "current=\(reading.currentRPM) target=\(target) \(modeValue)"
            )
        }
    }

    private static func providerDiscover() async throws {
        let provider = AppleSiliconHardwareProvider()
        let inventory = try await provider.discover()
        let diagnostics = await provider.diagnostics()

        print("provider-discover: capability=\(inventory.capability.message)")
        print("provider-discover: fanCount=\(inventory.fans.count)")
        print("provider-discover: controlChannel=\(diagnostics.controlChannel ?? "nil")")
        print("provider-discover: lastError=\(diagnostics.lastError ?? "nil")")
    }

    private static func providerApplyMode(_ mode: FanMode) async throws {
        let provider = AppleSiliconHardwareProvider()
        let inventory = try await provider.discover()
        let diagnosticsBefore = await provider.diagnostics()
        print("provider-apply-mode: capability=\(inventory.capability.message)")
        print("provider-apply-mode: controlChannel(before)=\(diagnosticsBefore.controlChannel ?? "nil")")

        try await provider.apply(mode)

        let diagnosticsAfter = await provider.diagnostics()
        print("provider-apply-mode: success mode=\(mode.rawValue)")
        print("provider-apply-mode: controlChannel(after)=\(diagnosticsAfter.controlChannel ?? "nil")")
        print("provider-apply-mode: lastError=\(diagnosticsAfter.lastError ?? "nil")")
    }
}
