# 智能BSP算法改进

本次改进为AeroSpace窗口管理器实现了更智能的BSP（Binary Space Partitioning）算法，解决了移动窗口导致root container变化后BSP失效的问题。

## 主要改进

### 1. 智能树结构优化
- **自动结构修复**: 检测并修复BSP树结构问题
- **容器合并**: 自动移除不必要的嵌套容器
- **空容器清理**: 自动清理空的容器节点

### 2. 动态比例调整
- **智能重新平衡**: 根据容器特征动态调整窗口比例
- **自适应权重**: 基于窗口数量和容器尺寸计算最优权重
- **中心偏向算法**: 为中心位置的窗口分配更多空间

### 3. 智能分割方向选择
- **自动方向选择**: 根据容器宽高比选择最优分割方向
- **尺寸验证**: 确保分割后窗口不会过小
- **动态调整**: 在容器尺寸变化时自动调整分割方向

### 4. 错误处理和恢复
- **全面错误处理**: 处理各种BSP操作中可能出现的错误
- **自动恢复**: 在错误发生时尝试自动恢复
- **结构重建**: 在严重错误时重建BSP树结构

## 新增功能

### 配置选项
```toml
[bsp]
split-ratio = 0.5                    # 分割比例
auto-split-threshold = 1.2           # 自动分割阈值
preferred-split-direction = 'auto'   # 首选分割方向
enable-intelligent-rebalancing = true  # 启用智能重新平衡
enable-adaptive-weighting = true       # 启用自适应权重
enable-auto-optimization = true        # 启用自动优化
```

### 新命令
- `optimize-bsp`: 手动触发BSP优化
  - `--window-id <id>`: 优化指定窗口所在的BSP布局
  - `--workspace <name>`: 优化指定工作区的BSP布局

### 自动优化触发
- 窗口移动后自动优化
- 容器规范化时自动优化
- root container变化时自动优化

## 技术实现

### 核心算法
1. **结构验证**: `validateBSPTreeStructure()`
2. **智能重新平衡**: `intelligentBSPRebalance()`
3. **结构重建**: `rebuildBSPTreeStructure()`
4. **根容器变化处理**: `handleRootContainerChange()`

### 权重计算算法
```swift
基础权重 = 1.0 / 窗口数量
主窗口加成 = 基础权重 × 1.1 (第一个窗口)
中心偏向 = 根据窗口位置调整权重
最终权重 = 归一化处理确保总和为1.0
```

### 分割方向选择
- 宽容器（宽高比 > 1.5）：优先垂直分割
- 高容器（宽高比 < 0.67）：优先水平分割
- 方形容器：交替分割方向

## 文件修改列表

### 核心实现
- `Sources/AppBundle/tree/TilingContainer.swift`: 主要BSP算法实现
- `Sources/AppBundle/tree/normalizeContainers.swift`: 容器规范化集成
- `Sources/AppBundle/command/impl/MoveCommand.swift`: 移动命令集成

### 新增文件
- `Sources/AppBundle/command/impl/OptimizeBSPCommand.swift`: 优化命令
- `Sources/Common/cmdArgs/impl/OptimizeBSPCmdArgs.swift`: 命令参数
- `Sources/AppBundle/config/parseBSPConfig.swift`: 配置解析器
- `Sources/AppBundleTests/tree/IntelligentBSPTest.swift`: 测试文件

### 配置和文档
- `Sources/AppBundle/config/Config.swift`: BSP配置结构
- `Sources/AppBundle/config/parseConfig.swift`: 配置解析集成
- `docs/config-examples/intelligent-bsp-config.toml`: 示例配置
- `docs/intelligent-bsp.md`: 详细文档

### 命令系统集成
- `Sources/Common/cmdArgs/cmdArgsManifest.swift`: 命令清单
- `Sources/AppBundle/command/cmdManifest.swift`: 命令映射
- `Sources/Common/cmdHelpGenerated.swift`: 帮助文档

## 使用方法

### 基本配置
```toml
# 启用BSP作为默认布局
default-root-container-layout = 'bsp'

# 配置智能BSP
[bsp]
enable-intelligent-rebalancing = true
enable-adaptive-weighting = true
enable-auto-optimization = true
```

### 键位绑定
```toml
[mode.main.binding]
# 移动窗口（自动触发优化）
alt-shift-h = 'move left'
alt-shift-j = 'move down'
alt-shift-k = 'move up'
alt-shift-l = 'move right'

# 手动优化
alt-shift-o = 'optimize-bsp'
```

### 命令行使用
```bash
# 优化当前工作区
aerospace optimize-bsp

# 优化指定工作区
aerospace optimize-bsp --workspace 1

# 优化指定窗口所在的布局
aerospace optimize-bsp --window-id 12345
```

## 性能考虑

- 智能功能会增加一些计算开销
- 对于简单布局，可以禁用自适应权重以提高性能
- 大量窗口时建议启用所有优化功能以获得最佳体验

## 向后兼容性

- 所有新功能都是可选的，默认配置保持向后兼容
- 现有的BSP配置继续有效
- 新功能可以通过配置选项逐步启用

## 测试

- 添加了全面的单元测试
- 测试覆盖了所有主要功能
- 包括错误处理和边界情况测试

这次改进彻底解决了BSP算法在窗口移动后失效的问题，提供了更智能、更稳定的窗口管理体验。