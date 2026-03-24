# GPU 支持和运动特效配置指南

## 概述

AeroSpace 的动画系统支持 GPU 硬件加速和高级运动特效，包括运动模糊、粒子效果和涟漪效果。本指南将详细介绍如何配置和优化这些功能。

## GPU 硬件加速配置

### 1. 基础 GPU 配置

在 `~/.aerospace.toml` 配置文件中添加 GPU 加速设置：

```toml
[animations]
    # 启用动画系统
    enabled = true
    
    # GPU 加速设置
    gpu-acceleration-enabled = true
    gpu-acceleration-mode = "automatic"  # "disabled", "automatic", "forced"
    gpu-batch-size = 32
    gpu-fallback-threshold = 0.8
    
    # 基础动画设置
    default-duration = 0.25
    easing-function = "ease-out"
    max-concurrent-animations = 10
    adaptive-quality = true
    min-frame-rate = 30.0
```

### 2. GPU 加速模式说明

- **disabled**: 完全禁用 GPU 加速，使用 CPU 处理所有动画
- **automatic**: 系统自动检测并在合适时使用 GPU 加速（推荐）
- **forced**: 强制使用 GPU 加速（如果可用）

### 3. GPU 性能参数

```toml
[animations]
    # GPU 批处理大小（1-256）
    gpu-batch-size = 32
    
    # GPU 回退阈值（0.0-1.0）
    # 当 GPU 利用率超过此值时回退到 CPU
    gpu-fallback-threshold = 0.8
    
    # 自适应质量调整
    adaptive-quality = true
```

## 运动特效配置

### 1. 启用视觉特效

```toml
[visual-effects]
    # 主开关
    enabled = true
    
    # 自适应质量
    adaptive-quality = true
    
    # 性能阈值（毫秒）
    performance-threshold = 16.67  # ~60fps
```

### 2. 运动模糊效果

```toml
[visual-effects.motion-blur]
    # 启用运动模糊
    enabled = true
    
    # 触发运动模糊的速度阈值（像素/秒）
    velocity-threshold = 100.0
    
    # 最大运动模糊速度
    max-speed = 1000.0
    
    # 最大模糊强度（0.0-1.0）
    max-intensity = 0.8
    
    # 自动运动效果
    automatic-effects = true
```

### 3. 残影效果

```toml
[visual-effects.afterimage]
    # 启用残影效果
    enabled = true
    
    # 残影轨迹长度
    trail-length = 5
    
    # 透明度衰减率（0.1-1.0）
    opacity-decay = 0.7
    
    # 更新间隔（秒）
    update-interval = 0.033  # ~30fps
```

### 4. 粒子效果

```toml
[visual-effects.particles]
    # 启用粒子效果
    enabled = true
    
    # 粒子数量
    count = 20
    
    # 粒子大小
    size-width = 4.0
    size-height = 4.0
    
    # 效果持续时间（秒）
    duration = 1.0
    
    # 粒子扩散范围（像素）
    spread = 50.0
    
    # 粒子速度（像素/秒）
    velocity = 100.0
    
    # 可用粒子类型
    available-types = ["spark", "bubble", "star", "geometric"]
    
    # 默认粒子类型
    default-type = "spark"
```

### 5. 涟漪效果

```toml
[visual-effects.ripple]
    # 启用涟漪效果
    enabled = true
    
    # 涟漪传播速度（像素/秒）
    speed = 300.0
    
    # 最大涟漪半径（像素）
    max-radius = 200.0
    
    # 涟漪持续时间（秒）
    duration = 0.8
    
    # 涟漪强度（0.0-1.0）
    intensity = 0.6
```

## 完整配置示例

我们提供了多个预设配置文件，位于 `docs/config-examples/` 目录：

- `default-config.toml` - 默认配置，包含所有新功能的说明
- `advanced-effects-config.toml` - 高级特效配置，展示所有功能
- `performance-optimized-config.toml` - 性能优化配置
- `accessibility-friendly-config.toml` - 无障碍友好配置

### 高性能配置（适合游戏和高刷新率显示器）

```toml
[animations]
    enabled = true
    default-duration = 0.12
    easing-function = "ease-out"
    max-concurrent-animations = 15
    adaptive-quality = false
    min-frame-rate = 60.0
    
    # GPU 设置
    gpu-acceleration-enabled = true
    gpu-acceleration-mode = "forced"
    gpu-batch-size = 64
    gpu-fallback-threshold = 0.9

[visual-effects]
    enabled = true
    adaptive-quality = true
    performance-threshold = 8.33  # 120fps
    
    [visual-effects.motion-blur]
        enabled = true
        velocity-threshold = 150.0
        max-speed = 1500.0
        max-intensity = 1.0
        automatic-effects = true
    
    [visual-effects.particles]
        enabled = true
        count = 30
        size-width = 6.0
        size-height = 6.0
        duration = 0.8
        default-type = "geometric"
    
    [visual-effects.ripple]
        enabled = true
        speed = 400.0
        max-radius = 250.0
        duration = 0.6
        intensity = 0.8
```

### 节能配置（适合笔记本电脑）

```toml
[animations]
    enabled = true
    default-duration = 0.2
    easing-function = "linear"
    max-concurrent-animations = 3
    adaptive-quality = true
    min-frame-rate = 24.0
    
    # GPU 设置
    gpu-acceleration-enabled = true
    gpu-acceleration-mode = "automatic"
    gpu-batch-size = 16
    gpu-fallback-threshold = 0.6

[visual-effects]
    enabled = false  # 禁用特效以节省电量
```

### 无障碍配置（适合运动敏感用户）

```toml
[animations]
    enabled = true
    default-duration = 0.1
    easing-function = "linear"
    max-concurrent-animations = 2
    respect-system-preferences = true
    
    # 禁用复杂动画
    move-animation-enabled = true
    resize-animation-enabled = false
    layout-change-animation-enabled = false
    workspace-transition-animation-enabled = false
    
    # GPU 设置
    gpu-acceleration-enabled = false

[visual-effects]
    enabled = false  # 完全禁用视觉特效
```

## 编程配置方式

### Swift 代码配置

```swift
import AppBundle

// 配置 GPU 加速
var animationConfig = AnimationConfig.default
animationConfig.gpuAccelerationEnabled = true
animationConfig.gpuAccelerationMode = .automatic
animationConfig.gpuBatchSize = 32
animationConfig.gpuFallbackThreshold = 0.8

WindowAnimationEngine.shared.updateConfiguration(animationConfig)

// 配置视觉特效
var visualConfig = VisualEffectsConfig.default
visualConfig.enabled = true
visualConfig.motionBlurEnabled = true
visualConfig.particleEffectsEnabled = true
visualConfig.rippleEffectsEnabled = true

// 运动模糊设置
visualConfig.motionBlurVelocityThreshold = 100.0
visualConfig.maxMotionBlurIntensity = 0.8

// 粒子效果设置
visualConfig.particleCount = 20
visualConfig.particleSize = CGSize(width: 4.0, height: 4.0)
visualConfig.defaultParticleType = .spark

// 涟漪效果设置
visualConfig.rippleSpeed = 300.0
visualConfig.rippleMaxRadius = 200.0

VisualEffectsEngine.shared.updateConfiguration(visualConfig)
```

### 动态配置调整

```swift
// 根据系统状态动态调整
class DynamicEffectsManager {
    func adjustForSystemState() {
        let resourceInfo = HardwareAcceleration.getResourceInfo()
        
        var config = VisualEffectsConfig.default
        
        // 根据 GPU 利用率调整
        if let info = resourceInfo, info.gpuUtilization > 0.8 {
            config.particleCount = 10  // 减少粒子数量
            config.effectQualityLevel = .medium
        }
        
        // 根据热状态调整
        if let info = resourceInfo, info.thermalState == .serious {
            config.enabled = false  // 禁用特效
        }
        
        // 根据电源状态调整
        if let info = resourceInfo, info.powerState == .powerSaver {
            config.particleEffectsEnabled = false
            config.motionBlurEnabled = false
        }
        
        VisualEffectsEngine.shared.updateConfiguration(config)
    }
}
```

## 性能监控和调试

### 1. 检查 GPU 支持状态

```swift
let status = HardwareAcceleration.detectCapabilities()
switch status {
case .available(let info):
    print("GPU 加速可用: \(info.name)")
    print("离散 GPU: \(info.isDiscrete)")
    print("统一内存: \(info.hasUnifiedMemory)")
case .unavailable(let reason):
    print("GPU 加速不可用: \(reason)")
case .disabled(let reason):
    print("GPU 加速已禁用: \(reason)")
}
```

### 2. 监控性能指标

```swift
// 获取动画性能指标
let metrics = WindowAnimationEngine.shared.getPerformanceMetrics()
print("平均帧率: \(metrics.averageFrameRate)")
print("活跃动画数: \(metrics.activeAnimationCount)")
print("内存使用: \(metrics.memoryUsage) bytes")

// 获取 GPU 资源信息
if let resourceInfo = HardwareAcceleration.getResourceInfo() {
    print("GPU 利用率: \(resourceInfo.gpuUtilization * 100)%")
    print("可用内存: \(resourceInfo.availableMemory / 1024 / 1024) MB")
    print("热状态: \(resourceInfo.thermalState)")
}
```

### 3. 调试特效

```swift
// 启用调试模式
var config = VisualEffectsConfig.default
config.enabled = true

// 单独测试各种特效
config.motionBlurEnabled = true
config.particleEffectsEnabled = false
config.rippleEffectsEnabled = false

VisualEffectsEngine.shared.updateConfiguration(config)

// 手动触发特效
let window = // 获取窗口
let velocity = CGVector(dx: 200, dy: 100)
VisualEffectsEngine.shared.applyMotionEffects(
    for: window,
    velocity: velocity,
    duration: 1.0
)
```

## 故障排除

### 常见问题

1. **GPU 加速不工作**
   - 检查系统是否支持 Metal
   - 确认 GPU 驱动程序是最新的
   - 检查 `gpu-acceleration-mode` 设置

2. **特效性能差**
   - 降低粒子数量
   - 减少并发特效数量
   - 启用自适应质量

3. **内存使用过高**
   - 减少残影轨迹长度
   - 降低特效质量等级
   - 启用 GPU 回退机制

### 性能优化建议

1. **根据硬件调整**
   - 集成 GPU: 使用较低的特效设置
   - 独立 GPU: 可以使用更高的特效设置
   - 高刷新率显示器: 调整性能阈值

2. **根据使用场景调整**
   - 游戏时: 禁用特效以获得最佳性能
   - 演示时: 启用所有特效以获得最佳视觉效果
   - 电池供电: 使用节能配置

3. **监控和调整**
   - 定期检查性能指标
   - 根据用户反馈调整设置
   - 使用自适应配置

## 总结

通过合理配置 GPU 加速和运动特效，可以显著提升 AeroSpace 的视觉体验。建议：

1. 从 `automatic` GPU 模式开始
2. 根据系统性能调整特效强度
3. 启用自适应质量以平衡性能和视觉效果
4. 定期监控性能指标并调整配置
5. 为不同使用场景准备多套配置预设

记住，最佳配置因硬件和使用习惯而异，建议根据实际使用情况进行微调。