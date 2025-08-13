# BSP 布局问题修复设计文档

## 概述

本文档描述了修复 AeroSpace BSP 布局功能中两个关键问题的技术设计：

1. **Resize 命令在 BSP 模式下不生效**：当前 resize 命令虽然支持 BSP 布局，但存在权重归一化和布局更新的问题
2. **Move window 后窗口意外变成 tiles 模式**：move 操作后某些容器的布局模式被错误地重置为 tiles
3. **BSP 模式下强制所有容器使用 BSP 布局**：确保在 BSP 模式下所有新创建的容器都使用 BSP 布局

通过分析现有代码，我发现了问题的根本原因并设计了相应的解决方案。

## 问题分析

### 问题 1：Resize 在 BSP 模式下不生效

**根本原因分析：**

1. **权重归一化问题**：在 `ResizeCommand.swift` 中，BSP 布局的权重被归一化到总和为 1.0，但这与 `layoutBSP` 函数中的权重计算逻辑不一致
2. **布局更新缺失**：resize 操作后没有触发布局的重新计算，导致视觉上没有变化
3. **权重传播问题**：BSP 树结构中的权重变化没有正确地向上传播到父容器

**当前实现问题：**
```swift
// 在 ResizeCommand.swift 中
if parent.layout == .bsp {
    let totalWeight = parent.children.sumOfDouble { $0.getWeight(orientation) }
    if totalWeight > 0 {
        for child in parent.children {
            child.setWeight(orientation, child.getWeight(orientation) / totalWeight)
        }
    }
}
```

这个归一化逻辑与 `layoutBSP` 中的比例计算不匹配，因为 `layoutBSP` 会动态计算总权重并按比例分配空间。

### 问题 2：Move window 后布局模式意外切换

**根本原因分析：**

1. **容器创建逻辑问题**：在 `MoveCommand.swift` 的 `createImplicitContainerAndMoveWindow` 函数中，强制创建了 tiles 布局的容器
2. **BSP 优化函数不完整**：虽然代码中调用了 `optimizeBSPAfterWindowMove`，但这个函数没有正确处理布局模式保持
3. **布局保持逻辑缺失**：move 操作没有保持原有容器的布局模式

**当前实现问题：**
```swift
// 在 MoveCommand.swift 中
private func createImplicitContainerAndMoveWindow(...) {
    // Force tiles layout - 这里强制使用了 tiles 布局
    _ = TilingContainer(parent: workspace, adaptiveWeight: WEIGHT_AUTO, direction.orientation, .tiles, index: 0)
}
```

### 问题 3：BSP 模式下布局一致性

**根本原因分析：**

1. **缺乏全局布局模式管理**：系统没有机制确保在 BSP 模式下所有容器都使用 BSP 布局
2. **容器创建时没有考虑工作区布局模式**：新容器创建时使用默认的 tiles 布局而不是继承工作区的布局模式

## 架构设计

### 核心组件修复

#### 1. ResizeCommand 修复

**设计原则：**
- 移除 BSP 权重系统的强制归一化
- 确保 resize 操作后立即触发布局更新
- 正确处理 BSP 树结构中的权重传播

**修复方案：**
```swift
// 修复后的 ResizeCommand 逻辑
if parent.layout == .bsp {
    // 不进行归一化，保持权重的绝对值
    // BSP 布局会在 layoutBSP 中自动处理比例计算
    
    // 触发布局更新
    Task { @MainActor in
        try await parent.nodeWorkspace?.layoutWorkspace()
    }
}
```

#### 2. MoveCommand 修复

**设计原则：**
- 保持原有容器的布局模式或使用工作区的布局模式
- 正确实现 BSP 树结构优化
- 确保 move 操作不会意外改变布局类型

**修复方案：**
```swift
// 修复后的容器创建逻辑
private func createImplicitContainerAndMoveWindow(...) {
    let prevRoot = workspace.rootTilingContainer
    let targetLayout = prevRoot.layout // 保持原有布局模式
    
    prevRoot.unbindFromParent()
    _ = TilingContainer(parent: workspace, adaptiveWeight: WEIGHT_AUTO, direction.orientation, targetLayout, index: 0)
    // ... 其余逻辑
}
```

#### 3. BSP 布局一致性机制

**设计目标：**
- 实现工作区级别的布局模式管理
- 确保新容器创建时使用正确的布局模式
- 提供布局模式强制转换机制

## 组件和接口

### 1. ResizeCommand 扩展

```swift
extension ResizeCommand {
    /// 处理 BSP 布局的 resize 操作
    private func handleBSPResize(parent: TilingContainer, node: TreeNode, diff: CGFloat, orientation: Orientation) -> Bool {
        // 1. 应用权重变化（不归一化）
        let childDiff = diff / CGFloat(parent.children.count - 1)
        parent.children.lazy
            .filter { $0 != node }
            .forEach { $0.setWeight(orientation, $0.getWeight(orientation) - childDiff) }
        
        node.setWeight(orientation, node.getWeight(orientation) + diff)
        
        // 2. 验证权重有效性
        validateBSPWeights(parent: parent, orientation: orientation)
        
        // 3. 触发布局更新
        Task { @MainActor in
            try await parent.nodeWorkspace?.layoutWorkspace()
        }
        
        return true
    }
    
    /// 验证 BSP 权重的有效性
    private func validateBSPWeights(parent: TilingContainer, orientation: Orientation) {
        let minWeight: CGFloat = 0.1
        for child in parent.children {
            let currentWeight = child.getWeight(orientation)
            if currentWeight < minWeight {
                child.setWeight(orientation, minWeight)
            }
        }
    }
}
```

### 2. MoveCommand 修复扩展

```swift
extension MoveCommand {
    /// 修复后的隐式容器创建函数
    private func createImplicitContainerAndMoveWindow(
        _ window: Window,
        _ workspace: Workspace,
        _ direction: CardinalDirection
    ) {
        let prevRoot = workspace.rootTilingContainer
        let targetLayout = prevRoot.layout  // 保持原有布局
        
        prevRoot.unbindFromParent()
        
        // 使用原有布局而不是强制 tiles
        _ = TilingContainer(
            parent: workspace,
            adaptiveWeight: WEIGHT_AUTO,
            direction.orientation,
            targetLayout,  // 关键修复：保持原有布局
            index: 0
        )
        
        check(prevRoot != workspace.rootTilingContainer)
        prevRoot.bind(to: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: 0)
        window.bind(to: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: direction.insertionOffset)
        
        // 如果是 BSP 布局，进行优化
        if targetLayout == .bsp {
            workspace.rootTilingContainer.optimizeBSPAfterWindowMove()
        }
    }
    
    /// 实现完整的 BSP 移动后优化
    private func optimizeBSPAfterWindowMove(window: Window) {
        guard let workspace = window.nodeWorkspace else { return }
        let rootContainer = workspace.rootTilingContainer
        
        // 只对 BSP 布局进行优化
        guard rootContainer.layout == .bsp else { return }
        
        // 优化整个 BSP 树结构
        rootContainer.optimizeBSPTreeStructure()
        
        // 优化受影响的父容器
        var currentParent = window.parent as? TilingContainer
        while let parent = currentParent {
            if parent.layout == .bsp {
                parent.optimizeBSPTreeStructure()
            }
            currentParent = parent.parent as? TilingContainer
        }
    }
}
```

### 3. TilingContainer BSP 布局一致性扩展

```swift
extension TilingContainer {
    /// 确保在 BSP 模式下所有子容器都使用 BSP 布局
    @MainActor
    func enforceBSPLayoutConsistency() {
        guard layout == .bsp else { return }
        
        // 递归地将所有子容器转换为 BSP 布局
        for child in children {
            if let childContainer = child as? TilingContainer {
                if childContainer.layout != .bsp {
                    childContainer.layout = .bsp
                }
                childContainer.enforceBSPLayoutConsistency()
            }
        }
    }
    
    /// 创建新的子容器时使用正确的布局模式
    @MainActor
    static func createChildContainer(
        parent: NonLeafTreeNodeObject,
        adaptiveWeight: CGFloat,
        orientation: Orientation,
        index: Int
    ) -> TilingContainer {
        // 确定目标布局：如果父容器是 BSP，则使用 BSP；否则使用 tiles
        let targetLayout: Layout
        if let parentContainer = parent as? TilingContainer, parentContainer.layout == .bsp {
            targetLayout = .bsp
        } else if let workspace = parent as? Workspace, workspace.rootTilingContainer.layout == .bsp {
            targetLayout = .bsp
        } else {
            targetLayout = .tiles
        }
        
        return TilingContainer(
            parent: parent,
            adaptiveWeight: adaptiveWeight,
            orientation,
            targetLayout,
            index: index
        )
    }
}
```

### 4. LayoutCommand 安全转换扩展

```swift
extension TilingContainer {
    /// 安全地转换到 BSP 布局
    @MainActor
    func safeTransitionToBSP(_ targetLayout: Layout) throws {
        guard targetLayout == .bsp else { return }
        
        // 验证转换的可行性
        try validateBSPTransition()
        
        // 执行转换
        layout = .bsp
        
        // 强制所有子容器也使用 BSP 布局
        enforceBSPLayoutConsistency()
        
        // 优化 BSP 树结构
        optimizeBSPTreeStructure()
    }
    
    /// 验证 BSP 转换的可行性
    private func validateBSPTransition() throws {
        // 检查是否有足够的空间进行 BSP 分割
        if let rect = lastAppliedLayoutVirtualRect {
            let minSize: CGFloat = 100.0
            if rect.width < minSize * 2 || rect.height < minSize * 2 {
                throw BSPError.windowTooSmall(minSize: minSize * 2, actualSize: min(rect.width, rect.height))
            }
        }
        
        // 检查子节点数量
        if children.count > 10 {
            throw BSPError.configurationError(reason: "Too many children for BSP layout (max 10)")
        }
    }
}
```

## 数据模型修复

### 权重系统一致性

**问题：** 当前 BSP 布局的权重系统在 resize 和 layout 之间不一致。

**解决方案：**
- Resize 操作不再强制归一化权重
- Layout 计算时动态计算比例
- 保持权重的绝对值，让布局函数处理比例

### 布局模式保持

**问题：** Move 操作会意外改变容器的布局模式。

**解决方案：**
- 在创建新容器时保持原有布局模式
- 实现布局模式的传播机制
- 添加布局模式验证

## 错误处理

### 1. Resize 错误处理

```swift
enum BSPResizeError: Error {
    case invalidWeightDistribution
    case containerTooSmall
    case orientationMismatch
}

extension ResizeCommand {
    private func validateBSPResize(parent: TilingContainer, diff: CGFloat, orientation: Orientation) throws {
        // 验证权重分配的有效性
        let totalWeight = parent.children.sumOfDouble { $0.getWeight(orientation) }
        if totalWeight + diff <= 0 {
            throw BSPResizeError.invalidWeightDistribution
        }
        
        // 验证容器尺寸
        if let rect = parent.lastAppliedLayoutVirtualRect {
            let minSize: CGFloat = 100.0
            let dimension = orientation == .h ? rect.width : rect.height
            if dimension * CGFloat(abs(diff)) < minSize {
                throw BSPResizeError.containerTooSmall
            }
        }
    }
}
```

### 2. Move 错误处理

```swift
extension MoveCommand {
    private func validateBSPMove(window: Window, targetContainer: TilingContainer) -> Bool {
        // 验证目标容器是否适合 BSP 布局
        guard targetContainer.layout == .bsp else { return true }
        
        // 验证树结构的完整性
        return targetContainer.validateBSPTreeStructure()
    }
}
```

## 测试策略

### 1. Resize 功能测试

```swift
class BSPResizeTests: XCTestCase {
    func testBSPResizePreservesLayout() {
        // 测试 resize 操作不会改变 BSP 布局模式
    }
    
    func testBSPResizeUpdatesWeights() {
        // 测试权重正确更新
    }
    
    func testBSPResizeTriggersLayout() {
        // 测试布局重新计算
    }
}
```

### 2. Move 功能测试

```swift
class BSPMoveTests: XCTestCase {
    func testMovePreservesBSPLayout() {
        // 测试 move 操作保持 BSP 布局
    }
    
    func testMoveOptimizesTree() {
        // 测试树结构优化
    }
}
```

## 实现细节

### 1. 布局更新触发机制

**当前问题：** Resize 操作后没有触发布局更新。

**解决方案：**
```swift
extension TilingContainer {
    func triggerLayoutUpdate() {
        // 异步触发布局更新
        Task { @MainActor in
            try await self.nodeWorkspace?.layoutWorkspace()
        }
    }
}
```

### 2. 权重传播机制

**设计目标：** 确保权重变化正确传播到整个 BSP 树。

**实现方案：**
```swift
extension TreeNode {
    func propagateBSPWeightChange(orientation: Orientation, delta: CGFloat) {
        // 向上传播权重变化
        if let parent = parent as? TilingContainer,
           parent.layout == .bsp,
           parent.orientation == orientation {
            
            // 调整兄弟节点的权重
            let siblings = parent.children.filter { $0 != self }
            let siblingDelta = -delta / CGFloat(siblings.count)
            
            for sibling in siblings {
                sibling.setWeight(orientation, sibling.getWeight(orientation) + siblingDelta)
            }
            
            // 继续向上传播
            parent.propagateBSPWeightChange(orientation: orientation, delta: 0)
        }
    }
}
```

### 3. BSP 布局一致性强制机制

**设计目标：** 确保在 BSP 模式下所有容器都使用 BSP 布局。

**实现方案：**
```swift
extension Workspace {
    /// 强制工作区使用 BSP 布局
    @MainActor
    func enforceBSPLayout() {
        rootTilingContainer.layout = .bsp
        rootTilingContainer.enforceBSPLayoutConsistency()
    }
}
```

## 向后兼容性

### 配置兼容性
- 所有现有的 BSP 配置将继续工作
- 修复不会改变配置文件格式
- 保持与现有命令的兼容性

### API 兼容性
- 不改变公共 API
- 内部实现的修复对外部调用透明
- 保持现有的命令行接口

## 性能考虑

### 1. 布局更新优化
- 只在必要时触发布局更新
- 使用异步布局更新避免阻塞
- 批量处理多个权重变化

### 2. 树结构优化
- 限制优化的深度和频率
- 使用缓存避免重复计算
- 增量更新而非全量重建

## 部署策略

### 1. 渐进式修复
- 首先修复 resize 问题
- 然后修复 move 问题
- 最后实现布局一致性强制机制

### 2. 测试验证
- 单元测试覆盖所有修复点
- 集成测试验证端到端功能
- 回归测试确保不引入新问题

### 3. 用户验证
- 提供测试版本给用户验证
- 收集反馈并进行调整
- 确保修复解决了实际问题