//
//  iFansApp.swift
//  iFans
//
//  Created by 伟（Wade） 王 on 2026/4/17.
//

import AppKit
import ApplicationServices
import SwiftUI

@main
struct iFansApp: App {
    @NSApplicationDelegateAdaptor(AppTerminationCoordinator.self) private var terminationCoordinator
    @State private var model: AppModel

    private static func mainWindowSize(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> CGSize {
        if arguments.contains("-ui-test-menu-panel") {
            return CGSize(width: 296, height: 244)
        }

        return CGSize(width: 332, height: 388)
    }

    private static func appDefaults(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> UserDefaults {
        if arguments.contains("-ui-test-preview-data") || arguments.contains("-ui-test-read-only") {
            let suiteName = "com.sobigrice.iFans.ui-tests"
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                return .standard
            }

            defaults.removePersistentDomain(forName: suiteName)
            return defaults
        }

        return .standard
    }

    init() {
        let runtimeEnvironment = AppRuntimeEnvironment.current()
        let arguments = ProcessInfo.processInfo.arguments
        let provider = Self.makeHardwareProvider(
            runtimeEnvironment: runtimeEnvironment,
            arguments: arguments
        )

        let appModel = AppModel(
            provider: provider,
            defaults: Self.appDefaults(arguments: arguments),
            runtimeEnvironment: runtimeEnvironment
        )

        _model = State(
            initialValue: appModel
        )

        AppTerminationCoordinator.prepareForTermination = {
            await appModel.prepareForTermination()
        }

        Task { @MainActor in
            appModel.start()
        }
    }

    private static func makeHardwareProvider(
        runtimeEnvironment: AppRuntimeEnvironment,
        arguments: [String]
    ) -> any HardwareProvider {
        if arguments.contains("-ui-test-helper-install") {
            return PreviewHardwareProvider(scenario: .helperInstallRequired)
        }

        if arguments.contains("-ui-test-read-only") {
            return PreviewHardwareProvider(scenario: .readOnly)
        }

        if arguments.contains("-ui-test-preview-data") || arguments.contains("-ui-test-menu-panel") {
            return PreviewHardwareProvider()
        }

        if runtimeEnvironment.isSandboxed {
            return UnsupportedHardwareProvider(message: runtimeEnvironment.sandboxUnsupportedMessage)
        }

        return AppleSiliconHardwareProvider()
    }

    var body: some Scene {
        let mainWindowSize = Self.mainWindowSize()

        WindowGroup(AppBrand.displayName, id: WindowIdentifier.main.rawValue) {
            ContentView()
                .environment(model)
                .frame(width: mainWindowSize.width, height: mainWindowSize.height)
                .toolbar(removing: .title)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .defaultSize(width: mainWindowSize.width, height: mainWindowSize.height)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .windowBackgroundDragBehavior(.enabled)

        MenuBarExtra {
            MenuBarPanelView()
                .environment(model)
                .frame(width: 296)
        } label: {
            MenuBarStatusLabel(
                title: model.menuBarLabel,
                systemImage: model.menuBarSymbol
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
                .frame(width: 520, height: 460)
        }
    }
}

private struct MenuBarStatusLabel: View {
    let title: String
    let systemImage: String
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Label(title, systemImage: systemImage)
            .accessibilityLabel(AppBrand.menuBarAccessibilityLabel)
            .accessibilityIdentifier("menubar.ifans")
            .background {
                MenuBarSecondaryClickInstaller(
                    onOpenSettings: { openSettings() },
                    onQuit: { NSApp.terminate(nil) }
                )
                .frame(width: 0, height: 0)
            }
    }
}

private struct MenuBarSecondaryClickInstaller: NSViewRepresentable {
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        coordinator.onOpenSettings = onOpenSettings
        coordinator.onQuit = onQuit
        return coordinator
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.installIfNeeded()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onOpenSettings = onOpenSettings
        context.coordinator.onQuit = onQuit
        context.coordinator.installIfNeeded()
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class Coordinator: NSObject {
        var onOpenSettings: (() -> Void)?
        var onQuit: (() -> Void)?

        private var globalMonitor: Any?
        private var localMonitor: Any?
        private lazy var menu: NSMenu = makeMenu()

        func installIfNeeded() {
            if globalMonitor == nil {
                globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .rightMouseDown) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.showMenuIfNeeded()
                    }
                }
            }

            if localMonitor == nil {
                localMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
                    guard let self else {
                        return event
                    }

                    guard self.showMenuIfNeeded() else {
                        return event
                    }

                    return nil
                }
            }
        }

        func teardown() {
            if let globalMonitor {
                NSEvent.removeMonitor(globalMonitor)
                self.globalMonitor = nil
            }

            if let localMonitor {
                NSEvent.removeMonitor(localMonitor)
                self.localMonitor = nil
            }
        }

        @discardableResult
        private func showMenuIfNeeded() -> Bool {
            guard let frame = statusItemFrame() else {
                return false
            }

            let mouseLocation = NSEvent.mouseLocation
            guard frame.insetBy(dx: -2, dy: -2).contains(mouseLocation) else {
                return false
            }

            let menuOrigin = NSPoint(x: frame.minX, y: frame.minY)
            menu.popUp(positioning: nil, at: menuOrigin, in: nil)
            return true
        }

        private func makeMenu() -> NSMenu {
            let menu = NSMenu()
            menu.autoenablesItems = false

            let settingsItem = NSMenuItem(
                title: "设置",
                action: #selector(openSettingsAction),
                keyEquivalent: ""
            )
            settingsItem.target = self

            let quitItem = NSMenuItem(
                title: "退出",
                action: #selector(quitAction),
                keyEquivalent: ""
            )
            quitItem.target = self

            menu.addItem(settingsItem)
            menu.addItem(.separator())
            menu.addItem(quitItem)
            return menu
        }

        private func statusItemFrame() -> CGRect? {
            let appElement = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)

            var extrasRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, "AXExtrasMenuBar" as CFString, &extrasRef) == .success,
                  let extrasRef else {
                return nil
            }

            let extrasMenuBar = unsafeBitCast(extrasRef, to: AXUIElement.self)

            var childrenRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(extrasMenuBar, kAXChildrenAttribute as CFString, &childrenRef) == .success,
                  let children = childrenRef as? [AXUIElement] else {
                return nil
            }

            guard let statusItem = children.first(where: {
                self.stringValue(for: $0, attribute: kAXTitleAttribute as CFString) == AppBrand.menuBarAccessibilityLabel
            }),
            let position = pointValue(for: statusItem, attribute: kAXPositionAttribute as CFString),
            let size = sizeValue(for: statusItem, attribute: kAXSizeAttribute as CFString),
            let desktopFrame = desktopFrame else {
                return nil
            }

            return CGRect(
                x: position.x,
                y: desktopFrame.maxY - position.y - size.height,
                width: size.width,
                height: size.height
            )
        }

        private var desktopFrame: CGRect? {
            let screens = NSScreen.screens.map(\.frame)
            guard let first = screens.first else {
                return nil
            }

            return screens.dropFirst().reduce(first) { partial, screen in
                partial.union(screen)
            }
        }

        private func stringValue(for element: AXUIElement, attribute: CFString) -> String? {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
                return nil
            }

            return value as? String
        }

        private func pointValue(for element: AXUIElement, attribute: CFString) -> CGPoint? {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
                  let value else {
                return nil
            }

            let axValue = unsafeBitCast(value, to: AXValue.self)
            guard
                  AXValueGetType(axValue) == .cgPoint else {
                return nil
            }

            var point = CGPoint.zero
            guard AXValueGetValue(axValue, .cgPoint, &point) else {
                return nil
            }

            return point
        }

        private func sizeValue(for element: AXUIElement, attribute: CFString) -> CGSize? {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
                  let value else {
                return nil
            }

            let axValue = unsafeBitCast(value, to: AXValue.self)
            guard
                  AXValueGetType(axValue) == .cgSize else {
                return nil
            }

            var size = CGSize.zero
            guard AXValueGetValue(axValue, .cgSize, &size) else {
                return nil
            }

            return size
        }

        @objc
        private func openSettingsAction(_ sender: Any?) {
            onOpenSettings?()
        }

        @objc
        private func quitAction(_ sender: Any?) {
            onQuit?()
        }
    }
}
