# Window Animation System - Developer Guide

## Architecture Overview

The Window Animation System is built with a modular architecture designed for performance, maintainability, and extensibility. The system consists of several key components working together to provide smooth window animations.

## Core Components

### WindowAnimationEngine

The central coordinator for all window animations. Implemented as a singleton with `@MainActor` annotation for thread safety.

**Key Responsibilities:**
- Managing animation lifecycle
- Performance monitoring and optimization
- Memory pooling and resource management
- System integration (accessibility, display refresh rate)
- Configuration management

**Performance Features:**
- Memory pooling for animation contexts
- CPU throttling during high system load
- Display refresh rate synchronization
- Adaptive quality control
- Animation batching

### WindowAnimationContext

Represents individual animation state and progress tracking.

**Key Features:**
- Immutable animation parameters
- Real-time progress calculation
- Memory pool compatibility
- Support for position, size, and opacity animations

### AnimationInterpolator

Handles mathematical interpolation between animation states.

**Capabilities:**
- Multiple easing functions (linear, easeIn, easeOut, easeInOut)
- Rectangle interpolation (position + size)
- Opacity interpolation
- Progress calculation with time-based precision

### AnimationConfig

Configuration structure for animation behavior and performance settings.

**Configuration Categories:**
- Core animation settings
- Per-operation toggles
- Performance optimization parameters
- Accessibility integration options

## Memory Management

### Animation Context Pooling

The system uses object pooling to minimize memory allocations during animations:

```swift
// Pool management in WindowAnimationEngine
private var animationContextPool: [WindowAnimationContext] = []
private let maxPoolSize = 20

private func getAnimationContextFromPool(...) -> WindowAnimationContext {
    if let pooledContext = animationContextPool.popLast() {
        pooledContext.reset(...)  // Reuse existing context
        return pooledContext
    } else {
        return WindowAnimationContext(...)  // Create new if pool empty
    }
}

private func returnAnimationContextToPool(_ context: WindowAnimationContext) {
    guard animationContextPool.count < maxPoolSize else { return }
    context.cleanup()
    animationContextPool.append(context)
}
```

### Memory Pool Benefits

- **Reduced GC pressure**: Fewer allocations during animation-heavy periods
- **Consistent performance**: Eliminates allocation spikes
- **Memory efficiency**: Reuses objects instead of creating new ones
- **Bounded memory usage**: Pool size limits prevent unbounded growth

## Performance Optimization

### CPU Throttling

The system monitors CPU usage and automatically throttles animation frame rates during high system load:

```swift
private func checkAndAdjustCPUThrottling() {
    let cpuUsage = getCurrentCPUUsage()
    
    if cpuUsage > 80.0 {
        cpuThrottleLevel = max(0.3, cpuThrottleLevel - 0.1)  // Increase throttling
    } else if cpuUsage < 50.0 {
        cpuThrottleLevel = min(1.0, cpuThrottleLevel + 0.1)  // Decrease throttling
    }
    
    updateTimerForThrottling()
}
```

### Display Refresh Rate Synchronization

Animations are synchronized to the display refresh rate for optimal smoothness:

```swift
private func detectDisplayRefreshRate() {
    guard let screen = NSScreen.main else {
        displayRefreshRate = 60.0
        return
    }
    
    if let displayLink = screen.displayLink {
        displayRefreshRate = 1.0 / displayLink.duration
    }
    
    displayRefreshRate = max(30.0, min(240.0, displayRefreshRate))
}

private func getOptimalTimerInterval() -> TimeInterval {
    let baseInterval = 1.0 / displayRefreshRate
    return baseInterval / cpuThrottleLevel
}
```

### Animation Batching

Multiple animation requests are batched together to reduce overhead:

```swift
private func addToBatch(_ window: Window, _ targetRect: Rect, ...) {
    batchedAnimations.append((window, targetRect, duration, easing))
    
    if batchTimer == nil {
        batchTimer = Timer.scheduledTimer(withTimeInterval: batchDelay, repeats: false) {
            self.processBatchedAnimations()
        }
    }
}
```

### Adaptive Quality Control

The system automatically adjusts animation quality based on performance metrics:

```swift
private func checkAndAdaptPerformance(currentTime: Date) {
    let averageFrameRate = frameRateHistory.reduce(0, +) / Double(frameRateHistory.count)
    
    performanceThresholdExceeded = averageFrameRate < config.minFrameRate
    
    if performanceThresholdExceeded {
        adaptQualityForPerformance()  // Reduce concurrent animations
    }
}
```

## Threading Model

### Main Actor Isolation

All animation operations are isolated to the main actor for thread safety:

```swift
@MainActor
class WindowAnimationEngine {
    // All methods run on main thread
    func animateWindow(...) async throws { ... }
}

@MainActor  
class WindowAnimationContext {
    // Animation state is main-thread only
    func update() -> Rect? { ... }
}
```

### Async/Await Integration

Animation methods use Swift's async/await for clean asynchronous code:

```swift
func animateWindow(
    _ window: Window,
    to targetRect: Rect,
    duration: TimeInterval? = nil,
    easing: AnimationEasing? = nil
) async throws {
    // Animation setup and execution
}
```

## Error Handling

### Animation Errors

The system defines specific error types for different failure scenarios:

```swift
enum AnimationError: Error, LocalizedError {
    case windowNotFound(UInt32)
    case animationCancelled
    case performanceThresholdExceeded
    case systemResourcesUnavailable
    case configurationInvalid(String)
    case duplicateAnimation(UInt32)
}
```

### Error Recovery

- **Window not found**: Animation is silently cancelled
- **Performance threshold exceeded**: Animation is applied immediately
- **System resources unavailable**: Fallback to immediate application
- **Configuration invalid**: Previous valid configuration is retained

## System Integration

### Accessibility Support

The system integrates with macOS accessibility preferences:

```swift
private func checkSystemMotionPreferences() {
    let reducedMotionEnabled = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    
    if reducedMotionEnabled && config.respectSystemPreferences {
        // Disable animations for accessibility
        var updatedConfig = config
        updatedConfig.enabled = false
        self.config = updatedConfig
        cancelAllAnimations()
    }
}
```

### Notification System

Configuration changes are broadcast via NotificationCenter:

```swift
extension Notification.Name {
    static let animationConfigurationDidChange = Notification.Name("animationConfigurationDidChange")
}

// Posted when configuration updates
NotificationCenter.default.post(
    name: .animationConfigurationDidChange,
    object: self,
    userInfo: ["oldConfig": oldConfig, "newConfig": newConfig]
)
```

## Testing Architecture

### Test Window Implementation

A specialized test window class provides controlled animation testing:

```swift
class TestWindow: Window {
    var mockRect: Rect?
    var mockAlpha: Double = 1.0
    
    override func getAxRect() async throws -> Rect? {
        return mockRect
    }
    
    override func setAxFrameImmediate(_ topLeftCorner: CGPoint, _ size: CGSize) {
        mockRect = Rect(topLeftX: topLeftCorner.x, topLeftY: topLeftCorner.y, 
                       width: size.width, height: size.height)
    }
}
```

### Performance Testing

Performance metrics are exposed for testing and monitoring:

```swift
struct AnimationPerformanceMetrics {
    let averageFrameRate: Double
    let droppedFrames: Int
    let activeAnimationCount: Int
    let totalAnimationsCompleted: Int
    let memoryUsage: Int
    let cpuThrottleLevel: Double
    let displayRefreshRate: Double
    let pooledContexts: Int
    let batchedAnimations: Int
}
```

## Extension Points

### Custom Easing Functions

Add new easing functions by extending the AnimationEasing enum:

```swift
enum AnimationEasing: String, CaseIterable {
    case linear = "linear"
    case easeIn = "ease-in"
    case easeOut = "ease-out"
    case easeInOut = "ease-in-out"
    // Add custom easing functions here
}
```

### Custom Animation Types

Extend AnimationType for new animation behaviors:

```swift
enum AnimationType {
    case move
    case resize
    case moveAndResize
    case layoutTransition
    case workspaceTransition
    case workspaceTransitionFadeOut
    case workspaceTransitionFadeIn
    // Add custom animation types here
}
```

### Performance Monitoring

Implement custom performance monitoring by observing metrics:

```swift
class AnimationPerformanceMonitor {
    func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let metrics = WindowAnimationEngine.shared.getPerformanceMetrics()
            self.logMetrics(metrics)
        }
    }
}
```

## Best Practices for Developers

### Configuration Management

- Always validate configuration before applying
- Use the default configuration as a starting point
- Test configuration changes thoroughly
- Provide fallback configurations for edge cases

### Memory Management

- Leverage the animation context pool
- Avoid creating custom animation contexts outside the pool
- Monitor memory usage in production
- Clean up resources properly in deinit methods

### Performance Optimization

- Enable adaptive quality for production deployments
- Monitor frame rate and adjust thresholds as needed
- Use batch operations for multiple simultaneous animations
- Profile animation performance under various system loads

### Error Handling

- Always handle animation errors gracefully
- Provide meaningful error messages for debugging
- Implement fallback behavior for failed animations
- Log errors for monitoring and debugging

### Testing

- Use TestWindow for unit testing animation logic
- Test performance under various system conditions
- Verify accessibility integration works correctly
- Test configuration validation thoroughly

## Debugging and Monitoring

### Debug Information

Get detailed debug information about the animation system:

```swift
let debugInfo = WindowAnimationEngine.shared.getDebugInfo()
for line in debugInfo {
    print(line)
}
```

### Performance Metrics

Monitor real-time performance:

```swift
let metrics = WindowAnimationEngine.shared.getPerformanceMetrics()
print("FPS: \(metrics.averageFrameRate)")
print("Memory: \(metrics.memoryUsage) bytes")
print("CPU Throttle: \(metrics.cpuThrottleLevel)")
```

### Animation State Inspection

Check animation state for specific windows:

```swift
let hasAnimation = WindowAnimationEngine.shared.hasActiveAnimation(for: window)
let context = WindowAnimationEngine.shared.getActiveAnimationContext(for: window)
print("Animation progress: \(context?.currentProgress ?? 0.0)")
```

This architecture provides a robust, performant, and maintainable foundation for window animations while supporting extensive customization and monitoring capabilities.