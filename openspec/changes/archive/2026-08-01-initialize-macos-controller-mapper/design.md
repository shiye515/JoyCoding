## Context

JoyCoding 当前是一个只有 `WindowGroup` 和默认 `ContentView` 的 SwiftUI macOS 工程。首阶段需要同时建立应用生命周期、菜单栏入口、手柄设备/输入状态和首次权限引导，这些状态会跨多个视图共享；后续真正发送键盘事件时也会继续复用这套基础。

参考项目证明了以下做法在 macOS 上可行：通过 `GCControllerDidConnect`/`GCControllerDidDisconnect` 和 `GCController.controllers()` 同时覆盖启动前已连接与运行时热插拔，通过 `pressedChangedHandler` 驱动实时按键状态，以及按步骤、由用户操作触发 TCC 授权并轮询授权结果。本设计仅吸收这些边界清晰的模式，不引入参考项目的原始 HID、多设备路由、映射引擎或后台更新等复杂能力。

约束如下：

- 使用现有 SwiftUI App 生命周期和系统框架，不增加第三方依赖。
- UI 状态更新必须在主 actor 上完成，GameController 回调不能让已释放的控制器或服务被强引用。
- 普通 `GameController` 输入本身不依赖输入监控权限；输入监控用于后续扩展原始 HID/特殊按键，辅助功能用于后续发送键盘事件。引导必须准确解释这一差异。
- 系统权限提示只能由明确的用户操作触发，不能在启动时同时弹出多个系统对话框。

## Goals / Non-Goals

**Goals:**

- 建立关闭主窗口后仍常驻的菜单栏 macOS 应用外壳，并能可靠打开或聚焦唯一主窗口。
- 展示所有由 `GameController` 发现的已连接设备，维持合理且确定的当前选中设备。
- 使用经典左右双栏展示选中设备的可用按钮，并以低延迟反映按下和松开状态。
- 支持选择当前设备中的一个按键，并在右栏展示其名称作为映射目标占位。
- 在首次启动时用可恢复、可跳过的向导说明并请求输入监控和辅助功能权限。
- 让设备选择、按键状态归约和引导状态机可单元测试。

**Non-Goals:**

- 配置、持久化或执行“手柄按键 → 键盘按键”映射；本阶段仅展示映射设置占位。
- 支持 `IOHIDManager` 原始 HID、Xbox Guide 特殊通道、厂商扩展按键、震动、灯光或电量。
- 后台启动、登录项、自动更新、遥测、许可、配置导入导出和多语言本地化。
- 为每种手柄绘制定制图形；本阶段使用统一的设备与按钮列表。

## Decisions

### 1. 使用单一 Window scene 与 MenuBarExtra

应用入口改为带稳定 id 的 `Window` scene，并增加 `MenuBarExtra`。菜单栏面板提供“打开 JoyCoding”和“退出”操作；打开操作通过 SwiftUI `openWindow(id:)` 创建或重新激活主窗口，并调用 `NSApp.activate` 将其带到前台。`NSApplicationDelegate` 返回“不在最后窗口关闭后退出”，确保菜单栏常驻。

选择这一方案是因为它保留 SwiftUI 的 scene 生命周期和可测试视图结构，同时比手工管理 `NSWindowController` 更少状态。直接用 `NSStatusItem` 可以做到单击立即打开窗口，但需要额外桥接 scene 创建；本阶段采用原生 `MenuBarExtra` 的一次点击展开入口，再由明确菜单操作打开窗口。

### 2. 用一个 MainActor ControllerService 作为设备状态唯一来源

新增 `@MainActor`、`ObservableObject` 的 `ControllerService`，负责：启动时读取 `GCController.controllers()`；订阅连接/断开通知；为每台设备安装输入处理器；发布轻量的 `ControllerDevice` 展示模型、`selectedDeviceID` 和按设备区分的按下按钮集合。

视图不直接持有 `GCController`，避免框架对象进入 SwiftUI identity 与持久状态。服务内部以连接期间稳定的 `ObjectIdentifier` 关联框架对象和展示模型；断开时清除回调及状态。相比让每个列表项自己订阅通知，集中式服务可保证选择规则和事件清理只有一份实现。

### 3. 以规范化按钮标识隔离 GameController 差异

定义 `ControllerButton` 值类型，包含稳定 id、展示名称和排序序号。优先从 `GCExtendedGamepad` 绑定 A/B/X/Y、肩键、扳机、方向键、Menu/Options/Home 和摇杆按压；若没有 extended profile，则从 `physicalInputProfile` 的按钮集合生成回退条目。扳机按 `pressedChangedHandler` 的布尔值处理，本阶段不展示模拟量。

服务在安装 handler 时同时生成该设备实际可展示的按钮集合；事件回调只改变对应设备的 pressed set。这样 UI 不需要理解 Xbox/PlayStation 命名差异，后续映射模型也可以复用稳定标识。首版不把摇杆轴方向伪装成按钮，避免阈值和回滞策略过早进入范围。

### 4. 使用确定性的设备选择归约规则与独立的按键选择状态

首次发现设备时自动选中列表首项；用户选择后保持该选择；非选中设备断开不改变选择；选中设备断开时选择剩余列表首项；没有设备时选择为空。设备选择使用左栏顶部的 `Picker`/下拉控件。

新增 `selectedButtonID`，它仅在当前选中设备的按钮集合内有效：设备切换时自动选择该设备首个按钮；用户选择其他按钮时更新；按钮所属设备断开或该按钮不再可用时清空或回退到首项。此状态与按下状态完全分离，因此按住某键只改变高亮，不会抢占用户正在配置的按键。

这些规则封装为无框架依赖的纯函数/模型测试，避免连接通知到达顺序造成 UI 选择漂移。

### 5. 权限采用显式状态机与按需系统请求

新增 `PermissionsManager`，用三态值表示输入监控与辅助功能权限。辅助功能通过 `AXIsProcessTrusted` 查询并通过 `AXIsProcessTrustedWithOptions` 请求；输入监控通过 `IOHIDCheckAccess` 查询并由 `IOHIDRequestAccess` 请求。打开引导时以约 1 秒周期刷新，关闭后停止轮询。

首次启动标记使用 `@AppStorage`/`UserDefaults` 持久化。未完成时在主窗口显示不可重复叠加的 sheet；步骤依次为欢迎、输入监控、辅助功能、完成。每个系统请求都必须由对应按钮触发，并提供打开系统设置的入口。用户可暂时跳过，不阻塞本阶段的标准手柄检测；完成或跳过后记录已展示。菜单栏面板提供“权限设置…”以再次打开向导。

不申请蓝牙权限，因为本阶段不直接使用 CoreBluetooth，蓝牙手柄由 GameController 框架提供；添加不需要的权限会降低信任并产生误导。

### 6. 左右双栏界面与映射占位

主窗口使用 `NavigationSplitView` 或等价的 `HSplitView` 实现可调整的经典双栏。左栏顶部为带设备显示名称的下拉选择控件，下面为纵向 `List`；每行同时显示按键名称、实时按下/松开状态，并有持久的选择样式。右栏在未选中设备或按键时显示空状态；选中按键时显示其名称和“映射到”字段，字段值固定使用当前按键名称作为不可执行的占位值。

选择 `NavigationSplitView` 是因为它提供原生的 macOS 栏宽、列表选择和键盘辅助功能表现；相比手工 HStack 拼接，它更容易随窗口大小保持左右区域清晰。映射占位不写入领域模型，以免把未来映射格式过早固化。

### 7. 测试逻辑边界，硬件路径保留手动验收

为设备选择归约、按钮 pressed set 更新、断开清理、首次启动标记和权限向导步骤流添加单元测试。`GCController` 难以稳定构造，服务通过小型输入适配协议或可注入事件源隔离框架，以便测试模型逻辑。真实蓝牙/USB 连接、菜单栏交互和系统 TCC 跳转使用手动验收清单验证。

## Risks / Trade-offs

- [不同厂商对 `GameController` 元素暴露不一致] → 优先支持标准 extended profile，并用 physical profile 回退；未知元素以系统名称展示，后续再补设备专用适配。
- [连接/断开通知与启动快照重复或乱序] → 按 `ObjectIdentifier` 去重，断开前校验当前注册表，并让更新操作幂等。
- [闭包导致服务或控制器生命周期泄漏] → handler 使用弱引用；断开与服务销毁时显式置空所有已安装 handler。
- [快速按下/松开造成主线程更新频繁] → 仅在集合成员实际改变时发布状态；按钮事件保持常数时间更新，不做日志洪泛。
- [TCC 状态可能在系统设置切换后短暂滞后] → 引导可见期间轮询，并提供重新打开系统设置/重新启动应用的说明，不把授权作为退出向导的硬性门槛。
- [MenuBarExtra 需要二次点击才能执行“打开主界面”] → 菜单项置于首位并明确命名；若产品体验要求图标单击直达，可在后续用 `NSStatusItem` 替换，不影响主窗口和服务架构。
- [按键被按下时覆盖用户选择] → 将 `selectedButtonID` 与实时 pressed set 分离，并在设备切换/断开时显式归约选择。

## Migration Plan

1. 将默认 `WindowGroup` 替换为带 id 的单一主窗口 scene，接入菜单栏和应用代理。
2. 引入设备/按钮领域模型及可测试状态归约，再接入 GameController 事件源。
3. 将主界面替换为左右双栏，接入设备下拉选择、按键选择、实时状态和映射占位。
4. 接入权限状态与首次启动向导，补充需要的隐私描述。
5. 运行单元测试和 Debug 构建，并用至少一个真实手柄完成连接、按键、断开和重新连接验收。

回滚时可恢复原 `JoyCodingApp` 与 `ContentView`，删除新增服务和视图；本 change 不迁移用户业务数据，唯一新增持久状态是首次引导展示标记。

## Open Questions

当前没有阻塞实现的问题。应用显示名、图标细节和后续映射编辑交互不在本 change 内确定。
