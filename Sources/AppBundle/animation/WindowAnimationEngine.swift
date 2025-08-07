import Foundation
import Common

/// Central coordinator for all window animations
@MainActor
class WindowAnimationEngine {
    
    // MARK: - Properties
    
    private var config: AnimationConfig
    private var activeAnimations: [UInt32: WindowAnimationContext] = [:]
    private var animationTimer: Timer?
    private var isPaused: Bool = false
    
    // Performance monitoring
    private var frameCount: Int = 0
    private var lastFrameTime: Date = Date()
    private var totalAnimationsCompleted: Int = 0
    private var frameRateHistory: [Double] = []
    private let maxFrameRateHistorySize = 60 // Keep last 60 frame rates
    
    // Adaptive quality control
    private var performanceThresholdExceeded: Bool = false
    private var lastPerformanceCheck: Date = Date()
    private let performanceCheckInterval: TimeInterval = 1.0 // Check every second
    
    // MARK: - Singleton
    
    static let shared = WindowAnimationEngine()
    
    private init() {
        self.config = AnimationConfig.default
        setupSystemPreferencesObserver()
    }
    
    // MARK: - Configuration
    
    /// Update the animation configuration
    func updateConfiguration(_ newConfig: AnimationConfig) {
        let validationErrors = newConfig.validate()
        if !validationErrors.isEmpty {
            print("Animation configuration validation errors: \(validationErrors)")
            return
        }
        
        self.config = newConfig
        
        // If animations are disabled, cancel all active animations
        if !newConfig.enabled {
            cancelAllAnimations()
        }
        
        // Update timer interval if needed
        updateTimerIfNeeded()
    }
    
    /// Get current configuration
    var currentConfiguration: AnimationConfig {
        return config
    }
    
    // MARK: - Core Animation Methods
    
    /// Animate a window to a new rectangle (position and size)
    func animateWindow(
        _ window: Window,
        to targetRect: Rect,
        duration: TimeInterval? = nil,
        easing: AnimationEasing? = nil
    ) async throws {
        guard config.enabled else {
            // If animations are disabled, apply immediately
            window.setAxFrameImmediate(CGPoint(x: targetRect.topLeftX, y: targetRect.topLeftY), 
                                     CGSize(width: targetRect.width, height: targetRect.height))
            return
        }
        
        guard let currentRect = try await window.getAxRect() else {
            throw AnimationError.windowNotFound(window.windowId)
        }
        
        let animationDuration = duration ?? config.defaultDuration
        let animationEasing = easing ?? config.easingFunction
        
        // Cancel any existing animation for this window
        cancelAnimation(for: window)
        
        // Check if we're at max concurrent animations
        if activeAnimations.count >= config.maxConcurrentAnimations {
            // Apply immediately if we're at the limit
            window.setAxFrameImmediate(CGPoint(x: targetRect.topLeftX, y: targetRect.topLeftY),
                                     CGSize(width: targetRect.width, height: targetRect.height))
            return
        }
        
        // Create animation context
        let animationContext = WindowAnimationContext(
            windowId: window.windowId,
            animationType: .moveAndResize,
            sourceRect: currentRect,
            targetRect: targetRect,
            duration: animationDuration,
            easingFunction: animationEasing
        )
        
        activeAnimations[window.windowId] = animationContext
        
        // Start timer if not already running
        startTimerIfNeeded()
    }
    
    /// Animate a window to a new position
    func animateWindowPosition(
        _ window: Window,
        to targetPosition: CGPoint,
        duration: TimeInterval? = nil,
        easing: AnimationEasing? = nil
    ) async throws {
        guard config.enabled && config.moveAnimationEnabled else {
            window.setAxTopLeftCornerImmediate(targetPosition)
            return
        }
        
        guard let currentRect = try await window.getAxRect() else {
            throw AnimationError.windowNotFound(window.windowId)
        }
        
        let targetRect = Rect(
            topLeftX: targetPosition.x,
            topLeftY: targetPosition.y,
            width: currentRect.width,
            height: currentRect.height
        )
        
        try await animateWindow(window, to: targetRect, duration: duration, easing: easing)
    }
    
    /// Animate a window to a new size
    func animateWindowSize(
        _ window: Window,
        to targetSize: CGSize,
        duration: TimeInterval? = nil,
        easing: AnimationEasing? = nil
    ) async throws {
        guard config.enabled && config.resizeAnimationEnabled else {
            window.setSizeAsyncImmediate(targetSize)
            return
        }
        
        guard let currentRect = try await window.getAxRect() else {
            throw AnimationError.windowNotFound(window.windowId)
        }
        
        let targetRect = Rect(
            topLeftX: currentRect.topLeftX,
            topLeftY: currentRect.topLeftY,
            width: targetSize.width,
            height: targetSize.height
        )
        
        try await animateWindow(window, to: targetRect, duration: duration, easing: easing)
    }
    
    // MARK: - Animation Control
    
    /// Cancel animation for a specific window
    func cancelAnimation(for window: Window) {
        if let animationContext = activeAnimations[window.windowId] {
            animationContext.cancel()
            activeAnimations.removeValue(forKey: window.windowId)
        }
    }
    
    /// Cancel all active animations
    func cancelAllAnimations() {
        for (_, context) in activeAnimations {
            context.cancel()
        }
        activeAnimations.removeAll()
        stopTimer()
    }
    
    /// Force stop all animations and cleanup resources (for testing)
    func forceStopAllAnimations() {
        cancelAllAnimations()
        isPaused = false
        frameCount = 0
        frameRateHistory.removeAll()
        totalAnimationsCompleted = 0
        performanceThresholdExceeded = false
        lastPerformanceCheck = Date()
    }
    
    /// Pause all animations
    func pauseAnimations() {
        isPaused = true
        stopTimer()
    }
    
    /// Resume all animations
    func resumeAnimations() {
        isPaused = false
        startTimerIfNeeded()
    }
    
    /// Check if animations are currently paused
    var areAnimationsPaused: Bool {
        return isPaused
    }
    
    /// Get the number of active animations
    var activeAnimationCount: Int {
        return activeAnimations.count
    }
    
    /// Check if a specific window has an active animation
    func hasActiveAnimation(for window: Window) -> Bool {
        return activeAnimations[window.windowId]?.isActive == true
    }
    
    /// Batch animate multiple windows simultaneously
    func batchAnimateWindows(_ animations: [(Window, Rect, TimeInterval?, AnimationEasing?)]) async throws {
        guard config.enabled else {
            // If animations are disabled, apply all immediately
            for (window, targetRect, _, _) in animations {
                window.setAxFrameImmediate(CGPoint(x: targetRect.topLeftX, y: targetRect.topLeftY),
                                         CGSize(width: targetRect.width, height: targetRect.height))
            }
            return
        }
        
        // Process animations in batch, respecting concurrent limits
        var processedCount = 0
        for (window, targetRect, duration, easing) in animations {
            // Check if we're at the concurrent limit
            if activeAnimations.count >= config.maxConcurrentAnimations {
                // Apply remaining animations immediately
                window.setAxFrameImmediate(CGPoint(x: targetRect.topLeftX, y: targetRect.topLeftY),
                                         CGSize(width: targetRect.width, height: targetRect.height))
            } else {
                try await animateWindow(window, to: targetRect, duration: duration, easing: easing)
                processedCount += 1
            }
        }
        
        print("Batch animated \(processedCount) windows, \(animations.count - processedCount) applied immediately")
    }
    
    // MARK: - Timer Management
    
    private func startTimerIfNeeded() {
        guard animationTimer == nil && !activeAnimations.isEmpty && !isPaused else { return }
        
        let targetFrameRate = 60.0
        let timerInterval = 1.0 / targetFrameRate
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAnimations()
            }
        }
    }
    
    private func stopTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func updateTimerIfNeeded() {
        if animationTimer != nil {
            stopTimer()
            startTimerIfNeeded()
        }
    }
    
    // MARK: - Animation Updates
    
    private func updateAnimations() {
        let currentTime = Date()
        var completedAnimations: [UInt32] = []
        
        // Update frame rate tracking
        updateFrameRateTracking(currentTime: currentTime)
        
        // Check performance and adapt quality if needed
        checkAndAdaptPerformance(currentTime: currentTime)
        
        for (windowId, context) in activeAnimations {
            guard let window = Window.get(byId: windowId) else {
                // Window no longer exists, remove animation
                completedAnimations.append(windowId)
                continue
            }
            
            if let currentRect = context.update() {
                // Apply the current animation frame
                window.setAxFrameImmediate(
                    CGPoint(x: currentRect.topLeftX, y: currentRect.topLeftY),
                    CGSize(width: currentRect.width, height: currentRect.height)
                )
            } else {
                // Animation is complete or cancelled
                if context.isComplete {
                    // Ensure final position is set
                    let finalRect = context.targetRect
                    window.setAxFrameImmediate(
                        CGPoint(x: finalRect.topLeftX, y: finalRect.topLeftY),
                        CGSize(width: finalRect.width, height: finalRect.height)
                    )
                    totalAnimationsCompleted += 1
                }
                completedAnimations.append(windowId)
            }
        }
        
        // Remove completed animations
        for windowId in completedAnimations {
            activeAnimations.removeValue(forKey: windowId)
        }
        
        // Stop timer if no more animations
        if activeAnimations.isEmpty {
            stopTimer()
        }
    }
    
    // MARK: - Performance Monitoring
    
    private func updateFrameRateTracking(currentTime: Date) {
        frameCount += 1
        
        let timeSinceLastFrame = currentTime.timeIntervalSince(lastFrameTime)
        if timeSinceLastFrame > 0 {
            let currentFrameRate = 1.0 / timeSinceLastFrame
            frameRateHistory.append(currentFrameRate)
            
            // Keep only recent frame rates
            if frameRateHistory.count > maxFrameRateHistorySize {
                frameRateHistory.removeFirst()
            }
        }
        
        lastFrameTime = currentTime
    }
    
    private func checkAndAdaptPerformance(currentTime: Date) {
        // Only check performance periodically
        guard currentTime.timeIntervalSince(lastPerformanceCheck) >= performanceCheckInterval else {
            return
        }
        
        lastPerformanceCheck = currentTime
        
        // Check if adaptive quality is enabled
        guard config.adaptiveQuality else { return }
        
        // Calculate average frame rate over recent history
        let averageFrameRate = frameRateHistory.isEmpty ? 60.0 : frameRateHistory.reduce(0, +) / Double(frameRateHistory.count)
        
        // Check if performance is below threshold
        let wasExceeded = performanceThresholdExceeded
        performanceThresholdExceeded = averageFrameRate < config.minFrameRate
        
        // If performance threshold is exceeded, take adaptive actions
        if performanceThresholdExceeded && !wasExceeded {
            print("Animation performance threshold exceeded (avg FPS: \(String(format: "%.1f", averageFrameRate))). Adapting quality...")
            adaptQualityForPerformance()
        } else if !performanceThresholdExceeded && wasExceeded {
            print("Animation performance recovered (avg FPS: \(String(format: "%.1f", averageFrameRate))). Restoring quality...")
            restoreQualityAfterPerformance()
        }
    }
    
    private func adaptQualityForPerformance() {
        // Reduce concurrent animations if we have too many
        if activeAnimations.count > 3 {
            let animationsToCancel = Array(activeAnimations.keys.prefix(activeAnimations.count - 3))
            for windowId in animationsToCancel {
                if let context = activeAnimations[windowId] {
                    context.cancel()
                    activeAnimations.removeValue(forKey: windowId)
                }
            }
        }
        
        // Could also reduce animation quality here (e.g., lower frame rate, simpler easing)
    }
    
    private func restoreQualityAfterPerformance() {
        // Performance has recovered, we can allow normal operation again
        // The system will naturally allow more animations as they are requested
    }
    
    /// Get current performance metrics
    func getPerformanceMetrics() -> AnimationPerformanceMetrics {
        let averageFrameRate = frameRateHistory.isEmpty ? 0.0 : frameRateHistory.reduce(0, +) / Double(frameRateHistory.count)
        let droppedFrames = frameRateHistory.filter { $0 < config.minFrameRate }.count
        
        // Estimate memory usage (rough calculation)
        let memoryUsage = activeAnimations.count * MemoryLayout<WindowAnimationContext>.size
        
        return AnimationPerformanceMetrics(
            averageFrameRate: averageFrameRate,
            droppedFrames: droppedFrames,
            activeAnimationCount: activeAnimations.count,
            totalAnimationsCompleted: totalAnimationsCompleted,
            averageAnimationDuration: config.defaultDuration,
            memoryUsage: memoryUsage
        )
    }
    
    // MARK: - System Integration
    
    private func setupSystemPreferencesObserver() {
        // Monitor system accessibility preferences for reduced motion
        if config.respectSystemPreferences {
            // This would typically observe NSWorkspace or other system notifications
            // For now, we'll implement a basic check
            checkSystemMotionPreferences()
        }
    }
    
    private func checkSystemMotionPreferences() {
        // Check if system has reduced motion enabled
        // This is a placeholder - actual implementation would check system preferences
        let reducedMotionEnabled = false // UserDefaults.standard.bool(forKey: "reduceMotion")
        
        if reducedMotionEnabled && config.respectSystemPreferences {
            var updatedConfig = config
            updatedConfig.enabled = false
            updateConfiguration(updatedConfig)
        }
    }
    
    // MARK: - Debugging
    
    /// Get debug information about active animations
    func getDebugInfo() -> [String] {
        var info: [String] = []
        info.append("WindowAnimationEngine Debug Info:")
        info.append("- Active animations: \(activeAnimations.count)")
        info.append("- Timer running: \(animationTimer != nil)")
        info.append("- Paused: \(isPaused)")
        info.append("- Total completed: \(totalAnimationsCompleted)")
        
        let metrics = getPerformanceMetrics()
        info.append("- Average FPS: \(String(format: "%.1f", metrics.averageFrameRate))")
        info.append("- Dropped frames: \(metrics.droppedFrames)")
        
        for (windowId, context) in activeAnimations {
            info.append("- Window \(windowId): \(context.debugDescription)")
        }
        
        return info
    }
}