# oh fans 辅助控件安装说明

当前 macOS 会拒绝非特权进程直接写 AppleSMC 风扇控制 key，错误码为 `kIOReturnNotPrivileged (0xe00002c1)`。
用户界面里统一把这条底层能力称为“辅助控件”；文档里保留 `helper` 一词，是为了和脚本名、目录名、二进制名对应。

## 开发版安装步骤

1. 构建辅助控件：
   - `./script/build_helper.sh`
   - 该脚本会同时生成当前源码对应的 `./build/helper/helper_smoke_test`，用于握手 / probe / provider-discover 验证。
2. 安装并启动辅助控件：
   - `./script/install_helper.sh`
   - app 内“安装辅助控件 / 重装辅助控件”按钮会优先使用 app bundle 内置的 payload 执行同等安装；如果当前是开发环境，也仍然保留 `./script/install_helper.sh` 这条 canonical 手动安装链路。
   - 当前安装脚本会在 `bootstrap` 前自动补做 `launchctl enable system/com.sobigrice.iFans.helper`，并等待 disabled override 真正清掉；如果 system 域仍然保留 disabled 状态，脚本会直接退出并给出诊断，不再静默继续。
   - app 内安装完成后也会立即再做一次辅助控件握手；如果控制通道没有真正上线，界面会直接显示失败原因和诊断信息。
3. 重启 oh fans，再次进入仪表盘确认“能力与提示”不再显示只读提示。
4. 如需确认当前系统辅助控件与源码一致，可执行：
   - `./build/helper/helper_smoke_test handshake`
   - `./build/helper/helper_smoke_test probe`
   - `./build/helper/helper_smoke_test provider-discover`

## 升级注意事项

- 只要辅助控件二进制有更新，就必须重新执行一次 `./script/install_helper.sh`，否则系统里的 `/Library/PrivilegedHelperTools/com.sobigrice.iFans.helper` 仍然会继续跑旧版本逻辑。
- 只要辅助控件的 XPC / wire 协议有变更，也必须重新执行一次 `./script/install_helper.sh`；否则主 app 可能只能进入监控模式，并提示“检测到旧版 oh fans 辅助控件”。
- 可用下面两条命令核对“系统辅助控件”和“本地新构建辅助控件”的时间是否一致：
  - `stat -f '%Sm %N' -t '%Y-%m-%d %H:%M:%S' /Library/PrivilegedHelperTools/com.sobigrice.iFans.helper`
  - `stat -f '%Sm %N' -t '%Y-%m-%d %H:%M:%S' ./build/helper/com.sobigrice.iFans.helper`

## 当前边界

- 这个辅助控件方案先解决“控制链路打通”，仍然是开发版安装路径。
- 当前仓库没有可用的代码签名身份；如果后续要做真正产品化安装，需要补签名、安装包和辅助控件升级/卸载流程。
