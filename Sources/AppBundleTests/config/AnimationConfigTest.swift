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
        XCTAssertEqual(config.springDamping, 0.8)
        XCTAssertEqual(config.springVelocity, 0.0)
        XCTAssertEqual(config.bounceIntensity, 1.0)
        XCTAssertEqual(config.elasticAmplitude, 0.5)
        XCTAssertEqual(config.elasticPeriod, 0.3)
    }

    func testAnimationDurationOneParsing() {
        let tomlString = """
            [animations]
            enabled = true
            default-duration = 1
            """

        let (config, errors) = parseConfig(tomlString)
        XCTAssertTrue(errors.isEmpty, "Parsing should succeed: \(errors)")
        XCTAssertEqual(config.animation.defaultDuration, 1.0, "Duration should be 1.0 second")
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

        // Reset to valid
        config.minFrameRate = 30.0
        XCTAssertTrue(config.validate().isEmpty)

        // Test invalid spring parameters
        config.springDamping = -0.1
        XCTAssertFalse(config.validate().isEmpty)
        XCTAssertTrue(config.validate().contains { $0.contains("Spring parameters are invalid") })

        config.springDamping = 2.5
        XCTAssertFalse(config.validate().isEmpty)

        config.springDamping = 1.0
        config.springVelocity = 15.0
        XCTAssertFalse(config.validate().isEmpty)

        config.springVelocity = -15.0
        XCTAssertFalse(config.validate().isEmpty)

        // Reset to valid
        config.springVelocity = 0.0
        XCTAssertTrue(config.validate().isEmpty)

        // Test invalid bounce parameters
        config.bounceIntensity = -0.1
        XCTAssertFalse(config.validate().isEmpty)
        XCTAssertTrue(config.validate().contains { $0.contains("Bounce parameters are invalid") })

        config.bounceIntensity = 3.5
        XCTAssertFalse(config.validate().isEmpty)

        // Reset to valid
        config.bounceIntensity = 1.0
        XCTAssertTrue(config.validate().isEmpty)

        // Test invalid elastic parameters
        config.elasticAmplitude = -0.1
        XCTAssertFalse(config.validate().isEmpty)
        XCTAssertTrue(config.validate().contains { $0.contains("Elastic parameters are invalid") })

        config.elasticAmplitude = 2.5
        XCTAssertFalse(config.validate().isEmpty)

        config.elasticAmplitude = 1.0
        config.elasticPeriod = 0.0
        XCTAssertFalse(config.validate().isEmpty)

        config.elasticPeriod = 1.5
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

    // MARK: - Custom Bézier Curve Tests

    func testCustomBezierCurveValidation() {
        var config = AnimationConfig()

        // Valid custom easing function
        config.easingFunction = .custom(x1: 0.25, y1: 0.1, x2: 0.75, y2: 0.9)
        XCTAssertTrue(config.validate().isEmpty)

        // Invalid custom easing function (X values outside [0, 1])
        config.easingFunction = .custom(x1: -0.1, y1: 0.0, x2: 1.0, y2: 1.0)
        XCTAssertFalse(config.validate().isEmpty)
        XCTAssertTrue(config.validate().contains { $0.contains("invalid Bézier curve parameters") })

        config.easingFunction = .custom(x1: 0.0, y1: 0.0, x2: 1.5, y2: 1.0)
        XCTAssertFalse(config.validate().isEmpty)

        // Y values outside [0, 1] should be valid (for overshoot effects)
        config.easingFunction = .custom(x1: 0.5, y1: -0.5, x2: 0.5, y2: 1.5)
        XCTAssertTrue(config.validate().isEmpty)

        // Standard easing functions should always be valid
        config.easingFunction = .linear
        XCTAssertTrue(config.validate().isEmpty)

        config.easingFunction = .easeIn
        XCTAssertTrue(config.validate().isEmpty)

        config.easingFunction = .easeOut
        XCTAssertTrue(config.validate().isEmpty)

        config.easingFunction = .easeInOut
        XCTAssertTrue(config.validate().isEmpty)

        // Spring easing functions should be valid with proper parameters
        config.easingFunction = .spring(damping: 0.8, velocity: 0.0)
        XCTAssertTrue(config.validate().isEmpty)

        config.easingFunction = .spring(damping: 1.0, velocity: 2.0)
        XCTAssertTrue(config.validate().isEmpty)

        // Invalid spring easing function parameters
        config.easingFunction = .spring(damping: -0.1, velocity: 0.0)
        XCTAssertFalse(config.validate().isEmpty)
        XCTAssertTrue(config.validate().contains { $0.contains("invalid parameters") })

        config.easingFunction = .spring(damping: 2.5, velocity: 0.0)
        XCTAssertFalse(config.validate().isEmpty)

        config.easingFunction = .spring(damping: 1.0, velocity: 15.0)
        XCTAssertFalse(config.validate().isEmpty)

        // Bounce easing functions should be valid with proper parameters
        config.easingFunction = .bounce(intensity: 1.0)
        XCTAssertTrue(config.validate().isEmpty)

        config.easingFunction = .bounce(intensity: 2.5)
        XCTAssertTrue(config.validate().isEmpty)

        // Invalid bounce easing function parameters
        config.easingFunction = .bounce(intensity: -0.1)
        XCTAssertFalse(config.validate().isEmpty)
        XCTAssertTrue(config.validate().contains { $0.contains("invalid parameters") })

        config.easingFunction = .bounce(intensity: 3.5)
        XCTAssertFalse(config.validate().isEmpty)

        // Elastic easing functions should be valid with proper parameters
        config.easingFunction = .elastic(amplitude: 0.5, period: 0.3)
        XCTAssertTrue(config.validate().isEmpty)

        config.easingFunction = .elastic(amplitude: 1.5, period: 0.8)
        XCTAssertTrue(config.validate().isEmpty)

        // Invalid elastic easing function parameters
        config.easingFunction = .elastic(amplitude: -0.1, period: 0.3)
        XCTAssertFalse(config.validate().isEmpty)
        XCTAssertTrue(config.validate().contains { $0.contains("invalid parameters") })

        config.easingFunction = .elastic(amplitude: 2.5, period: 0.3)
        XCTAssertFalse(config.validate().isEmpty)

        config.easingFunction = .elastic(amplitude: 1.0, period: 0.0)
        XCTAssertFalse(config.validate().isEmpty)

        config.easingFunction = .elastic(amplitude: 1.0, period: 1.5)
        XCTAssertFalse(config.validate().isEmpty)
    }

    func testCustomBezierCurveStringParsing() {
        // Valid cubic-bezier strings
        let validCases = [
            ("cubic-bezier(0.25, 0.1, 0.75, 0.9)", AnimationEasing.custom(x1: 0.25, y1: 0.1, x2: 0.75, y2: 0.9)),
            ("cubic-bezier(0.42, 0, 0.58, 1)", AnimationEasing.custom(x1: 0.42, y1: 0.0, x2: 0.58, y2: 1.0)),
            ("cubic-bezier(0, 0, 1, 1)", AnimationEasing.custom(x1: 0.0, y1: 0.0, x2: 1.0, y2: 1.0)),
            ("cubic-bezier(0.5, -0.5, 0.5, 1.5)", AnimationEasing.custom(x1: 0.5, y1: -0.5, x2: 0.5, y2: 1.5)),
        ]

        for (input, expected) in validCases {
            let result = AnimationEasing.from(string: input)
            XCTAssertEqual(result, expected, "Failed to parse: \(input)")
        }

        // Standard easing strings
        XCTAssertEqual(AnimationEasing.from(string: "linear"), .linear)
        XCTAssertEqual(AnimationEasing.from(string: "ease-in"), .easeIn)
        XCTAssertEqual(AnimationEasing.from(string: "ease-out"), .easeOut)
        XCTAssertEqual(AnimationEasing.from(string: "ease-in-out"), .easeInOut)

        // Spring easing strings
        XCTAssertEqual(AnimationEasing.from(string: "spring(0.8, 0.0)"), .spring(damping: 0.8, velocity: 0.0))
        XCTAssertEqual(AnimationEasing.from(string: "spring(1.0, 2.0)"), .spring(damping: 1.0, velocity: 2.0))
        XCTAssertEqual(AnimationEasing.from(string: "spring(0.5, -1.5)"), .spring(damping: 0.5, velocity: -1.5))

        // Bounce easing strings
        XCTAssertEqual(AnimationEasing.from(string: "bounce(1.0)"), .bounce(intensity: 1.0))
        XCTAssertEqual(AnimationEasing.from(string: "bounce(2.5)"), .bounce(intensity: 2.5))
        XCTAssertEqual(AnimationEasing.from(string: "bounce(0.5)"), .bounce(intensity: 0.5))

        // Elastic easing strings
        XCTAssertEqual(AnimationEasing.from(string: "elastic(0.5, 0.3)"), .elastic(amplitude: 0.5, period: 0.3))
        XCTAssertEqual(AnimationEasing.from(string: "elastic(1.0, 0.2)"), .elastic(amplitude: 1.0, period: 0.2))
        XCTAssertEqual(AnimationEasing.from(string: "elastic(0.8, 0.8)"), .elastic(amplitude: 0.8, period: 0.8))

        // Invalid strings
        XCTAssertNil(AnimationEasing.from(string: "invalid"))
        XCTAssertNil(AnimationEasing.from(string: "cubic-bezier(0.25, 0.1, 0.75)")) // Missing parameter
        XCTAssertNil(AnimationEasing.from(string: "cubic-bezier(1.5, 0, 0.5, 1)")) // Invalid X parameter
        XCTAssertNil(AnimationEasing.from(string: "cubic-bezier(a, b, c, d)")) // Non-numeric parameters
        XCTAssertNil(AnimationEasing.from(string: "spring(0.8)")) // Missing parameter
        XCTAssertNil(AnimationEasing.from(string: "spring(2.5, 0.0)")) // Invalid damping
        XCTAssertNil(AnimationEasing.from(string: "spring(1.0, 15.0)")) // Invalid velocity
        XCTAssertNil(AnimationEasing.from(string: "spring(a, b)")) // Non-numeric parameters
        XCTAssertNil(AnimationEasing.from(string: "bounce()")) // Missing parameter
        XCTAssertNil(AnimationEasing.from(string: "bounce(3.5)")) // Invalid intensity
        XCTAssertNil(AnimationEasing.from(string: "bounce(a)")) // Non-numeric parameter
        XCTAssertNil(AnimationEasing.from(string: "elastic(0.5)")) // Missing parameter
        XCTAssertNil(AnimationEasing.from(string: "elastic(2.5, 0.3)")) // Invalid amplitude
        XCTAssertNil(AnimationEasing.from(string: "elastic(0.5, 1.5)")) // Invalid period
        XCTAssertNil(AnimationEasing.from(string: "elastic(a, b)")) // Non-numeric parameters
    }

    func testCustomBezierCurveRawValue() {
        let customEasing = AnimationEasing.custom(x1: 0.25, y1: 0.1, x2: 0.75, y2: 0.9)
        XCTAssertEqual(customEasing.rawValue, "cubic-bezier(0.25, 0.1, 0.75, 0.9)")

        let standardEasing = AnimationEasing.linear
        XCTAssertEqual(standardEasing.rawValue, "linear")

        let springEasing = AnimationEasing.spring(damping: 0.8, velocity: 2.0)
        XCTAssertEqual(springEasing.rawValue, "spring(0.8, 2.0)")

        let bounceEasing = AnimationEasing.bounce(intensity: 1.5)
        XCTAssertEqual(bounceEasing.rawValue, "bounce(1.5)")

        let elasticEasing = AnimationEasing.elastic(amplitude: 0.8, period: 0.4)
        XCTAssertEqual(elasticEasing.rawValue, "elastic(0.8, 0.4)")
    }

    func testCustomBezierCurveConfigParsing() {
        let tomlString = """
            [animation]
            easing-function = "cubic-bezier(0.25, 0.1, 0.75, 0.9)"
            """

        let (config, errors) = parseConfig(tomlString)
        XCTAssertTrue(errors.isEmpty, "Parsing should succeed without errors: \(errors)")

        XCTAssertEqual(config.animation.easingFunction, .custom(x1: 0.25, y1: 0.1, x2: 0.75, y2: 0.9))
    }

    func testCustomBezierCurveConfigParsingErrors() {
        let tomlString = """
            [animation]
            easing-function = "cubic-bezier(1.5, 0, 0.5, 1)"
            """

        let (_, errors) = parseConfig(tomlString)
        XCTAssertFalse(errors.isEmpty, "Should have validation errors")

        let errorMessages = errors.map(\.description)
        XCTAssertTrue(errorMessages.contains { $0.contains("Invalid animation easing") })
    }

    func testCustomBezierCurveOvershootEffects() {
        let tomlString = """
            [animation]
            easing-function = "cubic-bezier(0.5, -0.5, 0.5, 1.5)"
            """

        let (config, errors) = parseConfig(tomlString)
        XCTAssertTrue(errors.isEmpty, "Overshoot effects should be valid: \(errors)")

        XCTAssertEqual(config.animation.easingFunction, .custom(x1: 0.5, y1: -0.5, x2: 0.5, y2: 1.5))
    }

    // MARK: - Spring Easing Tests

    func testSpringEasingConfigParsing() {
        let tomlString = """
            [animation]
            easing-function = "spring(0.8, 2.0)"
            spring-damping = 0.6
            spring-velocity = 1.5
            """

        let (config, errors) = parseConfig(tomlString)
        XCTAssertTrue(errors.isEmpty, "Parsing should succeed without errors: \(errors)")

        XCTAssertEqual(config.animation.easingFunction, .spring(damping: 0.8, velocity: 2.0))
        XCTAssertEqual(config.animation.springDamping, 0.6)
        XCTAssertEqual(config.animation.springVelocity, 1.5)
    }

    func testSpringEasingConfigParsingErrors() {
        let tomlString = """
            [animation]
            easing-function = "spring(2.5, 0.0)"
            spring-damping = -0.1
            spring-velocity = 15.0
            """

        let (_, errors) = parseConfig(tomlString)
        XCTAssertFalse(errors.isEmpty, "Should have validation errors")

        let errorMessages = errors.map(\.description)
        XCTAssertTrue(errorMessages.contains { $0.contains("Invalid animation easing") })
        XCTAssertTrue(errorMessages.contains { $0.contains("Spring parameters are invalid") })
    }

    func testSpringEasingParameterValidation() {
        // Test parameter validation
        XCTAssertTrue(AnimationEasing.validateSpringParameters(damping: 0.0, velocity: 0.0))
        XCTAssertTrue(AnimationEasing.validateSpringParameters(damping: 1.0, velocity: 5.0))
        XCTAssertTrue(AnimationEasing.validateSpringParameters(damping: 2.0, velocity: -5.0))

        // Invalid parameters
        XCTAssertFalse(AnimationEasing.validateSpringParameters(damping: -0.1, velocity: 0.0))
        XCTAssertFalse(AnimationEasing.validateSpringParameters(damping: 2.1, velocity: 0.0))
        XCTAssertFalse(AnimationEasing.validateSpringParameters(damping: 1.0, velocity: 11.0))
        XCTAssertFalse(AnimationEasing.validateSpringParameters(damping: 1.0, velocity: -11.0))
    }

    // MARK: - Bounce Easing Configuration Tests

    func testBounceEasingConfigParsing() {
        let tomlString = """
            [animation]
            easing-function = "bounce(1.5)"
            bounce-intensity = 2.0
            """

        let (config, errors) = parseConfig(tomlString)
        XCTAssertTrue(errors.isEmpty, "Parsing should succeed without errors: \(errors)")

        XCTAssertEqual(config.animation.easingFunction, .bounce(intensity: 1.5))
        XCTAssertEqual(config.animation.bounceIntensity, 2.0)
    }

    func testBounceEasingConfigParsingErrors() {
        let tomlString = """
            [animation]
            easing-function = "bounce(3.5)"
            bounce-intensity = -0.1
            """

        let (_, errors) = parseConfig(tomlString)
        XCTAssertFalse(errors.isEmpty, "Should have validation errors")

        let errorMessages = errors.map(\.description)
        XCTAssertTrue(errorMessages.contains { $0.contains("Invalid animation easing") })
        XCTAssertTrue(errorMessages.contains { $0.contains("Bounce parameters are invalid") })
    }

    func testBounceEasingParameterValidation() {
        // Test parameter validation
        XCTAssertTrue(AnimationEasing.validateBounceParameters(intensity: 0.0))
        XCTAssertTrue(AnimationEasing.validateBounceParameters(intensity: 1.0))
        XCTAssertTrue(AnimationEasing.validateBounceParameters(intensity: 3.0))

        // Invalid parameters
        XCTAssertFalse(AnimationEasing.validateBounceParameters(intensity: -0.1))
        XCTAssertFalse(AnimationEasing.validateBounceParameters(intensity: 3.1))
    }

    // MARK: - Elastic Easing Configuration Tests

    func testElasticEasingConfigParsing() {
        let tomlString = """
            [animation]
            easing-function = "elastic(0.8, 0.4)"
            elastic-amplitude = 1.2
            elastic-period = 0.6
            """

        let (config, errors) = parseConfig(tomlString)
        XCTAssertTrue(errors.isEmpty, "Parsing should succeed without errors: \(errors)")

        XCTAssertEqual(config.animation.easingFunction, .elastic(amplitude: 0.8, period: 0.4))
        XCTAssertEqual(config.animation.elasticAmplitude, 1.2)
        XCTAssertEqual(config.animation.elasticPeriod, 0.6)
    }

    func testElasticEasingConfigParsingErrors() {
        let tomlString = """
            [animation]
            easing-function = "elastic(2.5, 0.3)"
            elastic-amplitude = -0.1
            elastic-period = 1.5
            """

        let (_, errors) = parseConfig(tomlString)
        XCTAssertFalse(errors.isEmpty, "Should have validation errors")

        let errorMessages = errors.map(\.description)
        XCTAssertTrue(errorMessages.contains { $0.contains("Invalid animation easing") })
        XCTAssertTrue(errorMessages.contains { $0.contains("Elastic parameters are invalid") })
    }

    func testElasticEasingParameterValidation() {
        // Test parameter validation
        XCTAssertTrue(AnimationEasing.validateElasticParameters(amplitude: 0.0, period: 0.1))
        XCTAssertTrue(AnimationEasing.validateElasticParameters(amplitude: 1.0, period: 0.5))
        XCTAssertTrue(AnimationEasing.validateElasticParameters(amplitude: 2.0, period: 1.0))

        // Invalid parameters
        XCTAssertFalse(AnimationEasing.validateElasticParameters(amplitude: -0.1, period: 0.5))
        XCTAssertFalse(AnimationEasing.validateElasticParameters(amplitude: 2.1, period: 0.5))
        XCTAssertFalse(AnimationEasing.validateElasticParameters(amplitude: 1.0, period: 0.0))
        XCTAssertFalse(AnimationEasing.validateElasticParameters(amplitude: 1.0, period: 1.1))
    }
}
