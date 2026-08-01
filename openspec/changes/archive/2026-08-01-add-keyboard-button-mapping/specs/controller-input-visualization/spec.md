## MODIFIED Requirements

### Requirement: 展示并选择设备可用按键
应用 SHALL 在左栏的垂直列表显示当前设备通过标准 extended gamepad profile 暴露的按钮，并 SHALL 在无法使用该 profile 时以 physical input profile 提供合理回退。每个条目 SHALL 具有稳定标识、可读名称、选中状态和当前已保存键盘映射的摘要；没有映射时 SHALL 显示明确的未映射状态。

#### Scenario: 标准扩展手柄
- **WHEN** 选中设备提供 extended gamepad profile
- **THEN** 列表按稳定顺序显示该设备可用的面键、肩键、扳机、方向键、菜单类按钮和摇杆按压按钮

#### Scenario: 非标准物理输入配置
- **WHEN** 选中设备没有 extended gamepad profile 但提供 physical input profile
- **THEN** 列表使用系统暴露的物理按钮名称生成可识别条目

#### Scenario: 选择一个按键
- **WHEN** 用户点击当前设备按键列表中的一个条目
- **THEN** 该条目显示为当前选中按键，且右栏更新为该按键的详情与映射编辑器

#### Scenario: 切换设备后的按键选择
- **WHEN** 用户切换到另一个有可识别按键的设备
- **THEN** 应用选择该设备的首个按键，且不保留前一设备的按键选择

#### Scenario: 展示已有映射摘要
- **WHEN** 当前设备的一个按键已有保存的键盘映射
- **THEN** 该按键条目显示格式化的单键或组合键名称，同时继续显示实时按下状态

#### Scenario: 展示未映射状态
- **WHEN** 当前设备的一个按键没有保存的键盘映射
- **THEN** 该按键条目显示“未映射”且不影响其按下状态高亮

## ADDED Requirements

### Requirement: 显示并编辑选中按键映射
右栏 SHALL 为当前选中按键显示键盘映射编辑器，包括当前已保存映射、键盘录入控件、按住行为选择、“保存”和“清除映射”操作；没有可用按键时 SHALL 显示引导性空状态。

#### Scenario: 选择已有映射的按键
- **WHEN** 用户选择一个已有保存映射的手柄按键
- **THEN** 右栏编辑器载入该映射的键盘按键和按住行为

#### Scenario: 选择未映射按键
- **WHEN** 用户选择一个没有保存映射的手柄按键
- **THEN** 右栏显示空的录入状态、“保存”不可用且“清除映射”不可用

#### Scenario: 未选择按键
- **WHEN** 当前没有可用设备或可用按键
- **THEN** 右栏显示选择设备和按键的引导，不显示映射编辑字段

## REMOVED Requirements

### Requirement: 显示映射设置占位

**Reason**: 第二阶段用真实可编辑、可保存并可执行的键盘映射替代只读按键名称占位。

**Migration**: 右栏原“映射到”占位替换为键盘录入和按住行为编辑器；第一阶段没有持久化映射数据，因此无需数据迁移。
