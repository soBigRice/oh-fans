import Darwin
import Foundation
import IOKit

struct SMCDecodedValue: Sendable {
    let dataSize: Int
    let dataType: String
    let bytes: [UInt8]

    nonisolated var intValue: Int? {
        switch dataType {
        case "ui8 ":
            return bytes.first.map(Int.init)
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Int(bytes[0]) << 8 | Int(bytes[1])
        case "ui32":
            guard bytes.count >= 4 else { return nil }
            return Int(bytes[0]) << 24 | Int(bytes[1]) << 16 | Int(bytes[2]) << 8 | Int(bytes[3])
        default:
            return nil
        }
    }

    nonisolated var floatValue: Float? {
        switch dataType {
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            return bytes.withUnsafeBytes { rawBuffer in
                rawBuffer.loadUnaligned(as: Float.self)
            }
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            let raw = Int(bytes[0]) << 8 | Int(bytes[1])
            return Float(raw >> 2) + Float(raw & 0b11) / 4
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
            return Float(raw) / 256
        default:
            return nil
        }
    }

    nonisolated var rpmValue: Int? {
        if let floatValue {
            return Int(floatValue.rounded())
        }
        return intValue
    }
}

private struct FanKeySet: Sendable {
    let current: String
    let minimum: String
    let maximum: String
    let mode: String?
    let target: String
}

private struct FanUnlockRegister: Sendable {
    let key: String
    let value: SMCDecodedValue
}

final class SMCBridge: @unchecked Sendable {
    nonisolated(unsafe) private let handle: UnsafeMutableRawPointer

    nonisolated init?() {
        var rawHandle: UnsafeMutableRawPointer?
        let result = ifans_smc_open(&rawHandle)
        guard result == kIOReturnSuccess, let rawHandle else {
            return nil
        }
        self.handle = rawHandle
    }

    nonisolated deinit {
        ifans_smc_close(handle)
    }

    nonisolated func fanDescriptors() throws -> [FanDescriptor] {
        let fanCountValue = try read(key: "FNum")
        guard let fanCount = fanCountValue.intValue else {
            throw HardwareControlError.readFailed("AppleSMC 返回了不可解析的风扇数量。")
        }

        guard fanCount > 0 else {
            return []
        }

        return try (0..<fanCount).map { index in
            let keys = try keys(for: index)
            let minimumValue = try read(key: keys.minimum)
            let maximumValue = try read(key: keys.maximum)
            _ = try read(key: keys.current)

            let targetValue = try? read(key: keys.target)
            let supportsManualControl = keys.mode != nil && targetValue?.rpmValue != nil

            return FanDescriptor(
                id: keys.current,
                name: "风扇 \(index + 1)",
                defaultMinRPM: minimumValue.rpmValue ?? 0,
                maxRPM: maximumValue.rpmValue ?? 0,
                supportsManualControl: supportsManualControl
            )
        }
    }

    nonisolated func fanReading(for fan: FanDescriptor) throws -> FanReading {
        let keys = try keys(for: fan)
        let currentRPM = try read(key: keys.current).rpmValue ?? 0
        let targetRPM = try? read(key: keys.target).rpmValue

        return FanReading(
            id: fan.id,
            currentRPM: currentRPM,
            targetRPM: targetRPM.flatMap { $0 > 0 ? $0 : nil }
        )
    }

    nonisolated func supportsManualControl(for fan: FanDescriptor) -> Bool {
        fan.supportsManualControl
    }

    nonisolated func apply(targetRPM: Int, to fan: FanDescriptor) throws {
        let keys = try keys(for: fan)
        try unlockManualControl(for: fan, keys: keys)
        try writeRPMAndConfirm(
            key: keys.target,
            expectedRPM: targetRPM,
            tolerance: 64,
            maxAttempts: 20,
            delayMicros: 100_000
        )
    }

    nonisolated func probeWriteAccess(for fan: FanDescriptor) throws {
        let keys = try keys(for: fan)
        guard let modeKey = keys.mode else {
            throw HardwareControlError.unsupported("当前机型未暴露可写的风扇模式 key，无法验证手动控制。")
        }

        let existingMode = try read(key: modeKey)
        guard let rawMode = existingMode.intValue else {
            throw HardwareControlError.denied("SMC key \(modeKey) 的当前值不可解析，无法验证写入权限。")
        }

        let originalUnlockRegister = try readFanUnlockRegisterIfPresent()

        do {
            if rawMode == 1 {
                try writeIntegerAndConfirm(
                    key: modeKey,
                    expected: rawMode,
                    maxAttempts: 5,
                    delayMicros: 50_000
                )
            } else {
                try unlockManualControl(for: fan, keys: keys)
                try writeIntegerAndConfirm(
                    key: modeKey,
                    expected: rawMode,
                    maxAttempts: 20,
                    delayMicros: 100_000
                )
            }

            try restoreProbeState(
                originalMode: rawMode,
                originalUnlockRegister: originalUnlockRegister,
                keys: keys
            )
        } catch {
            try? restoreProbeState(
                originalMode: rawMode,
                originalUnlockRegister: originalUnlockRegister,
                keys: keys
            )
            throw error
        }
    }

    nonisolated func restoreAutomatic(for fan: FanDescriptor) throws {
        let keys = try keys(for: fan)

        if let modeKey = keys.mode {
            try writeIntegerAndConfirm(
                key: modeKey,
                expected: 0,
                maxAttempts: 20,
                delayMicros: 100_000
            )
        }

        if let unlockRegister = try readFanUnlockRegisterIfPresent(),
           unlockRegister.value.bytes.first != 0
        {
            try writeFirstByteAndConfirm(
                key: unlockRegister.key,
                expectedByte: 0,
                maxAttempts: 20,
                delayMicros: 100_000
            )
        }
    }

    nonisolated func verifyManualControl(for fan: FanDescriptor, expectedTargetRPM: Int) throws -> Bool {
        let keys = try keys(for: fan)
        for attempt in 0..<20 {
            let modeValue = keys.mode.flatMap { try? read(key: $0).intValue }
            let targetValue = try? read(key: keys.target).rpmValue

            let targetMatches = targetValue.map { abs($0 - expectedTargetRPM) <= 64 } ?? false
            let modeMatches = modeValue.map { $0 == 1 } ?? true

            if targetMatches, modeMatches {
                return true
            }

            if attempt < 19 {
                usleep(100_000)
            }
        }

        return false
    }

    nonisolated func read(key: String) throws -> SMCDecodedValue {
        var dataType: UInt32 = 0
        var dataSize: UInt32 = 0
        var bytes = Array(repeating: UInt8(0), count: 32)

        let result = key.withCString { cKey in
            bytes.withUnsafeMutableBufferPointer { buffer in
                ifans_smc_read(
                    handle,
                    cKey,
                    &dataType,
                    &dataSize,
                    buffer.baseAddress,
                    UInt32(buffer.count)
                )
            }
        }

        guard result == kIOReturnSuccess else {
            throw HardwareControlError.readFailed("AppleSMC 读取 \(key) 失败（\(smcErrorHex(result))）。")
        }

        return SMCDecodedValue(
            dataSize: Int(dataSize),
            dataType: smcString(for: dataType),
            bytes: Array(bytes.prefix(Int(dataSize)))
        )
    }

    private nonisolated func keys(for index: Int) throws -> FanKeySet {
        FanKeySet(
            current: "F\(index)Ac",
            minimum: "F\(index)Mn",
            maximum: "F\(index)Mx",
            mode: try resolveModeKey(for: index),
            target: "F\(index)Tg"
        )
    }

    private nonisolated func keys(for fan: FanDescriptor) throws -> FanKeySet {
        let indexString = fan.id.dropFirst().prefix { $0.isNumber }
        let index = Int(indexString) ?? 0
        return try keys(for: index)
    }

    private nonisolated func write(key: String, value: SMCWriteValue) throws {
        let existing = try read(key: key)
        let bytes = try value.encodedBytes(matching: existing, key: key)

        guard existing.dataSize == bytes.count else {
            throw HardwareControlError.denied("SMC key \(key) 的数据长度不匹配，已停止写入。")
        }

        let result = key.withCString { cKey in
            bytes.withUnsafeBufferPointer { buffer in
                ifans_smc_write(handle, cKey, buffer.baseAddress, UInt32(buffer.count))
            }
        }

        guard result == kIOReturnSuccess else {
            throw HardwareControlError.denied(smcWriteErrorMessage(for: key, result: result))
        }
    }

    private nonisolated func resolveModeKey(for index: Int) throws -> String? {
        let candidates = [
            "F\(index)Md",
            "F\(index)md"
        ]

        for candidate in candidates {
            if let value = try? read(key: candidate), value.dataSize > 0 {
                return candidate
            }
        }

        return nil
    }

    private nonisolated func readFanUnlockRegisterIfPresent() throws -> FanUnlockRegister? {
        guard let value = try? read(key: "Ftst"), value.dataSize > 0 else {
            return nil
        }

        return FanUnlockRegister(key: "Ftst", value: value)
    }

    private nonisolated func unlockManualControl(for fan: FanDescriptor, keys: FanKeySet) throws {
        guard let modeKey = keys.mode else {
            throw HardwareControlError.unsupported("风扇 \(fan.name) 没有暴露可写的模式 key。")
        }

        let currentMode = try read(key: modeKey)
        guard currentMode.intValue != nil else {
            throw HardwareControlError.denied("SMC key \(modeKey) 的值不可解析，无法切换手动模式。")
        }

        do {
            try writeIntegerAndConfirm(
                key: modeKey,
                expected: 1,
                maxAttempts: 20,
                delayMicros: 100_000
            )
            return
        } catch let directError as HardwareControlError {
            guard let unlockRegister = try readFanUnlockRegisterIfPresent() else {
                throw directError
            }

            if unlockRegister.value.bytes.first != 1 {
                try writeFirstByteAndConfirm(
                    key: unlockRegister.key,
                    expectedByte: 1,
                    maxAttempts: 100,
                    delayMicros: 50_000
                )

                usleep(3_000_000)
            }

            try writeIntegerAndConfirm(
                key: modeKey,
                expected: 1,
                maxAttempts: 300,
                delayMicros: 100_000
            )
        }
    }

    private nonisolated func restoreProbeState(
        originalMode: Int,
        originalUnlockRegister: FanUnlockRegister?,
        keys: FanKeySet
    ) throws {
        if let modeKey = keys.mode {
            try writeIntegerAndConfirm(
                key: modeKey,
                expected: originalMode,
                maxAttempts: 20,
                delayMicros: 100_000
            )
        }

        if let originalUnlockRegister {
            try writeFirstByteAndConfirm(
                key: originalUnlockRegister.key,
                expectedByte: originalUnlockRegister.value.bytes.first ?? 0,
                maxAttempts: 20,
                delayMicros: 100_000
            )
        }
    }

    private nonisolated func writeIntegerAndConfirm(
        key: String,
        expected: Int,
        maxAttempts: Int,
        delayMicros: useconds_t
    ) throws {
        try writeAndConfirm(
            key: key,
            value: .integer(expected),
            maxAttempts: maxAttempts,
            delayMicros: delayMicros
        ) { $0.intValue == expected }
    }

    private nonisolated func writeRPMAndConfirm(
        key: String,
        expectedRPM: Int,
        tolerance: Int,
        maxAttempts: Int,
        delayMicros: useconds_t
    ) throws {
        try writeAndConfirm(
            key: key,
            value: .rpm(expectedRPM),
            maxAttempts: maxAttempts,
            delayMicros: delayMicros
        ) { value in
            guard let rpm = value.rpmValue else {
                return false
            }
            return abs(rpm - expectedRPM) <= tolerance
        }
    }

    private nonisolated func writeFirstByteAndConfirm(
        key: String,
        expectedByte: UInt8,
        maxAttempts: Int,
        delayMicros: useconds_t
    ) throws {
        let existing = try read(key: key)
        try writeAndConfirm(
            key: key,
            value: .bytes(replacingFirstByte(of: existing, with: expectedByte)),
            maxAttempts: maxAttempts,
            delayMicros: delayMicros
        ) { value in
            value.bytes.first == expectedByte
        }
    }

    private nonisolated func writeAndConfirm(
        key: String,
        value: SMCWriteValue,
        maxAttempts: Int,
        delayMicros: useconds_t,
        predicate: (SMCDecodedValue) -> Bool
    ) throws {
        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                try write(key: key, value: value)
            } catch {
                lastError = error
            }

            if let current = try? read(key: key), predicate(current) {
                return
            }

            if attempt < maxAttempts - 1, delayMicros > 0 {
                usleep(delayMicros)
            }
        }

        if let lastError {
            throw lastError
        }

        throw HardwareControlError.denied("AppleSMC 写入 \(key) 未在预期时间内生效。")
    }

    private nonisolated func writeWithRetry(
        key: String,
        value: SMCWriteValue,
        maxAttempts: Int = 10,
        delayMicros: useconds_t = 50_000
    ) throws {
        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                try write(key: key, value: value)
                return
            } catch {
                lastError = error
                if attempt < maxAttempts - 1, delayMicros > 0 {
                    usleep(delayMicros)
                }
            }
        }

        throw lastError ?? HardwareControlError.denied("AppleSMC 写入 \(key) 失败。")
    }
}

private enum SMCWriteValue {
    case integer(Int)
    case rpm(Int)
    case bytes([UInt8])

    nonisolated func encodedBytes(matching existing: SMCDecodedValue, key: String) throws -> [UInt8] {
        switch self {
        case let .integer(raw):
            switch existing.dataType {
            case "ui8 ":
                return [UInt8(clamping: raw)]
            case "ui16":
                let value = UInt16(clamping: raw)
                return [UInt8((value >> 8) & 0xff), UInt8(value & 0xff)]
            case "ui32":
                let value = UInt32(clamping: raw)
                return [
                    UInt8((value >> 24) & 0xff),
                    UInt8((value >> 16) & 0xff),
                    UInt8((value >> 8) & 0xff),
                    UInt8(value & 0xff)
                ]
            default:
                throw HardwareControlError.denied("SMC key \(key) 的类型 \(existing.dataType) 不支持整数写入。")
            }
        case let .rpm(raw):
            switch existing.dataType {
            case "flt ":
                var value = Float(raw)
                return withUnsafeBytes(of: &value) { Array($0) }
            case "fpe2":
                let fixedPoint = UInt16(clamping: raw * 4)
                return [UInt8((fixedPoint >> 8) & 0xff), UInt8(fixedPoint & 0xff)]
            case "ui16":
                let value = UInt16(clamping: raw)
                return [UInt8((value >> 8) & 0xff), UInt8(value & 0xff)]
            case "ui8 ":
                return [UInt8(clamping: raw)]
            default:
                throw HardwareControlError.denied("SMC key \(key) 的类型 \(existing.dataType) 不支持 RPM 写入。")
            }
        case let .bytes(bytes):
            guard bytes.count == existing.dataSize else {
                throw HardwareControlError.denied("SMC key \(key) 的原始写入长度不匹配。")
            }
            return bytes
        }
    }
}

private nonisolated func replacingFirstByte(of value: SMCDecodedValue, with newByte: UInt8) -> [UInt8] {
    guard !value.bytes.isEmpty else {
        return []
    }

    var bytes = value.bytes
    bytes[0] = newByte
    return bytes
}

private nonisolated func smcErrorHex(_ result: kern_return_t) -> String {
    String(format: "0x%08x", UInt32(bitPattern: result))
}

private nonisolated func smcWriteErrorMessage(for key: String, result: kern_return_t) -> String {
    let hex = smcErrorHex(result)

    if result == kIOReturnNotPrivileged {
        return "AppleSMC 写入 \(key) 被内核拒绝（\(hex)，privilege violation）。当前进程没有风扇控制权限。"
    }

    if result == kIOReturnNotWritable {
        return "AppleSMC 写入 \(key) 失败（\(hex)）。当前机型未开放该控制 key 的写入能力。"
    }

    if result == kIOReturnError {
        return "AppleSMC 写入 \(key) 失败（\(hex)）。IOKit 已返回成功，但 SMC 固件拒绝了这次写入；通常是权限、解锁顺序或 key 选择不满足。"
    }

    return "AppleSMC 写入 \(key) 失败（\(hex)）。"
}

private nonisolated func smcString(for fourCC: UInt32) -> String {
    let characters: [UInt8] = [
        UInt8((fourCC >> 24) & 0xff),
        UInt8((fourCC >> 16) & 0xff),
        UInt8((fourCC >> 8) & 0xff),
        UInt8(fourCC & 0xff)
    ]
    return String(decoding: characters, as: UTF8.self)
}
