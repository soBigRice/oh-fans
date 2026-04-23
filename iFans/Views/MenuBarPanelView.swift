import SwiftUI

struct MenuBarPanelView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        CompactGlassPanelView(
            model: model,
            density: .menuBar,
            primaryAction: primaryAction
        )
    }

    private var primaryAction: CompactPanelAction {
        if let helperInstallAction = model.helperInstallAction {
            return CompactPanelAction(
                title: model.isInstallingHelper
                    ? helperInstallAction.kind.inProgressTitle
                    : helperInstallAction.kind.title,
                systemImage: helperInstallAction.kind.systemImage,
                accessibilityIdentifier: "helper.install.panel",
                isEnabled: !model.isInstallingHelper
            ) {
                Task { await model.installPrivilegedHelper() }
            }
        }

        return CompactPanelAction(
            title: "打开主窗口",
            systemImage: "macwindow",
            accessibilityIdentifier: "menu.open-main-window"
        ) {
            openWindow(id: WindowIdentifier.main.rawValue)
        }
    }
}
