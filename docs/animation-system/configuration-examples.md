# Animation System Configuration Examples

This document provides practical configuration examples for different use cases and scenarios.

## Basic Configurations

### Default Configuration

```swift
let config = AnimationConfig.default
// enabled: true
// defaultDuration: 0.25
// easingFunction: .easeOut
// respectSystemPreferences: true
// All animation types enabled
// maxConcurrentAnimations: 10
// adaptiveQuality: true
// minFrameRate: 30.0
```

### Minimal Animation Setup

For users who prefer subtle animations:

```swift
var config = AnimationConfig.default
config.defaultDuration = 0.15
config.easingFunction = .linear
config.moveAnimationEnabled = true
config.resizeAnimationEnabled = false
config.layoutChangeAnimationEnabled = false
config.workspaceTransitionAnimationEnabled = true
WindowAnimationEngine.shared.updateConfiguration(config)
```

### Disabled Animations

For accessibility or performance reasons:

```swift
var config = AnimationConfig.default
config.enabled = false
config.respectSystemPreferences = true
WindowAnimationEngine.shared.updateConfiguration(config)
```

## Performance-Optimized Configurations

### High Performance Setup

For systems with limited resources:

```swift
var config = AnimationConfig.default
config.defaultDuration = 0.1
config.maxConcurrentAnimations = 3
config.adaptiveQuality = true
config.minFrameRate = 45.0
config.easingFunction = .linear  // Fastest to compute
WindowAnimationEngine.shared.updateConfiguration(config)
```

### Battery-Saving Configuration

Optimized for laptop battery life:

```swift
var config = AnimationConfig.default
config.defaultDuration = 0.2
config.maxConcurrentAnimations = 2
config.adaptiveQuality = true
config.minFrameRate = 24.0  // Lower threshold
config.workspaceTransitionAnimationEnabled = false  // Skip heavy animations
WindowAnimationEngine.shared.updateConfiguration(config)
```

### Gaming/High-Refresh Setup

For high-performance systems with high refresh rate displays:

```swift
var config = AnimationConfig.default
config.defaultDuration = 0.12
config.maxConcurrentAnimations = 15
config.adaptiveQuality = false  // Disable throttling
config.minFrameRate = 60.0
config.easingFunction = .easeOut
WindowAnimationEngine.shared.updateConfiguration(config)
```

## Use Case Specific Configurations

### Presentation Mode

Smooth, professional animations for presentations:

```swift
var config = AnimationConfig.default
config.defaultDuration = 0.4
config.easingFunction = .easeInOut
config.maxConcurrentAnimations = 5
config.adaptiveQuality = false  // Consistent quality
config.workspaceTransitionAnimationEnabled = true
WindowAnimationEngine.shared.updateConfiguration(config)
```

### Development Environment

Quick, efficient animations for coding:

```swift
var config = AnimationConfig.default
config.defaultDuration = 0.15
config.easingFunction = .easeOut
config.maxConcurrentAnimations = 8
config.layoutChangeAnimationEnabled = true  // Important for IDE layouts
config.resizeAnimationEnabled = true
WindowAnimationEngine.shared.updateConfiguration(config)
```

### Accessibility-First Configuration

Optimized for users with motion sensitivity:

```swift
var config = AnimationConfig.default
config.respectSystemPreferences = true
config.defaultDuration = 0.1  // Very short
config.easingFunction = .linear  // No acceleration
config.workspaceTransitionAnimationEnabled = false
config.layoutChangeAnimationEnabled = false
WindowAnimationEngine.shared.updateConfiguration(config)
```

### Media/Creative Work

Smooth animations that don't interfere with creative work:

```swift
var config = AnimationConfig.default
config.defaultDuration = 0.25
config.easingFunction = .easeOut
config.maxConcurrentAnimations = 6
config.adaptiveQuality = true
config.moveAnimationEnabled = true
config.resizeAnimationEnabled = false  // Avoid interfering with precise sizing
WindowAnimationEngine.shared.updateConfiguration(config)
```

## Dynamic Configuration Examples

### Adaptive Configuration Based on System State

```swift
class AdaptiveAnimationManager {
    private let engine = WindowAnimationEngine.shared
    
    func updateConfigurationForSystemState() {
        var config = AnimationConfig.default
        
        // Check battery level (iOS/macOS)
        let batteryLevel = getBatteryLevel()
        if batteryLevel < 0.2 {
            // Low battery - reduce animations
            config.defaultDuration = 0.1
            config.maxConcurrentAnimations = 2
            config.workspaceTransitionAnimationEnabled = false
        }
        
        // Check system load
        let cpuUsage = getCurrentCPUUsage()
        if cpuUsage > 70.0 {
            // High CPU - throttle animations
            config.maxConcurrentAnimations = 3
            config.minFrameRate = 20.0
        }
        
        // Check if external display connected
        if hasExternalDisplay() {
            // Presentation mode
            config.defaultDuration = 0.3
            config.easingFunction = .easeInOut
        }
        
        engine.updateConfiguration(config)
    }
}
```

### Time-Based Configuration

```swift
class TimeBasedAnimationManager {
    private let engine = WindowAnimationEngine.shared
    
    func updateConfigurationForTimeOfDay() {
        var config = AnimationConfig.default
        
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 9...17:  // Work hours
            config.defaultDuration = 0.15
            config.easingFunction = .easeOut
            config.layoutChangeAnimationEnabled = true
            
        case 18...22:  // Evening
            config.defaultDuration = 0.25
            config.easingFunction = .easeInOut
            config.workspaceTransitionAnimationEnabled = true
            
        default:  // Night/early morning
            config.defaultDuration = 0.1
            config.maxConcurrentAnimations = 3
            config.workspaceTransitionAnimationEnabled = false
        }
        
        engine.updateConfiguration(config)
    }
}
```

### Application-Specific Configuration

```swift
class ApplicationAwareAnimationManager {
    private let engine = WindowAnimationEngine.shared
    
    func updateConfigurationForActiveApplication(_ appName: String) {
        var config = AnimationConfig.default
        
        switch appName {
        case "Xcode", "Visual Studio Code":
            // IDE - quick, efficient animations
            config.defaultDuration = 0.12
            config.layoutChangeAnimationEnabled = true
            config.resizeAnimationEnabled = true
            
        case "Final Cut Pro", "Adobe Premiere":
            // Video editing - minimal animations to avoid interference
            config.defaultDuration = 0.08
            config.resizeAnimationEnabled = false
            config.workspaceTransitionAnimationEnabled = false
            
        case "Keynote", "PowerPoint":
            // Presentation software - smooth, professional animations
            config.defaultDuration = 0.3
            config.easingFunction = .easeInOut
            config.adaptiveQuality = false
            
        case "Games":
            // Gaming - disable animations for performance
            config.enabled = false
            
        default:
            // General use
            config = AnimationConfig.default
        }
        
        engine.updateConfiguration(config)
    }
}
```

## Configuration Validation Examples

### Safe Configuration Updates

```swift
extension AnimationConfig {
    static func createSafeConfiguration(
        duration: TimeInterval? = nil,
        easing: AnimationEasing? = nil,
        maxConcurrent: Int? = nil
    ) -> AnimationConfig {
        var config = AnimationConfig.default
        
        // Validate and apply duration
        if let duration = duration {
            config.defaultDuration = max(0.05, min(1.0, duration))
        }
        
        // Apply easing if provided
        if let easing = easing {
            config.easingFunction = easing
        }
        
        // Validate and apply concurrent limit
        if let maxConcurrent = maxConcurrent {
            config.maxConcurrentAnimations = max(1, min(20, maxConcurrent))
        }
        
        // Ensure configuration is valid
        let errors = config.validate()
        if !errors.isEmpty {
            print("Configuration validation errors: \(errors)")
            return AnimationConfig.default
        }
        
        return config
    }
}
```

### Configuration Presets

```swift
extension AnimationConfig {
    static let performance = AnimationConfig(
        enabled: true,
        defaultDuration: 0.1,
        easingFunction: .linear,
        respectSystemPreferences: true,
        moveAnimationEnabled: true,
        resizeAnimationEnabled: false,
        layoutChangeAnimationEnabled: false,
        workspaceTransitionAnimationEnabled: true,
        maxConcurrentAnimations: 3,
        adaptiveQuality: true,
        minFrameRate: 45.0
    )
    
    static let smooth = AnimationConfig(
        enabled: true,
        defaultDuration: 0.3,
        easingFunction: .easeInOut,
        respectSystemPreferences: true,
        moveAnimationEnabled: true,
        resizeAnimationEnabled: true,
        layoutChangeAnimationEnabled: true,
        workspaceTransitionAnimationEnabled: true,
        maxConcurrentAnimations: 8,
        adaptiveQuality: true,
        minFrameRate: 30.0
    )
    
    static let minimal = AnimationConfig(
        enabled: true,
        defaultDuration: 0.15,
        easingFunction: .easeOut,
        respectSystemPreferences: true,
        moveAnimationEnabled: true,
        resizeAnimationEnabled: false,
        layoutChangeAnimationEnabled: false,
        workspaceTransitionAnimationEnabled: false,
        maxConcurrentAnimations: 5,
        adaptiveQuality: true,
        minFrameRate: 30.0
    )
    
    static let accessibility = AnimationConfig(
        enabled: false,
        defaultDuration: 0.05,
        easingFunction: .linear,
        respectSystemPreferences: true,
        moveAnimationEnabled: false,
        resizeAnimationEnabled: false,
        layoutChangeAnimationEnabled: false,
        workspaceTransitionAnimationEnabled: false,
        maxConcurrentAnimations: 1,
        adaptiveQuality: true,
        minFrameRate: 60.0
    )
}

// Usage
WindowAnimationEngine.shared.updateConfiguration(.performance)
WindowAnimationEngine.shared.updateConfiguration(.smooth)
WindowAnimationEngine.shared.updateConfiguration(.minimal)
WindowAnimationEngine.shared.updateConfiguration(.accessibility)
```

## Testing Configurations

### Unit Test Configuration

```swift
extension AnimationConfig {
    static let testing = AnimationConfig(
        enabled: true,
        defaultDuration: 0.01,  // Very fast for tests
        easingFunction: .linear,
        respectSystemPreferences: false,  // Ignore system settings in tests
        moveAnimationEnabled: true,
        resizeAnimationEnabled: true,
        layoutChangeAnimationEnabled: true,
        workspaceTransitionAnimationEnabled: true,
        maxConcurrentAnimations: 50,  // Allow many concurrent for testing
        adaptiveQuality: false,  // Consistent behavior in tests
        minFrameRate: 60.0
    )
}
```

### Performance Testing Configuration

```swift
extension AnimationConfig {
    static let performanceTesting = AnimationConfig(
        enabled: true,
        defaultDuration: 0.25,
        easingFunction: .easeOut,
        respectSystemPreferences: false,
        moveAnimationEnabled: true,
        resizeAnimationEnabled: true,
        layoutChangeAnimationEnabled: true,
        workspaceTransitionAnimationEnabled: true,
        maxConcurrentAnimations: 20,  // Stress test
        adaptiveQuality: true,
        minFrameRate: 30.0
    )
}
```

## Configuration Migration

### Version Migration Example

```swift
class AnimationConfigMigration {
    static func migrateFromVersion1(_ oldConfig: [String: Any]) -> AnimationConfig {
        var config = AnimationConfig.default
        
        // Migrate old boolean "animations_enabled" to new "enabled"
        if let enabled = oldConfig["animations_enabled"] as? Bool {
            config.enabled = enabled
        }
        
        // Migrate old "animation_speed" to new duration
        if let speed = oldConfig["animation_speed"] as? String {
            switch speed {
            case "fast":
                config.defaultDuration = 0.15
            case "normal":
                config.defaultDuration = 0.25
            case "slow":
                config.defaultDuration = 0.4
            default:
                config.defaultDuration = 0.25
            }
        }
        
        // Migrate old "smooth_animations" to easing
        if let smooth = oldConfig["smooth_animations"] as? Bool {
            config.easingFunction = smooth ? .easeInOut : .linear
        }
        
        return config
    }
}
```

These configuration examples provide a comprehensive foundation for implementing animation behavior that suits different users, use cases, and system conditions. Choose the appropriate configuration based on your specific requirements and user preferences.