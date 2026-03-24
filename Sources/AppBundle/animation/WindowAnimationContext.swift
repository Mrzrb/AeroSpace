import Foundation
import Common
import CoreGraphics

/// Represents the type of animation being performed
enum AnimationType {
    case move
    case resize
    case moveAndResize
    case layoutTransition
    case workspaceTransition
    case workspaceTransitionFadeOut
    case workspaceTransitionFadeIn
}

/// Tracks animation state for individual windows
@MainActor
class WindowAnimationContext {

    // MARK: - Properties

    var windowId: UInt32
    var animationType: AnimationType
    var startTime: Date
    var duration: TimeInterval
    var easingFunction: AnimationEasing
    var maxOvershootPixels: Double

    var sourceRect: Rect
    var targetRect: Rect

    // Opacity animation support
    var sourceOpacity: Double?
    var targetOpacity: Double?

    private var _isComplete: Bool = false
    private var _isCancelled: Bool = false

    // MARK: - Computed Properties

    /// Current progress of the animation (0.0 to 1.0)
    var currentProgress: Double {
        if _isComplete || _isCancelled {
            return 1.0
        }
        return AnimationInterpolator.calculateProgress(
            startTime: startTime,
            duration: duration,
            currentTime: Date(),
        )
    }

    /// Whether the animation has completed
    var isComplete: Bool {
        if _isComplete {
            return true
        }
        let progress = AnimationInterpolator.calculateProgress(
            startTime: startTime,
            duration: duration,
            currentTime: Date(),
        )
        return progress >= 1.0
    }

    /// Whether the animation has been cancelled
    var isCancelled: Bool {
        return _isCancelled
    }

    /// Whether the animation is currently active (not complete and not cancelled)
    var isActive: Bool {
        return !isComplete && !isCancelled
    }

    // MARK: - Initialization

    init(
        windowId: UInt32,
        animationType: AnimationType,
        sourceRect: Rect,
        targetRect: Rect,
        duration: TimeInterval,
        easingFunction: AnimationEasing = .easeOut,
        startTime: Date = Date(),
        sourceOpacity: Double? = nil,
        targetOpacity: Double? = nil,
        maxOvershootPixels: Double = 0
    ) {
        self.windowId = windowId
        self.animationType = animationType
        self.sourceRect = sourceRect
        self.targetRect = targetRect
        self.duration = duration
        self.easingFunction = easingFunction
        self.startTime = startTime
        self.sourceOpacity = sourceOpacity
        self.targetOpacity = targetOpacity
        self.maxOvershootPixels = maxOvershootPixels
    }

    // MARK: - Animation Lifecycle Methods

    /// Start the animation (called automatically during initialization)
    func start() {
        _isComplete = false
        _isCancelled = false
    }

    /// Reset the context for reuse from memory pool
    func reset(
        windowId: UInt32,
        animationType: AnimationType,
        sourceRect: Rect,
        targetRect: Rect,
        duration: TimeInterval,
        easingFunction: AnimationEasing,
        sourceOpacity: Double? = nil,
        targetOpacity: Double? = nil,
        maxOvershootPixels: Double = 0
    ) {
        // Update all properties for reuse
        self.windowId = windowId
        self.animationType = animationType
        self.sourceRect = sourceRect
        self.targetRect = targetRect
        self.duration = duration
        self.easingFunction = easingFunction
        self.sourceOpacity = sourceOpacity
        self.targetOpacity = targetOpacity
        self.maxOvershootPixels = maxOvershootPixels
        self.startTime = Date()

        // Reset state
        _isComplete = false
        _isCancelled = false
    }

    /// Clean up the context before returning to pool
    func cleanup() {
        _isComplete = false
        _isCancelled = false
        // Clear any references that might cause memory leaks
    }

    /// Update the animation and return the current interpolated rectangle
    /// Returns nil if the animation should be removed (completed or cancelled)
    func update() -> Rect? {
        if _isCancelled {
            return nil
        }

        if _isComplete {
            return nil
        }

        let rawProgress = AnimationInterpolator.calculateProgress(
            startTime: startTime,
            duration: duration,
            currentTime: Date(),
        )

        if rawProgress >= 1.0 {
            _isComplete = true
            return targetRect
        }

        let easedProgress = AnimationInterpolator.applyEasing(rawProgress, easing: easingFunction)
        return AnimationInterpolator.interpolateRect(sourceRect, targetRect, progress: easedProgress, maxOvershootPixels: maxOvershootPixels)
    }

    /// Complete the animation immediately
    func complete() {
        _isComplete = true
    }

    /// Cancel the animation
    func cancel() {
        _isCancelled = true
    }

    /// Get the current interpolated rectangle based on animation progress
    func getCurrentRect() -> Rect {
        if _isCancelled {
            return sourceRect
        }

        if isComplete {
            return targetRect
        }

        let rawProgress = currentProgress
        let easedProgress = AnimationInterpolator.applyEasing(rawProgress, easing: easingFunction)
        return AnimationInterpolator.interpolateRect(sourceRect, targetRect, progress: easedProgress, maxOvershootPixels: maxOvershootPixels)
    }

    /// Get the current interpolated position
    func getCurrentPosition() -> CGPoint {
        let currentRect = getCurrentRect()
        return CGPoint(x: currentRect.topLeftX, y: currentRect.topLeftY)
    }

    /// Get the current interpolated size
    func getCurrentSize() -> CGSize {
        let currentRect = getCurrentRect()
        return CGSize(width: currentRect.width, height: currentRect.height)
    }

    /// Get the current interpolated opacity (if opacity animation is enabled)
    func getCurrentOpacity() -> Double? {
        guard let sourceOpacity, let targetOpacity else {
            return nil
        }

        if _isCancelled {
            return sourceOpacity
        }

        if isComplete {
            return targetOpacity
        }

        let rawProgress = currentProgress
        let easedProgress = AnimationInterpolator.applyEasing(rawProgress, easing: easingFunction)
        return AnimationInterpolator.interpolateDouble(sourceOpacity, targetOpacity, progress: easedProgress)
    }

    // MARK: - Utility Methods

    /// Get the remaining duration of the animation
    var remainingDuration: TimeInterval {
        if isComplete || isCancelled {
            return 0.0
        }

        let elapsed = Date().timeIntervalSince(startTime)
        return max(0.0, duration - elapsed)
    }

    /// Get the elapsed time since animation started
    var elapsedTime: TimeInterval {
        return Date().timeIntervalSince(startTime)
    }

    /// Check if this animation conflicts with another animation for the same window
    func conflictsWith(_ other: WindowAnimationContext) -> Bool {
        return windowId == other.windowId && isActive && other.isActive
    }

    /// Create a description string for debugging
    var debugDescription: String {
        let statusString = isCancelled ? "cancelled" : (isComplete ? "complete" : "active")
        return "WindowAnimationContext(windowId: \(windowId), type: \(animationType), status: \(statusString), progress: \(String(format: "%.2f", currentProgress)))"
    }
}

// MARK: - Animation State Tracking

/// Represents the overall state of an animation
enum AnimationState {
    case notStarted
    case inProgress
    case completed
    case cancelled
}

/// Performance metrics for animation monitoring
struct AnimationPerformanceMetrics {
    let averageFrameRate: Double
    let droppedFrames: Int
    let activeAnimationCount: Int
    let totalAnimationsCompleted: Int
    let averageAnimationDuration: TimeInterval
    let memoryUsage: Int // in bytes
    let cpuThrottleLevel: Double
    let displayRefreshRate: Double
    let pooledContexts: Int
    let batchedAnimations: Int

    // CVDisplayLink-specific metrics
    let usingDisplayLink: Bool
    let displayLinkRunning: Bool
    let displaySyncAccuracy: Double // Percentage accuracy of display synchronization

    // Multi-display metrics
    let activeDisplayCount: Int
    let displayRefreshRates: [CGDirectDisplayID: Double]

    static let empty = AnimationPerformanceMetrics(
        averageFrameRate: 0.0,
        droppedFrames: 0,
        activeAnimationCount: 0,
        totalAnimationsCompleted: 0,
        averageAnimationDuration: 0.0,
        memoryUsage: 0,
        cpuThrottleLevel: 1.0,
        displayRefreshRate: 60.0,
        pooledContexts: 0,
        batchedAnimations: 0,
        usingDisplayLink: false,
        displayLinkRunning: false,
        displaySyncAccuracy: 0.0,
        activeDisplayCount: 0,
        displayRefreshRates: [:],
    )
}

/// Error types that can occur during animation
enum AnimationError: Error, LocalizedError {
    case windowNotFound(UInt32)
    case animationCancelled
    case performanceThresholdExceeded
    case systemResourcesUnavailable
    case configurationInvalid(String)
    case duplicateAnimation(UInt32)

    var errorDescription: String? {
        switch self {
            case .windowNotFound(let windowId):
                return "Window with ID \(windowId) not found"
            case .animationCancelled:
                return "Animation was cancelled"
            case .performanceThresholdExceeded:
                return "Animation performance threshold exceeded"
            case .systemResourcesUnavailable:
                return "System resources unavailable for animation"
            case .configurationInvalid(let message):
                return "Invalid animation configuration: \(message)"
            case .duplicateAnimation(let windowId):
                return "Animation already exists for window \(windowId)"
        }
    }
}
