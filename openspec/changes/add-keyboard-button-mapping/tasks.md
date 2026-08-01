## 1. 映射领域模型与设备配置标识

- [ ] 1.1 在 `KeyboardMappingModels.swift` 新增 `KeyboardModifiers`、`KeyboardBinding`、`MappingHoldBehavior`、`KeyboardButtonMapping` 与 `MappingSource`，符合 design 中固定字段、枚举值及 Codable/Hashable/Sendable 约束。
- [ ] 1.2 在 `ControllerModels.swift` 为 `ControllerDevice` 增加 `profileID`，并按“规范化字段 → sortedKeys JSON → Base64 → v1 前缀”的算法实现 `ControllerProfileID.make`；不得使用 Swift `Hasher`。
- [ ] 1.3 在 `KeyboardKeyCatalog.swift` 实现确定性的 Carbon 虚拟键码目录与格式化，覆盖 ANSI 字母/数字、标点、方向键、导航键、F1–F20、左右修饰键及 `Key <code>` 回退。
- [ ] 1.4 在 `KeyboardMappingModelsTests.swift` 验证 Codable 往返、组合键格式化、独立修饰键、未知键回退，以及 profileID 对大小写/首尾空白/按键顺序稳定并对真实字段变化敏感。

## 2. 映射持久化存储

- [ ] 2.1 在 `KeyboardMappingStore.swift` 定义 `@MainActor KeyboardMappingStoring`，提供按 `profileID + buttonID` 查询、保存、删除及可观察快照，并实现 `UserDefaultsKeyboardMappingStore`。
- [ ] 2.2 使用固定键 `keyboardButtonMappings.v1` 和 `{schemaVersion: 1, profiles: ...}` 根结构实现整体 JSON Data 读写；缺失、损坏和未知版本只回退内存空配置，首次用户修改前不得覆盖原 Data。
- [ ] 2.3 保存和删除时先更新内存快照、再写 UserDefaults，并只发布一次变更，确保左右栏使用同一个 store 实例同步刷新。
- [ ] 2.4 在 `KeyboardMappingStoreTests.swift` 使用独立 UserDefaults suite 验证保存覆盖、删除、不同 profile 隔离、同 profile 重连恢复、损坏数据、未知版本及修改后重写 v1 数据。

## 3. 键盘录入控件与编辑草稿

- [ ] 3.1 在 `KeyboardCaptureView.swift` 提取纯 `KeyboardCaptureState`，严格实现 design 的五步状态机：修饰键暂存、非修饰主键提交组合、单修饰键松开提交、多修饰无主键报错、自动重复忽略。
- [ ] 3.2 用 `NSViewRepresentable` 包装 first-responder NSView，把 `keyDown`/`flagsChanged` 转换为状态机输入并全部消费；实现开始/停止、焦点丢失和选择变化取消，Escape 保留为可录入键。
- [ ] 3.3 在 `MappingEditorView.swift` 实现按当前 profile/button 载入的本地草稿、有效性和 dirty 判断；捕获未完成时保留旧草稿，切换选择时放弃未保存草稿。
- [ ] 3.4 在 `KeyboardCaptureStateTests.swift` 验证普通单键、Command+K 不提前提交 Command、独立左右修饰键、多修饰无主键、Escape、自动重复及取消保留原草稿。

## 4. 键盘事件发送与映射执行器

- [ ] 4.1 在 `KeyboardEventSender.swift` 定义 `KeyboardEventSending` 和记录型替身；生产 sender 使用 `.hidSystemState` source 与 `.cghidEventTap`，按 Control→Option→Shift→Command 顺序和累计 flags 发送，释放顺序相反。
- [ ] 4.2 让 sender 在 CGEvent 创建失败时返回失败，并测试主键、组合键及独立修饰键每个事件的 keyCode、down/up、flags 和顺序。
- [ ] 4.3 在 `MappingEngine.swift` 实现 `@MainActor MappingEngine`、`MappingSleeping` 与生产 `ContinuousClock` sleeper；活动记录按 `(deviceSessionID, buttonID)` 保存按下时的映射快照。
- [ ] 4.4 实现持续按住模式和按物理 keyCode 的 0→1/1→0 引用计数；若中途发送失败，立即回滚该来源已成功按下的键且不保留半完成记录。
- [ ] 4.5 实现重复按下模式：首次同步执行完整循环，每个来源持有可取消 `Task`，之后每 200 ms 重复；松开时先取消/移除任务再结束来源。
- [ ] 4.6 实现辅助功能权限门控及 `release(source:)`、`releaseAll(deviceSessionID:)`、`releaseAll(profileID:buttonID:)`、`releaseAll()` 幂等 API；强制释放不得因当前权限检查而跳过 key-up。
- [ ] 4.7 在 `MappingEngineTests.swift` 用手动推进 sleeper 和记录型 sender 验证事件顺序、200 ms 节奏、任务取消、重复边沿去重、映射快照、多来源引用计数、发送失败回滚、权限拒绝及全部释放 API。

## 5. 手柄服务与生命周期集成

- [ ] 5.1 修改 `ControllerState.setPressed` 返回真实边沿，并在 `ControllerService` 只对变化边沿调用 `MappingEngine`，同时保持现有按键状态高亮。
- [ ] 5.2 向 `ControllerService` 注入共享 store 与 engine；注册设备时生成 profileID，按下时传入 profileID/sessionID/buttonID，断开时调用按 session 释放。
- [ ] 5.3 为 `ControllerService` 实现幂等 `stop()`，统一停止发现、移除观察者、清除 GameController handlers 和 `releaseAll()`；监听 `NSApplication.willTerminateNotification` 同步调用，deinit 仅作兜底。
- [ ] 5.4 保存配置不得修改活动记录；清除配置先删除 store 项，再调用 `releaseAll(profileID:buttonID:)`，确保所有同 profile 活动会话停止。
- [ ] 5.5 在 `ControllerMappingIntegrationTests.swift` 覆盖未映射、保存前旧配置仍生效、保存时已经按住、重复状态回调、断开释放、清除停止和 stop 幂等。

## 6. 映射配置界面

- [ ] 6.1 在 `MappingEditorView.swift` 完成录入控件、“持续按住/重复按下”选择、dirty 提示、“保存”“清除映射”和捕获错误文案；保存仅在有效且有变更时可用，清除仅在已有持久映射时可用。
- [ ] 6.2 修改 `ContentView.swift` 用编辑器替换右栏占位，并让左栏从共享 store 显示格式化映射或“未映射”，同时保留选中样式与实时按下高亮。
- [ ] 6.3 右栏观察现有 `PermissionsManager.accessibility`；未授权时展示“映射已保存但不会执行”和打开辅助功能设置按钮，不触发自动权限请求。
- [ ] 6.4 修改 `JoyCodingApp.swift` 创建唯一 `UserDefaultsKeyboardMappingStore`、sender、sleeper、engine 与 service，并通过 initializer 向预览/测试注入替身，不增加 singleton。
- [ ] 6.5 增加有映射、无映射、捕获中、多修饰错误、dirty、无设备和权限不足等 SwiftUI 预览或可验证状态。

## 7. 验证与交付

- [ ] 7.1 运行全部单元测试、Debug build 和静态分析；修复映射模型、存储、捕获、执行及现有 ControllerState/权限流程测试中的回归，并记录可复现命令与结果。
- [ ] 7.2 验证工程没有新增第三方依赖、CoreBluetooth 权限或启动时自动权限请求，并检查新增 Swift 文件同时属于应用和对应测试 target。
- [ ] 7.3 **用户验收**：由用户使用真实手柄确认单键、Command/Option/Control/Shift 组合键、独立修饰键、持续按住、固定重复、保存后生效、清除和重连恢复；实施代理在用户明确确认前 MUST NOT 勾选本项。
- [ ] 7.4 **用户验收**：由用户确认权限拒绝、重复期间断开、持续按住时清除和退出应用均未留下卡键；实施代理在用户明确确认前 MUST NOT 勾选本项。
