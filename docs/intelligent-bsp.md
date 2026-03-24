# 智能BSP算法

AeroSpace的智能BSP（Binary Space Partitioning）算法提供了一个更加智能和自适应的窗口管理解决方案。当你移动窗口导致root container变化后，传统的BSP算法可能会失效，但智能BSP算法能够动态调整所有窗口的比例，保持最优的布局。

## 主要特性

### 1. 自动优化
- **自动树结构优化**: 在窗口移动、添加或删除后自动优化BSP树结构
- **智能容器合并**: 自动移除不必要的嵌套容器
- **结构验证**: 自动检测和修复BSP树结构问题

### 2. 智能重新平衡
- **自适应权重分配**: 根据容器尺寸和窗口数量智能分配权重
- **动态比例调整**: 在root container变化后自动调整所有窗口比例
- **中心偏向算法**: 为中心位置的窗口分配更多空间以提高可用性

### 3. 智能分割方向选择
- **自动方向选择**: 根据容器宽高比自动选择最优分割方向
- **尺寸验证**: 确保分割后的窗口不会过小
- **动态方向调整**: 在容器尺寸变化时自动调整分割方向

## 配置选项

在你的配置文件中添加以下BSP配置：

```toml
[bsp]
# 基本配置
split-ratio = 0.5                    # 分割比例 (0.1-0.9)
auto-split-threshold = 1.2           # 自动分割阈值
preferred-split-direction = 'auto'   # 首选分割方向

# 智能功能
enable-intelligent-rebalancing = true  # 启用智能重新平衡
enable-adaptive-weighting = true       # 启用自适应权重
enable-auto-optimization = true        # 启用自动优化
```

### 配置说明

- **split-ratio**: 新窗口分割时的比例，范围0.1到0.9
- **auto-split-threshold**: 宽高比阈值，超过此值时自动选择分割方向
- **preferred-split-direction**: 首选分割方向
  - `'horizontal'`: 水平分割（创建垂直排列的窗口）
  - `'vertical'`: 垂直分割（创建水平排列的窗口）
  - `'auto'`: 自动选择最优方向
- **enable-intelligent-rebalancing**: 启用智能重新平衡功能
- **enable-adaptive-weighting**: 启用自适应权重分配
- **enable-auto-optimization**: 启用自动优化功能

## 使用方法

### 自动优化
智能BSP算法会在以下情况自动触发优化：

1. **窗口移动后**: 使用`move`命令移动窗口时
2. **容器规范化时**: 在容器结构规范化过程中
3. **布局变化时**: 当root container结构发生变化时

### 手动优化
你也可以手动触发BSP优化：

```bash
# 优化当前工作区的BSP布局
aerospace optimize-bsp

# 优化特定窗口所在的BSP布局
aerospace optimize-bsp --window-id <window-id>
```

在配置文件中绑定快捷键：
```toml
[mode.main.binding]
alt-shift-o = 'optimize-bsp'
```

## 算法工作原理

### 1. 结构验证和修复
- 检测空容器、单子容器等结构问题
- 自动移除不必要的嵌套
- 修复权重分配问题

### 2. 智能重新平衡
- 分析容器特征（宽高比、窗口数量、嵌套深度）
- 选择合适的重新平衡策略
- 计算最优权重分配

### 3. 自适应权重计算
```
基础权重 = 1.0 / 窗口数量
主窗口加成 = 基础权重 × 1.1 (第一个窗口)
中心偏向 = 根据窗口位置调整权重
最终权重 = 归一化处理确保总和为1.0
```

### 4. 分割方向优化
- 宽容器（宽高比 > 1.5）：优先垂直分割
- 高容器（宽高比 < 0.67）：优先水平分割
- 方形容器：交替分割方向

## 最佳实践

### 1. 推荐配置
```toml
# 启用所有智能功能
[bsp]
split-ratio = 0.5
auto-split-threshold = 1.2
preferred-split-direction = 'auto'
enable-intelligent-rebalancing = true
enable-adaptive-weighting = true
enable-auto-optimization = true

# 启用容器规范化
enable-normalization-flatten-containers = true
enable-normalization-opposite-orientation-for-nested-containers = true
```

### 2. 键位绑定建议
```toml
[mode.main.binding]
# 基本操作
alt-h = 'focus left'
alt-j = 'focus down'
alt-k = 'focus up'
alt-l = 'focus right'

# 移动窗口（自动触发优化）
alt-shift-h = 'move left'
alt-shift-j = 'move down'
alt-shift-k = 'move up'
alt-shift-l = 'move right'

# 手动优化
alt-shift-o = 'optimize-bsp'

# 布局切换
alt-shift-b = 'layout bsp'
```

### 3. 性能考虑
- 智能功能会增加一些计算开销
- 对于简单布局，可以禁用自适应权重以提高性能
- 大量窗口时建议启用所有优化功能

## 故障排除

### 常见问题

1. **窗口比例不合理**
   - 检查`split-ratio`配置
   - 尝试手动运行`optimize-bsp`
   - 确保启用了`enable-intelligent-rebalancing`

2. **分割方向不理想**
   - 调整`auto-split-threshold`值
   - 设置`preferred-split-direction`
   - 检查容器尺寸是否足够大

3. **性能问题**
   - 禁用`enable-adaptive-weighting`
   - 减少`auto-split-threshold`值
   - 考虑使用传统tiles布局

### 调试信息
启用调试模式查看BSP优化过程：
```bash
# 查看当前BSP树结构
aerospace debug-windows

# 查看配置信息
aerospace config
```

## 与传统BSP的区别

| 特性 | 传统BSP | 智能BSP |
|------|---------|---------|
| 窗口移动后 | 可能失效 | 自动优化 |
| 权重分配 | 固定比例 | 自适应调整 |
| 树结构 | 手动维护 | 自动优化 |
| 分割方向 | 固定规则 | 智能选择 |
| 容器合并 | 不支持 | 自动合并 |
| 错误恢复 | 有限 | 全面支持 |

智能BSP算法确保你的窗口布局始终保持最优状态，即使在复杂的窗口操作后也能自动恢复到理想的比例分配。