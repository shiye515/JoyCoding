## ADDED Requirements

### Requirement: 发现并维护已连接设备
应用 SHALL 使用 macOS GameController 框架发现启动前已经连接及运行期间新连接的游戏手柄，并 SHALL 在设备断开后将其从列表中移除。

#### Scenario: 启动时已有设备
- **WHEN** 应用启动时系统已经识别一个或多个游戏手柄
- **THEN** 顶部设备列表显示每个已识别设备且不产生重复条目

#### Scenario: 运行时连接设备
- **WHEN** 应用运行期间系统通知一个新游戏手柄已连接
- **THEN** 新设备被添加到顶部设备列表

#### Scenario: 设备断开
- **WHEN** 一个已显示的游戏手柄断开
- **THEN** 该设备及其按下状态从应用状态和界面中移除

### Requirement: 选择当前设备
应用 SHALL 始终将按键列表关联到一个明确的当前设备，并 SHALL 使用确定性的规则处理初始选择和设备断开。

#### Scenario: 首个设备出现
- **WHEN** 当前没有选中设备且首个游戏手柄被发现
- **THEN** 应用自动选中该设备

#### Scenario: 用户切换设备
- **WHEN** 用户在顶部设备列表选择另一个游戏手柄
- **THEN** 选中样式与底部按键列表切换到该设备

#### Scenario: 选中设备断开
- **WHEN** 当前选中设备断开且仍有其他设备连接
- **THEN** 应用自动选择剩余设备列表中的首个设备

#### Scenario: 最后一个设备断开
- **WHEN** 当前选中设备是最后一个已连接设备且其断开
- **THEN** 当前选择清空且界面显示未连接设备的空状态

### Requirement: 展示设备可用按键
应用 SHALL 在底部列表显示当前设备通过标准 extended gamepad profile 暴露的按钮，并 SHALL 在无法使用该 profile 时以 physical input profile 提供合理回退。每个条目 SHALL 具有稳定标识和可读名称。

#### Scenario: 标准扩展手柄
- **WHEN** 选中设备提供 extended gamepad profile
- **THEN** 列表按稳定顺序显示该设备可用的面键、肩键、扳机、方向键、菜单类按钮和摇杆按压按钮

#### Scenario: 非标准物理输入配置
- **WHEN** 选中设备没有 extended gamepad profile 但提供 physical input profile
- **THEN** 列表使用系统暴露的物理按钮名称生成可识别条目

### Requirement: 实时高亮按下按键
应用 SHALL 监听每台已注册设备的按钮按下和松开事件，并 SHALL 仅在事件所属设备当前被选中时在列表中实时呈现对应高亮状态。

#### Scenario: 按下当前设备的按键
- **WHEN** 用户按下当前选中设备中一个已列出的按钮
- **THEN** 对应按钮条目立即进入高亮状态

#### Scenario: 松开当前设备的按键
- **WHEN** 用户松开一个正在高亮的按钮
- **THEN** 对应按钮条目立即恢复普通状态

#### Scenario: 同时按下多个按键
- **WHEN** 用户在当前选中设备上同时按住多个按钮
- **THEN** 所有仍处于按下状态的对应条目同时高亮

#### Scenario: 非选中设备产生输入
- **WHEN** 非当前选中设备产生按键事件
- **THEN** 应用记录该设备自己的状态但不错误高亮当前设备的按钮条目

### Requirement: 无设备空状态
应用 SHALL 在没有可用游戏手柄时显示说明性空状态，而不是空白按键列表或错误信息。

#### Scenario: 未连接任何设备
- **WHEN** 系统没有识别到游戏手柄
- **THEN** 主界面提示用户通过 USB 或蓝牙连接手柄
