import XCTest
import CoreGraphics
import QuartzCore
@testable import AppBundle

class AnimationInterpolatorTest: XCTestCase {

    // MARK: - Easing Function Tests

    func testLinearEasing() {
        XCTAssertEqual(AnimationInterpolator.linear(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.linear(0.25), 0.25, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.linear(0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.linear(0.75), 0.75, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.linear(1.0), 1.0, accuracy: 0.001)
    }

    func testEaseInEasing() {
        XCTAssertEqual(AnimationInterpolator.easeIn(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.easeIn(0.5), 0.25, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.easeIn(1.0), 1.0, accuracy: 0.001)

        // Ease-in should be slower at the beginning
        XCTAssertLessThan(AnimationInterpolator.easeIn(0.25), 0.25)
        XCTAssertGreaterThan(AnimationInterpolator.easeIn(0.75), 0.5)
    }

    func testEaseOutEasing() {
        XCTAssertEqual(AnimationInterpolator.easeOut(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.easeOut(0.5), 0.75, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.easeOut(1.0), 1.0, accuracy: 0.001)

        // Ease-out should be faster at the beginning
        XCTAssertGreaterThan(AnimationInterpolator.easeOut(0.25), 0.25)
        XCTAssertLessThan(AnimationInterpolator.easeOut(0.75), 1.0)
    }

    func testEaseInOutEasing() {
        XCTAssertEqual(AnimationInterpolator.easeInOut(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.easeInOut(0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.easeInOut(1.0), 1.0, accuracy: 0.001)

        // Should be slower at beginning and end, faster in middle
        XCTAssertLessThan(AnimationInterpolator.easeInOut(0.25), 0.25)
        XCTAssertGreaterThan(AnimationInterpolator.easeInOut(0.75), 0.75)
    }

    func testSpringEasing() {
        // Test basic spring behavior with moderate damping
        let damping: Float = 0.8
        let velocity: Float = 0.0

        // Spring should start at 0 and end at 1
        XCTAssertEqual(AnimationInterpolator.spring(0.0, damping: damping, velocity: velocity), 0.0, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.spring(1.0, damping: damping, velocity: velocity), 1.0, accuracy: 0.01)

        // Spring should be monotonic for overdamped case
        let progress25 = AnimationInterpolator.spring(0.25, damping: damping, velocity: velocity)
        let progress50 = AnimationInterpolator.spring(0.5, damping: damping, velocity: velocity)
        let progress75 = AnimationInterpolator.spring(0.75, damping: damping, velocity: velocity)

        XCTAssertGreaterThan(progress25, 0.0)
        XCTAssertGreaterThan(progress50, progress25)
        XCTAssertGreaterThan(progress75, progress50)
        XCTAssertLessThan(progress75, 1.1) // Allow for slight overshoot in spring
    }

    func testSpringEasingUnderdamped() {
        // Test underdamped spring (oscillatory behavior)
        let damping: Float = 0.3
        let velocity: Float = 0.0

        // Should still start at 0 and end at 1
        XCTAssertEqual(AnimationInterpolator.spring(0.0, damping: damping, velocity: velocity), 0.0, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.spring(1.0, damping: damping, velocity: velocity), 1.0, accuracy: 0.1)

        // Underdamped spring may overshoot
        let midProgress = AnimationInterpolator.spring(0.5, damping: damping, velocity: velocity)
        XCTAssertGreaterThan(midProgress, 0.0)
        // May overshoot 1.0 temporarily
    }

    func testSpringEasingOverdamped() {
        // Test overdamped spring (no oscillation)
        let damping: Float = 1.5
        let velocity: Float = 0.0

        // Should be monotonic and smooth
        XCTAssertEqual(AnimationInterpolator.spring(0.0, damping: damping, velocity: velocity), 0.0, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.spring(1.0, damping: damping, velocity: velocity), 1.0, accuracy: 0.01)

        // Should be monotonic
        let values = [0.0, 0.25, 0.5, 0.75, 1.0]
        let results = values.map { AnimationInterpolator.spring($0, damping: damping, velocity: velocity) }

        for i in 1 ..< results.count {
            XCTAssertGreaterThanOrEqual(results[i], results[i - 1], "Overdamped spring should be monotonic")
        }
    }

    func testSpringEasingWithVelocity() {
        // Test spring with initial velocity
        let damping: Float = 0.8
        let positiveVelocity: Float = 2.0
        let negativeVelocity: Float = -2.0

        // With positive velocity, should start faster
        let posVel25 = AnimationInterpolator.spring(0.25, damping: damping, velocity: positiveVelocity)
        let noVel25 = AnimationInterpolator.spring(0.25, damping: damping, velocity: 0.0)
        XCTAssertGreaterThan(posVel25, noVel25)

        // With negative velocity, should start slower
        let negVel25 = AnimationInterpolator.spring(0.25, damping: damping, velocity: negativeVelocity)
        XCTAssertLessThan(negVel25, noVel25)

        // All should end at 1.0
        XCTAssertEqual(AnimationInterpolator.spring(1.0, damping: damping, velocity: positiveVelocity), 1.0, accuracy: 0.01)
        XCTAssertEqual(AnimationInterpolator.spring(1.0, damping: damping, velocity: negativeVelocity), 1.0, accuracy: 0.01)
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

    func testSpringEasingStringParsing() {
        // Valid spring strings
        let validCases = [
            ("spring(0.8, 0.0)", AnimationEasing.spring(damping: 0.8, velocity: 0.0)),
            ("spring(1.0, 2.0)", AnimationEasing.spring(damping: 1.0, velocity: 2.0)),
            ("spring(0.5, -1.5)", AnimationEasing.spring(damping: 0.5, velocity: -1.5)),
        ]

        for (input, expected) in validCases {
            let result = AnimationEasing.from(string: input)
            XCTAssertEqual(result, expected, "Failed to parse: \(input)")
        }

        // Invalid strings
        XCTAssertNil(AnimationEasing.from(string: "spring(0.8)")) // Missing parameter
        XCTAssertNil(AnimationEasing.from(string: "spring(2.5, 0.0)")) // Invalid damping
        XCTAssertNil(AnimationEasing.from(string: "spring(1.0, 15.0)")) // Invalid velocity
        XCTAssertNil(AnimationEasing.from(string: "spring(a, b)")) // Non-numeric parameters
    }

    func testSpringEasingRawValue() {
        let springEasing = AnimationEasing.spring(damping: 0.8, velocity: 2.0)
        XCTAssertEqual(springEasing.rawValue, "spring(0.8, 2.0)")
    }

    // MARK: - Bounce Easing Tests

    func testBounceEasing() {
        // Test basic bounce behavior with moderate intensity
        let intensity: Float = 1.0

        // Bounce should start at 0 and end at 1
        XCTAssertEqual(AnimationInterpolator.bounce(0.0, intensity: intensity), 0.0, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.bounce(1.0, intensity: intensity), 1.0, accuracy: 0.001)

        // Bounce should have characteristic bouncing behavior
        let progress25 = AnimationInterpolator.bounce(0.25, intensity: intensity)
        let progress50 = AnimationInterpolator.bounce(0.5, intensity: intensity)
        let progress75 = AnimationInterpolator.bounce(0.75, intensity: intensity)

        XCTAssertGreaterThan(progress25, 0.0)
        XCTAssertGreaterThan(progress50, progress25)
        XCTAssertGreaterThan(progress75, progress50)
        XCTAssertLessThan(progress75, 1.0)
    }

    func testBounceEasingIntensityVariations() {
        let testProgress = 0.8

        // Test different intensities
        let lowIntensity = AnimationInterpolator.bounce(testProgress, intensity: 0.5)
        let mediumIntensity = AnimationInterpolator.bounce(testProgress, intensity: 1.0)
        let highIntensity = AnimationInterpolator.bounce(testProgress, intensity: 2.0)

        // Higher intensity should generally produce more pronounced effects
        XCTAssertGreaterThan(mediumIntensity, 0.0)
        XCTAssertGreaterThan(highIntensity, 0.0)

        // All should be reasonable values
        XCTAssertLessThan(lowIntensity, 1.5)
        XCTAssertLessThan(mediumIntensity, 1.5)
        XCTAssertLessThan(highIntensity, 2.0)
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

    func testBounceEasingStringParsing() {
        // Valid bounce strings
        let validCases = [
            ("bounce(0.5)", AnimationEasing.bounce(intensity: 0.5)),
            ("bounce(1.0)", AnimationEasing.bounce(intensity: 1.0)),
            ("bounce(2.5)", AnimationEasing.bounce(intensity: 2.5)),
        ]

        for (input, expected) in validCases {
            let result = AnimationEasing.from(string: input)
            XCTAssertEqual(result, expected, "Failed to parse: \(input)")
        }

        // Invalid strings
        XCTAssertNil(AnimationEasing.from(string: "bounce()")) // Missing parameter
        XCTAssertNil(AnimationEasing.from(string: "bounce(3.5)")) // Invalid intensity
        XCTAssertNil(AnimationEasing.from(string: "bounce(a)")) // Non-numeric parameter
        XCTAssertNil(AnimationEasing.from(string: "bounce(1.0, 2.0)")) // Too many parameters
    }

    func testBounceEasingRawValue() {
        let bounceEasing = AnimationEasing.bounce(intensity: 1.5)
        XCTAssertEqual(bounceEasing.rawValue, "bounce(1.5)")
    }

    // MARK: - Elastic Easing Tests

    func testElasticEasing() {
        // Test basic elastic behavior with moderate parameters
        let amplitude: Float = 0.5
        let period: Float = 0.3

        // Elastic should start at 0 and end at 1
        XCTAssertEqual(AnimationInterpolator.elastic(0.0, amplitude: amplitude, period: period), 0.0, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.elastic(1.0, amplitude: amplitude, period: period), 1.0, accuracy: 0.001)

        // Elastic should have oscillatory behavior
        let progress25 = AnimationInterpolator.elastic(0.25, amplitude: amplitude, period: period)
        let progress50 = AnimationInterpolator.elastic(0.5, amplitude: amplitude, period: period)
        let progress75 = AnimationInterpolator.elastic(0.75, amplitude: amplitude, period: period)

        // Values should be reasonable (may overshoot due to elastic nature)
        XCTAssertGreaterThan(progress25, -0.5)
        XCTAssertLessThan(progress25, 1.5)
        XCTAssertGreaterThan(progress50, -0.5)
        XCTAssertLessThan(progress50, 1.5)
        XCTAssertGreaterThan(progress75, -0.5)
        XCTAssertLessThan(progress75, 1.5)
    }

    func testElasticEasingParameterVariations() {
        let testProgress = 0.7

        // Test different amplitudes
        let lowAmplitude = AnimationInterpolator.elastic(testProgress, amplitude: 0.2, period: 0.3)
        let highAmplitude = AnimationInterpolator.elastic(testProgress, amplitude: 1.0, period: 0.3)

        // Test different periods
        let shortPeriod = AnimationInterpolator.elastic(testProgress, amplitude: 0.5, period: 0.1)
        let longPeriod = AnimationInterpolator.elastic(testProgress, amplitude: 0.5, period: 0.8)

        // All should produce reasonable values
        XCTAssertGreaterThan(lowAmplitude, -1.0)
        XCTAssertLessThan(lowAmplitude, 2.0)
        XCTAssertGreaterThan(highAmplitude, -2.0)
        XCTAssertLessThan(highAmplitude, 3.0)
        XCTAssertGreaterThan(shortPeriod, -2.0)
        XCTAssertLessThan(shortPeriod, 3.0)
        XCTAssertGreaterThan(longPeriod, -2.0)
        XCTAssertLessThan(longPeriod, 3.0)
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

    func testElasticEasingStringParsing() {
        // Valid elastic strings
        let validCases = [
            ("elastic(0.5, 0.3)", AnimationEasing.elastic(amplitude: 0.5, period: 0.3)),
            ("elastic(1.0, 0.2)", AnimationEasing.elastic(amplitude: 1.0, period: 0.2)),
            ("elastic(0.8, 0.8)", AnimationEasing.elastic(amplitude: 0.8, period: 0.8)),
        ]

        for (input, expected) in validCases {
            let result = AnimationEasing.from(string: input)
            XCTAssertEqual(result, expected, "Failed to parse: \(input)")
        }

        // Invalid strings
        XCTAssertNil(AnimationEasing.from(string: "elastic(0.5)")) // Missing parameter
        XCTAssertNil(AnimationEasing.from(string: "elastic(2.5, 0.3)")) // Invalid amplitude
        XCTAssertNil(AnimationEasing.from(string: "elastic(0.5, 1.5)")) // Invalid period
        XCTAssertNil(AnimationEasing.from(string: "elastic(a, b)")) // Non-numeric parameters
    }

    func testElasticEasingRawValue() {
        let elasticEasing = AnimationEasing.elastic(amplitude: 0.8, period: 0.4)
        XCTAssertEqual(elasticEasing.rawValue, "elastic(0.8, 0.4)")
    }

    func testEasingFunctionSelection() {
        let linearFunc = AnimationInterpolator.easingFunction(for: .linear)
        let easeInFunc = AnimationInterpolator.easingFunction(for: .easeIn)
        let easeOutFunc = AnimationInterpolator.easingFunction(for: .easeOut)
        let easeInOutFunc = AnimationInterpolator.easingFunction(for: .easeInOut)
        let springFunc = AnimationInterpolator.easingFunction(for: .spring(damping: 0.8, velocity: 0.0))
        let bounceFunc = AnimationInterpolator.easingFunction(for: .bounce(intensity: 1.0))
        let elasticFunc = AnimationInterpolator.easingFunction(for: .elastic(amplitude: 0.5, period: 0.3))

        XCTAssertEqual(linearFunc(0.5), 0.5, accuracy: 0.01)
        XCTAssertEqual(easeInFunc(0.5), 0.25, accuracy: 0.01)
        XCTAssertEqual(easeOutFunc(0.5), 0.75, accuracy: 0.01)
        XCTAssertEqual(easeInOutFunc(0.5), 0.5, accuracy: 0.01)

        // Spring function should produce reasonable values
        let springResult = springFunc(0.5)
        XCTAssertGreaterThan(springResult, 0.0)
        XCTAssertLessThan(springResult, 1.5) // Allow for some overshoot

        // Bounce function should produce reasonable values
        let bounceResult = bounceFunc(0.5)
        XCTAssertGreaterThan(bounceResult, 0.0)
        XCTAssertLessThan(bounceResult, 1.5) // Allow for some overshoot

        // Elastic function should produce reasonable values
        let elasticResult = elasticFunc(0.5)
        XCTAssertGreaterThan(elasticResult, -1.0) // Allow for undershoot
        XCTAssertLessThan(elasticResult, 2.0) // Allow for overshoot
    }

    func testManualEasingFunctionSelection() {
        let linearFunc = AnimationInterpolator.manualEasingFunction(for: .linear)
        let easeInFunc = AnimationInterpolator.manualEasingFunction(for: .easeIn)
        let easeOutFunc = AnimationInterpolator.manualEasingFunction(for: .easeOut)
        let easeInOutFunc = AnimationInterpolator.manualEasingFunction(for: .easeInOut)
        let springFunc = AnimationInterpolator.manualEasingFunction(for: .spring(damping: 0.8, velocity: 0.0))
        let bounceFunc = AnimationInterpolator.manualEasingFunction(for: .bounce(intensity: 1.0))
        let elasticFunc = AnimationInterpolator.manualEasingFunction(for: .elastic(amplitude: 0.5, period: 0.3))

        XCTAssertEqual(linearFunc(0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(easeInFunc(0.5), 0.25, accuracy: 0.001)
        XCTAssertEqual(easeOutFunc(0.5), 0.75, accuracy: 0.001)
        XCTAssertEqual(easeInOutFunc(0.5), 0.5, accuracy: 0.001)

        // Spring function should produce reasonable values
        let springResult = springFunc(0.5)
        XCTAssertGreaterThan(springResult, 0.0)
        XCTAssertLessThan(springResult, 1.5) // Allow for some overshoot

        // Bounce function should produce reasonable values
        let bounceResult = bounceFunc(0.5)
        XCTAssertGreaterThan(bounceResult, 0.0)
        XCTAssertLessThan(bounceResult, 1.5) // Allow for some overshoot

        // Elastic function should produce reasonable values
        let elasticResult = elasticFunc(0.5)
        XCTAssertGreaterThan(elasticResult, -1.0) // Allow for undershoot
        XCTAssertLessThan(elasticResult, 2.0) // Allow for overshoot
    }

    // MARK: - Interpolation Tests

    func testInterpolatePoint() {
        let from = CGPoint(x: 0, y: 0)
        let to = CGPoint(x: 100, y: 200)

        let result0 = AnimationInterpolator.interpolatePoint(from, to, progress: 0.0)
        XCTAssertEqual(result0.x, 0, accuracy: 0.001)
        XCTAssertEqual(result0.y, 0, accuracy: 0.001)

        let result50 = AnimationInterpolator.interpolatePoint(from, to, progress: 0.5)
        XCTAssertEqual(result50.x, 50, accuracy: 0.001)
        XCTAssertEqual(result50.y, 100, accuracy: 0.001)

        let result100 = AnimationInterpolator.interpolatePoint(from, to, progress: 1.0)
        XCTAssertEqual(result100.x, 100, accuracy: 0.001)
        XCTAssertEqual(result100.y, 200, accuracy: 0.001)
    }

    func testInterpolatePointClamping() {
        let from = CGPoint(x: 0, y: 0)
        let to = CGPoint(x: 100, y: 100)

        // Test negative progress
        let resultNegative = AnimationInterpolator.interpolatePoint(from, to, progress: -0.5)
        XCTAssertEqual(resultNegative.x, 0, accuracy: 0.001)
        XCTAssertEqual(resultNegative.y, 0, accuracy: 0.001)

        // Test progress > 1
        let resultOver = AnimationInterpolator.interpolatePoint(from, to, progress: 1.5)
        XCTAssertEqual(resultOver.x, 100, accuracy: 0.001)
        XCTAssertEqual(resultOver.y, 100, accuracy: 0.001)
    }

    func testInterpolateSize() {
        let from = CGSize(width: 100, height: 50)
        let to = CGSize(width: 200, height: 150)

        let result0 = AnimationInterpolator.interpolateSize(from, to, progress: 0.0)
        XCTAssertEqual(result0.width, 100, accuracy: 0.001)
        XCTAssertEqual(result0.height, 50, accuracy: 0.001)

        let result50 = AnimationInterpolator.interpolateSize(from, to, progress: 0.5)
        XCTAssertEqual(result50.width, 150, accuracy: 0.001)
        XCTAssertEqual(result50.height, 100, accuracy: 0.001)

        let result100 = AnimationInterpolator.interpolateSize(from, to, progress: 1.0)
        XCTAssertEqual(result100.width, 200, accuracy: 0.001)
        XCTAssertEqual(result100.height, 150, accuracy: 0.001)
    }

    func testInterpolateRect() {
        let from = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let to = Rect(topLeftX: 50, topLeftY: 25, width: 200, height: 150)

        let result0 = AnimationInterpolator.interpolateRect(from, to, progress: 0.0)
        XCTAssertEqual(result0.topLeftX, 0, accuracy: 0.001)
        XCTAssertEqual(result0.topLeftY, 0, accuracy: 0.001)
        XCTAssertEqual(result0.width, 100, accuracy: 0.001)
        XCTAssertEqual(result0.height, 100, accuracy: 0.001)

        let result50 = AnimationInterpolator.interpolateRect(from, to, progress: 0.5)
        XCTAssertEqual(result50.topLeftX, 25, accuracy: 0.001)
        XCTAssertEqual(result50.topLeftY, 12.5, accuracy: 0.001)
        XCTAssertEqual(result50.width, 150, accuracy: 0.001)
        XCTAssertEqual(result50.height, 125, accuracy: 0.001)

        let result100 = AnimationInterpolator.interpolateRect(from, to, progress: 1.0)
        XCTAssertEqual(result100.topLeftX, 50, accuracy: 0.001)
        XCTAssertEqual(result100.topLeftY, 25, accuracy: 0.001)
        XCTAssertEqual(result100.width, 200, accuracy: 0.001)
        XCTAssertEqual(result100.height, 150, accuracy: 0.001)
    }

    func testInterpolateDouble() {
        let result0 = AnimationInterpolator.interpolateDouble(10.0, 20.0, progress: 0.0)
        XCTAssertEqual(result0, 10.0, accuracy: 0.001)

        let result50 = AnimationInterpolator.interpolateDouble(10.0, 20.0, progress: 0.5)
        XCTAssertEqual(result50, 15.0, accuracy: 0.001)

        let result100 = AnimationInterpolator.interpolateDouble(10.0, 20.0, progress: 1.0)
        XCTAssertEqual(result100, 20.0, accuracy: 0.001)
    }

    func testInterpolateCGFloat() {
        let result0 = AnimationInterpolator.interpolateCGFloat(10.0, 20.0, progress: 0.0)
        XCTAssertEqual(result0, 10.0, accuracy: 0.001)

        let result50 = AnimationInterpolator.interpolateCGFloat(10.0, 20.0, progress: 0.5)
        XCTAssertEqual(result50, 15.0, accuracy: 0.001)

        let result100 = AnimationInterpolator.interpolateCGFloat(10.0, 20.0, progress: 1.0)
        XCTAssertEqual(result100, 20.0, accuracy: 0.001)
    }

    // MARK: - Utility Method Tests

    func testCalculateProgress() {
        let startTime = Date()
        let duration: TimeInterval = 1.0

        // Test at start
        let progress0 = AnimationInterpolator.calculateProgress(
            startTime: startTime,
            duration: duration,
            currentTime: startTime,
        )
        XCTAssertEqual(progress0, 0.0, accuracy: 0.001)

        // Test at middle
        let midTime = startTime.addingTimeInterval(0.5)
        let progress50 = AnimationInterpolator.calculateProgress(
            startTime: startTime,
            duration: duration,
            currentTime: midTime,
        )
        XCTAssertEqual(progress50, 0.5, accuracy: 0.001)

        // Test at end
        let endTime = startTime.addingTimeInterval(1.0)
        let progress100 = AnimationInterpolator.calculateProgress(
            startTime: startTime,
            duration: duration,
            currentTime: endTime,
        )
        XCTAssertEqual(progress100, 1.0, accuracy: 0.001)

        // Test beyond end
        let beyondTime = startTime.addingTimeInterval(1.5)
        let progressBeyond = AnimationInterpolator.calculateProgress(
            startTime: startTime,
            duration: duration,
            currentTime: beyondTime,
        )
        XCTAssertEqual(progressBeyond, 1.0, accuracy: 0.001)
    }

    func testCalculateProgressZeroDuration() {
        let startTime = Date()
        let duration: TimeInterval = 0.0
        let currentTime = startTime.addingTimeInterval(0.5)

        let progress = AnimationInterpolator.calculateProgress(
            startTime: startTime,
            duration: duration,
            currentTime: currentTime,
        )
        XCTAssertEqual(progress, 1.0, accuracy: 0.001)
    }

    func testApplyEasing() {
        // CAMediaTimingFunction-based easing (with slightly relaxed accuracy due to bezier calculation)
        XCTAssertEqual(AnimationInterpolator.applyEasing(0.5, easing: .linear), 0.5, accuracy: 0.01)
        XCTAssertEqual(AnimationInterpolator.applyEasing(0.5, easing: .easeIn), 0.25, accuracy: 0.01)
        XCTAssertEqual(AnimationInterpolator.applyEasing(0.5, easing: .easeOut), 0.75, accuracy: 0.01)
        XCTAssertEqual(AnimationInterpolator.applyEasing(0.5, easing: .easeInOut), 0.5, accuracy: 0.01)

        // Test clamping
        XCTAssertEqual(AnimationInterpolator.applyEasing(-0.5, easing: .linear), 0.0, accuracy: 0.01)
        XCTAssertEqual(AnimationInterpolator.applyEasing(1.5, easing: .linear), 1.0, accuracy: 0.01)
    }

    func testApplyManualEasing() {
        XCTAssertEqual(AnimationInterpolator.applyManualEasing(0.5, easing: .linear), 0.5, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.applyManualEasing(0.5, easing: .easeIn), 0.25, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.applyManualEasing(0.5, easing: .easeOut), 0.75, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.applyManualEasing(0.5, easing: .easeInOut), 0.5, accuracy: 0.001)

        // Test clamping
        XCTAssertEqual(AnimationInterpolator.applyManualEasing(-0.5, easing: .linear), 0.0, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.applyManualEasing(1.5, easing: .linear), 1.0, accuracy: 0.001)
    }

    func testCalculateEasedProgress() {
        let startTime = Date()
        let duration: TimeInterval = 1.0
        let midTime = startTime.addingTimeInterval(0.5)

        let linearProgress = AnimationInterpolator.calculateEasedProgress(
            startTime: startTime,
            duration: duration,
            easing: .linear,
            currentTime: midTime,
        )
        XCTAssertEqual(linearProgress, 0.5, accuracy: 0.001)

        let easeInProgress = AnimationInterpolator.calculateEasedProgress(
            startTime: startTime,
            duration: duration,
            easing: .easeIn,
            currentTime: midTime,
        )
        XCTAssertEqual(easeInProgress, 0.25, accuracy: 0.01)
    }

    // MARK: - CAMediaTimingFunction Tests

    func testTimingFunctionCreation() {
        let linearTiming = AnimationInterpolator.timingFunction(for: .linear)
        let easeInTiming = AnimationInterpolator.timingFunction(for: .easeIn)
        let easeOutTiming = AnimationInterpolator.timingFunction(for: .easeOut)
        let easeInOutTiming = AnimationInterpolator.timingFunction(for: .easeInOut)

        XCTAssertNotNil(linearTiming)
        XCTAssertNotNil(easeInTiming)
        XCTAssertNotNil(easeOutTiming)
        XCTAssertNotNil(easeInOutTiming)
    }

    func testTimingFunctionApplication() {
        let linearTiming = AnimationInterpolator.timingFunction(for: .linear)
        let easeInTiming = AnimationInterpolator.timingFunction(for: .easeIn)

        let linearResult = AnimationInterpolator.applyTimingFunction(0.5, timingFunction: linearTiming)
        let easeInResult = AnimationInterpolator.applyTimingFunction(0.5, timingFunction: easeInTiming)

        XCTAssertEqual(linearResult, 0.5, accuracy: 0.01)
        XCTAssertEqual(easeInResult, 0.25, accuracy: 0.01)

        // Test boundary values
        XCTAssertEqual(AnimationInterpolator.applyTimingFunction(0.0, timingFunction: linearTiming), 0.0, accuracy: 0.01)
        XCTAssertEqual(AnimationInterpolator.applyTimingFunction(1.0, timingFunction: linearTiming), 1.0, accuracy: 0.01)
    }

    func testTimingFunctionClamping() {
        let linearTiming = AnimationInterpolator.timingFunction(for: .linear)

        // Test values outside [0, 1] range
        let negativeResult = AnimationInterpolator.applyTimingFunction(-0.5, timingFunction: linearTiming)
        let overResult = AnimationInterpolator.applyTimingFunction(1.5, timingFunction: linearTiming)

        XCTAssertEqual(negativeResult, 0.0, accuracy: 0.01)
        XCTAssertEqual(overResult, 1.0, accuracy: 0.01)
    }

    func testManualVsTimingFunctionConsistency() {
        let testValues = [0.0, 0.25, 0.5, 0.75, 1.0]
        let easingTypes: [AnimationEasing] = [.linear, .easeIn, .easeOut, .easeInOut]

        for easing in easingTypes {
            for progress in testValues {
                let manualResult = AnimationInterpolator.applyManualEasing(progress, easing: easing)
                let timingFunctionResult = AnimationInterpolator.applyEasing(progress, easing: easing)

                // Allow for some difference due to different calculation methods
                XCTAssertEqual(manualResult, timingFunctionResult, accuracy: 0.05,
                               "Mismatch for \(easing.rawValue) at progress \(progress)")
            }
        }
    }

    // MARK: - Performance Benchmark Tests

    func testEasingPerformanceBenchmark() {
        let benchmark = AnimationInterpolator.benchmarkEasingPerformance(easing: .easeIn, iterations: 1000)

        XCTAssertEqual(benchmark.easingType, .easeIn)
        XCTAssertEqual(benchmark.iterations, 1000)
        XCTAssertGreaterThan(benchmark.manualEasingTime, 0)
        XCTAssertGreaterThan(benchmark.timingFunctionTime, 0)
        XCTAssertGreaterThan(benchmark.speedupFactor, 0)

        // Verify the description contains expected information
        XCTAssertTrue(benchmark.description.contains("ease-in"))
        XCTAssertTrue(benchmark.description.contains("1000"))
    }

    func testComprehensiveEasingBenchmarks() {
        let benchmarks = AnimationInterpolator.runComprehensiveEasingBenchmarks(iterations: 100)

        XCTAssertEqual(benchmarks.count, AnimationEasing.allCases.count)

        for benchmark in benchmarks {
            XCTAssertEqual(benchmark.iterations, 100)
            XCTAssertGreaterThan(benchmark.manualEasingTime, 0)
            XCTAssertGreaterThan(benchmark.timingFunctionTime, 0)
            XCTAssertGreaterThan(benchmark.speedupFactor, 0)
        }

        // Verify all easing types are covered
        let easingTypes = Set(benchmarks.map { $0.easingType })
        let expectedTypes = Set(AnimationEasing.allCases)
        XCTAssertEqual(easingTypes, expectedTypes)
    }

    func testBenchmarkPerformanceReasonable() {
        // This test ensures benchmarks complete in reasonable time
        let startTime = CFAbsoluteTimeGetCurrent()
        let benchmark = AnimationInterpolator.benchmarkEasingPerformance(easing: .linear, iterations: 1000)
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime

        // Benchmark should complete within 1 second for 1000 iterations
        XCTAssertLessThan(totalTime, 1.0)
        XCTAssertGreaterThan(benchmark.speedupFactor, 0)
    }

    // MARK: - Custom Bézier Curve Tests

    func testCustomBezierCurveCreation() {
        let customEasing = AnimationEasing.custom(x1: 0.25, y1: 0.1, x2: 0.75, y2: 0.9)
        let timingFunction = AnimationInterpolator.timingFunction(for: customEasing)

        XCTAssertNotNil(timingFunction)

        // Test that the timing function produces reasonable values
        let result0 = AnimationInterpolator.applyTimingFunction(0.0, timingFunction: timingFunction)
        let result50 = AnimationInterpolator.applyTimingFunction(0.5, timingFunction: timingFunction)
        let result100 = AnimationInterpolator.applyTimingFunction(1.0, timingFunction: timingFunction)

        XCTAssertEqual(result0, 0.0, accuracy: 0.01)
        XCTAssertEqual(result100, 1.0, accuracy: 0.01)
        XCTAssertGreaterThan(result50, 0.0)
        XCTAssertLessThan(result50, 1.0)
    }

    func testCustomBezierCurveValidation() {
        // Valid parameters
        XCTAssertTrue(AnimationEasing.validateBezierParameters(x1: 0.0, y1: 0.0, x2: 1.0, y2: 1.0))
        XCTAssertTrue(AnimationEasing.validateBezierParameters(x1: 0.25, y1: 0.1, x2: 0.75, y2: 0.9))
        XCTAssertTrue(AnimationEasing.validateBezierParameters(x1: 0.42, y1: 0.0, x2: 0.58, y2: 1.0))

        // Y values can be outside [0, 1] for overshoot effects
        XCTAssertTrue(AnimationEasing.validateBezierParameters(x1: 0.5, y1: -0.5, x2: 0.5, y2: 1.5))

        // Invalid X parameters (outside [0, 1])
        XCTAssertFalse(AnimationEasing.validateBezierParameters(x1: -0.1, y1: 0.0, x2: 1.0, y2: 1.0))
        XCTAssertFalse(AnimationEasing.validateBezierParameters(x1: 0.0, y1: 0.0, x2: 1.1, y2: 1.0))
        XCTAssertFalse(AnimationEasing.validateBezierParameters(x1: 1.5, y1: 0.0, x2: 0.5, y2: 1.0))
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

        // Invalid strings
        XCTAssertNil(AnimationEasing.from(string: "invalid"))
        XCTAssertNil(AnimationEasing.from(string: "cubic-bezier(0.25, 0.1, 0.75)")) // Missing parameter
        XCTAssertNil(AnimationEasing.from(string: "cubic-bezier(1.5, 0, 0.5, 1)")) // Invalid X parameter
        XCTAssertNil(AnimationEasing.from(string: "cubic-bezier(a, b, c, d)")) // Non-numeric parameters
    }

    func testCustomBezierCurveRawValue() {
        let customEasing = AnimationEasing.custom(x1: 0.25, y1: 0.1, x2: 0.75, y2: 0.9)
        XCTAssertEqual(customEasing.rawValue, "cubic-bezier(0.25, 0.1, 0.75, 0.9)")

        let standardEasing = AnimationEasing.linear
        XCTAssertEqual(standardEasing.rawValue, "linear")
    }

    func testCustomBezierCurvePerformanceBenchmark() {
        let customEasing = AnimationEasing.custom(x1: 0.25, y1: 0.1, x2: 0.75, y2: 0.9)
        let benchmark = AnimationInterpolator.benchmarkEasingPerformance(easing: customEasing, iterations: 1000)

        XCTAssertEqual(benchmark.easingType, customEasing)
        XCTAssertEqual(benchmark.iterations, 1000)
        XCTAssertGreaterThan(benchmark.manualEasingTime, 0)
        XCTAssertGreaterThan(benchmark.timingFunctionTime, 0)
        XCTAssertGreaterThan(benchmark.speedupFactor, 0)
    }

    func testCustomBezierCurveAccuracy() {
        let customEasing = AnimationEasing.custom(x1: 0.25, y1: 0.1, x2: 0.75, y2: 0.9)

        // Test boundary values
        XCTAssertEqual(AnimationInterpolator.applyEasing(0.0, easing: customEasing), 0.0, accuracy: 0.01)
        XCTAssertEqual(AnimationInterpolator.applyEasing(1.0, easing: customEasing), 1.0, accuracy: 0.01)

        // Test intermediate values are reasonable
        let midResult = AnimationInterpolator.applyEasing(0.5, easing: customEasing)
        XCTAssertGreaterThan(midResult, 0.0)
        XCTAssertLessThan(midResult, 1.0)

        // Test monotonicity (for valid timing functions)
        let values = [0.0, 0.25, 0.5, 0.75, 1.0]
        let results = values.map { AnimationInterpolator.applyEasing($0, easing: customEasing) }

        for i in 1 ..< results.count {
            XCTAssertGreaterThanOrEqual(results[i], results[i - 1], "Custom bezier curve should be monotonic")
        }
    }

    func testCustomBezierCurveManualVsTimingFunctionConsistency() {
        let customEasing = AnimationEasing.custom(x1: 0.25, y1: 0.1, x2: 0.75, y2: 0.9)
        let testValues = [0.0, 0.25, 0.5, 0.75, 1.0]

        for progress in testValues {
            let manualResult = AnimationInterpolator.applyManualEasing(progress, easing: customEasing)
            let timingFunctionResult = AnimationInterpolator.applyEasing(progress, easing: customEasing)

            // Allow for some difference due to different calculation methods
            XCTAssertEqual(manualResult, timingFunctionResult, accuracy: 0.1,
                           "Mismatch for custom bezier at progress \(progress)")
        }
    }

    // MARK: - Edge Case Tests

    func testInterpolationWithIdenticalValues() {
        let point = CGPoint(x: 50, y: 50)
        let size = CGSize(width: 100, height: 100)
        let rect = Rect(topLeftX: 10, topLeftY: 10, width: 50, height: 50)

        let resultPoint = AnimationInterpolator.interpolatePoint(point, point, progress: 0.5)
        XCTAssertEqual(resultPoint.x, 50, accuracy: 0.001)
        XCTAssertEqual(resultPoint.y, 50, accuracy: 0.001)

        let resultSize = AnimationInterpolator.interpolateSize(size, size, progress: 0.5)
        XCTAssertEqual(resultSize.width, 100, accuracy: 0.001)
        XCTAssertEqual(resultSize.height, 100, accuracy: 0.001)

        let resultRect = AnimationInterpolator.interpolateRect(rect, rect, progress: 0.5)
        XCTAssertEqual(resultRect.topLeftX, 10, accuracy: 0.001)
        XCTAssertEqual(resultRect.topLeftY, 10, accuracy: 0.001)
        XCTAssertEqual(resultRect.width, 50, accuracy: 0.001)
        XCTAssertEqual(resultRect.height, 50, accuracy: 0.001)
    }

    func testInterpolationWithNegativeValues() {
        let from = CGPoint(x: -50, y: -25)
        let to = CGPoint(x: 50, y: 25)

        let result = AnimationInterpolator.interpolatePoint(from, to, progress: 0.5)
        XCTAssertEqual(result.x, 0, accuracy: 0.001)
        XCTAssertEqual(result.y, 0, accuracy: 0.001)
    }

    // MARK: - Overshoot Tests (Elastic/Bounce)

    func testElasticEasingProducesOvershoot() {
        // Elastic easing should produce values > 1.0 at some point (overshoot)
        let amplitude: Float = 1.0
        let period: Float = 0.4

        var hasOvershoot = false
        for i in 0...100 {
            let progress = Double(i) / 100.0
            let result = AnimationInterpolator.elastic(progress, amplitude: amplitude, period: period)
            if result > 1.0 {
                hasOvershoot = true
                break
            }
        }
        XCTAssertTrue(hasOvershoot, "Elastic easing should produce overshoot (values > 1.0)")
    }

    func testInterpolateRectAllowsOvershoot() {
        // Test that interpolateRect allows progress > 1.0 for overshoot effects
        let from = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let to = Rect(topLeftX: 100, topLeftY: 100, width: 200, height: 200)

        // Progress > 1.0 should overshoot the target
        let overshootResult = AnimationInterpolator.interpolateRect(from, to, progress: 1.1)
        XCTAssertEqual(overshootResult.topLeftX, 110, accuracy: 0.001, "Should overshoot X position")
        XCTAssertEqual(overshootResult.topLeftY, 110, accuracy: 0.001, "Should overshoot Y position")
        XCTAssertEqual(overshootResult.width, 210, accuracy: 0.001, "Should overshoot width")
        XCTAssertEqual(overshootResult.height, 210, accuracy: 0.001, "Should overshoot height")
    }

    func testInterpolateRectWithElasticEasing() {
        // Simulate elastic animation: position should overshoot then settle
        let from = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let to = Rect(topLeftX: 100, topLeftY: 0, width: 100, height: 100)
        let amplitude: Float = 1.0
        let period: Float = 0.4

        // Find the overshoot point
        var maxX: Double = 0
        for i in 0...100 {
            let rawProgress = Double(i) / 100.0
            let easedProgress = AnimationInterpolator.elastic(rawProgress, amplitude: amplitude, period: period)
            let rect = AnimationInterpolator.interpolateRect(from, to, progress: easedProgress)
            maxX = max(maxX, rect.topLeftX)
        }

        // The max X should exceed the target (100) due to overshoot
        XCTAssertGreaterThan(maxX, 100, "Elastic easing should cause position to overshoot target")

        // Final position should be at target
        let finalProgress = AnimationInterpolator.elastic(1.0, amplitude: amplitude, period: period)
        let finalRect = AnimationInterpolator.interpolateRect(from, to, progress: finalProgress)
        XCTAssertEqual(finalRect.topLeftX, 100, accuracy: 0.001, "Final position should be at target")
    }

    func testInterpolateRectPreventsNegativeSize() {
        // Even with negative progress, size should not go below 1.0
        let from = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let to = Rect(topLeftX: 100, topLeftY: 100, width: 50, height: 50)

        // Extreme overshoot that would make size negative without protection
        let result = AnimationInterpolator.interpolateRect(from, to, progress: 3.0)
        XCTAssertGreaterThanOrEqual(result.width, 1.0, "Width should never be less than 1.0")
        XCTAssertGreaterThanOrEqual(result.height, 1.0, "Height should never be less than 1.0")
    }

    // MARK: - Real Animation Flow Tests

    func testElasticAnimationContextProducesOvershoot() {
        // This test simulates the REAL animation flow through WindowAnimationContext
        let from = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let to = Rect(topLeftX: 100, topLeftY: 0, width: 100, height: 100)
        let elasticEasing = AnimationEasing.elastic(amplitude: 1.0, period: 0.4)

        // Simulate animation at various progress points
        var maxX: Double = 0
        var hasOvershoot = false

        // Test the easing + interpolation pipeline directly (what WindowAnimationContext.update() does)
        for i in 0...100 {
            let rawProgress = Double(i) / 100.0
            let easedProgress = AnimationInterpolator.applyEasing(rawProgress, easing: elasticEasing)
            let rect = AnimationInterpolator.interpolateRect(from, to, progress: easedProgress)

            if rect.topLeftX > to.topLeftX {
                hasOvershoot = true
            }
            maxX = max(maxX, rect.topLeftX)
        }

        XCTAssertTrue(hasOvershoot, "Elastic animation should produce overshoot (X > 100). Max X was: \(maxX)")
        XCTAssertGreaterThan(maxX, 100, "Max X position should exceed target (100). Got: \(maxX)")
    }

    // MARK: - Fixed Pixel Overshoot Tests

    func testInterpolateRectWithMaxOvershootPixels() {
        let from = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let to = Rect(topLeftX: 500, topLeftY: 0, width: 100, height: 100)  // 500px distance
        let maxOvershoot: Double = 20.0

        // Progress 1.25 would normally overshoot by 25% = 125px
        // But with maxOvershootPixels = 20, it should be clamped to 20px
        let result = AnimationInterpolator.interpolateRect(from, to, progress: 1.25, maxOvershootPixels: maxOvershoot)

        XCTAssertEqual(result.topLeftX, 520, accuracy: 0.001, "Overshoot should be clamped to 20px (500 + 20 = 520)")
    }

    func testInterpolateRectWithMaxOvershootPixelsSmallDistance() {
        let from = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let to = Rect(topLeftX: 50, topLeftY: 0, width: 100, height: 100)  // 50px distance
        let maxOvershoot: Double = 20.0

        // Progress 1.25 would overshoot by 25% = 12.5px
        // Since 12.5 < 20, it should NOT be clamped
        let result = AnimationInterpolator.interpolateRect(from, to, progress: 1.25, maxOvershootPixels: maxOvershoot)

        XCTAssertEqual(result.topLeftX, 62.5, accuracy: 0.001, "Small overshoot (12.5px) should not be clamped")
    }

    func testInterpolateRectWithMaxOvershootPixelsNegativeDirection() {
        let from = Rect(topLeftX: 500, topLeftY: 0, width: 100, height: 100)
        let to = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)  // Moving left 500px
        let maxOvershoot: Double = 20.0

        // Progress 1.25 would overshoot by 125px in negative direction
        // Should be clamped to -20px from target
        let result = AnimationInterpolator.interpolateRect(from, to, progress: 1.25, maxOvershootPixels: maxOvershoot)

        XCTAssertEqual(result.topLeftX, -20, accuracy: 0.001, "Negative overshoot should be clamped to -20px")
    }

    func testInterpolateRectWithZeroMaxOvershootPixels() {
        let from = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let to = Rect(topLeftX: 500, topLeftY: 0, width: 100, height: 100)

        // With maxOvershootPixels = 0, overshoot should be unlimited (percentage-based)
        let result = AnimationInterpolator.interpolateRect(from, to, progress: 1.25, maxOvershootPixels: 0)

        XCTAssertEqual(result.topLeftX, 625, accuracy: 0.001, "With maxOvershootPixels=0, overshoot should be unlimited (25% = 125px)")
    }

    func testElasticWithFixedPixelOvershoot() {
        // Simulate real elastic animation with fixed pixel overshoot
        let from = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let to = Rect(topLeftX: 500, topLeftY: 0, width: 100, height: 100)
        let elasticEasing = AnimationEasing.elastic(amplitude: 1.0, period: 0.4)
        let maxOvershoot: Double = 30.0

        var maxX: Double = 0
        for i in 0...100 {
            let rawProgress = Double(i) / 100.0
            let easedProgress = AnimationInterpolator.applyEasing(rawProgress, easing: elasticEasing)
            let rect = AnimationInterpolator.interpolateRect(from, to, progress: easedProgress, maxOvershootPixels: maxOvershoot)
            maxX = max(maxX, rect.topLeftX)
        }

        // Max overshoot should be clamped to target + maxOvershoot
        XCTAssertLessThanOrEqual(maxX, 530, "Max X should not exceed target + maxOvershoot (500 + 30 = 530)")
        XCTAssertGreaterThan(maxX, 500, "Should still have some overshoot")
    }
}
