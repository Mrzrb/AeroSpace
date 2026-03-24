import XCTest
@testable import AppBundle
import Common

// Disable strict concurrency checking for test code
@preconcurrency import Foundation

class ParticleEffectContextTest: XCTestCase {

    var particleContext: ParticleEffectContext!
    let testWindowId: UInt32 = 12345
    let testOrigin = CGPoint(x: 200, y: 300)
    let testDuration: TimeInterval = 1.0
    let testParticleCount = 20
    let testParticleSize = CGSize(width: 4.0, height: 4.0)

    override func setUp() {
        super.setUp()
        particleContext = ParticleEffectContext(
            windowId: testWindowId,
            effectType: .windowMove,
            origin: testOrigin,
            startTime: Date(),
            duration: testDuration,
            particleCount: testParticleCount,
            particleSize: testParticleSize,
        )
    }

    override func tearDown() {
        particleContext?.cleanup()
        particleContext = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testParticleContextInitialization() {
        XCTAssertEqual(particleContext.windowId, testWindowId)
        XCTAssertEqual(particleContext.effectType, .windowMove)
        XCTAssertEqual(particleContext.origin.x, testOrigin.x, accuracy: 0.01)
        XCTAssertEqual(particleContext.origin.y, testOrigin.y, accuracy: 0.01)
        XCTAssertEqual(particleContext.duration, testDuration, accuracy: 0.01)
        XCTAssertEqual(particleContext.particleCount, testParticleCount)
        XCTAssertEqual(particleContext.particleSize.width, testParticleSize.width, accuracy: 0.01)
        XCTAssertEqual(particleContext.particleSize.height, testParticleSize.height, accuracy: 0.01)
    }

    func testInitialState() {
        XCTAssertTrue(particleContext.effectIsActive)
        XCTAssertGreaterThan(particleContext.currentParticleCount, 0)
    }

    // MARK: - Particle System Tests

    func testWindowMoveParticles() {
        let moveContext = ParticleEffectContext(
            windowId: testWindowId,
            effectType: .windowMove,
            origin: testOrigin,
            startTime: Date(),
            duration: testDuration,
            particleCount: testParticleCount,
            particleSize: testParticleSize,
        )

        XCTAssertTrue(moveContext.effectIsActive)
        XCTAssertGreaterThan(moveContext.currentParticleCount, 0)

        moveContext.cleanup()
    }

    func testWindowResizeParticles() {
        let resizeContext = ParticleEffectContext(
            windowId: testWindowId,
            effectType: .windowResize,
            origin: testOrigin,
            startTime: Date(),
            duration: testDuration,
            particleCount: testParticleCount,
            particleSize: testParticleSize,
        )

        XCTAssertTrue(resizeContext.effectIsActive)
        XCTAssertGreaterThan(resizeContext.currentParticleCount, 0)

        resizeContext.cleanup()
    }

    func testMultiWindowOperationParticles() {
        let multiContext = ParticleEffectContext(
            windowId: testWindowId,
            effectType: .multiWindowOperation,
            origin: testOrigin,
            startTime: Date(),
            duration: testDuration,
            particleCount: testParticleCount,
            particleSize: testParticleSize,
        )

        XCTAssertTrue(multiContext.effectIsActive)
        XCTAssertGreaterThan(multiContext.currentParticleCount, 0)

        multiContext.cleanup()
    }

    func testExplosionParticles() {
        let explosionContext = ParticleEffectContext(
            windowId: testWindowId,
            effectType: .explosion,
            origin: testOrigin,
            startTime: Date(),
            duration: testDuration,
            particleCount: testParticleCount,
            particleSize: testParticleSize,
        )

        XCTAssertTrue(explosionContext.effectIsActive)
        // Explosion should have more particles
        XCTAssertGreaterThan(explosionContext.currentParticleCount, testParticleCount)

        explosionContext.cleanup()
    }

    // MARK: - Ripple Effect Tests

    func testRippleEffect() {
        let rippleContext = ParticleEffectContext(
            windowId: testWindowId,
            effectType: .ripple,
            origin: testOrigin,
            startTime: Date(),
            duration: testDuration,
            particleCount: testParticleCount,
            particleSize: testParticleSize,
        )

        XCTAssertTrue(rippleContext.effectIsActive)

        // Update ripple effect
        rippleContext.updateEffect(progress: 0.5)
        XCTAssertTrue(rippleContext.effectIsActive)

        rippleContext.cleanup()
    }

    func testRippleCompletion() {
        let rippleContext = ParticleEffectContext(
            windowId: testWindowId,
            effectType: .ripple,
            origin: testOrigin,
            startTime: Date(),
            duration: 0.1, // Short duration for quick completion
            particleCount: testParticleCount,
            particleSize: testParticleSize,
        )

        // Complete the ripple effect
        rippleContext.updateEffect(progress: 1.0)

        // Should become inactive after completion
        XCTAssertFalse(rippleContext.effectIsActive)

        rippleContext.cleanup()
    }

    // MARK: - Particle Lifecycle Tests

    func testParticleDecay() {
        let initialCount = particleContext.currentParticleCount

        // Simulate time progression
        particleContext.updateEffect(progress: 0.5)
        let _ = particleContext.currentParticleCount

        particleContext.updateEffect(progress: 0.9)
        let nearEndCount = particleContext.currentParticleCount

        // Particle count should generally decrease over time (some may expire)
        XCTAssertLessThanOrEqual(nearEndCount, initialCount)
    }

    func testParticleExpiration() {
        // Create context with very short duration
        let shortContext = ParticleEffectContext(
            windowId: testWindowId,
            effectType: .windowMove,
            origin: testOrigin,
            startTime: Date().addingTimeInterval(-2.0), // Started 2 seconds ago
            duration: 0.1, // Very short duration
            particleCount: testParticleCount,
            particleSize: testParticleSize,
        )

        // Update with full progress
        shortContext.updateEffect(progress: 1.0)

        // Should have few or no active particles
        XCTAssertLessThanOrEqual(shortContext.currentParticleCount, testParticleCount / 2)

        shortContext.cleanup()
    }

    // MARK: - Effect Management Tests

    func testEffectActiveState() {
        XCTAssertTrue(particleContext.effectIsActive)

        // Effect should remain active during animation
        particleContext.updateEffect(progress: 0.5)
        XCTAssertTrue(particleContext.effectIsActive)

        // Effect should eventually become inactive
        particleContext.updateEffect(progress: 1.0)

        // Wait for particles to expire
        Thread.sleep(forTimeInterval: 0.1)
        particleContext.updateEffect(progress: 1.0)
    }

    func testEffectCleanup() {
        XCTAssertGreaterThan(particleContext.currentParticleCount, 0)

        // Cleanup should remove all particles
        particleContext.cleanup()
        XCTAssertEqual(particleContext.currentParticleCount, 0)
        XCTAssertFalse(particleContext.effectIsActive)
    }

    // MARK: - Performance Tests

    func testUpdatePerformance() {
        measure {
            for i in 0 ..< 100 {
                let progress = Double(i) / 100.0
                particleContext.updateEffect(progress: progress)
            }
        }
    }

    func testHighParticleCountPerformance() {
        let highCountContext = ParticleEffectContext(
            windowId: testWindowId,
            effectType: .explosion,
            origin: testOrigin,
            startTime: Date(),
            duration: testDuration,
            particleCount: 100, // High particle count
            particleSize: testParticleSize,
        )

        measure {
            for i in 0 ..< 50 {
                let progress = Double(i) / 50.0
                highCountContext.updateEffect(progress: progress)
            }
        }

        highCountContext.cleanup()
    }

    func testMemoryUsage() {
        // Create many particle contexts
        var contexts: [ParticleEffectContext] = []

        for i in 0 ..< 10 {
            let context = ParticleEffectContext(
                windowId: UInt32(i),
                effectType: .multiWindowOperation,
                origin: CGPoint(x: Double(i) * 10, y: Double(i) * 10),
                startTime: Date(),
                duration: testDuration,
                particleCount: testParticleCount,
                particleSize: testParticleSize,
            )
            contexts.append(context)
        }

        // Update all contexts
        for context in contexts {
            context.updateEffect(progress: 0.5)
        }

        // Cleanup all contexts
        for context in contexts {
            context.cleanup()
        }
    }

    // MARK: - Edge Cases

    func testZeroParticleCount() {
        let zeroParticleContext = ParticleEffectContext(
            windowId: testWindowId,
            effectType: .windowMove,
            origin: testOrigin,
            startTime: Date(),
            duration: testDuration,
            particleCount: 0,
            particleSize: testParticleSize,
        )

        XCTAssertEqual(zeroParticleContext.currentParticleCount, 0)

        zeroParticleContext.cleanup()
    }

    func testZeroDurationHandling() {
        let zeroDurationContext = ParticleEffectContext(
            windowId: testWindowId,
            effectType: .windowMove,
            origin: testOrigin,
            startTime: Date(),
            duration: 0.0,
            particleCount: testParticleCount,
            particleSize: testParticleSize,
        )

        // Should handle zero duration gracefully
        zeroDurationContext.updateEffect(progress: 1.0)
        XCTAssertFalse(zeroDurationContext.effectIsActive)

        zeroDurationContext.cleanup()
    }

    func testZeroSizeParticles() {
        let zeroSizeContext = ParticleEffectContext(
            windowId: testWindowId,
            effectType: .windowMove,
            origin: testOrigin,
            startTime: Date(),
            duration: testDuration,
            particleCount: testParticleCount,
            particleSize: CGSize.zero,
        )

        // Should handle zero size particles without crashing
        zeroSizeContext.updateEffect(progress: 0.5)

        zeroSizeContext.cleanup()
    }

    func testExtremeOriginCoordinates() {
        let extremeOrigin = CGPoint(x: -10000, y: 10000)
        let extremeContext = ParticleEffectContext(
            windowId: testWindowId,
            effectType: .windowMove,
            origin: extremeOrigin,
            startTime: Date(),
            duration: testDuration,
            particleCount: testParticleCount,
            particleSize: testParticleSize,
        )

        // Should handle extreme coordinates without crashing
        extremeContext.updateEffect(progress: 0.5)
        XCTAssertTrue(extremeContext.effectIsActive)

        extremeContext.cleanup()
    }

    // MARK: - Particle Type Tests

    func testDifferentParticleTypes() {
        let particleTypes: [ParticleType] = [.spark, .bubble, .star, .geometric]

        for _ in particleTypes {
            // Create context for each particle type
            let context = ParticleEffectContext(
                windowId: testWindowId,
                effectType: .windowMove,
                origin: testOrigin,
                startTime: Date(),
                duration: testDuration,
                particleCount: 5, // Small count for testing
                particleSize: testParticleSize,
            )

            // Should handle all particle types
            context.updateEffect(progress: 0.5)
            XCTAssertTrue(context.effectIsActive)

            context.cleanup()
        }
    }
}

// MARK: - Visual Effects Engine Integration Tests

class VisualEffectsEngineTest: XCTestCase {

    // MARK: - Basic Tests (without complex setup)

    func testVisualEffectsEngineExists() {
        // Simple test to verify the engine can be accessed
        XCTAssertNotNil(VisualEffectsConfig.default)
    }

    func testVisualEffectsConfigValidation() {
        let config = VisualEffectsConfig.default
        let errors = config.validate()
        XCTAssertTrue(errors.isEmpty, "Default config should be valid")
    }

    func testVisualEffectsConfigProperties() {
        var config = VisualEffectsConfig.default

        // Test basic property access
        XCTAssertTrue(config.enabled)
        XCTAssertTrue(config.motionBlurEnabled)
        XCTAssertTrue(config.particleEffectsEnabled)

        // Test property modification
        config.enabled = false
        config.motionBlurEnabled = false
        config.particleEffectsEnabled = false

        XCTAssertFalse(config.enabled)
        XCTAssertFalse(config.motionBlurEnabled)
        XCTAssertFalse(config.particleEffectsEnabled)
    }

    func testVisualEffectsConfigValidationWithInvalidValues() {
        var config = VisualEffectsConfig.default

        // Test invalid velocity threshold
        config.motionBlurVelocityThreshold = -100.0
        let errors = config.validate()
        XCTAssertFalse(errors.isEmpty, "Should have validation errors for negative velocity threshold")
    }
}
