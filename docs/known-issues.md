# iFans 已知问题与规避记录

## 2026-04-23 未签名 DMG 从 GitHub 下载后，macOS 可能把 app 或 DMG 拦成“无法验证开发者”“已损坏”或直接打不开
- 现象：本地构建出来的 unsigned `oh fans.app` 明明可用，但用户从 GitHub 下载 `.dmg` 后，双击 app 可能提示“无法打开，因为无法验证开发者”、`oh fans.app`“已损坏，无法打开”，或者看起来像双击没反应。
- 影响：如果发布包里只有 app 没有随包说明，普通用户通常会把这个问题误判成“包坏了”或“项目根本不能用”，测试反馈也会被 Gatekeeper 噪音淹没。
- 解决：unsigned DMG 必须随包附带 README，至少写清楚三条处理路径：右键 `Applications/oh fans.app` -> “打开”；“系统设置” -> “隐私与安全性”里的“仍要打开”；终端执行 `xattr -dr com.apple.quarantine "/Applications/oh fans.app"`。如果连 DMG 本身都打不开，再补一条对 DMG 路径执行同样 `xattr` 的备用命令。
- 规避：后续只要继续发布未签名测试包，不要只上传 `.dmg` 就结束；必须把“打不开怎么办”README 一起塞进 DMG，且不要建议用户全局关闭 Gatekeeper。

## 2026-04-23 用 Icon Composer 导出的 macOS 图标替换工程资源时，不能只换 `AppIcon.appiconset`
- 现象：把 Icon Composer 导出的 `Default` 图标只缩放塞进 `AppIcon.appiconset` 后，构建虽然能过，但运行中的 Dock 图标仍会继续读取 `RuntimeLightAppIcon` / `RuntimeDarkAppIcon`，看起来像“主图标换了，App 里还是旧图标”。
- 影响：Finder、Spotlight 和运行中的 Dock 图标会出现新旧不一致，深色模式下尤其明显，排查时也容易误判成 Xcode 资源缓存。
- 解决：当前工程继续让 `AppIcon.appiconset` 使用 `icon-macOS-Default-1024x1024@1x.png` 生成固定尺寸；`RuntimeLightAppIcon.imageset` 同步替换为 `Default`；`RuntimeDarkAppIcon.imageset` 同步替换为 `Dark`。如果后续全面切到 Icon Composer `.icon` 原生流程，再一起移除运行时覆盖逻辑。
- 规避：后续替换图标前，先搜 `applicationIconImage`、`RuntimeLightAppIcon`、`RuntimeDarkAppIcon`；确认主图标和运行时 Dock 图标两套资源都已经同步更新。

## 2026-04-23 macOS `AppIcon.appiconset` 就算写了 `dark` appearance，编译产物也可能只保留默认图标
- 现象：给 macOS 的 `AppIcon.appiconset` 条目补上 `appearances = [{ appearance = luminosity, value = dark }]` 以后，`actool` 仍然可以顺利编译，但导出的 `Assets.car` / `AppIcon.icns` 只保留默认图标，dark 版本会被静默丢掉。
- 影响：看起来工程里已经配好了浅色 / 深色 app icon，实际 Finder、Dock 或 Spotlight 仍然只会显示默认图，属于“资源改了但系统并没切换”的假完成。
- 解决：传统 `.appiconset` 继续只放默认图标；如果项目需要真正随系统外观切换，要么改用 Xcode 26 的 Icon Composer `.icon` 流程，要么像当前项目这样在运行时基于 `NSApp.effectiveAppearance` 覆盖 `applicationIconImage`。
- 规避：后续凡是给 macOS app icon 做 light/dark 双版本，不要只看 `Contents.json` 和 `actool` 通过就结束；至少要检查编译产物里是否真的包含 dark rendition，或者直接做一次运行态图标验证。

## 2026-04-23 helper 已安装但被 `launchctl` 标记成 disabled 时，单跑 `bootstrap` 可能直接报 `Input/output error (5)` 或 `Service is disabled (119)`
- 现象：系统里明明已经有 `/Library/PrivilegedHelperTools/com.sobigrice.iFans.helper` 和 LaunchDaemon plist，但 app 内“重装 helper”仍然返回 `Bootstrap failed: 5: Input/output error (5)`、`Service is disabled (119)`，或者用户输入管理员密码后界面像“没反应”，同时 `launchctl print system/com.sobigrice.iFans.helper` 查不到 service。
- 影响：界面会退回监控模式，控制通道显示“未建立”；如果安装脚本把 `launchctl enable` 的失败静默吞掉，UI 只会表现成“输完密码但没有结果”，排查方向也容易被带偏。
- 解决：安装脚本不能只做 `bootout -> enable -> bootstrap -> kickstart`，还要显式验证 disabled override 已经清掉；如果 `launchctl print-disabled system` 里仍然命中 `com.sobigrice.iFans.helper => disabled`，就必须立即退出并把诊断抛回 UI，而不是继续静默 `bootstrap`。App 侧在授权脚本返回后，也要再做一次 helper 握手校验，保证“安装成功”和“控制通道已上线”是同一件事。
- 规避：后续只要 helper 文件在、但 launchd system 域查不到 service，就先执行 `launchctl print-disabled system | rg com.sobigrice.iFans.helper`；如果命中 disabled，优先怀疑安装链路没有真正清掉 disabled override，不要继续把它当成单纯“旧版本不兼容”。

## 2026-04-23 选中态图标底色如果继续走 `Material` 会偏灰
- 现象：模式按钮的选中态虽然已经叠了 tint，但底层仍然使用 `thinMaterial` 时，浅色模式下看起来会发灰，做不到真正的纯白底。
- 影响：当设计明确要求“选中图标底色为纯白，暗黑模式为纯黑”时，界面会一直夹着一层材质灰感，和预期不一致。
- 解决：在 `CompactSurfaceBackground` 里把 `.activeSegment` 从材质分支剥离出来，浅色直接填充 `Color.white`，暗色直接填充 `Color.black`，只保留独立描边。
- 规避：后续只要某个选中态卡片或按钮需要纯净实色底，不要继续依赖 `Material + tint` 叠加；应单独走颜色分支并按 `colorScheme` 切换。

## 2026-04-23 改 Bundle Identifier 时不能把 `.xcodeproj` 误建到源码目录里
- 现象：为了改 app 的 `Bundle Identifier`，如果误在 `iFans/Models/` 下面又生成了一份 `iFans.xcodeproj`，再把它引用回主工程，`xcodebuild` 虽然还是走 `iFans` scheme，但 target 的 `SRCROOT` 会漂移到 `.../iFans/Models`。
- 影响：所有依赖仓库根目录的构建脚本都会直接炸掉，比如 `Bundle Helper Installer` 会去找并不存在的 `iFans/Models/script/prepare_helper_bundle.sh`，表现成“改了个包名后突然编译失败”。
- 解决：只保留仓库根目录这一份 `iFans.xcodeproj`，Bundle ID 直接改主 target 的 `PRODUCT_BUNDLE_IDENTIFIER`；不要在源码子目录里再创建第二份同名工程。
- 规避：后续凡是改签名、显示名、Bundle ID，一律先确认当前打开的是仓库根目录工程；如果 `xcodebuild` 日志里的 project path 变成了源码子目录，优先检查是不是误加了嵌套 `.xcodeproj`。

## 2026-04-23 标题栏做成 full-size glass 后，拖拽区不会自动跟着回来
- 现象：主窗口用了 `hiddenTitleBar`、隐藏了 `windowToolbar` 背景，并让 glass shell 延伸进 titlebar 后，窗口虽然视觉上像正常标题栏，但顶部空白区并不会自动恢复成可拖拽区域；只在 SwiftUI 里补 `WindowDragGesture()` 也不一定能覆盖到 AppKit 的 titlebar 背景语义。
- 影响：用户看到的是标准 macOS 窗口形态，却不能像普通窗口一样抓住顶栏移动，属于基础桌面交互回归。
- 解决：窗口层打开 `isMovableByWindowBackground`，再在主窗口顶部补一个避开 traffic lights 的透明 drag region；窗口语义和视图命中区两层都补齐。
- 规避：后续只要窗口内容延伸进 titlebar，就必须把“视觉顶栏”和“实际 drag region”分开检查；不能以为 toolbar 背景隐藏后拖拽能力会自动存在。

## 2026-04-23 透明 shell 不能直接 `allowsHitTesting(false)`，否则空白区会像点穿一样
- 现象：主窗口背景改成透明后，如果最外层 glass shell 只负责视觉、同时又关闭 hit testing，而内部内容并没有铺满整个窗口，用户点击空白区时事件就会漏到底下的应用，看起来像“整个窗口选不中”。
- 影响：窗口不会像正常 macOS 窗口那样先被选中或激活，用户会误以为 app 失焦、不可点，属于基础交互故障。
- 解决：给整块 panel 增加一层不可见但可命中的 backdrop，专门兜住空白区点击；视觉 shell 可以继续只管外观，但命中层不能缺。
- 规避：后续只要窗口或 panel 是透明背景，就要单独检查“空白区域是否还能选中窗口”；不要默认有玻璃外观就等于有命中区域。

## 2026-04-23 `.glassProminent` 在非聚焦窗口里会把主按钮语义做丢
- 现象：footer 主按钮如果直接用系统 `.buttonStyle(.glassProminent)`，窗口失焦后系统会把按钮自动漂成接近白色，原本的蓝色 / 橙色语义会明显丢失。
- 影响：用户一旦切到别的窗口，主操作按钮就和整体 UI 语义脱节，看起来像“禁用态”或默认白按钮，不像同一套 panel。
- 尝试过的方案：主按钮改成自定义的语义玻璃按钮，保留 `glassEffect` 质感，让 inactive 态只轻微降饱和，不让系统把语义 tint 直接抹掉。
- 当前取舍：如果自定义按钮会把聚焦态主按钮的系统观感改坏，就直接回退到系统 `.glassProminent`，接受非聚焦时发白这类系统行为，不再为了修这个点继续改主视觉。
- 规避：后续只要想改主按钮的 inactive 行为，就必须同时对比 active 态真实窗口；不能只修“失焦不发白”，结果把聚焦态主按钮整体做偏。

## 2026-04-23 只把内容玻璃延伸到顶栏还不够，`windowToolbar` 背景不隐藏就会像另一层皮
- 现象：即使主内容的 glass shell 已经 `ignoresSafeArea()` 延伸进标题栏区域，如果 scene 没有同时对 `.windowToolbar` 做 `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)`，窗口顶部仍会挂着系统自己的 toolbar material。
- 影响：用户看到的会是“下面一套玻璃，上面另一套半透明顶栏”，材质断层很明显，整体不像同一个 macOS utility panel。
- 解决：主窗口统一采用“隐藏标题文本 + 隐藏 toolbar 背景 + 保留系统 traffic lights”的组合；内容 glass shell 再负责贴齐窗口顶部，两个层面一起改才会统一。
- 规避：后续凡是要让内容延伸进 titlebar 的窗口，不要只改 view 层 `ignoresSafeArea()`；必须回到 scene 层检查 `windowToolbar` 背景是否也同步隐藏。

## 2026-04-23 透明窗口里不能再 inset 一层同尺寸大圆角 glass shell
- 现象：窗口本身已经是透明 / glass utility window，如果内容区域再通过 `chromeInsets` 额外缩出一层完整的大圆角 shell，视觉上就会变成“外面一个透明窗口，里面再套一个大 dom”。
- 影响：即使内部文字、模式条和按钮都对了，整体仍会显得像两个不同层级的容器硬叠在一起，不自然，也会拖累毛玻璃的整体感。
- 解决：让 glass shell 直接贴齐窗口边界，把玻璃当作窗口本体；内部只保留内容 padding，不再额外造一层接近整窗尺寸的内壳。
- 规避：后续只要窗口已经是透明 utility panel，就不要再用整块 `padding + rounded shell` 去补第二层轮廓；层级应该靠内容分区，而不是再塞一个同尺寸外框。

## 2026-04-23 不能为了做无边框玻璃感把整个 window toolbar 隐掉
- 现象：如果主窗口直接对 `.windowToolbar` 做 `.toolbarVisibility(.hidden, for: .windowToolbar)`，左上角 macOS 标准 traffic lights 会一起消失，看起来像“毛玻璃窗口”，实际却把最基本的桌面窗口交互砍掉了。
- 影响：用户无法通过系统级关闭、最小化、缩放按钮操作窗口；同时也会让后续所有视觉验收都建立在错误的窗口 chrome 前提上。
- 解决：保留系统 titlebar / toolbar 可见性，只移除多余标题文本；窗口透明、玻璃和拖拽区域的处理都建立在系统 chrome 仍存在的前提上。
- 规避：后续做 macOS utility window 时，不要把“隐藏标题”和“隐藏整个 toolbar”混为一谈；先保住系统窗口按钮，再调玻璃和内容布局。

## 2026-04-23 内层 section 背板一旦回潮，马上又会出现套壳和边距失衡
- 现象：即使外层 shell 已经改成单层 glass，只要 header、状态区、风扇区、footer 又重新各自包一层 `CompactSurfaceBackground`，画面马上回到“里面再套几块白壳”的状态，而且每块自己的内边距不同，边线看起来会乱。
- 影响：玻璃会继续发白，层级会变重，用户看到的不是轻量 utility panel，而是一块大壳里再塞四五块小壳。
- 解决：主窗口和菜单栏 panel 统一回到“单一 shell + 内容分区 + 少量局部承载面”的结构，只保留模式条、温度 badge、选中态这类真正需要承载或强调的小面积 surface。
- 规避：后续只要视觉开始出现“这里也糊一点背景、那里也补一块卡片”的趋势，就先停下来检查是不是又在用局部白板补可读性，而不是通过统一的间距、字重和层级解决问题。

## 2026-04-23 外层玻璃 + 内层高不透明白卡的回退方案会把 Liquid Glass 做废
- 现象：外层 panel shell 虽然保留了 `glassEffect`，但如果 header、模式区、指标卡、风扇区和 footer 又全部回退成高不透明白卡、厚描边和额外阴影，最终就会变成“灰玻璃外壳 + 一堆白板卡片”，既没有真实透明感，也不像系统级毛玻璃。
- 影响：视觉上会同时失去两件事：一是玻璃的轻盈和通透，二是层级节奏。用户看到的是“功能都堆出来了”，不是一个产品化的 macOS utility panel。
- 解决：外层只保留一层统一 shell glass；内层信息承载面改成更少、更轻的半透明 material surface；模式切换区收成真正的横向 segmented bar，不再继续堆四张独立大卡片。
- 规避：后续做 Liquid Glass 时，不要用“先做玻璃，再怕看不清就往里塞白卡”的拆东墙补西墙式修补；先定义 shell、surface、foreground 三层职责，再逐层验证。

## 2026-04-23 UI tests 通过不代表毛玻璃观感已经正确
- 现象：`panel.compact.window`、`summary.current-mode`、`status.current` 等 accessibility 锚点和现有 UI tests 都可以稳定通过，但真实窗口依然可能出现“透明感没了”“四根白柱”“文字存在但视觉层级很糟”的问题。
- 影响：如果只看 `xcodebuild test` 结果，很容易误判成这次 UI 重构已经完成，最后把明显不对的视觉方案继续带到后续开发里。
- 解决：涉及玻璃、透明、振彩前景的改动，必须补一次当前构建产物的真实运行截图或同等级视觉证据；`xcodebuild test` 只继续承担功能锚点验证，不再替代视觉验收。
- 规避：后续凡是改主窗口材质、菜单栏 panel 或紧凑模式条，都先跑自动化，再看真机窗口；两个都通过才算结束。

## 2026-04-23 主窗口信息卡片不能继续直接使用 `Color.clear.glassEffect(...)`
- 现象：即使已经避免把整块 utility panel 套成一整张玻璃壳，只要 header、模式条、指标卡和 footer 这些真正承载文字的区域继续直接用 `Color.clear.glassEffect(...)`，在桌面壁纸或复杂背景上仍会发灰发糊，accessibility tree 是完整的，但肉眼可读性明显下降。
- 影响：功能链路和 UI tests 都可能通过，但用户看到的主窗口仍像“内容被毛玻璃吞掉”，属于真实产品可用性问题，不是单纯审美偏好。
- 解决：主窗口外层只保留一层统一 panel shell 的 glass 质感，内部信息卡统一切回高对比 surface；温度 badge 和选中态按钮只叠轻量 tint，不再让正文直接贴在 clear glass 上。
- 规避：后续做毛玻璃时，先区分“外层 chrome”与“内容承载面”；内容层默认先保证对比度和字重清晰，再决定要不要加玻璃采样效果。

## 2026-04-21 Xcode 脚本沙盒不能直接删 HelperInstaller 输出目录
- 现象：`Bundle Helper Installer` build phase 如果先 `rm -rf "${TARGET_BUILD_DIR}/.../HelperInstaller"`，`xcodebuild test` 会在脚本阶段直接报 `Sandbox: rm deny file-write-unlink`，测试甚至还没开始就被取消。
- 影响：会把“测试失败”误判成产品或 UI 回归，实际根因只是构建脚本违反了 Xcode 对声明输出路径的脚本沙盒约束。
- 解决：helper bundle 构建统一走 `script/prepare_helper_bundle.sh`，只 `mkdir -p` 并覆盖声明过的输出文件，不再整目录删除 `HelperInstaller`。
- 规避：后续凡是 Xcode build phase 生成 bundle 内资源，都不要先删整个已声明输出目录；优先覆写具体输出文件，避免再次触发脚本沙盒拦截。

## 2026-04-23 `MenuBarExtra(.window)` 的 label 上直接挂 `contextMenu` 不会变成状态栏右键菜单
- 现象：把“设置 / 退出”直接写在 `MenuBarExtra` label 的 `.contextMenu` 上后，左键面板仍然正常，但用户对菜单栏风扇图标右键没有任何反应。
- 影响：看起来代码里已经有右键菜单，实际状态栏图标没有 secondary click 能力，功能属于假完成。
- 解决：保留左键 `MenuBarExtra(.window)` 面板不动，改用最小 AppKit 桥接监听右键事件；通过 `AXExtrasMenuBar` 实时读取当前状态栏图标 frame，命中时弹出原生 `NSMenu`。
- 规避：后续只要需求是“菜单栏图标右键菜单”，不要默认 SwiftUI view 层的 `.contextMenu` 会自动映射到 `NSStatusItem`；先在真实菜单栏上验证 secondary click，再决定是否需要 AppKit 补桥。

## 2026-04-21 退出恢复系统自动模式不能只做临时 restore，必须同步清掉持久化手动模式
- 现象：如果退出 app 时只是临时把风扇交回系统，但保留 `selectedFanMode = balanced/performance`，那么下次启动又会自动重新 apply 手动档，看起来像“退出恢复失效”。
- 影响：用户会误以为 app 退出后系统已经接管风扇，实际下一次启动却又被旧的持久化手动模式抢回控制，行为不确定。
- 解决：退出协调统一等待一次 `restoreAutomatic()`，并在同一流程里把当前模式和持久化模式都写回 `systemAuto`；即使超时放行退出，也不能保留旧手动模式。
- 规避：后续凡是“退出时恢复默认状态”的能力，都不要只恢复运行态，不处理持久化偏好；运行态和下次启动语义必须一致。

## 2026-04-21 app 内安装 helper 不能依赖工程目录或测试环境变量
- 现象：如果 app 只是去找仓库根目录下的 `./script/install_helper.sh`，那么从 Finder、`open` 或正常安装位置启动时，经常既没有正确的工作目录，也没有开发期注入的环境变量，结果按钮虽然存在，但真实用户环境里找不到安装器。
- 影响：开发测试里“能点通”，并不代表用户机器上的 app 内安装真的可用；这类问题很容易被误判成已经产品化。
- 解决：把当前源码生成的 helper 二进制、launchd plist 和自包含 installer 一起打进 app bundle，让面板按钮默认走 bundle payload，而不是依赖工程目录。
- 规避：后续凡是 app 内自修复 / 自安装链路，都不要把仓库路径、当前工作目录或临时环境变量当成正式产品依赖。

## 2026-04-21 正常信息不能再被统一映射成“异常”状态
- 现象：用户主动点回 `系统自动` 后，底层已经成功恢复系统热管理，但面板里的“控制状态”仍显示 `异常`，只是因为 `statusMessage` 里还留着一条成功提示。
- 影响：实际功能已经恢复，界面却继续传达故障感，用户会误以为 helper 或控制链路还有问题。
- 解决：把“用户主动恢复系统自动”这种正常提示从错误状态里剥离；成功提示可以继续显示在 header / footer，但不能再驱动控制卡片进入异常态。
- 规避：后续不要把所有 `statusMessage` 都当成错误源；状态语义至少要区分“成功提示 / 处理中 / 真错误”。

## 2026-04-21 app 内安装 helper 不能在主线程里做深层路径搜索
- 现象：点击“安装 helper / 重装 helper”后，界面没有弹出管理员授权，反而主窗口直接卡住；采样会看到主线程停在安装脚本定位逻辑里。
- 影响：用户会误以为按钮没反应或 app 崩了，真实安装链路根本到不了 `osascript` / 系统授权这一步。
- 解决：安装脚本定位和执行都必须放到后台线程，并把候选路径收敛成固定、可预测的集合（环境变量、当前工作目录、bundle resources / shared support），不能再做整棵祖先目录回溯。
- 规避：后续凡是 UI 按钮触发系统脚本、磁盘扫描或外部工具调用，都不要在主线程先做“聪明搜索”；先限定候选范围，再把解析和执行一起移到后台。

## 2026-04-21 特权 helper 不能只靠 shell 文案提示安装
- 现象：app 已经明确因为 helper 缺失或版本不匹配而退回监控模式，但界面里只有一段 `./script/install_helper.sh` 提示，没有可直接点的修复入口。
- 影响：用户知道“现在不能控”，却没法在产品里直接完成修复，体验会退化成开发者工具；真实环境里很容易停在“看得见状态、但就是不能用”。
- 解决：在现有面板 footer 和 Settings 诊断区提供上下文感知的“安装 helper / 重装 helper”按钮；点击后由 app 请求管理员授权，并调用同一条 canonical 安装链路。
- 规避：后续凡是核心能力依赖系统级组件，都不能只留 shell 命令说明；必须在现有 UI 里提供直达修复入口，并明确“不安装就只能监控，不能控制”。

## 2026-04-21 特权 helper 的 Objective-C XPC 方法签名一旦变更，旧 helper 会直接变成“看得见但连不上”
- 现象：系统里的 `/Library/PrivilegedHelperTools/com.sobigrice.iFans.helper` 明明还在运行，但主 app 启动后仍退回只读监控模式；日志里会出现 `incompatible reply block signature for handle:withReply:`，随后 direct probe 又会落到 `0xe00002c1 privilege violation`。
- 影响：自动化构建、单元测试、UI 测试都可能通过，但真实机器上的风扇控制会彻底失效，用户只能看到“helper 不可用”或长期停留在监控模式。
- 解决：冻结 Objective-C XPC 表面为稳定的 `NSData -> NSData` 单方法，不再通过方法签名扩展协议；后续版本兼容统一放进 JSON payload（`wireVersion` / `clientBuild` / `helperBuild` / `failureCode`）里处理。只要 helper 或 wire 协议有变更，就必须重新执行 `./script/install_helper.sh` 重装当前 helper。
- 规避：后续改 helper 通信时，不要再碰 Objective-C selector / reply block 形状；先保持 XPC 方法签名不动，再通过 `./build/helper/helper_smoke_test handshake` 和 `provider-discover` 验证当前源码与系统 helper 仍可通信。

## 2026-04-18 不能把整块小窗内容直接挂在大面积 `glassEffect` 外壳上
- 现象：把整个紧凑 utility panel 包进一个大 `glassEffect` 壳后，可访问树里明明有完整文字、图标和按钮，但视觉上会变成一整块发灰发糊的毛玻璃，文字像被雾化，用户几乎无法读。
- 影响：功能和测试都可能是好的，但真实 UI 观感会退化成“有内容但看不清”，产品层面仍然不可用。
- 解决：主窗只保留一层外部 material / glass 质感，真正承载信息的 header、模式条、监控行和底部状态区改用更高对比的独立 surface，不再让大面积 `glassEffect` 直接吃掉整个内容层。
- 规避：后续做超小浮窗时，不要把 `glassEffect` 当成“大背景万能解”；必须先做窗口级截图或真机肉眼验收，确认文字和图标不是只存在于 accessibility tree 里。

## 2026-04-18 不要混用仓库内旧 `build/` 产物和 Xcode 当前 `DerivedData` 产物
- 现象：手动 `open build/Build/Products/Debug/iFans.app` 时，可能启动的是仓库里遗留的旧 app 包；而 `xcodebuild` / Xcode Run 实际生成的新包在 `~/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug/iFans.app`。结果就是源码已经改了，屏幕上跑起来的却还是旧界面。
- 影响：会误判成“源码和运行结果不一致”或“编译缓存坏了”，把排查方向完全带偏。
- 解决：调试当前改动时，只启动本次构建对应的 `DerivedData` 产物，或统一收敛到单一 `build_and_run` 脚本，不再手开仓库里历史 `build/` 目录下的旧 app。
- 规避：后续凡是要做 UI 验收、日志复现或截图回归，先确认启动路径是不是当前构建产物；不要默认仓库里的 `build/Build/Products` 就是最新 app。

## 2026-04-18 正常运行时不能再把自己的 bundle identifier 当成默认 `UserDefaults` suite
- 现象：主 app 正常运行时如果用 `UserDefaults(suiteName: bundleIdentifier)` 作为默认偏好容器，控制台会报“Using your own bundle identifier as an NSUserDefaults suite name does not make sense and will not work”。
- 影响：不仅日志有噪音，持久化行为也会变得不可靠，后续模式恢复和调试都会被污染。
- 解决：正常运行统一走 `UserDefaults.standard`；只有 UI test 需要隔离状态时，才使用单独的测试 suite，并在启动前清空它。
- 规避：后续除非明确需要 App Group 或测试隔离，不要为了“看起来更独立”就额外创建 suite；默认偏好存储直接用 `.standard`。

## 2026-04-18 XPC reply 不能把 `NSError` 这类宽泛对象直接塞进协议里
- 现象：如果 helper 的 XPC 回调签名里包含 `NSError?` 这类 Objective-C 对象，运行时会触发 `NSXPCDecoder validateAllowedClass` / `NSSecureCoding allowed classes list contains [NSObject class]` 这类安全解码警告。
- 影响：控制台会持续报错噪音，而且这个检查未来会进一步收紧，存在变成硬错误的风险。
- 解决：主 app 和 helper 之间统一只传 `NSData` 形式的编码结果，由两端自己 decode 成明确的 Swift `Codable` 结构，不在 XPC 协议层暴露宽泛对象类型。
- 规避：后续只要改 XPC 协议，优先用明确的数据载体；如果 helper 二进制更新了，还要同步重装系统里的 helper，避免旧协议继续运行。

## 2026-04-18 不能只抄 glass 形状，不给语义文字和单位
- 现象：如果只把界面做成一堆半透明玻璃块，却没有把模式名、状态文案、温度单位、风扇转速这些语义信息明确摆出来，界面看上去像占位骨架，用户无法判断当前状态，也不知道该怎么操作。
- 影响：即使底层风扇控制和读取逻辑都正常，产品层也会表现成“功能还在，但完全不可用”，达不到上线标准。
- 解决：主窗口必须从信息层级出发设计，而不是从参考布局出发；每个交互控件和每个关键指标都必须有可见的文字、图标或单位，先保证可读，再加 glass 质感。
- 规避：后续再做毛玻璃/苹果风界面时，只借材质和密度，不直接照抄系统布局；任何没有语义承载的玻璃块都不应该进入最终 UI。

## 2026-04-18 纯装饰的 SwiftUI glass 容器不能直接当 UI test 锚点
- 现象：把 `accessibilityIdentifier` 直接挂在 `GlassEffectContainer` 或纯视觉包装视图上时，运行时不一定会生成独立的可访问元素；UI 看起来正常，但 `XCTest` 会找不到 `panel.compact.window` / `panel.compact.menu`。
- 影响：每次重构紧凑面板样式，smoke test 都可能因为“锚点消失”而误报失败，排查成本很高。
- 解决：对 panel 级锚点使用一个显式的隐藏 accessibility element 承载 identifier，而不是依赖装饰容器本身出现在可访问树里。
- 规避：后续新增 UI test 定位点时，不要把纯背景、纯 glass、纯 overlay 容器直接当锚点；必须确认它在可访问树里是稳定存在的元素。

## 2026-04-18 紧凑小窗隐藏标题后，必须显式保留可拖拽热区
- 现象：把主窗口改成类似控制中心的小面板并隐藏标题文字后，视觉上更干净，但如果没有补上明确的拖拽区域，用户会发现窗口只能抓系统按钮附近，或者看起来几乎拖不动。
- 影响：界面会出现“像原生浮层，但交互不如原生”的断层感；后续只要继续压缩窗口尺寸，这个问题会更明显。
- 解决：保留系统红黄绿按钮，同时在顶部状态头区域显式提供 `WindowDragGesture()` 热区，并允许点击激活后直接拖动窗口。
- 规避：后续凡是做隐藏标题的小窗、浮层或 glass utility panel，都不要只顾视觉收窄；必须同步验证拖拽路径是否仍然自然。

## 2026-04-18 启动首轮探测拿到“只读”时，不能直接放弃已保存的手动模式
- 现象：app 冷启动时，如果 helper / XPC 控制链恰好还在建立中，第一次 `discover()` 可能先返回只读；此时应用会跳过已保存的 `balanced` / `performance` 模式，最终进程已经起来了，但风扇仍停在系统自动。
- 影响：用户会体感成“启动很慢，而且保存过的模式根本没有生效”；即使几百毫秒后 helper 已经可用，app 也不会自动补做这次 apply。
- 解决：只在“已保存的是手动模式但当前还不可控”的场景下，加一个很短的受限重试窗口；一旦控制通道恢复，就立即补应用已保存模式。
- 规避：后续凡是依赖外部 helper / XPC 的启动控制链，不要把第一次不可控结果当成最终状态；已保存的关键控制动作必须允许短时恢复重试。

## 2026-04-18 有 helper 时不能先让主 app 的 direct probe 抢占控制通道
- 现象：主 app 对 `F%dMd` / `Ftst` 的探测有时会通过，于是界面显示“已验证风扇控制通道”；但真正写 `F%dTg` 目标转速时，内核仍可能返回 `0xe00002c1 privilege violation`，导致模式切换失败。
- 影响：helper 明明已经安装且能稳定控制，应用却因为先选了 `主进程直连 AppleSMC`，表现成“有时能切、有时根本不能用”的假打通。
- 解决：控制通道选择改成“先 probe 特权 helper，helper 可用就固定走 helper；只有 helper 明确不可达时才回退尝试 direct”。
- 规避：后续凡是存在 privileged helper 的控制链路，不要让低权限进程先用不完整的 direct probe 抢占通道；优先选择权限更稳定、验证更完整的路径。

## 2026-04-18 控制通道探测不能在启动和每次切模式时重复全量跑
- 现象：启动时 `discover()` 先 probe 一遍 helper，切模式时 `apply()` 又重新 probe 一遍同一批风扇；如果还要恢复自动或刷新诊断，整条链路会被无意义的重复验证拉长。
- 影响：冷启动应用已保存的模式会明显变慢，手动切换档位的体感也会拖沓，即使底层写入本身已经成功。
- 解决：一旦某条控制通道已经验证通过，就直接复用；只有写入失败或 helper 明确不可达时，才重新解析控制通道。
- 规避：后续凡是“先 discover 再 apply”的硬件控制链，不要把探测函数设计成每一步都强制重跑；验证结果必须缓存并带失效条件。

## 2026-04-18 不能再用 `defaults` CLI 代替 app 自己的模式持久化路径
- 现象：Shell 里执行 `defaults write/read com.sobigrice.iFans selectedFanMode balanced` 看起来成功，但 app 冷启动时仍可能读到 `systemAuto`；而改用 app 同样的 `UserDefaults(suiteName: "com.sobigrice.iFans")` 写入后，启动即可正确应用 `balanced`。
- 影响：如果把 `defaults` CLI 当成启动回归的唯一代理，会误判成“app 没有读取持久化模式”，从而把排查方向带偏。
- 解决：启动回归测试改成使用与 app 一致的 suite API 写入模式，或直接通过 app 自己的 `setMode` 流程落盘；同时 `loadInitialState()` 在真正开始硬件探测前再重读一次持久化模式。
- 规避：后续凡是验证 app 内部偏好读写，不要默认 `defaults` CLI 和 app 运行时看到的是同一份状态；关键启动项必须走与 app 相同的 API 或代码路径验证。

## 2026-04-18 helper 探测失败不能一律显示成“helper 不可用”
- 现象：特权 helper 实际已经在线，但如果 probe 被 helper 拒绝，应用层仍然统一显示“当前没有可用的 iFans 特权控制助手”。
- 影响：真实的写入验证失败、协议不兼容或 helper 返回异常都会被伪装成“没装 helper”，用户和开发都会被错误提示带偏。
- 解决：helper 探测失败时区分“helper 不可达”和“helper 已连接但拒绝请求”两类错误；前者才显示不可用，后者保留真实错误原因，并继续在诊断里标记当前走的是 helper 通道。
- 规避：后续只要是多段控制链路，不要把不同阶段的错误压扁成同一条提示；UI 必须保留最接近故障点的原始原因。

## 2026-04-18 AppleSMC 写入不能只看 IOKit 返回值，必须检查 SMC 固件结果码
- 现象：`IOConnectCallStructMethod` 可能返回成功，但 `AppleSMC` 的 `output.result` 仍然是非零；如果只看 IOKit 返回值，会把固件拒绝写入误判成写入成功。
- 影响：写权限探测、helper 探测和模式切换都会出现“看起来成功、实际没写进去”的假阳性。
- 解决：C 桥接层在写入后必须继续检查 `output.result`，非零时统一按失败处理，并把错误继续上抛到 Swift 层。
- 规避：后续凡是 AppleSMC 写路径，都不能只包一层 `IOConnectCallStructMethod` 就结束；必须同时校验 SMC 固件返回码。

## 2026-04-18 Apple Silicon 风扇控制不能假设所有机型都走同一条 key 路径
- 现象：不同代际的 Apple Silicon 机型会出现 `F%dMd` / `F%dmd` 大小写差异，而且有的机型需要先写 `Ftst` 解锁，有的机型根本没有 `Ftst`，只能直接写 mode key。
- 影响：如果代码把风扇控制路径写死成单一 key 组合，就会在某些机型上持续写入失败，helper 即使有 root 权限也无法稳定控制。
- 解决：先动态探测实际存在的 mode key，再按“直接写 mode -> 失败后尝试 `Ftst` 解锁 -> 重试 mode”的顺序兼容两条 Apple Silicon 控制链路。
- 规避：后续新增硬件适配时，不要把单台机器上跑通的 key 路径当成通用方案；必须先做 key 存在性探测，再决定写入顺序。

## 2026-04-18 风扇 mode/target 写入不能只做单次写入后立刻判失败
- 现象：在这台双风扇 Apple Silicon 机器上，`F1Md` 和 `F1Tg` 都存在，但单次写入后立刻读回，经常还是旧值；继续按同样值重试并读回确认后，目标值可以稳定落到预期。
- 影响：如果 helper 只做“一次 write 成功 + 一次 verify”，就会把本来能成功的第二个风扇误判成不可控，并在应用层触发错误回滚。
- 解决：对 `mode` 和 `target` 都改成“写入 + 读回确认 + 重试”，并把 helper 通道探测从“只测第一个风扇”改成“所有可控风扇都要通过”。
- 规避：后续只要是 AppleSMC 控制路径，都不要把“单次写返回成功”当成真实成功；必须等待硬件状态读回到预期值。

## 2026-04-17 不能把“能读到风扇 key”误判成“能控制风扇”
- 现象：`F0Md/F0Tg` 之类的 key 可以读出来，界面也显示“可控制”，但真正写入时 `AppleSMC` 统一返回 `0xe00002c1`，风扇不会响应。
- 影响：用户会看到模式切换成功，但实际仍然是系统自动控制，属于核心功能假打通。
- 解决：控制能力判定必须做真实写权限探测；当前主 app 没有特权时，只能判定为监控模式，并切换到特权 helper 架构承接写入。
- 规避：后续只要是 SMC/内核接口，不要把“读得到 key”当成“写得进去”；能力声明必须基于真实控制通道验证。

## 2026-04-17 风扇写入验证不能只看 `mode == 1` 或“目标值接近”
- 现象：原来的验证逻辑只要 `F0Md == 1`，或 `F0Tg` 与预设目标差值不大就判成功；但系统自动模式下的目标值本来就可能接近预设值，导致写入失败也被误判成功。
- 影响：尤其是较保守的预设档位，会出现“UI 显示成功、风扇实际没切过去”的假阳性。
- 解决：把验证收紧到“目标值必须贴近预期，且如果 mode key 存在则必须处于手动”。
- 规避：后续任何底层控制验证都要避免只靠单一弱信号；必须组合目标状态和控制状态一起判定。

## 2026-04-17 `IOHIDEventSystemClientCreateSimpleClient` 只能看到服务，读不到温度事件
- 现象：使用 `IOHIDEventSystemClientCreateSimpleClient` 后，`IOHIDServiceClientCopyEvent(..., 15, ...)` 持续返回 `nil`。
- 影响：Apple Silicon 温度传感器无法拿到实时数值，界面会只剩空的传感器列表。
- 解决：改为使用 `IOHIDEventSystemClientCreate` 并配合 `IOHIDEventSystemClientSetMatching` 设置 `PrimaryUsagePage = 65280`、`PrimaryUsage = 5`。
- 规避：后续如果再重构温度读取层，不要把 `Create` 替回 `CreateSimpleClient`。

## 2026-04-17 Apple Silicon 风扇当前转速允许为 `0 RPM`
- 现象：`AppleSMC` 的 `F0Ac/F1Ac` 在空闲状态下可能返回 `0`，而不是传统 Intel 机型的常驻低转速。
- 影响：如果把 `0` 当成读取失败，会错误触发“不支持风扇”或“读取失败”的告警。
- 解决：将 `0 RPM` 视为合法值，只在 SMC 调用失败时判定为读取错误。
- 规避：后续任何与风扇当前值相关的校验都不能简单写成 `rpm <= 0` 即失败。

## 2026-04-17 Liquid Glass 组件必须在统一容器内组织
- 现象：多个卡片或按钮分别独立加 `glassEffect` 时，视觉采样区域不一致，边缘会显得割裂。
- 影响：菜单栏面板和仪表盘的玻璃质感不统一，尤其在动态背景上更明显。
- 解决：对一组相邻的玻璃组件使用 `GlassEffectContainer`，并统一圆角与间距。
- 规避：后续新增玻璃化组件时，优先放进现有容器，不要各自孤立叠效果。

## 2026-04-17 `.buttonStyle(.glass)` 在当前 macOS 26 SDK 上不稳定
- 现象：直接使用 `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` 编译时会报错，当前工程 SDK 并没有稳定暴露这两个枚举样式。
- 影响：如果照着示例代码硬套，会卡在编译阶段，导致整个 Liquid Glass 方案无法落地。
- 解决：保留原生 `glassEffect`，但按钮层改为自定义 `LiquidGlassButtonStyle`，通过 `RoundedRectangle + glassEffect` 组合实现等价视觉。
- 规避：后续升级 SDK 前，不要假设所有 WWDC 示例 API 都已经在本机 SDK 中可直接调用；先以最小示例编译验证。

## 2026-04-17 Swift 6 默认 `MainActor` 隔离会误伤底层硬件桥接代码
- 现象：工程开启默认主线程隔离后，`IOKit` 私有符号封装、`SMCBridge` 的纯工具方法和常量会被推断成主线程隔离，产生大量并发告警。
- 影响：即使功能能跑，编译输出也会被噪音告警淹没，后续真正的并发问题更难识别。
- 解决：对底层无 UI 语义的辅助常量、解码属性、桥接方法显式标记 `nonisolated`，并把硬件访问收敛到 `actor` 内部。
- 规避：后续新增 `IOKit` / `SMC` 访问代码时，默认先判断它是不是纯工具逻辑；如果不是 UI 状态，就不要让它继承主线程隔离。

## 2026-04-17 Swift struct ABI 与 AppleSMC 的 C ABI 不一致会误判“无风扇”
- 现象：Swift 自定义的 `SMCKeyData` 实际内存布局是 `76` 字节，而 AppleSMC 期望的 C 结构体是 `80` 字节；`IOConnectCallStructMethod` 会直接返回 `0xe00002c2`。
- 影响：即使 MacBook Pro 本身有风扇，应用也会把 AppleSMC 读失败误判成“当前设备没有可发现的内建风扇”。
- 解决：把 AppleSMC 底层桥接改成最小 C 文件，沿用已验证可读的 `80` 字节 ABI；Swift 只负责包装返回值和能力状态。
- 规避：后续只要接 AppleSMC 这类内核接口，不要默认 Swift struct 能和 C ABI 完全对齐；先做 `sizeof/MemoryLayout` 的对照验证。

## 2026-04-17 侧载版误开 App Sandbox 会让 AppleSMC 完全不可用
- 现象：主 app target 打开 `ENABLE_APP_SANDBOX = YES` 后，即使机器本身有风扇，`AppleSMC` 的访问也会被当前分发形态挡住；界面会退化成“风扇读取接口不可用”。
- 影响：用户会误以为是缺少系统权限，实际上这不是 TCC 弹窗问题，而是构建/签名模式错误。
- 解决：个人侧载版关闭 `ENABLE_APP_SANDBOX`，保留 `Hardened Runtime`；运行时额外读取自身 entitlement，若检测到沙盒则直接显示“当前构建启用了 App Sandbox，AppleSMC 不可用”。
- 规避：后续只要还是“主 app 直连 AppleSMC”的侧载方案，就不要重新开启 `ENABLE_APP_SANDBOX`。如果未来要恢复沙盒或上架，必须改成 `SMJobBless + privileged XPC helper` 架构。
