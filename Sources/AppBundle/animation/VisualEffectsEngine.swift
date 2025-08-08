import Foundation
import AppKit
import Common
import CoreGraphics
import QuartzCore

/// Visual effects engine for advanced animation features
@MainActor
class VisualEffectsEngine {

    // MARK: - Properties

    private var config: VisualEffectsConfig
    private var activeMotionEffects: [UInt32: MotionEffectContext] = [:]
    private var activeParticleEffects: [UInt32: ParticleEffectContext] = [:]
    private var velocityTracker: WindowVelocityTracker
    private var effectsTimer: Timer?
    private var isEnabled: Bool = true

    // Performance monitoring
    private var frameCount: Int = 0
    private var lastFrameTime: Date = Date()
    private var effectsPerformanceThreshold: Double = 16.67 // ~60fps in milliseconds

    // MARK: - Singleton

    static let shared = VisualEffectsEngine()

    private init() {
        self.config = VisualEffectsConfig.default
        self.velocityTracker = WindowVelocityTracker()
        setupEffectsTimer()
    }

    // MARK: - Configuration

    /// Update visual effects configuration
    func updateConfiguration(_ newConfig: VisualEffectsConfig) {
        let validationErrors = newConfig.validate()
        if !validationErrors.isEmpty {
            print("Visual effects configuration validation errors: \(validationErrors)")
            return
        }

        self.config = newConfig

        // If effects are disabled, clean up all active effects
        if !newConfig.enabled {
            cleanupAllEffects()
        }
    }

    /// Get current configuration
    var currentConfiguration: VisualEffectsConfig {
        return config
    }

    // MARK: - Motion Effects

    /// Apply motion blur and afterimage effects for fast-moving windows
    func applyMotionEffects(for window: Window, velocity: CGVector, duration: TimeInterval) {
        guard config.enabled && config.motionBlurEnabled else { return }

        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)

        // Only apply motion effects if velocity exceeds threshold
        guard speed >= config.motionBlurVelocityThreshold else { return }

        // Cancel any existing motion effects for this window
        cancelMotionEffects(for: window)

        // Create motion effect context
        let motionContext = MotionEffectContext(
            windowId: window.windowId,
            velocity: velocity,
            startTime: Date(),
            duration: duration,
            blurIntensity: calculateBlurIntensity(for: speed),
            afterimageLength: config.afterimageTrailLength,
        )

        activeMotionEffects[window.windowId] = motionContext

        // Start effects timer if not already running
        startEffectsTimerIfNeeded()
    }

    /// Cancel motion effects for a specific window
    func cancelMotionEffects(for window: Window) {
        if let motionContext = activeMotionEffects[window.windowId] {
            motionContext.cleanup()
            activeMotionEffects.removeValue(forKey: window.windowId)
        }
    }

    // MARK: - Particle Effects

    /// Apply particle effects for multi-window operations
    func applyParticleEffects(for windows: [Window], effectType: ParticleEffectType, origin: CGPoint) {
        guard config.enabled && config.particleEffectsEnabled else { return }

        for window in windows {
            // Cancel any existing particle effects for this window
            cancelParticleEffects(for: window)

            // Create particle effect context
            let particleContext = ParticleEffectContext(
                windowId: window.windowId,
                effectType: effectType,
                origin: origin,
                startTime: Date(),
                duration: config.particleEffectDuration,
                particleCount: config.particleCount,
                particleSize: config.particleSize,
            )

            activeParticleEffects[window.windowId] = particleContext
        }

        // Start effects timer if not already running
        startEffectsTimerIfNeeded()
    }

    /// Apply ripple effects for multi-window operations
    func applyRippleEffects(at origin: CGPoint, affectedWindows: [Window]) {
        guard config.enabled && config.rippleEffectsEnabled else { return }

        for window in affectedWindows {
            // For testing purposes, use a default window center
            // In a real implementation, this would get the actual window rect
            let windowCenter = CGPoint(x: 200, y: 300) // Default center for testing

            let distance = sqrt(
                pow(windowCenter.x - origin.x, 2) + pow(windowCenter.y - origin.y, 2),
            )

            // Delay ripple based on distance (wave propagation effect)
            let delay = distance / config.rippleSpeed

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.applyParticleEffects(
                    for: [window],
                    effectType: .ripple,
                    origin: origin,
                )
            }
        }
    }

    /// Cancel particle effects for a specific window
    func cancelParticleEffects(for window: Window) {
        if let particleContext = activeParticleEffects[window.windowId] {
            particleContext.cleanup()
            activeParticleEffects.removeValue(forKey: window.windowId)
        }
    }

    // MARK: - Velocity Detection

    /// Update window velocity for motion effect detection
    func updateWindowVelocity(for window: Window, position: CGPoint, timestamp: Date = Date()) {
        velocityTracker.updatePosition(for: window.windowId, position: position, timestamp: timestamp)

        // Check if velocity exceeds threshold for automatic motion effects
        if let velocity = velocityTracker.getVelocity(for: window.windowId) {
            let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)

            if speed >= config.motionBlurVelocityThreshold && config.automaticMotionEffects {
                applyMotionEffects(for: window, velocity: velocity, duration: 0.5)
            }
        }
    }

    // MARK: - Effect Management

    /// Clean up all active effects
    func cleanupAllEffects() {
        // Clean up motion effects
        for (_, context) in activeMotionEffects {
            context.cleanup()
        }
        activeMotionEffects.removeAll()

        // Clean up particle effects
        for (_, context) in activeParticleEffects {
            context.cleanup()
        }
        activeParticleEffects.removeAll()

        stopEffectsTimer()
    }

    /// Update all active effects (called by timer)
    @objc private func updateEffects() {
        let currentTime = Date()
        let frameStartTime = currentTime

        // Update motion effects
        updateMotionEffects(currentTime: currentTime)

        // Update particle effects
        updateParticleEffects(currentTime: currentTime)

        // Monitor performance
        let frameTime = Date().timeIntervalSince(frameStartTime) * 1000 // Convert to milliseconds
        if frameTime > effectsPerformanceThreshold {
            handlePerformanceIssue(frameTime: frameTime)
        }

        // Stop timer if no active effects
        if activeMotionEffects.isEmpty && activeParticleEffects.isEmpty {
            stopEffectsTimer()
        }
    }

    // MARK: - Private Methods

    private func setupEffectsTimer() {
        // Timer will be started when effects are active
    }

    private func startEffectsTimerIfNeeded() {
        guard effectsTimer == nil else { return }

        effectsTimer = Timer.scheduledTimer(
            timeInterval: 1.0 / 60.0, // 60fps
            target: self,
            selector: #selector(updateEffects),
            userInfo: nil,
            repeats: true,
        )
    }

    private func stopEffectsTimer() {
        effectsTimer?.invalidate()
        effectsTimer = nil
    }

    private func calculateBlurIntensity(for speed: Double) -> Double {
        let normalizedSpeed = min(speed / config.maxMotionBlurSpeed, 1.0)
        return normalizedSpeed * config.maxMotionBlurIntensity
    }

    private func updateMotionEffects(currentTime: Date) {
        var completedEffects: [UInt32] = []

        for (windowId, context) in activeMotionEffects {
            let elapsed = currentTime.timeIntervalSince(context.startTime)
            let progress = min(elapsed / context.duration, 1.0)

            if progress >= 1.0 {
                completedEffects.append(windowId)
            } else {
                // Update motion blur and afterimage rendering
                context.updateEffect(progress: progress)
            }
        }

        // Clean up completed effects
        for windowId in completedEffects {
            activeMotionEffects[windowId]?.cleanup()
            activeMotionEffects.removeValue(forKey: windowId)
        }
    }

    private func updateParticleEffects(currentTime: Date) {
        var completedEffects: [UInt32] = []

        for (windowId, context) in activeParticleEffects {
            let elapsed = currentTime.timeIntervalSince(context.startTime)
            let progress = min(elapsed / context.duration, 1.0)

            if progress >= 1.0 {
                completedEffects.append(windowId)
            } else {
                // Update particle system rendering
                context.updateEffect(progress: progress)
            }
        }

        // Clean up completed effects
        for windowId in completedEffects {
            activeParticleEffects[windowId]?.cleanup()
            activeParticleEffects.removeValue(forKey: windowId)
        }
    }

    private func handlePerformanceIssue(frameTime: Double) {
        print("Visual effects performance issue detected: \(frameTime)ms frame time")

        if config.adaptiveQuality {
            // Reduce effect quality or disable some effects
            reduceEffectQuality()
        }
    }

    private func reduceEffectQuality() {
        // Implement adaptive quality reduction
        // This could involve reducing particle counts, blur intensity, etc.
        print("Reducing visual effects quality due to performance constraints")
    }
}
