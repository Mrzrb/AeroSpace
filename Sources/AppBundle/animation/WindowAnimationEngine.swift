import Foundation
import AppKit
import Common
import Darwin.Mach
import CoreGraphics

/// Notification posted when animation configuration changes
extension Notification.Name {
    static let animationConfigurationDidChange = Notification.Name("animationConfigurationDidChange")
}

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

    // Advanced performance optimizations
    private var animationContextPool: [WindowAnimationContext] = []
    private let maxPoolSize = 20
    private var batchedAnimations: [(Window, Rect, TimeInterval?, AnimationEasing?)] = []
    private var batchTimer: Timer?
    private let batchDelay: TimeInterval = 0.016 // ~60fps batching
    private var cpuThrottleLevel: Double = 1.0 // 1.0 = no throttling, 0.5 = 50% throttling
    private var displayRefreshRate: Double = 60.0
    private var lastCPUCheck: Date = Date()
    private let cpuCheckInterval: TimeInterval = 2.0

    // Accessibility integration
    private var originalConfigEnabled: Bool = true // Track original enabled state

    // MARK: - Singleton

    static let shared = WindowAnimationEngine()

    private init() {
        self.config = AnimationConfig.default
        self.originalConfigEnabled = AnimationConfig.default.enabled
        setupSystemPreferencesObserver()
        detectDisplayRefreshRate()
        initializeAnimationContextPool()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Configuration

    /// Update the animation configuration
    func updateConfiguration(_ newConfig: AnimationConfig) {
        let validationErrors = newConfig.validate()
        if !validationErrors.isEmpty {
            print("Animation configuration validation errors: \(validationErrors)")
            return
        }

        let oldConfig = self.config

        // Track original enabled state for accessibility restoration
        if config.respectSystemPreferences {
            originalConfigEnabled = newConfig.enabled
        }

        // Handle smooth transition between configurations
        handleConfigurationTransition(from: oldConfig, to: newConfig)

        self.config = newConfig

        // If animations are disabled, cancel all active animations
        if !newConfig.enabled {
            cancelAllAnimations()
        }

        // Update timer interval if needed
        updateTimerIfNeeded()

        // Re-check system preferences after config update
        if newConfig.respectSystemPreferences {
            checkSystemMotionPreferences()
        }

        // Post notification about configuration change
        NotificationCenter.default.post(
            name: .animationConfigurationDidChange,
            object: self,
            userInfo: ["oldConfig": oldConfig, "newConfig": newConfig],
        )
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
        easing: AnimationEasing? = nil,
    ) async throws {
        guard config.enabled else {
            // If animations are disabled, apply immediately
            window.setAxFrameImmediate(CGPoint(x: targetRect.topLeftX, y: targetRect.topLeftY),
                                       CGSize(width: targetRect.width, height: targetRect.height))

            // Provide accessibility feedback if needed
            if shouldUseAccessibilityAlternatives() {
                provideAccessibilityFeedback(for: window, operation: "move and resize")
            }
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

        // Create animation context from pool
        let animationContext = getAnimationContextFromPool(
            windowId: window.windowId,
            animationType: .moveAndResize,
            sourceRect: currentRect,
            targetRect: targetRect,
            duration: animationDuration,
            easingFunction: animationEasing,
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
        easing: AnimationEasing? = nil,
    ) async throws {
        guard config.enabled && config.moveAnimationEnabled else {
            window.setAxTopLeftCornerImmediate(targetPosition)

            // Provide accessibility feedback if needed
            if shouldUseAccessibilityAlternatives() {
                provideAccessibilityFeedback(for: window, operation: "move")
            }
            return
        }

        guard let currentRect = try await window.getAxRect() else {
            throw AnimationError.windowNotFound(window.windowId)
        }

        let targetRect = Rect(
            topLeftX: targetPosition.x,
            topLeftY: targetPosition.y,
            width: currentRect.width,
            height: currentRect.height,
        )

        try await animateWindow(window, to: targetRect, duration: duration, easing: easing)
    }

    /// Animate a window to a new size
    func animateWindowSize(
        _ window: Window,
        to targetSize: CGSize,
        duration: TimeInterval? = nil,
        easing: AnimationEasing? = nil,
    ) async throws {
        guard config.enabled && config.resizeAnimationEnabled else {
            window.setSizeAsyncImmediate(targetSize)

            // Provide accessibility feedback if needed
            if shouldUseAccessibilityAlternatives() {
                provideAccessibilityFeedback(for: window, operation: "resize")
            }
            return
        }

        guard let currentRect = try await window.getAxRect() else {
            throw AnimationError.windowNotFound(window.windowId)
        }

        let targetRect = Rect(
            topLeftX: currentRect.topLeftX,
            topLeftY: currentRect.topLeftY,
            width: targetSize.width,
            height: targetSize.height,
        )

        try await animateWindow(window, to: targetRect, duration: duration, easing: easing)
    }

    // MARK: - Workspace Transition Animations

    /// Animate window fade-out when moving to hidden workspace
    func animateWindowFadeOut(
        _ window: Window,
        duration: TimeInterval? = nil,
        easing: AnimationEasing? = nil,
    ) async throws {
        guard config.enabled && config.workspaceTransitionAnimationEnabled else {
            // If animations are disabled, hide immediately
            window.setAxAlphaImmediate(0.0)
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
            window.setAxAlphaImmediate(0.0)
            return
        }

        // Create fade-out animation context from pool
        let animationContext = getAnimationContextFromPool(
            windowId: window.windowId,
            animationType: .workspaceTransitionFadeOut,
            sourceRect: currentRect,
            targetRect: currentRect, // Position doesn't change during fade
            duration: animationDuration,
            easingFunction: animationEasing,
            sourceOpacity: 1.0,
            targetOpacity: 0.0,
        )

        activeAnimations[window.windowId] = animationContext

        // Start timer if not already running
        startTimerIfNeeded()
    }

    /// Animate window fade-in when workspace becomes visible
    func animateWindowFadeIn(
        _ window: Window,
        duration: TimeInterval? = nil,
        easing: AnimationEasing? = nil,
    ) async throws {
        guard config.enabled && config.workspaceTransitionAnimationEnabled else {
            // If animations are disabled, show immediately
            window.setAxAlphaImmediate(1.0)
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
            window.setAxAlphaImmediate(1.0)
            return
        }

        // Create fade-in animation context from pool
        let animationContext = getAnimationContextFromPool(
            windowId: window.windowId,
            animationType: .workspaceTransitionFadeIn,
            sourceRect: currentRect,
            targetRect: currentRect, // Position doesn't change during fade
            duration: animationDuration,
            easingFunction: animationEasing,
            sourceOpacity: 0.0,
            targetOpacity: 1.0,
        )

        activeAnimations[window.windowId] = animationContext

        // Start timer if not already running
        startTimerIfNeeded()
    }

    /// Animate window position transition during workspace-to-workspace moves
    func animateWorkspaceTransition(
        _ window: Window,
        to targetRect: Rect,
        duration: TimeInterval? = nil,
        easing: AnimationEasing? = nil,
    ) async throws {
        guard config.enabled && config.workspaceTransitionAnimationEnabled else {
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

        // Create workspace transition animation context from pool
        let animationContext = getAnimationContextFromPool(
            windowId: window.windowId,
            animationType: .workspaceTransition,
            sourceRect: currentRect,
            targetRect: targetRect,
            duration: animationDuration,
            easingFunction: animationEasing,
        )

        activeAnimations[window.windowId] = animationContext

        // Start timer if not already running
        startTimerIfNeeded()
    }

    // MARK: - Animation Control

    /// Cancel animation for a specific window
    func cancelAnimation(for window: Window) {
        if let animationContext = activeAnimations[window.windowId] {
            animationContext.cancel()
            activeAnimations.removeValue(forKey: window.windowId)
            returnAnimationContextToPool(animationContext)
        }
    }

    /// Cancel all active animations
    func cancelAllAnimations() {
        for (_, context) in activeAnimations {
            context.cancel()
            returnAnimationContextToPool(context)
        }
        activeAnimations.removeAll()
        stopTimer()
    }

    /// Force stop all animations and cleanup resources (for testing)
    func forceStopAllAnimations() {
        cancelAllAnimations()
        batchTimer?.invalidate()
        batchTimer = nil
        batchedAnimations.removeAll()
        isPaused = false
        frameCount = 0
        frameRateHistory.removeAll()
        totalAnimationsCompleted = 0
        performanceThresholdExceeded = false
        lastPerformanceCheck = Date()
        cpuThrottleLevel = 1.0
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

    // MARK: - Memory Pooling

    /// Initialize the animation context pool with pre-allocated contexts
    private func initializeAnimationContextPool() {
        animationContextPool.reserveCapacity(maxPoolSize)
        // Pre-allocate some contexts to avoid allocation during animation
        for _ in 0 ..< min(5, maxPoolSize) {
            let context = WindowAnimationContext(
                windowId: 0, // Will be reset when reused
                animationType: .move,
                sourceRect: Rect(topLeftX: 0, topLeftY: 0, width: 0, height: 0),
                targetRect: Rect(topLeftX: 0, topLeftY: 0, width: 0, height: 0),
                duration: 0.25,
                easingFunction: .easeOut,
            )
            animationContextPool.append(context)
        }
    }

    /// Get an animation context from the pool or create a new one
    private func getAnimationContextFromPool(
        windowId: UInt32,
        animationType: AnimationType,
        sourceRect: Rect,
        targetRect: Rect,
        duration: TimeInterval,
        easingFunction: AnimationEasing,
        sourceOpacity: Double? = nil,
        targetOpacity: Double? = nil,
    ) -> WindowAnimationContext {
        if let pooledContext = animationContextPool.popLast() {
            // Reuse pooled context
            pooledContext.reset(
                windowId: windowId,
                animationType: animationType,
                sourceRect: sourceRect,
                targetRect: targetRect,
                duration: duration,
                easingFunction: easingFunction,
                sourceOpacity: sourceOpacity,
                targetOpacity: targetOpacity,
            )
            return pooledContext
        } else {
            // Create new context if pool is empty
            return WindowAnimationContext(
                windowId: windowId,
                animationType: animationType,
                sourceRect: sourceRect,
                targetRect: targetRect,
                duration: duration,
                easingFunction: easingFunction,
                sourceOpacity: sourceOpacity,
                targetOpacity: targetOpacity,
            )
        }
    }

    /// Return an animation context to the pool for reuse
    private func returnAnimationContextToPool(_ context: WindowAnimationContext) {
        guard animationContextPool.count < maxPoolSize else {
            // Pool is full, let the context be deallocated
            return
        }

        // Clean the context before returning to pool
        context.cleanup()
        animationContextPool.append(context)
    }

    /// Clean up the animation context pool
    private func cleanupAnimationContextPool() {
        animationContextPool.removeAll()
    }

    // MARK: - Animation Batching

    /// Add animation to batch for processing
    private func addToBatch(_ window: Window, _ targetRect: Rect, _ duration: TimeInterval?, _ easing: AnimationEasing?) {
        batchedAnimations.append((window, targetRect, duration, easing))

        // Start batch timer if not already running
        if batchTimer == nil {
            batchTimer = Timer.scheduledTimer(withTimeInterval: batchDelay, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.processBatchedAnimations()
                }
            }
        }
    }

    /// Process all batched animations at once
    private func processBatchedAnimations() {
        batchTimer?.invalidate()
        batchTimer = nil

        guard !batchedAnimations.isEmpty else { return }

        let animations = batchedAnimations
        batchedAnimations.removeAll()

        Task {
            do {
                try await batchAnimateWindows(animations)
            } catch {
                print("Error processing batched animations: \(error)")
            }
        }
    }

    // MARK: - CPU Throttling

    /// Check CPU usage and adjust throttling level
    private func checkAndAdjustCPUThrottling() {
        let currentTime = Date()
        guard currentTime.timeIntervalSince(lastCPUCheck) >= cpuCheckInterval else {
            return
        }

        lastCPUCheck = currentTime

        // Get system CPU usage (simplified approach)
        let cpuUsage = getCurrentCPUUsage()

        // Adjust throttling based on CPU usage
        if cpuUsage > 80.0 {
            cpuThrottleLevel = max(0.3, cpuThrottleLevel - 0.1) // Increase throttling
        } else if cpuUsage < 50.0 {
            cpuThrottleLevel = min(1.0, cpuThrottleLevel + 0.1) // Decrease throttling
        }

        // Apply throttling by adjusting timer interval
        if cpuThrottleLevel < 1.0 {
            updateTimerForThrottling()
        }
    }

    /// Get current CPU usage percentage (simplified implementation)
    private func getCurrentCPUUsage() -> Double {
        // This is a simplified implementation
        // In a real implementation, you would use system APIs to get actual CPU usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }

        if kerr == KERN_SUCCESS {
            // This is a rough approximation - actual CPU usage calculation is more complex
            return Double(info.resident_size) / (1024 * 1024 * 1024) * 100 // Convert to percentage
        }

        return 50.0 // Default to moderate usage if we can't determine
    }

    /// Update timer interval based on throttling level
    private func updateTimerForThrottling() {
        guard animationTimer != nil else { return }

        stopTimer()
        startTimerIfNeeded()
    }

    // MARK: - Display Refresh Rate Synchronization

    /// Detect the display refresh rate for optimal animation timing
    private func detectDisplayRefreshRate() {
        guard let screen = NSScreen.main else {
            displayRefreshRate = 60.0 // Default fallback
            return
        }

        // Try to get refresh rate from display mode (compatible with older macOS)
        if let mode = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            // Use Core Graphics to get actual refresh rate
            let displayID = mode.uint32Value
            if let mode = CGDisplayCopyDisplayMode(displayID) {
                displayRefreshRate = mode.refreshRate
                if displayRefreshRate == 0 {
                    displayRefreshRate = 60.0 // Fallback for displays that report 0
                }
            } else {
                displayRefreshRate = 60.0 // Most common refresh rate
            }
        } else {
            displayRefreshRate = 60.0
        }

        // Clamp to reasonable values
        displayRefreshRate = max(30.0, min(240.0, displayRefreshRate))
    }

    /// Get optimal timer interval based on display refresh rate and throttling
    private func getOptimalTimerInterval() -> TimeInterval {
        let baseInterval = 1.0 / displayRefreshRate
        return baseInterval / cpuThrottleLevel
    }

    // MARK: - Timer Management

    private func startTimerIfNeeded() {
        guard animationTimer == nil && !activeAnimations.isEmpty && !isPaused else { return }

        let timerInterval = getOptimalTimerInterval()

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

        // Check and adjust CPU throttling
        checkAndAdjustCPUThrottling()

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
                    CGSize(width: currentRect.width, height: currentRect.height),
                )

                // Apply opacity animation if present
                if let currentOpacity = context.getCurrentOpacity() {
                    window.setAxAlphaImmediate(currentOpacity)
                }
            } else {
                // Animation is complete or cancelled
                if context.isComplete {
                    // Ensure final position is set
                    let finalRect = context.targetRect
                    window.setAxFrameImmediate(
                        CGPoint(x: finalRect.topLeftX, y: finalRect.topLeftY),
                        CGSize(width: finalRect.width, height: finalRect.height),
                    )

                    // Ensure final opacity is set if opacity animation was used
                    if let targetOpacity = context.targetOpacity {
                        window.setAxAlphaImmediate(targetOpacity)
                    }

                    totalAnimationsCompleted += 1
                }
                completedAnimations.append(windowId)
            }
        }

        // Remove completed animations and return contexts to pool
        for windowId in completedAnimations {
            if let context = activeAnimations.removeValue(forKey: windowId) {
                returnAnimationContextToPool(context)
            }
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
        let droppedFrames = frameRateHistory.count(where: { $0 < config.minFrameRate })

        // Estimate memory usage including pool
        let activeMemory = activeAnimations.count * MemoryLayout<WindowAnimationContext>.size
        let poolMemory = animationContextPool.count * MemoryLayout<WindowAnimationContext>.size
        let totalMemoryUsage = activeMemory + poolMemory

        return AnimationPerformanceMetrics(
            averageFrameRate: averageFrameRate,
            droppedFrames: droppedFrames,
            activeAnimationCount: activeAnimations.count,
            totalAnimationsCompleted: totalAnimationsCompleted,
            averageAnimationDuration: config.defaultDuration,
            memoryUsage: totalMemoryUsage,
            cpuThrottleLevel: cpuThrottleLevel,
            displayRefreshRate: displayRefreshRate,
            pooledContexts: animationContextPool.count,
            batchedAnimations: batchedAnimations.count,
        )
    }

    // MARK: - System Integration

    private func setupSystemPreferencesObserver() {
        // Monitor system accessibility preferences for reduced motion
        if config.respectSystemPreferences {
            checkSystemMotionPreferences()

            // Set up notification observer for accessibility preference changes
            NotificationCenter.default.addObserver(
                forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                object: nil,
                queue: .main,
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.checkSystemMotionPreferences()
                }
            }
        }
    }

    private func checkSystemMotionPreferences() {
        // Check if system has reduced motion enabled
        let reducedMotionEnabled = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if reducedMotionEnabled && config.respectSystemPreferences {
            // Disable animations when system prefers reduced motion
            if config.enabled {
                var updatedConfig = config
                updatedConfig.enabled = false
                // Temporarily update config without triggering recursive call
                self.config = updatedConfig
                cancelAllAnimations()
            }
        } else if !reducedMotionEnabled && config.respectSystemPreferences {
            // Re-enable animations if they were disabled due to system preferences
            // but only if the original config had them enabled
            if originalConfigEnabled && !config.enabled {
                var updatedConfig = config
                updatedConfig.enabled = true
                // Temporarily update config without triggering recursive call
                self.config = updatedConfig
            }
        }
    }

    // MARK: - Configuration Transitions

    /// Handle smooth transitions when animation settings change
    private func handleConfigurationTransition(from oldConfig: AnimationConfig, to newConfig: AnimationConfig) {
        // If animations were enabled but are now disabled, cancel all active animations
        if oldConfig.enabled && !newConfig.enabled {
            cancelAllAnimations()
        }

        // If animation duration changed significantly, adjust active animations
        if abs(oldConfig.defaultDuration - newConfig.defaultDuration) > 0.1 {
            adjustActiveAnimationDurations(newDuration: newConfig.defaultDuration)
        }

        // If easing function changed, we could potentially update active animations
        // For now, we'll let them complete with their original easing

        // If performance settings changed, update monitoring
        if oldConfig.maxConcurrentAnimations != newConfig.maxConcurrentAnimations ||
            oldConfig.minFrameRate != newConfig.minFrameRate
        {
            updatePerformanceSettings()
        }
    }

    /// Adjust the duration of active animations when configuration changes
    private func adjustActiveAnimationDurations(newDuration: TimeInterval) {
        for (_, context) in activeAnimations {
            // Calculate how much of the animation has completed
            let elapsed = Date().timeIntervalSince(context.startTime)
            let progress = elapsed / context.duration

            // If the animation is less than 50% complete, adjust its duration
            if progress < 0.5 {
                let remainingProgress = 1.0 - progress
                _ = newDuration * remainingProgress

                // Update the context with new timing
                // Note: This would require making WindowAnimationContext mutable
                // For now, we'll let existing animations complete with their original duration
            }
        }
    }

    /// Update performance monitoring settings
    private func updatePerformanceSettings() {
        // Reset performance history when settings change
        frameRateHistory.removeAll()
        performanceThresholdExceeded = false
        lastPerformanceCheck = Date()
    }

    // MARK: - Accessibility Alternatives

    /// Provide accessibility-friendly feedback when animations are disabled
    private func provideAccessibilityFeedback(for window: Window, operation: String) {
        // When animations are disabled due to accessibility preferences,
        // we can provide alternative feedback mechanisms

        // For now, this is a placeholder for potential future enhancements like:
        // - Audio feedback
        // - Haptic feedback (if available)
        // - Visual indicators that don't involve motion
        // - Screen reader announcements

        // Example: Could announce window movements to screen readers
        // NSAccessibility.post(element: window.axWindow, notification: .moved)
    }

    /// Check if accessibility alternatives should be used
    private func shouldUseAccessibilityAlternatives() -> Bool {
        return !config.enabled && config.respectSystemPreferences && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
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
        info.append("- CPU throttle level: \(String(format: "%.2f", metrics.cpuThrottleLevel))")
        info.append("- Display refresh rate: \(String(format: "%.1f", metrics.displayRefreshRate)) Hz")
        info.append("- Pooled contexts: \(metrics.pooledContexts)")
        info.append("- Batched animations: \(metrics.batchedAnimations)")
        info.append("- Memory usage: \(metrics.memoryUsage) bytes")

        for (windowId, context) in activeAnimations {
            info.append("- Window \(windowId): \(context.debugDescription)")
        }

        return info
    }

    /// Get active animation context for a window (for testing)
    func getActiveAnimationContext(for window: Window) -> WindowAnimationContext? {
        return activeAnimations[window.windowId]
    }
}
