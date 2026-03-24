# Window Animation System - User Guide

## Overview

The Window Animation System provides smooth, configurable animations for window operations including moving, resizing, and workspace transitions. This guide covers how to configure and use the animation system effectively.

## Quick Start

### Enabling/Disabling Animations

Animations are enabled by default. To disable all animations:

```swift
var config = AnimationConfig.default
config.enabled = false
WindowAnimationEngine.shared.updateConfiguration(config)
```

### Basic Configuration

```swift
var config = AnimationConfig.default
config.defaultDuration = 0.3        // Animation duration in seconds
config.easingFunction = .easeInOut   // Animation easing
WindowAnimationEngine.shared.updateConfiguration(config)
```

## Configuration Options

### Core Settings

- **enabled**: Master switch for all animations (default: `true`)
- **defaultDuration**: Default animation duration in seconds (default: `0.25`)
- **easingFunction**: Animation easing curve (default: `.easeOut`)
- **respectSystemPreferences**: Honor system accessibility settings (default: `true`)

### Per-Operation Settings

Control specific types of animations:

- **moveAnimationEnabled**: Enable/disable window move animations
- **resizeAnimationEnabled**: Enable/disable window resize animations  
- **layoutChangeAnimationEnabled**: Enable/disable layout transition animations
- **workspaceTransitionAnimationEnabled**: Enable/disable workspace change animations

### Performance Settings

- **maxConcurrentAnimations**: Maximum simultaneous animations (default: `10`)
- **adaptiveQuality**: Enable performance-based quality adjustment (default: `true`)
- **minFrameRate**: Minimum acceptable frame rate (default: `30.0`)

## Animation Types

### Window Movement

Animate a window to a new position:

```swift
try await WindowAnimationEngine.shared.animateWindowPosition(
    window,
    to: CGPoint(x: 100, y: 100),
    duration: 0.3,
    easing: .easeOut
)
```

### Window Resizing

Animate a window to a new size:

```swift
try await WindowAnimationEngine.shared.animateWindowSize(
    window,
    to: CGSize(width: 800, height: 600),
    duration: 0.25,
    easing: .easeInOut
)
```

### Combined Move and Resize

Animate both position and size simultaneously:

```swift
let targetRect = Rect(topLeftX: 100, topLeftY: 100, width: 800, height: 600)
try await WindowAnimationEngine.shared.animateWindow(
    window,
    to: targetRect,
    duration: 0.3,
    easing: .easeOut
)
```

### Workspace Transitions

Animate windows during workspace changes:

```swift
// Fade out when leaving workspace
try await WindowAnimationEngine.shared.animateWindowFadeOut(window)

// Fade in when entering workspace  
try await WindowAnimationEngine.shared.animateWindowFadeIn(window)

// Move between workspaces
try await WindowAnimationEngine.shared.animateWorkspaceTransition(
    window,
    to: targetRect
)
```

### Batch Operations

Animate multiple windows simultaneously:

```swift
let animations = [
    (window1, rect1, 0.3, AnimationEasing.easeOut),
    (window2, rect2, 0.25, AnimationEasing.easeInOut),
    (window3, rect3, 0.2, AnimationEasing.linear)
]

try await WindowAnimationEngine.shared.batchAnimateWindows(animations)
```

## Easing Functions

Choose from several easing curves:

- **linear**: Constant speed throughout
- **easeIn**: Slow start, fast finish
- **easeOut**: Fast start, slow finish (default)
- **easeInOut**: Slow start and finish, fast middle

## Performance Optimization

### Adaptive Quality

When enabled, the system automatically adjusts animation quality based on performance:

```swift
var config = AnimationConfig.default
config.adaptiveQuality = true
config.minFrameRate = 30.0  // Target minimum FPS
WindowAnimationEngine.shared.updateConfiguration(config)
```

### Concurrent Animation Limits

Control how many animations run simultaneously:

```swift
var config = AnimationConfig.default
config.maxConcurrentAnimations = 5  // Reduce for better performance
WindowAnimationEngine.shared.updateConfiguration(config)
```

### Performance Monitoring

Get real-time performance metrics:

```swift
let metrics = WindowAnimationEngine.shared.getPerformanceMetrics()
print("Average FPS: \(metrics.averageFrameRate)")
print("Active animations: \(metrics.activeAnimationCount)")
print("Memory usage: \(metrics.memoryUsage) bytes")
```

## Accessibility Integration

### System Preferences

The animation system respects macOS accessibility settings:

```swift
var config = AnimationConfig.default
config.respectSystemPreferences = true  // Honor "Reduce Motion" setting
WindowAnimationEngine.shared.updateConfiguration(config)
```

When "Reduce Motion" is enabled in System Preferences, animations are automatically disabled and windows move instantly to their target positions.

### Manual Accessibility Mode

Disable animations for accessibility without changing system settings:

```swift
var config = AnimationConfig.default
config.enabled = false
config.respectSystemPreferences = false
WindowAnimationEngine.shared.updateConfiguration(config)
```

## Animation Control

### Pausing and Resuming

```swift
// Pause all animations
WindowAnimationEngine.shared.pauseAnimations()

// Resume animations
WindowAnimationEngine.shared.resumeAnimations()

// Check if paused
let isPaused = WindowAnimationEngine.shared.areAnimationsPaused
```

### Canceling Animations

```swift
// Cancel animation for specific window
WindowAnimationEngine.shared.cancelAnimation(for: window)

// Cancel all animations
WindowAnimationEngine.shared.cancelAllAnimations()

// Check if window has active animation
let hasAnimation = WindowAnimationEngine.shared.hasActiveAnimation(for: window)
```

## Troubleshooting

### Poor Performance

If animations are choppy or slow:

1. **Enable adaptive quality**: Automatically adjusts based on performance
2. **Reduce concurrent animations**: Lower `maxConcurrentAnimations`
3. **Increase minimum frame rate**: Higher `minFrameRate` triggers quality adjustments sooner
4. **Shorten animation duration**: Faster animations are less noticeable when dropped

```swift
var config = AnimationConfig.default
config.adaptiveQuality = true
config.maxConcurrentAnimations = 3
config.minFrameRate = 45.0
config.defaultDuration = 0.15
WindowAnimationEngine.shared.updateConfiguration(config)
```

### Animations Not Working

1. **Check if enabled**: Verify `config.enabled = true`
2. **Check system preferences**: "Reduce Motion" may be enabled
3. **Check specific animation types**: Individual animation types may be disabled
4. **Verify window validity**: Ensure the window still exists

### Memory Issues

Monitor memory usage and adjust pool settings:

```swift
let metrics = WindowAnimationEngine.shared.getPerformanceMetrics()
print("Memory usage: \(metrics.memoryUsage) bytes")
print("Pooled contexts: \(metrics.pooledContexts)")
```

## Best Practices

### Duration Guidelines

- **Quick operations**: 0.15-0.2 seconds
- **Standard operations**: 0.25-0.3 seconds  
- **Complex transitions**: 0.3-0.5 seconds
- **Avoid**: Durations over 0.5 seconds (feels sluggish)

### Easing Selection

- **Window moves**: `easeOut` (feels natural)
- **Resizing**: `easeInOut` (smooth start and finish)
- **Workspace transitions**: `easeInOut` (professional feel)
- **Quick corrections**: `linear` (direct and efficient)

### Performance Considerations

- Enable adaptive quality for varying system loads
- Use batch operations for multiple simultaneous animations
- Monitor performance metrics in production
- Respect user accessibility preferences

### Error Handling

Always handle animation errors gracefully:

```swift
do {
    try await WindowAnimationEngine.shared.animateWindow(window, to: targetRect)
} catch AnimationError.windowNotFound {
    // Window was closed during animation
    print("Window no longer exists")
} catch AnimationError.performanceThresholdExceeded {
    // System is under heavy load
    print("Animation skipped due to performance")
} catch {
    print("Animation error: \(error)")
}
```

## Configuration Examples

### High Performance Setup

```swift
var config = AnimationConfig.default
config.defaultDuration = 0.15
config.maxConcurrentAnimations = 3
config.adaptiveQuality = true
config.minFrameRate = 45.0
WindowAnimationEngine.shared.updateConfiguration(config)
```

### Accessibility-Friendly Setup

```swift
var config = AnimationConfig.default
config.respectSystemPreferences = true
config.defaultDuration = 0.2  // Shorter for less distraction
config.easingFunction = .easeOut  // Gentle easing
WindowAnimationEngine.shared.updateConfiguration(config)
```

### Minimal Animation Setup

```swift
var config = AnimationConfig.default
config.moveAnimationEnabled = true
config.resizeAnimationEnabled = false
config.layoutChangeAnimationEnabled = false
config.workspaceTransitionAnimationEnabled = true
config.defaultDuration = 0.1
WindowAnimationEngine.shared.updateConfiguration(config)
```