# oh fans 特权 Helper 安装说明

当前 macOS 会拒绝非特权进程直接写 AppleSMC 风扇控制 key，错误码为 `kIOReturnNotPrivileged (0xe00002c1)`。

## 开发版安装步骤

1. 构建 helper：
   - `./script/build_helper.sh`
   - 该脚本会同时生成当前源码对应的 `./build/helper/helper_smoke_test`，用于握手 / probe / provider-discover 验证。
2. 安装并启动 helper：
   - `./script/install_helper.sh`
   - app 内“安装 helper / 重装 helper”按钮会优先使用 app bundle 内置的 helper payload 执行同等安装；如果当前是开发环境，也仍然保留 `./script/install_helper.sh` 这条 canonical 手动安装链路。
3. 重启 oh fans，再次进入仪表盘确认“能力与提示”不再显示只读提示。
4. 如需确认当前系统 helper 与源码一致，可执行：
   - `./build/helper/helper_smoke_test handshake`
   - `./build/helper/helper_smoke_test probe`
   - `./build/helper/helper_smoke_test provider-discover`

## 升级注意事项

- 只要 helper 二进制有更新，就必须重新执行一次 `./script/install_helper.sh`，否则系统里的 `/Library/PrivilegedHelperTools/com.sobigrice.iFans.helper` 仍然会继续跑旧版本逻辑。
- 只要 helper 的 XPC / wire 协议有变更，也必须重新执行一次 `./script/install_helper.sh`；否则主 app 可能只能进入监控模式，并提示“检测到旧版 oh fans 特权 helper”。
- 可用下面两条命令核对“系统 helper”和“本地新构建 helper”的时间是否一致：
  - `stat -f '%Sm %N' -t '%Y-%m-%d %H:%M:%S' /Library/PrivilegedHelperTools/com.sobigrice.iFans.helper`
  - `stat -f '%Sm %N' -t '%Y-%m-%d %H:%M:%S' ./build/helper/com.sobigrice.iFans.helper`

## 当前边界

- 这个 helper 方案先解决“控制链路打通”，仍然是开发版安装路径。
- 当前仓库没有可用的代码签名身份；如果后续要做真正产品化安装，需要补签名、安装包和 helper 升级/卸载流程。
