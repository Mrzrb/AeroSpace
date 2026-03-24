# BSP 布局功能设计文档

## 概述

本文档描述了为 AeroSpace 添加 BSP (Binary Space Partitioning) 布局功能的技术设计。BSP 布局是一种基于二进制树的窗口管理方式，它将屏幕空间递归地分割成更小的区域，每个分割都是水平或垂直的。这种布局方式提供了比传统 tiles 和 accordion 布局更灵活的窗口排列能力。

BSP 布局的核心思想是：
- 每个容器都有一个分割方向（水平或垂直）
- 当添加新窗口时，选择一个现有窗口进行分割
- 分割会创建一个新的容器，包含原窗口和新窗口
- 分割方向可以是智能选择的，也可以是用户指定的

## 架构

### 核心组件

#### 1. Layout 枚举扩展
```swift
enum Layout: String {
    case tiles
    case accordion
    case bsp        // 新增：自动 BSP 布局
}
```

#### 2. BSP 特定的配置
```swift
struct BSPConfig {
    let splitRatio: Double = 0.5           // 默认分割比例
    let autoSplitThreshold: Double = 1.2   // 宽高比阈值，用于自动选择分割方向
    let preferredSplitDirection: Orientation? = nil  // 用户偏好的分割方向
}
```

#### 3. BSP 布局算法
BSP 布局算法需要实现以下核心功能：
- **窗口插入算法**：决定在哪里插入新窗口
- **分割方向选择**：基于容器尺寸和配置选择分割方向
- **树结构优化**：保持树结构的平衡和简洁

### 布局算法设计

#### 窗口插入策略
1. **最近使用窗口分割**：默认在最近聚焦的窗口位置进行分割
2. **智能分割方向选择**：
   - 如果容器宽度/高度比 > `autoSplitThreshold`，使用垂直分割
   - 如果容器高度/宽度比 > `autoSplitThreshold`，使用水平分割
   - 否则使用配置的默认方向或交替方向

#### 树结构管理
- 使用现有的 `TilingContainer` 结构
- 每个 BSP 分割创建一个新的容器
- 保持树的平衡，避免过深的嵌套

## 组件和接口

### 1. TilingContainer 扩展

```swift
extension TilingContainer {
    // BSP 布局的核心实现
    @MainActor
    fileprivate func layoutBSP(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        // 实现 BSP 布局算法
        // 递归地为每个子节点分配空间
    }
    
    // BSP 窗口插入逻辑
    func insertWindowBSP(_ window: Window, relativeTo targetWindow: Window?) {
        // 在指定窗口位置进行 BSP 分割
    }
    
    // BSP 分割方向选择
    private func chooseSplitDirection(width: CGFloat, height: CGFloat) -> Orientation {
        // 基于尺寸和配置选择分割方向
    }
}
```

### 2. LayoutCmdArgs 扩展

```swift
public enum LayoutDescription: String, CaseIterable, Equatable, Sendable {
    case accordion, tiles
    case horizontal, vertical
    case h_accordion, v_accordion, h_tiles, v_tiles
    case tiling, floating
    case bsp           // 新增：自动 BSP
    case h_bsp         // 新增：水平 BSP
    case v_bsp         // 新增：垂直 BSP
}
```

### 3. 配置系统集成

在 `default-config.toml` 中添加 BSP 相关配置：
```toml
# BSP 布局配置
[bsp]
    split-ratio = 0.5              # 默认分割比例
    auto-split-threshold = 1.2     # 自动分割方向选择的宽高比阈值
    preferred-split-direction = "auto"  # "auto", "horizontal", "vertical"
```

## 数据模型

### BSP 树结构
BSP 布局将重用现有的树结构，但会有特定的组织方式：

```
Workspace
└── TilingContainer (BSP, orientation: .h)
    ├── Window A
    └── TilingContainer (BSP, orientation: .v)
        ├── Window B
        └── TilingContainer (BSP, orientation: .h)
            ├── Window C
            └── Window D
```

### 窗口权重计算
BSP 布局中的窗口权重将基于分割比例计算：
- 新分割默认使用 50:50 比例
- 用户可以通过 resize 命令调整比例
- 权重会在树结构中向上传播

## 错误处理

### 1. 布局转换错误
- **问题**：从其他布局转换到 BSP 时可能出现的问题
- **解决方案**：实现渐进式转换，保持现有窗口的相对位置

### 2. 树结构异常
- **问题**：BSP 树可能变得过于复杂或不平衡
- **解决方案**：实现树结构优化算法，定期简化树结构

### 3. 分割失败
- **问题**：窗口太小无法进一步分割
- **解决方案**：设置最小窗口尺寸阈值，拒绝过小的分割

## 测试策略

### 1. 单元测试
- BSP 分割算法测试
- 树结构操作测试
- 配置解析测试

### 2. 集成测试
- 与现有命令的兼容性测试
- 布局切换测试
- 多窗口场景测试

### 3. 性能测试
- 大量窗口的布局性能
- 频繁分割/合并的性能
- 内存使用情况

## 实现细节

### 1. layoutRecursive 集成
BSP 布局将集成到现有的 `layoutRecursive` 框架中：

```swift
extension TreeNode {
    @MainActor
    fileprivate func layoutRecursive(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        // ... 现有代码 ...
        case .tilingContainer(let container):
            switch container.layout {
                case .tiles:
                    try await container.layoutTiles(point, width: width, height: height, virtual: virtual, context)
                case .accordion:
                    try await container.layoutAccordion(point, width: width, height: height, virtual: virtual, context)
                case .bsp:  // 新增
                    try await container.layoutBSP(point, width: width, height: height, virtual: virtual, context)
            }
    }
}
```

### 2. 命令兼容性
确保现有命令与 BSP 布局兼容：

- **focus 命令**：在 BSP 树中正确导航
- **move 命令**：重新排列 BSP 树结构
- **resize 命令**：调整 BSP 分割比例
- **split 命令**：在 BSP 模式下创建新分割

### 3. 配置加载
扩展配置系统以支持 BSP 配置：

```swift
struct Config {
    // ... 现有配置 ...
    let bsp: BSPConfig
}
```

## 向后兼容性

### 配置兼容性
- 现有配置文件将继续工作
- BSP 配置是可选的，有合理的默认值
- `default-root-container-layout` 支持新的 `bsp` 值

### 命令兼容性
- 所有现有命令将与 BSP 布局兼容
- 新的布局描述符（`bsp`, `h_bsp`, `v_bsp`）是附加的

### API 兼容性
- 现有的内部 API 保持不变
- 新功能通过扩展现有接口实现

## 性能考虑

### 1. 布局计算优化
- BSP 布局计算是 O(n) 复杂度，其中 n 是窗口数量
- 使用缓存避免重复计算
- 增量更新而非全量重新计算

### 2. 内存使用
- BSP 树结构重用现有的 `TilingContainer`
- 不引入额外的内存开销
- 树结构优化减少不必要的嵌套

### 3. 渲染性能
- 与现有布局系统使用相同的渲染路径
- 不影响现有布局的性能
- 异步布局计算避免阻塞 UI

## 未来扩展

### 1. 高级 BSP 功能
- 自定义分割算法
- 窗口优先级系统
- 动态分割比例调整

### 2. 可视化增强
- BSP 树结构可视化
- 分割预览
- 交互式树编辑

### 3. 智能布局
- 基于窗口类型的智能分割
- 学习用户习惯的自适应布局
- 工作区特定的 BSP 配置