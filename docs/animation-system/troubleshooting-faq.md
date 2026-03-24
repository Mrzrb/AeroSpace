# Animation System Troubleshooting & FAQ

## Common Issues and Solutions

### Animations Not Working

#### Problem: No animations are playing at all

**Possible Causes:**
1. Animations are disabled in configuration
2. System "Reduce Motion" setting is enabled
3. Animation engine is paused
4. Window references are invalid

**Solutions:**

```swift
// Check if animations are enabled
let config = WindowAnimationEngine.shared.currentConfiguration
print("Animations enabled: \(config.enabled)")

// Check system preferences
let reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
print("Reduce motion enabled: \(reducedMotion)")

// Check if engine is paused
let isPaused = WindowAnimationEngine.shared.areAnimationsPaused
print("Engine paused: \(isPaused)")

// Resume if paused
if isPaused {
    WindowAnimationEngine.shared.resumeAnimations()
}

// Enable animations if disabled
if !config.enabled {
    var newConfig = config
    newConfig.enabled = true
    WindowAnimationEngine.shared.updateConfiguration(newConfig)
}
```

#### Problem: Specific animation types not working

**Check individual animation type settings:**

```swift
let config = WindowAnimationEngine.shared.currentConfiguration
print("Move animations: \(config.moveAnimationEnabled)")
print("Resize animations: \(config.resizeAnimationEnabled)")
print("Layout animations: \(config.layoutChangeAnimationEnabled)")
print("Workspace animations: \(config.workspaceTransitionAnimationEnabled)")
```

### Performance Issues

#### Problem: Choppy or stuttering animations

**Diagnostic Steps:**

```swift
// Check performance metrics
let metrics = WindowAnimationEngine.shared.getPerformanceMetrics()
print("Average FPS: \(metrics.averageFrameRate)")
print("Dropped frames: \(metrics.droppedFrames)")
print("Active animations: \(metrics.activeAnimationCount)")
print("CPU throttle level: \(metrics.cpuThrottleLevel)")
```

**Solutions:**

1. **Enable adaptive quality:**
```swift
var config = WindowAnimationEngine.shared.currentConfiguration
config.adaptiveQuality = true
config.minFrameRate = 30.0
WindowAnimationEngine.shared.updateConfiguration(config)
```

2. **Reduce concurrent animations:**
```swift
var config = WindowAnimationEngine.shared.currentConfiguration
config.maxConcurrentAnimations = 3
WindowAnimationEngine.shared.updateConfiguration(config)
```

3. **Shorten animation duration:**
```swift
var config = WindowAnimationEngine.shared.currentConfiguration
config.defaultDuration = 0.15
WindowAnimationEngine.shared.updateConfiguration(config)
```

4. **Use simpler easing:**
```swift
var config = WindowAnimationEngine.shared.currentConfiguration
config.easingFunction = .linear
WindowAnimationEngine.shared.updateConfiguration(config)
```

#### Problem: High CPU usage during animations

**Check CPU throttling status:**

```swift
let metrics = WindowAnimationEngine.shared.getPerformanceMetrics()
print("CPU throttle level: \(metrics.cpuThrottleLevel)")

// If throttle level is low (< 0.5), system is under heavy load
if metrics.cpuThrottleLevel < 0.5 {
    print("System is under heavy CPU load")
    
    // Reduce animation load
    var config = WindowAnimationEngine.shared.currentConfiguration
    config.maxConcurrentAnimations = 2
    config.defaultDuration = 0.1
    WindowAnimationEngine.shared.updateConfiguration(config)
}
```

#### Problem: Memory usage growing over time

**Check memory metrics:**

```swift
let metrics = WindowAnimationEngine.shared.getPerformanceMetrics()
print("Memory usage: \(metrics.memoryUsage) bytes")
print("Pooled contexts: \(metrics.pooledContexts)")
print("Active animations: \(metrics.activeAnimationCount)")

// If memory usage is high, check for leaked animations
if metrics.activeAnimationCount > 20 {
    print("Warning: High number of active animations")
    WindowAnimationEngine.shared.cancelAllAnimations()
}
```

### Window-Specific Issues

#### Problem: Animation fails with "window not found" error

**Cause:** Window was closed or became invalid during animation setup.

**Solution:**
```swift
do {
    try await WindowAnimationEngine.shared.animateWindow(window, to: targetRect)
} catch AnimationError.windowNotFound(let windowId) {
    print("Window \(windowId) no longer exists")
    // Handle gracefully - window was probably closed
} catch {
    print("Other animation error: \(error)")
}
```

#### Problem: Animation appears to start but window doesn't move

**Diagnostic Steps:**

```swift
// Check if window has active animation
let hasAnimation = WindowAnimationEngine.shared.hasActiveAnimation(for: window)
print("Window has active animation: \(hasAnimation)")

// Get animation context for debugging
if let context = WindowAnimationEngine.shared.getActiveAnimationContext(for: window) {
    print("Animation progress: \(context.currentProgress)")
    print("Animation type: \(context.animationType)")
    print("Source rect: \(context.sourceRect)")
    print("Target rect: \(context.targetRect)")
}
```

**Possible Solutions:**

1. **Check window accessibility permissions:**
```swift
// Ensure app has accessibility permissions to control windows
let trusted = AXIsProcessTrusted()
if !trusted {
    print("App needs accessibility permissions")
}
```

2. **Verify window is controllable:**
```swift
// Test if window can be moved manually
do {
    let currentRect = try await window.getAxRect()
    print("Current window rect: \(currentRect)")
    
    // Try immediate move to test accessibility
    window.setAxFrameImmediate(CGPoint(x: 100, y: 100), CGSize(width: 800, height: 600))
} catch {
    print("Cannot control window: \(error)")
}
```

### Configuration Issues

#### Problem: Configuration validation errors

**Common validation errors and fixes:**

```swift
let config = AnimationConfig(
    enabled: true,
    defaultDuration: 5.0,  // Too long!
    easingFunction: .easeOut,
    maxConcurrentAnimations: 100,  // Too many!
    minFrameRate: 200.0  // Too high!
)

let errors = config.validate()
for error in errors {
    print("Validation error: \(error)")
}

// Fix validation errors
var fixedConfig = config
fixedConfig.defaultDuration = min(2.0, max(0.01, config.defaultDuration))
fixedConfig.maxConcurrentAnimations = min(50, max(1, config.maxConcurrentAnimations))
fixedConfig.minFrameRate = min(120.0, max(15.0, config.minFrameRate))
```

#### Problem: Configuration changes not taking effect

**Check configuration update:**

```swift
let oldConfig = WindowAnimationEngine.shared.currentConfiguration
var newConfig = oldConfig
newConfig.defaultDuration = 0.5

WindowAnimationEngine.shared.updateConfiguration(newConfig)

let updatedConfig = WindowAnimationEngine.shared.currentConfiguration
print("Duration changed: \(updatedConfig.defaultDuration == 0.5)")
```

**Listen for configuration change notifications:**

```swift
NotificationCenter.default.addObserver(
    forName: .animationConfigurationDidChange,
    object: nil,
    queue: .main
) { notification in
    if let userInfo = notification.userInfo,
       let newConfig = userInfo["newConfig"] as? AnimationConfig {
        print("Configuration updated: \(newConfig)")
    }
}
```

## Frequently Asked Questions

### General Questions

**Q: How do I completely disable animations?**

A: Set the `enabled` property to `false`:
```swift
var config = WindowAnimationEngine.shared.currentConfiguration
config.enabled = false
WindowAnimationEngine.shared.updateConfiguration(config)
```

**Q: Can I have different animation settings for different types of operations?**

A: Yes, use the per-operation settings:
```swift
var config = WindowAnimationEngine.shared.currentConfiguration
config.moveAnimationEnabled = true
config.resizeAnimationEnabled = false
config.layoutChangeAnimationEnabled = true
config.workspaceTransitionAnimationEnabled = false
WindowAnimationEngine.shared.updateConfiguration(config)
```

**Q: How do I make animations faster/slower?**

A: Adjust the `defaultDuration` property:
```swift
var config = WindowAnimationEngine.shared.currentConfiguration
config.defaultDuration = 0.1  // Faster
// or
config.defaultDuration = 0.5  // Slower
WindowAnimationEngine.shared.updateConfiguration(config)
```

**Q: What's the difference between the easing functions?**

A: 
- `linear`: Constant speed throughout
- `easeIn`: Starts slow, accelerates
- `easeOut`: Starts fast, decelerates (most natural)
- `easeInOut`: Slow start and end, fast middle (smoothest)

### Performance Questions

**Q: How many animations can run simultaneously?**

A: By default, up to 10 concurrent animations. Adjust with:
```swift
var config = WindowAnimationEngine.shared.currentConfiguration
config.maxConcurrentAnimations = 5  // Reduce for better performance
WindowAnimationEngine.shared.updateConfiguration(config)
```

**Q: How do I optimize animations for battery life?**

A: Use a battery-optimized configuration:
```swift
var config = WindowAnimationEngine.shared.currentConfiguration
config.defaultDuration = 0.15  // Shorter animations
config.maxConcurrentAnimations = 3  // Fewer concurrent
config.adaptiveQuality = true  // Enable throttling
config.minFrameRate = 24.0  // Lower threshold
WindowAnimationEngine.shared.updateConfiguration(config)
```

**Q: What is adaptive quality and should I enable it?**

A: Adaptive quality automatically reduces animation quality when system performance is poor. It's recommended for most users:
```swift
var config = WindowAnimationEngine.shared.currentConfiguration
config.adaptiveQuality = true
config.minFrameRate = 30.0  // Threshold for quality reduction
WindowAnimationEngine.shared.updateConfiguration(config)
```

### Accessibility Questions

**Q: How do I respect system accessibility preferences?**

A: Enable `respectSystemPreferences`:
```swift
var config = WindowAnimationEngine.shared.currentConfiguration
config.respectSystemPreferences = true
WindowAnimationEngine.shared.updateConfiguration(config)
```

**Q: How do I provide custom accessibility behavior?**

A: Disable system preference respect and implement custom logic:
```swift
var config = WindowAnimationEngine.shared.currentConfiguration
config.respectSystemPreferences = false

// Implement custom accessibility logic
if userPrefersReducedMotion() {
    config.enabled = false
    config.defaultDuration = 0.05
}

WindowAnimationEngine.shared.updateConfiguration(config)
```

### Development Questions

**Q: How do I test animations in unit tests?**

A: Use a test-specific configuration:
```swift
// In test setup
var testConfig = AnimationConfig.default
testConfig.defaultDuration = 0.01  // Very fast
testConfig.respectSystemPreferences = false
testConfig.adaptiveQuality = false
WindowAnimationEngine.shared.updateConfiguration(testConfig)

// Test animation
try await WindowAnimationEngine.shared.animateWindow(testWindow, to: targetRect)

// Verify result
let finalRect = try await testWindow.getAxRect()
XCTAssertEqual(finalRect, targetRect)
```

**Q: How do I debug animation issues?**

A: Use the debug information methods:
```swift
// Get detailed debug info
let debugInfo = WindowAnimationEngine.shared.getDebugInfo()
for line in debugInfo {
    print(line)
}

// Get performance metrics
let metrics = WindowAnimationEngine.shared.getPerformanceMetrics()
print("Performance: \(metrics)")

// Check specific window animation
let hasAnimation = WindowAnimationEngine.shared.hasActiveAnimation(for: window)
print("Window has animation: \(hasAnimation)")
```

**Q: How do I handle animation errors properly?**

A: Use comprehensive error handling:
```swift
do {
    try await WindowAnimationEngine.shared.animateWindow(window, to: targetRect)
} catch AnimationError.windowNotFound(let windowId) {
    // Window was closed
    print("Window \(windowId) no longer exists")
} catch AnimationError.performanceThresholdExceeded {
    // System is under heavy load
    print("Animation skipped due to performance")
    // Apply change immediately
    window.setAxFrameImmediate(targetPoint, targetSize)
} catch AnimationError.configurationInvalid(let message) {
    // Configuration problem
    print("Configuration error: \(message)")
    // Reset to default configuration
    WindowAnimationEngine.shared.updateConfiguration(.default)
} catch {
    // Other errors
    print("Animation error: \(error)")
}
```

## Diagnostic Tools

### Performance Monitor

```swift
class AnimationPerformanceMonitor {
    private var timer: Timer?
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let metrics = WindowAnimationEngine.shared.getPerformanceMetrics()
            
            if metrics.averageFrameRate < 20.0 {
                print("⚠️ Low frame rate: \(metrics.averageFrameRate)")
            }
            
            if metrics.activeAnimationCount > 15 {
                print("⚠️ High animation count: \(metrics.activeAnimationCount)")
            }
            
            if metrics.memoryUsage > 1024 * 1024 {  // 1MB
                print("⚠️ High memory usage: \(metrics.memoryUsage) bytes")
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
}
```

### Configuration Validator

```swift
class AnimationConfigValidator {
    static func validateAndSuggestFixes(_ config: AnimationConfig) -> [String] {
        var suggestions: [String] = []
        
        if config.defaultDuration > 0.5 {
            suggestions.append("Consider reducing defaultDuration (currently \(config.defaultDuration)s) for better user experience")
        }
        
        if config.maxConcurrentAnimations > 15 {
            suggestions.append("High maxConcurrentAnimations (\(config.maxConcurrentAnimations)) may impact performance")
        }
        
        if !config.adaptiveQuality && config.maxConcurrentAnimations > 8 {
            suggestions.append("Enable adaptiveQuality for better performance with high concurrent animations")
        }
        
        if config.minFrameRate < 24.0 {
            suggestions.append("minFrameRate (\(config.minFrameRate)) is very low, animations may appear choppy")
        }
        
        return suggestions
    }
}
```

This troubleshooting guide should help resolve most common issues with the animation system. For additional support, check the debug output and performance metrics to identify specific problems.