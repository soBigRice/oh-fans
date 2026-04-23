# oh fans

`oh fans` 是一个面向通用 M 系列 Mac 用户的菜单栏风扇控制工具，仅支持 Apple Silicon（M1 / M2 / M3 / M4 及后续 M 系列），不支持 Intel Mac。

它的目标不是做一个只能“读到风扇数据”的演示，而是把真实的控制链路打通：左键打开菜单栏面板，右键状态栏图标弹出“设置 / 退出”，主窗口和设置页都能直接操作，同时通过辅助控件（底层为特权 helper）解决 AppleSMC 在普通进程里无法写入的问题。

## 支持范围

- 仅支持 Apple Silicon（M1 / M2 / M3 / M4 及后续 M 系列）Mac
- 不支持 Intel Mac
- 辅助控件是风扇写入链路的必要组件；缺失、损坏或版本不匹配时，app 只保留监控模式
- 只要辅助控件二进制或通信协议变更，就必须重新安装辅助控件，否则系统里的旧版本会继续运行

## 当前能力

- 菜单栏常驻：左键打开紧凑面板，右键状态栏图标弹出“设置 / 退出”
- 主窗口 + Settings：支持模式切换、辅助控件诊断、作者链接、版本号、退出入口
- 外观样式切换：Settings 支持“高透 / 正常”，主窗口与顶部小菜单同步生效
- 模式切换支持长按液态滑动预览：拖动时液滴跟手，松开后再切换模式
- Apple Silicon 风扇读取与控制
- 辅助控件安装 / 重装链路
- 辅助控件握手、probe、apply、restore 的命令行验证工具（`helper_smoke_test`）
- 预览数据 / 只读模式 / 辅助控件缺失场景的 UI 测试参数

## 技术要点

- SwiftUI + macOS `MenuBarExtra(.window)`
- AppKit / Accessibility 桥接状态栏右键菜单
- AppleSMC 底层桥接
- 特权辅助控件（底层为 helper）+ XPC 通信
- 开发期辅助控件 payload 自动打包进 app

## 目录结构

```text
.
├── iFans/                     主应用源码
│   ├── Hardware/              AppleSMC、辅助控件桥接、硬件探测
│   ├── Models/                预设模式、品牌信息、状态模型
│   └── Views/                 菜单栏面板、主窗口、设置页
├── helper/                    辅助控件底层入口
├── script/                    辅助控件构建 / 安装 / smoke test 脚本
├── docs/                      安装说明、踩坑记录
├── iFansTests/                单元测试
└── iFansUITests/              UI 测试
```

## 本地开发

### 环境要求

- macOS
- Xcode 26+
- M 系列 Apple Silicon Mac

### 构建 app

```bash
xcodebuild build \
  -project iFans.xcodeproj \
  -scheme iFans \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedDataBridge \
  CODE_SIGNING_ALLOWED=NO
```

### 构建辅助控件

```bash
./script/build_helper.sh
```

构建后会生成：

- `./build/helper/com.sobigrice.iFans.helper`
- `./build/helper/com.sobigrice.iFans.helper.plist`
- `./build/helper/helper_smoke_test`

### 安装辅助控件

```bash
./script/install_helper.sh
```

安装成功后，可以用下面几条命令做最小验证：

```bash
./build/helper/helper_smoke_test handshake
./build/helper/helper_smoke_test probe
./build/helper/helper_smoke_test status
```

当前安装脚本会在 `bootstrap` 前自动补做 `launchctl enable`，并等待 system 域里的 disabled override 真正清掉；如果辅助控件安装命令跑完后控制通道仍未上线，app 会直接回显诊断信息，而不是只表现成“输入密码后没反应”。

如果要验证真实控制，不要只看 `probe`，还应该继续做：

```bash
./build/helper/helper_smoke_test apply 3000
./build/helper/helper_smoke_test restore
```

## 运行说明

- 左键菜单栏风扇图标：打开紧凑控制面板
- 右键菜单栏风扇图标：弹出“设置 / 退出”
- 如果辅助控件缺失或版本不匹配，界面会退回监控模式，并在主界面 / 设置页给出安装或重装入口

## 文档

- [辅助控件安装说明](docs/privileged-helper-setup.md)
- [已知问题与规避记录](docs/known-issues.md)

## 当前限制

- 当前优先解决的是“真实可控”的开发版链路，还不是完整签名分发版本
- 当前只支持 M 系列 Apple Silicon Mac，不支持 Intel Mac
- 辅助控件代码或通信协议变更后，需要重新安装系统里的辅助控件
- `xcodebuild test` 这条链路目前还有工程级噪音，日常验证建议先以真实构建产物和 `helper_smoke_test` 为准

## 作者

- GitHub: [soBigRice](https://github.com/soBigRice)
