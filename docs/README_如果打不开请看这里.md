# README

这是 `oh fans` 的未签名测试版 DMG。

- 仅支持 Apple Silicon（M1 / M2 / M3 / M4 及后续 M 系列）
- 不支持 Intel Mac
- 当前包没有 Apple Developer 签名和 notarization，macOS 首次打开时可能会拦截

## 正常安装步骤

1. 打开 DMG。
2. 把 `oh fans.app` 拖到 `Applications`。
3. 进入“应用程序”目录，先不要双击，优先右键 `oh fans.app` -> “打开”。
4. 如果系统再次弹窗，继续点“打开”。

## 如果提示“无法打开，因为无法验证开发者”

优先按下面顺序处理：

1. 在 Finder 里右键 `Applications/oh fans.app` -> “打开”。
2. 如果还不行，打开“系统设置” -> “隐私与安全性”。
3. 在页面底部找到 `oh fans` 的拦截提示，点“仍要打开”。
4. 再回到“应用程序”目录重新打开一次。

## 如果提示“已损坏”“打不开”或双击没有反应

先确认你打开的是 `Applications` 里的 `oh fans.app`，不是 DMG 里临时挂载的那一份。

然后打开“终端”，执行：

```bash
xattr -dr com.apple.quarantine "/Applications/oh fans.app"
```

执行完成后，再回 Finder 里右键 `oh fans.app` -> “打开”。

## 如果连 DMG 都打不开

把下面命令里的路径替换成你实际下载的 DMG 路径：

```bash
xattr -dr com.apple.quarantine "/path/to/oh-fans-1.0-1-unsigned.dmg"
```

然后重新双击 DMG。

## 首次使用时还会发生什么

`oh fans` 要想真的控制风扇，需要安装辅助控件。

首次打开 app 后，如果界面提示安装或重装辅助控件：

1. 按界面提示继续。
2. 输入 macOS 管理员密码。
3. 安装完成后重新回到 app 确认已经不是只读监控模式。

如果辅助控件更新过，旧版本 helper 仍可能留在系统里，这时需要重新安装一次辅助控件。

## 不建议这样做

- 不要全局关闭 Gatekeeper
- 不要运行来源不明的“关闭安全限制”脚本
- 不要一直从 DMG 挂载盘里直接启动 app

推荐做法始终是：复制到 `Applications`，必要时只对 `oh fans.app` 或当前 DMG 移除 quarantine。
