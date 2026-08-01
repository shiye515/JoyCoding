## Context

JoyCoding 当前由 `ControllerService` 监听 GameController 按下/松开事件，并将瞬时状态写入 `ControllerState`；右栏只显示所选按键名称，不存在映射模型、持久化或键盘事件输出。运行时设备 ID 是每次连接生成的 UUID，因此不能直接作为跨启动配置键。现有权限层已经能检测辅助功能权限并打开系统设置，可复用于键盘事件发送的前置检查。

参考项目将键盘映射建模为主键、修饰键和按住策略，并将编辑态留在配置界面直至保存；本阶段沿用这些经过验证的边界，但只保留 JoyCoding MVP 所需的键盘单键/组合键、持续按住和重复按下，不引入宏、鼠标、脚本、分层或多击动作。

## Goals / Non-Goals

**Goals:**

- 为当前设备的每个可识别手柄按键配置一个键盘单键或标准修饰组合键。
- 仅通过用户在录入控件获得焦点后实际按下键盘按键来形成快捷键草稿。
- 在“持续按住”和“重复按下”两种长按行为之间选择，并正确配对键盘按下/松开事件。
- 保证草稿只有在显式保存后才持久化并影响下一次手柄输入。
- 在重启和同型号手柄重新连接后恢复映射，并支持清除映射。
- 对权限缺失、设备断开、配置替换等路径进行安全收尾，避免键盘键卡在按下状态。

**Non-Goals:**

- 鼠标操作、系统命令、宏、脚本、文本序列、手柄组合键和多层配置。
- 长按阈值、双击动作、按键序列或根据前台应用切换配置。
- 可视化全键盘选择器与自定义重复频率；MVP 的重复节奏固定为每秒 5 次。
- 区分两只完全相同且无法从 GameController 获取稳定硬件序列号的物理手柄。

## Decisions

### 1. 使用小型、可编码且不与 SwiftUI 重名的领域模型

在 `KeyboardMappingModels.swift` 中新增以下值类型：

- `KeyboardModifiers: OptionSet, Codable, Hashable, Sendable`，只包含 `command`、`option`、`control`、`shift`。
- `KeyboardBinding: Codable, Hashable, Sendable`，包含 `keyCode: UInt16` 与 `modifiers: KeyboardModifiers`。
- `MappingHoldBehavior: String, Codable, CaseIterable, Sendable`，只包含 `hold` 与 `repeatPress`。
- `KeyboardButtonMapping: Codable, Equatable, Sendable`，包含 `binding` 与 `holdBehavior`。

不使用 `KeyboardShortcut` 作为类型名，以避免和 SwiftUI 同名类型产生歧义。组合键限定为一个非修饰主键加零个或多个标准修饰键；独立修饰键以其物理虚拟键码作为 `keyCode` 且 `modifiers` 为空。组合键中的左右修饰键统一归一化为语义修饰键，执行时使用左侧虚拟键码。模型不存储 `NSEvent`、`CGEventFlags` 或显示字符串。

`KeyboardKeyCatalog.swift` 负责虚拟键码、修饰键和可读名称之间的集中转换。MVP 使用基于 Carbon 虚拟键码的确定性目录，覆盖 ANSI 字母/数字、标点、方向键、导航键、F1–F20 和标准修饰键；未知键显示为 `Key <code>`。本阶段不使用 `UCKeyTranslate` 动态适配键盘布局，以避免把输入法与布局状态引入持久化和测试。

### 2. 固定控制器配置标识算法与 v1 存储格式

为 `ControllerDevice` 增加 `profileID: String`。`ControllerProfileID.make(name:category:buttonIDs:)` 按以下确定性算法生成它：名称和类别分别去除首尾空白与换行，再使用 `en_US_POSIX` locale 转为小写；按键 ID 按 Unicode 标量升序排序；把 `{name, category, buttonIDs}` 编码为启用 `.sortedKeys` 的 JSON，随后使用标准 Base64 编码，并添加 `v1:` 前缀。不得使用 Swift `Hasher`，因为其结果不能跨进程稳定。

`KeyboardMappingStore.swift` 定义 `@MainActor`、可观察且可注入的 `KeyboardMappingStoring` 协议及 `UserDefaultsKeyboardMappingStore` 实现。UserDefaults 固定键名为 `keyboardButtonMappings.v1`，值为 JSON Data，根对象固定为：

```text
{ schemaVersion: 1, profiles: { profileID: { buttonID: KeyboardButtonMapping } } }
```

加载时仅接受 `schemaVersion == 1`；键缺失、解码失败或版本不支持均在内存中回退为空配置，且在用户下一次保存或清除之前不覆盖原始 Data。每次修改先更新内存快照，再将整个根对象编码并写入 UserDefaults，同时发布一次变更供左右栏刷新。相同 `profileID` 的设备共享映射；运行时 UUID 仍只区分连接会话和活动输出。

GameController 未保证提供稳定硬件序列号，因此按运行时 UUID 存储会在重连后丢失配置，而尝试虚构单设备身份也不可靠。后续若能获取稳定硬件标识，可在版本化存储上增加每设备覆盖层。

### 3. 使用确定的修饰键暂存状态机录入键盘按键

`KeyboardCaptureView.swift` 使用 `NSViewRepresentable` 包装可成为 first responder 的 `NSView`。SwiftUI 编辑器显式控制 `isCapturing`；开始录入时清空捕获会话内部的 `pressedModifierKeyCodes`、`seenModifierKeyCodes` 与 `didReceiveMainKey`，但不清空外部草稿。捕获状态机固定为：

1. `flagsChanged` 报告修饰键按下时，只加入暂存集合，不立即提交，因而 Command 后续仍可与 K 组成 Command+K。
2. 第一个非修饰 `keyDown` 到达时，若 `isARepeat == false`，用该键作为主键并从当前 modifier flags 生成语义修饰集合，立即提交组合键并结束录入。
3. 若整个会话只出现一个物理修饰键且它随后松开，则在松开边沿把该虚拟键码提交为独立修饰键映射。
4. 若出现两个或更多修饰键但始终没有非修饰主键，则在全部松开时不提交，保持录入并显示“组合键需要一个非修饰主键”。MVP 不支持纯修饰键组合。
5. `isARepeat == true` 的 `keyDown` 一律消费并忽略。控件失去 first responder、用户点击“停止录入”或选择发生变化时取消本次捕获，保留进入录入前的草稿。

所有 `keyDown` 和 `flagsChanged` 都由该视图消费，不调用 `super`，避免触发菜单快捷键。Escape 也属于可映射单键，因此取消录入必须通过界面操作而不是占用 Escape。这种局部捕获不需要输入监控权限；MVP 不提供全局监听、下拉列表或可视键盘。

### 4. 草稿与生效映射分离

右栏编辑器以当前已保存映射创建本地草稿。录入快捷键或切换按住行为只改变草稿；“保存”校验草稿后原子替换存储中的映射，并让后续新的手柄按下读取新值。切换设备或按键会丢弃未保存草稿并载入新选择的已保存值。“清除映射”是独立的明确动作，会立即删除持久化配置、取消该来源正在执行的输出，并刷新界面。

保存发生时若对应手柄按键已经按住，不在中途合成键盘按下；新配置从下一次完整的手柄按下开始生效。这样可以避免缺少对应松开事件的半途状态。

### 5. 在 MainActor 上执行映射，并注入可取消时间源

`MappingEngine.swift` 定义 `@MainActor final class MappingEngine`。`ControllerService` 已在主 actor 更新状态，因此所有活动来源、引用计数和重复任务均由同一 actor 串行管理，不再引入锁或第二套 actor。`ControllerState.setPressed` 改为返回是否发生真实边沿；服务只在返回 `true` 时把事件转发给引擎。

引擎用 `MappingSource(deviceSessionID: UUID, buttonID: String)` 索引活动记录。按下边沿从 store 读取一次映射并将完整映射快照放入记录；松开使用该快照收尾，不重新查询配置。保存发生时不触碰活动记录，因此新配置只影响下一次按下。清除则通过 `profileID + buttonID` 找到所有匹配会话并立即取消。

`MappingSleeping` 协议提供可取消的 `sleep(for:) async throws`；生产实现使用 `ContinuousClock.sleep(for:)`，测试实现由测试代码显式推进。重复模式为每个来源保留一个 `Task<Void, Never>`：先同步执行一次完整按键循环，再循环等待 200 ms、检查取消、执行下一次；松开先取消并移除任务，再结束来源。所有任务闭包回到 MainActor 修改状态。

`KeyboardEventSending` 协议隔离 Core Graphics 实现和记录型测试替身。持续按住和重复循环都通过同一套物理键引用计数 API；每个 `CGKeyCode` 只在计数 0→1 时实际发送 key-down，在 1→0 时发送 key-up。若重复循环的键正被另一个持续来源持有，该次重复不会额外制造不匹配的 key-up；这是防卡键优先于重入重复效果的明确取舍。

该执行模型对应文件依赖为：`ControllerService → MappingEngine → KeyboardMappingStoring + KeyboardEventSending + MappingSleeping`。UI 只依赖同一个 `KeyboardMappingStoring` 实例，不直接调用 sender 或引擎。

### 6. 明确 Core Graphics 事件序列与 flags

`KeyboardEventSender.swift` 的生产实现持有 `CGEventSource(stateID: .hidSystemState)`，并把事件投递到 `.cghidEventTap`。组合键使用固定修饰顺序 Control、Option、Shift、Command，对应左侧 Carbon 虚拟键码；按下时逐个增加累计 flags，主键 key-down 携带完整 flags。释放时主键 key-up 仍携带完整 flags，随后以逆序释放修饰键，并在每次释放后携带剩余 flags。独立修饰键根据其 keyCode 设置对应按下或松开 flags。

若任一 `CGEvent` 无法创建，sender 返回失败，执行器立即释放该来源此前已经成功按下的键并不登记半完成活动记录。测试 SHALL 断言虚拟键码、down/up、flags 与顺序，而不依赖真实系统事件。

### 7. 权限检查、生命周期与强制释放属于执行边界

开始一次映射前通过注入闭包读取辅助功能权限。未授权时不创建活动记录、不发送部分事件；右栏直接观察现有 `PermissionsManager.accessibility`，展示未生效原因与 `openAccessibilitySettings()` 入口。

`ControllerService` 新增幂等 `stop()`：停止发现、移除通知观察、清空 GameController handlers，并调用 `MappingEngine.releaseAll()`。服务注册 `NSApplication.willTerminateNotification` 并同步调用 `stop()`；`deinit` 只作为相同清理的兜底，不是唯一退出路径。设备断开调用 `releaseAll(deviceSessionID:)`，清除映射调用 `releaseAll(profileID:buttonID:)`。强制释放绕过“当前是否仍有辅助功能权限”的启动检查，始终尝试发送配对 key-up。

### 8. 固定实现文件与依赖装配位置

新增生产文件：`KeyboardMappingModels.swift`、`KeyboardKeyCatalog.swift`、`KeyboardMappingStore.swift`、`KeyboardCaptureView.swift`、`KeyboardEventSender.swift`、`MappingEngine.swift`、`MappingEditorView.swift`。修改 `ControllerModels.swift`、`ControllerService.swift`、`ContentView.swift` 和 `JoyCodingApp.swift`。`JoyCodingApp` 在应用生命周期内创建唯一 store、sender、sleeper、engine 与 service，预览和测试通过 initializer 注入替身，不使用额外 singleton。

测试文件对应拆分为 `KeyboardMappingModelsTests.swift`、`KeyboardMappingStoreTests.swift`、`KeyboardCaptureStateTests.swift`、`MappingEngineTests.swift` 与 `ControllerMappingIntegrationTests.swift`。捕获逻辑中的纯状态转换提取为不依赖窗口的 `KeyboardCaptureState`，使 keyCode/flags 输入可在单元测试中验证；`NSViewRepresentable` 只负责把 NSEvent 转换为状态机输入。

## Risks / Trade-offs

- [设备配置键不是物理序列号，同型号手柄共享映射] → 在 UI 中按设备型号描述此行为，并通过版本化存储为未来的单设备覆盖保留迁移空间。
- [非 ANSI 键盘布局的字符标签可能与实体键帽不同] → MVP 明确使用确定性的 Carbon 键码目录而不承诺动态布局翻译；自动化测试验证标准键、特殊键和未知键回退。
- [Core Graphics 事件在辅助功能未授权时可能静默失败] → 发送前显式检查权限，UI 展示状态，并以可注入 sender 验证事件序列。
- [重复任务或异常断开可能造成卡键] → 所有活动输出按来源登记，清除/断开/停止统一走幂等 release-all 路径。
- [重复模式与另一来源同时持有同一物理键时无法产生独立重复边沿] → 引用计数以不产生错误 key-up 为优先；该并发冲突不属于 MVP 的独立重放保证。
- [固定每秒 5 次不适合所有游戏或应用] → MVP 先提供确定行为；未来可在不改变映射语义的前提下把间隔加入配置。

## Migration Plan

1. 新增映射模型与空的版本化存储；现有用户首次加载时得到空映射集合，不需要数据迁移。
2. 接入右栏编辑器和左栏摘要，但在执行器接入前保持无输出。
3. 接入权限门控与映射执行器，并增加断开、清除和服务结束的释放逻辑。
4. 若需要回滚，停止注入执行器并隐藏编辑控件即可；版本化映射数据可保留，旧版本会忽略未知 UserDefaults 键。

## Open Questions

无。自定义重复频率和同型号物理设备独立配置明确留待后续变更。
