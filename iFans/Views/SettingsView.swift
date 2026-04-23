import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("launchAtLoginEnabled") private var launchAtLoginEnabled = false
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section("启动与外观") {
                Toggle("登录时启动 \(AppBrand.displayName)", isOn: bindingForLaunchAtLogin)
                Text("如果状态栏图标不可见，请到 系统设置 > 菜单栏 中启用 \(AppBrand.displayName)。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("硬件状态") {
                Text(model.capabilityMessage)
                    .foregroundStyle(.secondary)

                if let hottestTemp = model.latestSnapshot?.hottestTemp {
                    Text("当前最高温度：\(hottestTemp.temperatureText)")
                }
            }

            Section("特权 helper") {
                Text(model.helperInstallStatusText)
                    .foregroundStyle(.secondary)

                Text(model.helperInstallDetailText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let helperInstallAction = model.helperInstallAction {
                    Button {
                        Task { await model.installPrivilegedHelper() }
                    } label: {
                        Label(
                            model.isInstallingHelper
                                ? helperInstallAction.kind.inProgressTitle
                                : helperInstallAction.kind.title,
                            systemImage: helperInstallAction.kind.systemImage
                        )
                    }
                    .disabled(model.isInstallingHelper)
                    .accessibilityIdentifier("helper.install.settings")
                }
            }

            Section("诊断") {
                LabeledContent("构建模式", value: model.buildModeDescription)
                LabeledContent("机型标识", value: model.machineIdentifier)
                LabeledContent("风扇数量", value: "\(model.detectedFanCount)")
                LabeledContent("控制通道", value: model.controlChannelDescription)
                LabeledContent("最近一次底层错误") {
                    Text(model.lastHardwareErrorMessage)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }
            }

            Section("关于") {
                LabeledContent("作者") {
                    Link(AppBrand.authorName, destination: AppBrand.authorProfileURL)
                        .accessibilityIdentifier("settings.author.link")
                }

                LabeledContent("版本") {
                    Text(AppBrand.versionDescription())
                        .accessibilityIdentifier("settings.version")
                }

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("退出 \(AppBrand.displayName)", systemImage: "power")
                }
                .accessibilityIdentifier("settings.quit")
            }
        }
        .formStyle(.grouped)
        .padding(18)
    }

    private var bindingForLaunchAtLogin: Binding<Bool> {
        Binding(
            get: { launchAtLoginEnabled },
            set: { enabled in
                launchAtLoginEnabled = enabled
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    launchAtLoginError = nil
                } catch {
                    launchAtLoginError = error.localizedDescription
                }
            }
        )
    }
}
