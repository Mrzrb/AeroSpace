import XCTest
@testable import AppBundle

@MainActor
class AnimationConfigTest: XCTestCase {
    
    func testDefaultAnimationConfig() {
        let config = AnimationConfig.default
        
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.defaultDuration, 0.25)
        XCTAssertEqual(config.easingFunction, .easeOut)
        XCTAssertTrue(config.respectSystemPreferences)
        XCTAssertTrue(config.moveAnimationEnabled)
        XCTAssertTrue(config.resizeAnimationEnabled)
        XCTAssertTrue(config.layoutChangeAnimationEnabled)
        XCTAssertTrue(config.workspaceTransitionAnimationEnabled)
        XCTAssertEqual(config.maxConcurrentAnimations, 10)
        XCTAssertTrue(config.adaptiveQuality)
        XCTAssertEqual(config.minFrameRate, 30.0)
    }
    
    func testAnimationConfigValidation() {
        var config = AnimationConfig()
        
        // Test valid configuration
        XCTAssertTrue(config.validate().isEmpty)
        
        // Test invalid duration
        config.defaultDuration = 0.005
        XCTAssertFalse(config.validate().isEmpty)
        XCTAssertTrue(config.validate().contains("Animation duration must be between 0.01 and 2.0 seconds"))
        
        config.defaultDuration = 3.0
        XCTAssertFalse(config.validate().isEmpty)
        
        // Reset to valid
        config.defaultDuration = 0.25
        XCTAssertTrue(config.validate().isEmpty)
        
        // Test invalid max concurrent animations
        config.maxConcurrentAnimations = 0
        XCTAssertFalse(config.validate().isEmpty)
        XCTAssertTrue(config.validate().contains("Max concurrent animations must be between 1 and 50"))
        
        config.maxConcurrentAnimations = 100
        XCTAssertFalse(config.validate().isEmpty)
        
        // Reset to valid
        config.maxConcurrentAnimations = 10
        XCTAssertTrue(config.validate().isEmpty)
        
        // Test invalid frame rate
        config.minFrameRate = 10.0
        XCTAssertFalse(config.validate().isEmpty)
        XCTAssertTrue(config.validate().contains("Min frame rate must be between 15.0 and 120.0 fps"))
        
        config.minFrameRate = 150.0
        XCTAssertFalse(config.validate().isEmpty)
    }
    
    func testAnimationEasingCases() {
        XCTAssertEqual(AnimationEasing.linear.rawValue, "linear")
        XCTAssertEqual(AnimationEasing.easeIn.rawValue, "ease-in")
        XCTAssertEqual(AnimationEasing.easeOut.rawValue, "ease-out")
        XCTAssertEqual(AnimationEasing.easeInOut.rawValue, "ease-in-out")
        
        // Test all cases are covered
        XCTAssertEqual(AnimationEasing.allCases.count, 4)
    }
    
    func testAnimationConfigParsing() {
        let tomlString = """
        [animation]
        enabled = false
        default-duration = 0.5
        easing-function = "ease-in"
        respect-system-preferences = false
        move-animation-enabled = false
        resize-animation-enabled = true
        layout-change-animation-enabled = false
        workspace-transition-animation-enabled = true
        max-concurrent-animations = 5
        adaptive-quality = false
        min-frame-rate = 60.0
        """
        
        let (config, errors) = parseConfig(tomlString)
        XCTAssertTrue(errors.isEmpty, "Parsing should succeed without errors: \(errors)")
        
        XCTAssertFalse(config.animation.enabled)
        XCTAssertEqual(config.animation.defaultDuration, 0.5)
        XCTAssertEqual(config.animation.easingFunction, .easeIn)
        XCTAssertFalse(config.animation.respectSystemPreferences)
        XCTAssertFalse(config.animation.moveAnimationEnabled)
        XCTAssertTrue(config.animation.resizeAnimationEnabled)
        XCTAssertFalse(config.animation.layoutChangeAnimationEnabled)
        XCTAssertTrue(config.animation.workspaceTransitionAnimationEnabled)
        XCTAssertEqual(config.animation.maxConcurrentAnimations, 5)
        XCTAssertFalse(config.animation.adaptiveQuality)
        XCTAssertEqual(config.animation.minFrameRate, 60.0)
    }
    
    func testAnimationConfigParsingWithDefaults() {
        let tomlString = """
        [animation]
        enabled = true
        """
        
        let (config, errors) = parseConfig(tomlString)
        XCTAssertTrue(errors.isEmpty, "Parsing should succeed without errors: \(errors)")
        
        // Should use defaults for unspecified values
        XCTAssertTrue(config.animation.enabled)
        XCTAssertEqual(config.animation.defaultDuration, 0.25)
        XCTAssertEqual(config.animation.easingFunction, .easeOut)
    }
    
    func testAnimationConfigParsingErrors() {
        let tomlString = """
        [animation]
        default-duration = 5.0
        easing-function = "invalid-easing"
        max-concurrent-animations = 100
        """
        
        let (_, errors) = parseConfig(tomlString)
        XCTAssertFalse(errors.isEmpty, "Should have validation errors")
        
        let errorMessages = errors.map(\.description)
        XCTAssertTrue(errorMessages.contains { $0.contains("Animation duration must be between 0.01 and 2.0 seconds") })
        XCTAssertTrue(errorMessages.contains { $0.contains("Invalid animation easing 'invalid-easing'") })
        XCTAssertTrue(errorMessages.contains { $0.contains("Max concurrent animations must be between 1 and 50") })
    }
    
    func testEmptyAnimationConfig() {
        let tomlString = """
        # No animation config specified
        """
        
        let (config, errors) = parseConfig(tomlString)
        XCTAssertTrue(errors.isEmpty, "Parsing should succeed without errors: \(errors)")
        
        // Should use default animation config
        XCTAssertEqual(config.animation.enabled, AnimationConfig.default.enabled)
        XCTAssertEqual(config.animation.defaultDuration, AnimationConfig.default.defaultDuration)
        XCTAssertEqual(config.animation.easingFunction, AnimationConfig.default.easingFunction)
    }
}