import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("launchAtLoginEnabled") private var launchAtLoginEnabled = false
    @AppStorage("dockIconHidden") private var dockIconHidden = false
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section("启动与外观") {
                Toggle("登录时启动 \(AppBrand.displayName)", isOn: bindingForLaunchAtLogin)
                Toggle("隐藏 Dock 图标（仅菜单栏）", isOn: bindingForDockIconVisibility)
                Text("如果状态栏图标不可见，请到 系统设置 > 菜单栏 中启用 \(AppBrand.displayName)。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker("面板外观", selection: bindingForAppearanceStyle) {
                    ForEach(AppAppearanceStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)

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

            Section("辅助控件") {
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

                LabeledContent("GitHub") {
                    Link(destination: AppBrand.githubRepositoryURL) {
                        Label {
                            Text("oh-fans")
                        } icon: {
                            githubIcon
                        }
                    }
                    .accessibilityIdentifier("settings.github.link")
                }

                LabeledContent("版本") {
                    Text(AppBrand.versionDescription())
                        .accessibilityIdentifier("settings.version")
                }

                LabeledContent("更新") {
                    VStack(alignment: .trailing, spacing: 8) {
                        Button {
                            Task { await model.checkForUpdates() }
                        } label: {
                            if model.isCheckingForUpdates {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("检查中")
                                }
                            } else {
                                Label("检查更新", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                        .disabled(model.isCheckingForUpdates)
                        .accessibilityIdentifier("settings.check-update")

                        if let updateStatusMessage = model.updateStatusMessage {
                            Text(updateStatusMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }

                        if let downloadURL = model.updateDownloadURL {
                            Link(destination: downloadURL) {
                                Label("下载更新", systemImage: "arrow.down.circle.fill")
                            }
                            .accessibilityIdentifier("settings.download-update")
                        }
                    }
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

    private var bindingForAppearanceStyle: Binding<AppAppearanceStyle> {
        Binding(
            get: { model.appearanceStyle },
            set: { style in
                model.setAppearanceStyle(style)
            }
        )
    }

    private var bindingForDockIconVisibility: Binding<Bool> {
        Binding(
            get: { dockIconHidden },
            set: { hidden in
                dockIconHidden = hidden
                applyDockIconVisibility(isHidden: hidden)
            }
        )
    }

    private func applyDockIconVisibility(isHidden: Bool) {
        _ = NSApp.setActivationPolicy(isHidden ? .accessory : .regular)
        if !isHidden {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @ViewBuilder
    private var githubIcon: some View {
        if let symbol = NSImage(
            systemSymbolName: "logo.github",
            accessibilityDescription: "GitHub"
        ) {
            Image(nsImage: symbol)
        } else {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
        }
    }
}
