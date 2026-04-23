import SwiftUI

struct DashboardView: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        CompactGlassPanelView(
            model: model,
            density: .window,
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
            title: "设置",
            systemImage: "slider.horizontal.3",
            accessibilityIdentifier: "dashboard.open-settings"
        ) {
            openSettings()
        }
    }
}
