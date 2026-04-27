# Changelog

## 2026-04-27

### Added
- 新增桌面小组件扩展目标 `i​Fans​WidgetsExtension` 及相关文件结构。
- 新增主应用到小组件的数据快照存储：`iFans/Models/WidgetSnapshotStore.swift`。
- 新增小组件温度展示实现：`i​Fans​Widgets/i_Fans_Widgets.swift`。

### Changed
- `iFans/AppModel.swift` 增加小组件快照发布逻辑，并在温度刷新后触发 timeline 刷新。
- 小组件视觉样式重构为紧凑的玻璃面板风格，适配 `systemSmall` 与 `systemMedium`。
- 小组件容器改为全幅背景渲染，并关闭系统内容边距：`.contentMarginsDisabled()`。
- 在无开发者账号场景下调整扩展配置，避免因 App Groups 签名限制导致无法编译。

### Fixed
- 修复小号组件标题截断、底部信息拥挤与信息重复问题。
- 修复小组件在编辑态和非编辑态下视觉留白不一致导致的观感偏差。

### Notes
- 当前无开发者账号配置下，小组件可显示状态信息，但不启用 App Group 实时共享控制数据。
