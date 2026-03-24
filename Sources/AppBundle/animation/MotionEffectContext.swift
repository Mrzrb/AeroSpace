import Foundation
import AppKit
import CoreGraphics
import QuartzCore

/// Context for managing motion blur and afterimage effects for a window
class MotionEffectContext {

    // MARK: - Properties

    let windowId: UInt32
    let velocity: CGVector
    let startTime: Date
    let duration: TimeInterval
    let blurIntensity: Double
    let afterimageLength: Int

    // Motion blur state
    private var blurLayer: CALayer?
    private var blurFilter: CIFilter?
    private var isBlurActive: Bool = false

    // Afterimage state
    private var afterimageFrames: [AfterimageFrame] = []
    private var lastAfterimageUpdate: Date = Date()
    private let afterimageUpdateInterval: TimeInterval = 1.0 / 30.0 // 30fps

    // Performance tracking
    private var frameCount: Int = 0
    private var lastPerformanceCheck: Date = Date()

    // MARK: - Initialization

    init(windowId: UInt32, velocity: CGVector, startTime: Date, duration: TimeInterval,
         blurIntensity: Double, afterimageLength: Int)
    {
        self.windowId = windowId
        self.velocity = velocity
        self.startTime = startTime
        self.duration = duration
        self.blurIntensity = blurIntensity
        self.afterimageLength = afterimageLength

        setupMotionBlur()
        initializeAfterimageSystem()
    }

    // MARK: - Motion Blur Implementation

    private func setupMotionBlur() {
        guard blurIntensity > 0.0 else { return }

        // Create motion blur filter
        blurFilter = CIFilter(name: "CIMotionBlur")
        blurFilter?.setValue(blurIntensity * 10.0, forKey: kCIInputRadiusKey) // Scale intensity

        // Calculate blur angle based on velocity direction
        let angle = atan2(velocity.dy, velocity.dx)
        blurFilter?.setValue(angle, forKey: kCIInputAngleKey)

        isBlurActive = true
    }

    private func updateMotionBlur(progress: Double) {
        guard let blurFilter, isBlurActive else { return }

        // Fade out blur intensity as animation progresses
        let currentIntensity = blurIntensity * (1.0 - progress)
        blurFilter.setValue(currentIntensity * 10.0, forKey: kCIInputRadiusKey)

        // Apply blur to window if possible
        applyBlurToWindow(intensity: currentIntensity)
    }

    private func applyBlurToWindow(intensity: Double) {
        // In a real implementation, this would apply the blur effect to the window
        // For now, we'll simulate the effect by tracking the blur state

        // Note: Actual window blur application would require integration with
        // the window system and potentially Core Animation layers

        if intensity > 0.01 {
            // Blur is visible
            frameCount += 1
        }
    }

    // MARK: - Afterimage Implementation

    private func initializeAfterimageSystem() {
        afterimageFrames.reserveCapacity(afterimageLength)
    }

    private func updateAfterimage(progress: Double, currentPosition: CGPoint? = nil) {
        let now = Date()

        // Only update afterimages at the specified interval
        guard now.timeIntervalSince(lastAfterimageUpdate) >= afterimageUpdateInterval else { return }

        lastAfterimageUpdate = now

        // Add new afterimage frame if we have a current position
        if let position = currentPosition {
            let opacity = 1.0 - progress // Fade out as animation progresses
            let frame = AfterimageFrame(
                position: position,
                opacity: opacity,
                timestamp: now,
            )

            afterimageFrames.append(frame)

            // Remove old frames beyond the trail length
            if afterimageFrames.count > afterimageLength {
                afterimageFrames.removeFirst()
            }
        }

        // Update opacity of existing frames
        updateAfterimageOpacity()
    }

    private func updateAfterimageOpacity() {
        let now = Date()
        let maxAge: TimeInterval = 1.0 // Maximum age for afterimage frames

        // Update opacity based on age and remove expired frames
        afterimageFrames = afterimageFrames.compactMap { frame in
            let age = now.timeIntervalSince(frame.timestamp)

            if age > maxAge {
                return nil // Remove expired frame
            }

            // Calculate opacity decay based on age
            let ageRatio = age / maxAge
            let newOpacity = frame.opacity * (1.0 - ageRatio)

            if newOpacity < 0.05 {
                return nil // Remove nearly invisible frame
            }

            return AfterimageFrame(
                position: frame.position,
                opacity: newOpacity,
                timestamp: frame.timestamp,
            )
        }
    }

    private func renderAfterimages() {
        // In a real implementation, this would render the afterimage frames
        // For now, we'll track the rendering state

        for frame in afterimageFrames {
            // Simulate rendering an afterimage at the given position with opacity
            if frame.opacity > 0.05 {
                // Frame is visible enough to render
                frameCount += 1
            }
        }
    }

    // MARK: - Public Interface

    /// Update the motion effect with current progress
    func updateEffect(progress: Double) {
        updateMotionBlur(progress: progress)
        updateAfterimage(progress: progress)
        renderAfterimages()

        // Performance monitoring
        monitorPerformance()
    }

    /// Update with specific window position for afterimage tracking
    func updateEffect(progress: Double, windowPosition: CGPoint) {
        updateMotionBlur(progress: progress)
        updateAfterimage(progress: progress, currentPosition: windowPosition)
        renderAfterimages()

        // Performance monitoring
        monitorPerformance()
    }

    /// Get current blur intensity
    var currentBlurIntensity: Double {
        guard isBlurActive else { return 0.0 }

        let elapsed = Date().timeIntervalSince(startTime)
        let progress = min(elapsed / duration, 1.0)
        return blurIntensity * (1.0 - progress)
    }

    /// Get current afterimage count
    var currentAfterimageCount: Int {
        return afterimageFrames.count
    }

    /// Check if effect is still active
    var isActive: Bool {
        let elapsed = Date().timeIntervalSince(startTime)
        return elapsed < duration && (isBlurActive || !afterimageFrames.isEmpty)
    }

    /// Clean up resources
    func cleanup() {
        // Clean up motion blur
        blurFilter = nil
        blurLayer?.removeFromSuperlayer()
        blurLayer = nil
        isBlurActive = false

        // Clean up afterimages
        afterimageFrames.removeAll()

        // Reset counters
        frameCount = 0
    }

    // MARK: - Performance Monitoring

    private func monitorPerformance() {
        let now = Date()

        // Check performance every second
        if now.timeIntervalSince(lastPerformanceCheck) >= 1.0 {
            let fps = Double(frameCount) / now.timeIntervalSince(lastPerformanceCheck)

            if fps < 30.0 {
                print("Motion effect performance warning for window \(windowId): \(fps) fps")

                // Reduce quality if performance is poor
                reduceQuality()
            }

            frameCount = 0
            lastPerformanceCheck = now
        }
    }

    private func reduceQuality() {
        // Reduce afterimage trail length
        if afterimageFrames.count > 3 {
            let removeCount = afterimageFrames.count / 2
            afterimageFrames.removeFirst(removeCount)
        }

        // Reduce blur intensity
        if let blurFilter {
            let currentRadius = blurFilter.value(forKey: kCIInputRadiusKey) as? Double ?? 0.0
            blurFilter.setValue(currentRadius * 0.7, forKey: kCIInputRadiusKey)
        }
    }
}

// MARK: - Supporting Structures

/// Represents a single frame in the afterimage trail
private struct AfterimageFrame {
    let position: CGPoint
    let opacity: Double
    let timestamp: Date
}

/// Tracks window velocity for motion effect detection
class WindowVelocityTracker {

    private var positionHistory: [UInt32: [(position: CGPoint, timestamp: Date)]] = [:]
    private let maxHistorySize = 5
    private let velocityCalculationWindow: TimeInterval = 0.1 // 100ms window

    /// Update position for velocity tracking
    func updatePosition(for windowId: UInt32, position: CGPoint, timestamp: Date) {
        if positionHistory[windowId] == nil {
            positionHistory[windowId] = []
        }

        positionHistory[windowId]?.append((position: position, timestamp: timestamp))

        // Keep only recent history
        if let history = positionHistory[windowId], history.count > maxHistorySize {
            positionHistory[windowId] = Array(history.suffix(maxHistorySize))
        }

        // Clean up old entries
        cleanupOldEntries(for: windowId, currentTime: timestamp)
    }

    /// Get current velocity for a window
    func getVelocity(for windowId: UInt32) -> CGVector? {
        guard let history = positionHistory[windowId], history.count >= 2 else {
            return nil
        }

        let recent = history.suffix(2)
        let first = recent.first!
        let last = recent.last!

        let deltaTime = last.timestamp.timeIntervalSince(first.timestamp)
        guard deltaTime > 0 else { return nil }

        let deltaX = last.position.x - first.position.x
        let deltaY = last.position.y - first.position.y

        return CGVector(
            dx: deltaX / deltaTime,
            dy: deltaY / deltaTime,
        )
    }

    private func cleanupOldEntries(for windowId: UInt32, currentTime: Date) {
        guard let history = positionHistory[windowId] else { return }

        let cutoffTime = currentTime.addingTimeInterval(-velocityCalculationWindow * 2)
        positionHistory[windowId] = history.filter { $0.timestamp > cutoffTime }

        // Remove empty entries
        if positionHistory[windowId]?.isEmpty == true {
            positionHistory.removeValue(forKey: windowId)
        }
    }

    /// Clean up tracking for a specific window
    func cleanup(for windowId: UInt32) {
        positionHistory.removeValue(forKey: windowId)
    }

    /// Clean up all tracking data
    func cleanupAll() {
        positionHistory.removeAll()
    }
}
