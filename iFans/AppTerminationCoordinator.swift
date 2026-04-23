import AppKit
import Foundation

final class AppTerminationCoordinator: NSObject, NSApplicationDelegate {
    @MainActor
    static var prepareForTermination: (@Sendable () async -> Void)?

    private var isAwaitingTerminationReply = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let prepareForTermination = Self.prepareForTermination else {
            return .terminateNow
        }

        guard !isAwaitingTerminationReply else {
            return .terminateLater
        }

        isAwaitingTerminationReply = true

        Task { @MainActor [weak self] in
            await prepareForTermination()
            sender.reply(toApplicationShouldTerminate: true)
            self?.isAwaitingTerminationReply = false
        }

        return .terminateLater
    }
}
