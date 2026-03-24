# Design Document

## Overview

This design document outlines the implementation of a smooth window animation system for AeroSpace. The system will provide visually appealing transitions for window movements, resizing, and layout changes while maintaining AeroSpace's performance characteristics and architectural principles.

The animation system will be built as a modular layer that intercepts window positioning and sizing operations, applying smooth transitions between states. It will integrate seamlessly with AeroSpace's existing layout engine and configuration system.

## Architecture

### Core Components

#### 1. Animation Engine (`WindowAnimationEngine`)
- **Purpose**: Central coordinator for all window animations
- **Responsibilities**:
  - Manages animation queues and scheduling
  - Coordinates multiple simultaneous animations
  - Handles animation cancellation and cleanup
  - Provides performance monitoring and adaptive quality control

#### 2. Animation Interpolator (`AnimationInterpolator`)
- **Purpose**: Handles the mathematical interpolation between animation states
- **Responsibilities**:
  - Implements various easing functions (linear, ease-in, ease-out, ease-in-out)
  - Calculates intermediate values for position and size transitions
  - Provides timing control and frame rate management

#### 3. Window Animation Context (`WindowAnimationContext`)
- **Purpose**: Tracks animation state for individual windows
- **Responsibilities**:
  - Stores source and target states (position, size)
  - Maintains animation progress and timing information
  - Handles animation-specific metadata

#### 4. Animation Configuration (`AnimationConfig`)
- **Purpose**: Manages user-configurable animation settings
- **Responsibilities**:
  - Stores animation preferences (duration, easing, enabled states)
  - Provides runtime configuration updates
  - Handles system accessibility preferences

### Integration Points

#### 1. Layout System Integration
The animation system will integrate with AeroSpace's existing layout system at these key points:

- **`layoutRecursive` method**: Intercept final window positioning calls
- **`setAxFrame` family of methods**: Replace immediate positioning with animated transitions
- **Layout refresh cycle**: Coordinate animations with layout updates

#### 2. Configuration System Integration
- Extend `Config` struct with `AnimationConfig`
- Add animation settings to TOML configuration parsing
- Support runtime configuration updates

#### 3. Window Management Integration
- Integrate with `MacWindow` and `Window` classes
- Coordinate with existing window state management
- Handle animation cleanup during window lifecycle events

## Components and Interfaces

### WindowAnimationEngine

```swift
@MainActor
class WindowAnimationEngine {
    // Configuration
    private var config: AnimationConfig
    
    // Animation state management
    private var activeAnimations: [UInt32: WindowAnimationContext] = [:]
    private var animationTimer: Timer?
    
    // Core methods
    func animateWindow(_ window: Window, to targetRect: Rect, duration: TimeInterval?)
    func animateWindowPosition(_ window: Window, to targetPosition: CGPoint, duration: TimeInterval?)
    func animateWindowSize(_ window: Window, to targetSize: CGSize, duration: TimeInterval?)
    
    // Animation control
    func cancelAnimation(for window: Window)
    func cancelAllAnimations()
    func pauseAnimations()
    func resumeAnimations()
    
    // Configuration
    func updateConfiguration(_ newConfig: AnimationConfig)
    
    // Performance monitoring
    func getPerformanceMetrics() -> AnimationPerformanceMetrics
}
```

### AnimationInterpolator

```swift
struct AnimationInterpolator {
    // Easing functions
    static func linear(_ progress: Double) -> Double
    static func easeIn(_ progress: Double) -> Double
    static func easeOut(_ progress: Double) -> Double
    static func easeInOut(_ progress: Double) -> Double
    
    // Interpolation methods
    static func interpolatePoint(_ from: CGPoint, _ to: CGPoint, progress: Double) -> CGPoint
    static func interpolateSize(_ from: CGSize, _ to: CGSize, progress: Double) -> CGSize
    static func interpolateRect(_ from: Rect, _ to: Rect, progress: Double) -> Rect
}
```

### WindowAnimationContext

```swift
class WindowAnimationContext {
    let windowId: UInt32
    let startTime: Date
    let duration: TimeInterval
    let easingFunction: (Double) -> Double
    
    let sourceRect: Rect
    let targetRect: Rect
    
    var currentProgress: Double { get }
    var isComplete: Bool { get }
    
    func getCurrentRect() -> Rect
    func update() -> Bool // Returns true if animation should continue
}
```

### AnimationConfig

```swift
struct AnimationConfig: ConvenienceCopyable {
    var enabled: Bool = true
    var defaultDuration: TimeInterval = 0.25
    var easingFunction: AnimationEasing = .easeOut
    var respectSystemPreferences: Bool = true
    
    // Per-operation settings
    var moveAnimationEnabled: Bool = true
    var resizeAnimationEnabled: Bool = true
    var layoutChangeAnimationEnabled: Bool = true
    var workspaceTransitionAnimationEnabled: Bool = true
    
    // Performance settings
    var maxConcurrentAnimations: Int = 10
    var adaptiveQuality: Bool = true
    var minFrameRate: Double = 30.0
}

enum AnimationEasing: String {
    case linear, easeIn, easeOut, easeInOut
}
```

## Data Models

### Animation State Tracking

```swift
struct AnimationState {
    let windowId: UInt32
    let animationType: AnimationType
    let startRect: Rect
    let targetRect: Rect
    let startTime: Date
    let duration: TimeInterval
    let easingFunction: AnimationEasing
}

enum AnimationType {
    case move
    case resize
    case moveAndResize
    case layoutTransition
    case workspaceTransition
}
```

### Performance Metrics

```swift
struct AnimationPerformanceMetrics {
    let averageFrameRate: Double
    let droppedFrames: Int
    let activeAnimationCount: Int
    let totalAnimationsCompleted: Int
    let averageAnimationDuration: TimeInterval
}
```

## Error Handling

### Animation Error Types

```swift
enum AnimationError: Error {
    case windowNotFound(UInt32)
    case animationCancelled
    case performanceThresholdExceeded
    case systemResourcesUnavailable
    case configurationInvalid(String)
}
```

### Error Recovery Strategies

1. **Animation Cancellation**: Gracefully cancel animations when errors occur
2. **Fallback to Immediate Updates**: Revert to non-animated updates when animations fail
3. **Performance Degradation**: Automatically reduce animation quality under resource constraints
4. **Configuration Validation**: Validate animation settings and provide sensible defaults

## Testing Strategy

### Unit Tests

1. **Animation Interpolation Tests**
   - Test easing function calculations
   - Verify interpolation accuracy for positions and sizes
   - Test edge cases (zero duration, identical start/end states)

2. **Animation Engine Tests**
   - Test animation queuing and scheduling
   - Verify cancellation and cleanup behavior
   - Test configuration updates

3. **Integration Tests**
   - Test integration with layout system
   - Verify window state consistency during animations
   - Test performance under various loads

### Performance Tests

1. **Frame Rate Tests**
   - Measure animation smoothness under different loads
   - Test adaptive quality adjustments
   - Verify performance on different hardware configurations

2. **Memory Usage Tests**
   - Monitor memory usage during long-running animations
   - Test cleanup of completed animations
   - Verify no memory leaks in animation contexts

### User Experience Tests

1. **Visual Consistency Tests**
   - Verify animations look smooth and natural
   - Test different easing functions for user preference
   - Ensure animations don't interfere with productivity

2. **Accessibility Tests**
   - Test respect for system motion preferences
   - Verify animations can be completely disabled
   - Test with screen readers and other accessibility tools

## Implementation Phases

### Phase 1: Core Animation Infrastructure
- Implement `WindowAnimationEngine` and basic animation scheduling
- Create `AnimationInterpolator` with essential easing functions
- Add basic configuration support

### Phase 2: Layout System Integration
- Integrate animation engine with `layoutRecursive` method
- Replace immediate window positioning with animated transitions
- Handle animation coordination during layout updates

### Phase 3: Advanced Features
- Implement performance monitoring and adaptive quality
- Add support for complex animation sequences
- Integrate with workspace transitions

### Phase 4: Configuration and Polish
- Complete TOML configuration integration
- Add runtime configuration updates
- Implement comprehensive error handling and recovery

## Performance Considerations

### Optimization Strategies

1. **Animation Batching**: Group multiple window animations to reduce overhead
2. **Lazy Evaluation**: Only calculate intermediate values when needed
3. **Memory Pooling**: Reuse animation context objects to reduce allocations
4. **Adaptive Quality**: Automatically adjust animation quality based on system performance

### Resource Management

1. **Timer Management**: Use a single timer for all animations to reduce system overhead
2. **Memory Cleanup**: Automatically clean up completed animations
3. **CPU Throttling**: Limit animation calculations when system is under load

### Platform-Specific Optimizations

1. **macOS Integration**: Leverage Core Animation when possible
2. **Accessibility API Optimization**: Minimize AX API calls during animations
3. **Display Sync**: Synchronize animations with display refresh rate

## Security and Privacy Considerations

1. **No Data Collection**: Animation system will not collect or transmit user data
2. **Local Processing**: All animation calculations performed locally
3. **Permission Respect**: Honor existing accessibility permissions without requiring additional access

## Future Extensibility

### Planned Extensions

1. **Custom Animation Curves**: Support for user-defined easing functions
2. **Animation Scripting**: Allow users to define custom animation sequences
3. **Visual Effects**: Add support for fade, scale, and rotation effects
4. **Sound Integration**: Optional audio feedback for animations

### API Design for Extensions

The animation system will provide extension points for:
- Custom interpolation functions
- Animation event callbacks
- Performance monitoring hooks
- Configuration validation plugins