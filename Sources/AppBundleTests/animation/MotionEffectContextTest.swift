import XCTest
@testable import AppBundle
import Common

class MotionEffectContextTest: XCTestCase {

    var motionContext: MotionEffectContext!
    let testWindowId: UInt32 = 12345
    let testVelocity = CGVector(dx: 200.0, dy: 100.0)
    let testDuration: TimeInterval = 1.0
    let testBlurIntensity: Double = 0.8
    let testAfterimageLength = 5

    override func setUp() {
        super.setUp()
        motionContext = MotionEffectContext(
            windowId: testWindowId,
            velocity: testVelocity,
            startTime: Date(),
            duration: testDuration,
            blurIntensity: testBlurIntensity,
            afterimageLength: testAfterimageLength,
        )
    }

    override func tearDown() {
        motionContext?.cleanup()
        motionContext = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testMotionContextInitialization() {
        XCTAssertEqual(motionContext.windowId, testWindowId)
        XCTAssertEqual(motionContext.velocity.dx, testVelocity.dx, accuracy: 0.01)
        XCTAssertEqual(motionContext.velocity.dy, testVelocity.dy, accuracy: 0.01)
        XCTAssertEqual(motionContext.duration, testDuration, accuracy: 0.01)
        XCTAssertEqual(motionContext.blurIntensity, testBlurIntensity, accuracy: 0.01)
        XCTAssertEqual(motionContext.afterimageLength, testAfterimageLength)
    }

    func testInitialState() {
        XCTAssertTrue(motionContext.isActive)
        XCTAssertEqual(motionContext.currentAfterimageCount, 0)
        XCTAssertGreaterThan(motionContext.currentBlurIntensity, 0.0)
    }

    // MARK: - Motion Blur Tests

    func testBlurIntensityDecay() {
        let initialIntensity = motionContext.currentBlurIntensity

        // Simulate progress
        motionContext.updateEffect(progress: 0.5)
        let midIntensity = motionContext.currentBlurIntensity

        motionContext.updateEffect(progress: 0.9)
        let nearEndIntensity = motionContext.currentBlurIntensity

        // Blur intensity should decrease over time
        XCTAssertGreaterThan(initialIntensity, midIntensity)
        XCTAssertGreaterThan(midIntensity, nearEndIntensity)
    }

    func testBlurIntensityAtCompletion() {
        // Wait for the duration to pass to simulate completion
        Thread.sleep(forTimeInterval: testDuration + 0.1)
        motionContext.updateEffect(progress: 1.0)

        // Blur intensity should be near zero at completion
        XCTAssertLessThan(motionContext.currentBlurIntensity, 0.1)
    }

    func testZeroBlurIntensityHandling() {
        let zeroBlurContext = MotionEffectContext(
            windowId: testWindowId,
            velocity: testVelocity,
            startTime: Date(),
            duration: testDuration,
            blurIntensity: 0.0,
            afterimageLength: testAfterimageLength,
        )

        XCTAssertEqual(zeroBlurContext.currentBlurIntensity, 0.0)

        zeroBlurContext.cleanup()
    }

    // MARK: - Afterimage Tests

    func testAfterimageCreation() {
        let testPosition = CGPoint(x: 100, y: 200)

        // Wait a bit to ensure the afterimage update interval has passed
        Thread.sleep(forTimeInterval: 0.05)
        motionContext.updateEffect(progress: 0.1, windowPosition: testPosition)

        // Should have created at least one afterimage frame
        XCTAssertGreaterThan(motionContext.currentAfterimageCount, 0)
    }

    func testAfterimageTrailLength() {
        let _ = CGPoint(x: 100, y: 200)

        // Create multiple afterimage frames
        for i in 0 ..< 10 {
            let position = CGPoint(x: 100 + Double(i) * 10, y: 200)
            motionContext.updateEffect(progress: Double(i) * 0.1, windowPosition: position)

            // Add small delay to ensure different timestamps
            Thread.sleep(forTimeInterval: 0.01)
        }

        // Should not exceed the configured trail length
        XCTAssertLessThanOrEqual(motionContext.currentAfterimageCount, testAfterimageLength)
    }

    func testAfterimageOpacityDecay() {
        let testPosition = CGPoint(x: 100, y: 200)

        // Create initial afterimage
        motionContext.updateEffect(progress: 0.1, windowPosition: testPosition)
        let initialCount = motionContext.currentAfterimageCount

        // Wait and update to allow opacity decay
        Thread.sleep(forTimeInterval: 0.1)
        motionContext.updateEffect(progress: 0.5)

        // Afterimages should still exist but may have reduced opacity
        XCTAssertGreaterThanOrEqual(motionContext.currentAfterimageCount, 0)
        XCTAssertLessThanOrEqual(motionContext.currentAfterimageCount, initialCount)
    }

    // MARK: - Effect Lifecycle Tests

    func testEffectActiveState() {
        XCTAssertTrue(motionContext.isActive)

        // Effect should remain active during animation
        motionContext.updateEffect(progress: 0.5)
        XCTAssertTrue(motionContext.isActive)

        // Effect may become inactive after completion
        motionContext.updateEffect(progress: 1.0)

        // Wait for effect to fully complete
        Thread.sleep(forTimeInterval: 0.1)
        motionContext.updateEffect(progress: 1.0)
    }

    func testEffectCleanup() {
        let testPosition = CGPoint(x: 100, y: 200)

        // Wait a bit to ensure the afterimage update interval has passed
        Thread.sleep(forTimeInterval: 0.05)

        // Create some afterimages
        motionContext.updateEffect(progress: 0.1, windowPosition: testPosition)
        XCTAssertGreaterThan(motionContext.currentAfterimageCount, 0)

        // Cleanup should remove all afterimages
        motionContext.cleanup()
        XCTAssertEqual(motionContext.currentAfterimageCount, 0)
        XCTAssertEqual(motionContext.currentBlurIntensity, 0.0)
    }

    // MARK: - Performance Tests

    func testUpdatePerformance() {
        let _ = CGPoint(x: 100, y: 200)

        measure {
            for i in 0 ..< 100 {
                let progress = Double(i) / 100.0
                let position = CGPoint(x: 100 + Double(i), y: 200 + Double(i))
                motionContext.updateEffect(progress: progress, windowPosition: position)
            }
        }
    }

    func testMemoryUsage() {
        let _ = CGPoint(x: 100, y: 200)

        // Create many afterimage frames
        for i in 0 ..< 1000 {
            let progress = Double(i) / 1000.0
            let position = CGPoint(x: 100 + Double(i), y: 200)
            motionContext.updateEffect(progress: progress, windowPosition: position)
        }

        // Should not exceed reasonable memory usage (trail length limit)
        XCTAssertLessThanOrEqual(motionContext.currentAfterimageCount, testAfterimageLength * 2)
    }

    // MARK: - Edge Cases

    func testZeroDurationHandling() {
        let zeroDurationContext = MotionEffectContext(
            windowId: testWindowId,
            velocity: testVelocity,
            startTime: Date(),
            duration: 0.0,
            blurIntensity: testBlurIntensity,
            afterimageLength: testAfterimageLength,
        )

        // Should handle zero duration gracefully
        zeroDurationContext.updateEffect(progress: 1.0)
        XCTAssertEqual(zeroDurationContext.currentBlurIntensity, 0.0)

        zeroDurationContext.cleanup()
    }

    func testHighVelocityHandling() {
        let highVelocity = CGVector(dx: 10000.0, dy: 5000.0)
        let highVelocityContext = MotionEffectContext(
            windowId: testWindowId,
            velocity: highVelocity,
            startTime: Date(),
            duration: testDuration,
            blurIntensity: 1.0,
            afterimageLength: testAfterimageLength,
        )

        // Should handle high velocity without crashing
        highVelocityContext.updateEffect(progress: 0.5)
        XCTAssertGreaterThan(highVelocityContext.currentBlurIntensity, 0.0)

        highVelocityContext.cleanup()
    }

    func testNegativeVelocityHandling() {
        let negativeVelocity = CGVector(dx: -200.0, dy: -100.0)
        let negativeVelocityContext = MotionEffectContext(
            windowId: testWindowId,
            velocity: negativeVelocity,
            startTime: Date(),
            duration: testDuration,
            blurIntensity: testBlurIntensity,
            afterimageLength: testAfterimageLength,
        )

        // Should handle negative velocity correctly
        negativeVelocityContext.updateEffect(progress: 0.5)
        XCTAssertGreaterThan(negativeVelocityContext.currentBlurIntensity, 0.0)

        negativeVelocityContext.cleanup()
    }
}

// MARK: - Window Velocity Tracker Tests

class WindowVelocityTrackerTest: XCTestCase {

    var velocityTracker: WindowVelocityTracker!
    let testWindowId: UInt32 = 12345

    override func setUp() {
        super.setUp()
        velocityTracker = WindowVelocityTracker()
    }

    override func tearDown() {
        velocityTracker = nil
        super.tearDown()
    }

    func testVelocityCalculation() {
        let startPosition = CGPoint(x: 100, y: 200)
        let endPosition = CGPoint(x: 200, y: 300)
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(0.1) // 100ms

        velocityTracker.updatePosition(for: testWindowId, position: startPosition, timestamp: startTime)
        velocityTracker.updatePosition(for: testWindowId, position: endPosition, timestamp: endTime)

        guard let velocity = velocityTracker.getVelocity(for: testWindowId) else {
            XCTFail("Should have calculated velocity")
            return
        }

        // Expected velocity: 1000 pixels/second in both x and y
        XCTAssertEqual(velocity.dx, 1000.0, accuracy: 10.0)
        XCTAssertEqual(velocity.dy, 1000.0, accuracy: 10.0)
    }

    func testInsufficientDataHandling() {
        let position = CGPoint(x: 100, y: 200)
        velocityTracker.updatePosition(for: testWindowId, position: position, timestamp: Date())

        // Should return nil with insufficient data
        XCTAssertNil(velocityTracker.getVelocity(for: testWindowId))
    }

    func testZeroTimeIntervalHandling() {
        let position1 = CGPoint(x: 100, y: 200)
        let position2 = CGPoint(x: 200, y: 300)
        let timestamp = Date()

        velocityTracker.updatePosition(for: testWindowId, position: position1, timestamp: timestamp)
        velocityTracker.updatePosition(for: testWindowId, position: position2, timestamp: timestamp)

        // Should return nil for zero time interval
        XCTAssertNil(velocityTracker.getVelocity(for: testWindowId))
    }

    func testCleanup() {
        let position = CGPoint(x: 100, y: 200)
        velocityTracker.updatePosition(for: testWindowId, position: position, timestamp: Date())

        velocityTracker.cleanup(for: testWindowId)

        // Should return nil after cleanup
        XCTAssertNil(velocityTracker.getVelocity(for: testWindowId))
    }
}
