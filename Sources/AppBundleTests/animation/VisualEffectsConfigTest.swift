import XCTest
@testable import AppBundle

class VisualEffectsConfigTest: XCTestCase {

    var config: VisualEffectsConfig!

    override func setUp() {
        super.setUp()
        config = VisualEffectsConfig.default
    }

    override func tearDown() {
        config = nil
        super.tearDown()
    }

    // MARK: - Default Configuration Tests

    func testDefaultConfiguration() {
        XCTAssertTrue(config.enabled)
        XCTAssertTrue(config.adaptiveQuality)
        XCTAssertEqual(config.performanceThreshold, 16.67, accuracy: 0.01)

        // Motion blur defaults
        XCTAssertTrue(config.motionBlurEnabled)
        XCTAssertEqual(config.motionBlurVelocityThreshold, 100.0, accuracy: 0.01)
        XCTAssertEqual(config.maxMotionBlurSpeed, 1000.0, accuracy: 0.01)
        XCTAssertEqual(config.maxMotionBlurIntensity, 0.8, accuracy: 0.01)
        XCTAssertTrue(config.automaticMotionEffects)

        // Afterimage defaults
        XCTAssertTrue(config.afterimageEnabled)
        XCTAssertEqual(config.afterimageTrailLength, 5)
        XCTAssertEqual(config.afterimageOpacityDecay, 0.7, accuracy: 0.01)

        // Particle effects defaults
        XCTAssertTrue(config.particleEffectsEnabled)
        XCTAssertEqual(config.particleCount, 20)
        XCTAssertEqual(config.particleSize.width, 4.0, accuracy: 0.01)
        XCTAssertEqual(config.particleSize.height, 4.0, accuracy: 0.01)
        XCTAssertEqual(config.particleEffectDuration, 1.0, accuracy: 0.01)

        // Ripple effects defaults
        XCTAssertTrue(config.rippleEffectsEnabled)
        XCTAssertEqual(config.rippleSpeed, 300.0, accuracy: 0.01)
        XCTAssertEqual(config.rippleMaxRadius, 200.0, accuracy: 0.01)
        XCTAssertEqual(config.rippleDuration, 0.8, accuracy: 0.01)
        XCTAssertEqual(config.rippleIntensity, 0.6, accuracy: 0.01)

        // Performance defaults
        XCTAssertEqual(config.maxConcurrentEffects, 10)
        XCTAssertEqual(config.effectQualityLevel, .high)
        XCTAssertTrue(config.enableGPUAcceleration)
    }

    // MARK: - Validation Tests

    func testValidConfiguration() {
        let errors = config.validate()
        XCTAssertTrue(errors.isEmpty, "Default configuration should be valid")
    }

    func testMotionBlurValidation() {
        // Test invalid velocity threshold
        config.motionBlurVelocityThreshold = -50.0
        var errors = config.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("velocity threshold") })

        // Test velocity threshold too high
        config.motionBlurVelocityThreshold = 3000.0
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)

        // Reset to valid value
        config.motionBlurVelocityThreshold = 100.0

        // Test max speed less than threshold
        config.maxMotionBlurSpeed = 50.0
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("Max motion blur speed") })

        // Reset to valid value
        config.maxMotionBlurSpeed = 1000.0

        // Test invalid blur intensity
        config.maxMotionBlurIntensity = 1.5
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("blur intensity") })

        config.maxMotionBlurIntensity = -0.1
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)
    }

    func testAfterimageValidation() {
        // Test invalid trail length
        config.afterimageTrailLength = 0
        var errors = config.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("trail length") })

        config.afterimageTrailLength = 25
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)

        // Reset to valid value
        config.afterimageTrailLength = 5

        // Test invalid opacity decay
        config.afterimageOpacityDecay = 0.05
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("opacity decay") })

        config.afterimageOpacityDecay = 1.5
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)
    }

    func testParticleEffectsValidation() {
        // Test invalid particle count
        config.particleCount = 0
        var errors = config.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("Particle count") })

        config.particleCount = 150
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)

        // Reset to valid value
        config.particleCount = 20

        // Test invalid particle size
        config.particleSize = CGSize(width: 0.5, height: 4.0)
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("Particle size") })

        config.particleSize = CGSize(width: 4.0, height: 25.0)
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)

        // Reset to valid value
        config.particleSize = CGSize(width: 4.0, height: 4.0)

        // Test invalid effect duration
        config.particleEffectDuration = 0.05
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("effect duration") })

        config.particleEffectDuration = 6.0
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)
    }

    func testRippleEffectsValidation() {
        // Test invalid ripple speed
        config.rippleSpeed = 25.0
        var errors = config.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("Ripple speed") })

        config.rippleSpeed = 1500.0
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)

        // Reset to valid value
        config.rippleSpeed = 300.0

        // Test invalid max radius
        config.rippleMaxRadius = 25.0
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("max radius") })

        config.rippleMaxRadius = 600.0
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)

        // Reset to valid value
        config.rippleMaxRadius = 200.0

        // Test invalid duration
        config.rippleDuration = 0.1
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("Ripple duration") })

        config.rippleDuration = 4.0
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)
    }

    func testPerformanceValidation() {
        // Test invalid max concurrent effects
        config.maxConcurrentEffects = 0
        var errors = config.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("concurrent effects") })

        config.maxConcurrentEffects = 100
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)

        // Reset to valid value
        config.maxConcurrentEffects = 10

        // Test invalid performance threshold
        config.performanceThreshold = 5.0
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("Performance threshold") })

        config.performanceThreshold = 40.0
        errors = config.validate()
        XCTAssertFalse(errors.isEmpty)
    }

    // MARK: - Particle Type Tests

    func testParticleTypeDescriptions() {
        XCTAssertFalse(ParticleType.spark.description.isEmpty)
        XCTAssertFalse(ParticleType.bubble.description.isEmpty)
        XCTAssertFalse(ParticleType.star.description.isEmpty)
        XCTAssertFalse(ParticleType.geometric.description.isEmpty)
    }

    func testParticleTypeRawValues() {
        XCTAssertEqual(ParticleType.spark.rawValue, "spark")
        XCTAssertEqual(ParticleType.bubble.rawValue, "bubble")
        XCTAssertEqual(ParticleType.star.rawValue, "star")
        XCTAssertEqual(ParticleType.geometric.rawValue, "geometric")
    }

    func testAllParticleTypes() {
        let allTypes = ParticleType.allCases
        XCTAssertEqual(allTypes.count, 4)
        XCTAssertTrue(allTypes.contains(.spark))
        XCTAssertTrue(allTypes.contains(.bubble))
        XCTAssertTrue(allTypes.contains(.star))
        XCTAssertTrue(allTypes.contains(.geometric))
    }

    // MARK: - Particle Effect Type Tests

    func testParticleEffectTypeDescriptions() {
        XCTAssertFalse(ParticleEffectType.windowMove.description.isEmpty)
        XCTAssertFalse(ParticleEffectType.windowResize.description.isEmpty)
        XCTAssertFalse(ParticleEffectType.multiWindowOperation.description.isEmpty)
        XCTAssertFalse(ParticleEffectType.ripple.description.isEmpty)
        XCTAssertFalse(ParticleEffectType.explosion.description.isEmpty)
    }

    func testParticleEffectTypeRawValues() {
        XCTAssertEqual(ParticleEffectType.windowMove.rawValue, "window_move")
        XCTAssertEqual(ParticleEffectType.windowResize.rawValue, "window_resize")
        XCTAssertEqual(ParticleEffectType.multiWindowOperation.rawValue, "multi_window")
        XCTAssertEqual(ParticleEffectType.ripple.rawValue, "ripple")
        XCTAssertEqual(ParticleEffectType.explosion.rawValue, "explosion")
    }

    func testAllParticleEffectTypes() {
        let allTypes = ParticleEffectType.allCases
        XCTAssertEqual(allTypes.count, 5)
        XCTAssertTrue(allTypes.contains(.windowMove))
        XCTAssertTrue(allTypes.contains(.windowResize))
        XCTAssertTrue(allTypes.contains(.multiWindowOperation))
        XCTAssertTrue(allTypes.contains(.ripple))
        XCTAssertTrue(allTypes.contains(.explosion))
    }

    // MARK: - Effect Quality Level Tests

    func testEffectQualityLevelDescriptions() {
        XCTAssertFalse(EffectQualityLevel.low.description.isEmpty)
        XCTAssertFalse(EffectQualityLevel.medium.description.isEmpty)
        XCTAssertFalse(EffectQualityLevel.high.description.isEmpty)
        XCTAssertFalse(EffectQualityLevel.ultra.description.isEmpty)
    }

    func testEffectQualityLevelRawValues() {
        XCTAssertEqual(EffectQualityLevel.low.rawValue, "low")
        XCTAssertEqual(EffectQualityLevel.medium.rawValue, "medium")
        XCTAssertEqual(EffectQualityLevel.high.rawValue, "high")
        XCTAssertEqual(EffectQualityLevel.ultra.rawValue, "ultra")
    }

    func testEffectQualityLevelMultipliers() {
        XCTAssertEqual(EffectQualityLevel.low.particleMultiplier, 0.5, accuracy: 0.01)
        XCTAssertEqual(EffectQualityLevel.medium.particleMultiplier, 0.75, accuracy: 0.01)
        XCTAssertEqual(EffectQualityLevel.high.particleMultiplier, 1.0, accuracy: 0.01)
        XCTAssertEqual(EffectQualityLevel.ultra.particleMultiplier, 1.5, accuracy: 0.01)

        XCTAssertEqual(EffectQualityLevel.low.blurIntensityMultiplier, 0.3, accuracy: 0.01)
        XCTAssertEqual(EffectQualityLevel.medium.blurIntensityMultiplier, 0.6, accuracy: 0.01)
        XCTAssertEqual(EffectQualityLevel.high.blurIntensityMultiplier, 1.0, accuracy: 0.01)
        XCTAssertEqual(EffectQualityLevel.ultra.blurIntensityMultiplier, 1.2, accuracy: 0.01)
    }

    func testAllEffectQualityLevels() {
        let allLevels = EffectQualityLevel.allCases
        XCTAssertEqual(allLevels.count, 4)
        XCTAssertTrue(allLevels.contains(.low))
        XCTAssertTrue(allLevels.contains(.medium))
        XCTAssertTrue(allLevels.contains(.high))
        XCTAssertTrue(allLevels.contains(.ultra))
    }

    // MARK: - Configuration Modification Tests

    func testConfigurationModification() {
        // Test that we can modify configuration values
        config.enabled = false
        config.motionBlurEnabled = false
        config.particleEffectsEnabled = false
        config.rippleEffectsEnabled = false

        XCTAssertFalse(config.enabled)
        XCTAssertFalse(config.motionBlurEnabled)
        XCTAssertFalse(config.particleEffectsEnabled)
        XCTAssertFalse(config.rippleEffectsEnabled)

        // Should still validate (disabled features don't need validation)
        let errors = config.validate()
        XCTAssertTrue(errors.isEmpty)
    }

    func testPerformanceConfiguration() {
        // Test performance-oriented configuration
        config.effectQualityLevel = .low
        config.maxConcurrentEffects = 5
        config.particleCount = 10
        config.adaptiveQuality = true
        config.enableGPUAcceleration = false

        let errors = config.validate()
        XCTAssertTrue(errors.isEmpty, "Performance configuration should be valid")
    }

    func testHighQualityConfiguration() {
        // Test high-quality configuration
        config.effectQualityLevel = .ultra
        config.maxConcurrentEffects = 20
        config.particleCount = 50
        config.maxMotionBlurIntensity = 1.0
        config.afterimageTrailLength = 10

        let errors = config.validate()
        XCTAssertTrue(errors.isEmpty, "High quality configuration should be valid")
    }

    // MARK: - Edge Case Tests

    func testBoundaryValues() {
        // Test minimum valid values
        config.motionBlurVelocityThreshold = 0.0
        config.maxMotionBlurSpeed = 0.1
        config.maxMotionBlurIntensity = 0.0
        config.afterimageTrailLength = 1
        config.afterimageOpacityDecay = 0.1
        config.particleCount = 1
        config.particleSize = CGSize(width: 1.0, height: 1.0)
        config.particleEffectDuration = 0.1
        config.rippleSpeed = 50.0
        config.rippleMaxRadius = 50.0
        config.rippleDuration = 0.2
        config.maxConcurrentEffects = 1
        config.performanceThreshold = 8.33

        let errors = config.validate()
        XCTAssertTrue(errors.isEmpty, "Boundary values should be valid")

        // Test maximum valid values
        config.motionBlurVelocityThreshold = 2000.0
        config.maxMotionBlurSpeed = 2000.0
        config.maxMotionBlurIntensity = 1.0
        config.afterimageTrailLength = 20
        config.afterimageOpacityDecay = 1.0
        config.particleCount = 100
        config.particleSize = CGSize(width: 20.0, height: 20.0)
        config.particleEffectDuration = 5.0
        config.rippleSpeed = 1000.0
        config.rippleMaxRadius = 500.0
        config.rippleDuration = 3.0
        config.maxConcurrentEffects = 50
        config.performanceThreshold = 33.33

        let maxErrors = config.validate()
        XCTAssertTrue(maxErrors.isEmpty, "Maximum boundary values should be valid")
    }
}
