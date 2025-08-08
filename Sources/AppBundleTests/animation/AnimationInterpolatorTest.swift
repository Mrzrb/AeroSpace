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

    func testEasingFunctionSelection() {
        let linearFunc = AnimationInterpolator.easingFunction(for: .linear)
        let easeInFunc = AnimationInterpolator.easingFunction(for: .easeIn)
        let easeOutFunc = AnimationInterpolator.easingFunction(for: .easeOut)
        let easeInOutFunc = AnimationInterpolator.easingFunction(for: .easeInOut)

        XCTAssertEqual(linearFunc(0.5), 0.5, accuracy: 0.01)
        XCTAssertEqual(easeInFunc(0.5), 0.25, accuracy: 0.01)
        XCTAssertEqual(easeOutFunc(0.5), 0.75, accuracy: 0.01)
        XCTAssertEqual(easeInOutFunc(0.5), 0.5, accuracy: 0.01)
    }

    func testManualEasingFunctionSelection() {
        let linearFunc = AnimationInterpolator.manualEasingFunction(for: .linear)
        let easeInFunc = AnimationInterpolator.manualEasingFunction(for: .easeIn)
        let easeOutFunc = AnimationInterpolator.manualEasingFunction(for: .easeOut)
        let easeInOutFunc = AnimationInterpolator.manualEasingFunction(for: .easeInOut)

        XCTAssertEqual(linearFunc(0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(easeInFunc(0.5), 0.25, accuracy: 0.001)
        XCTAssertEqual(easeOutFunc(0.5), 0.75, accuracy: 0.001)
        XCTAssertEqual(easeInOutFunc(0.5), 0.5, accuracy: 0.001)
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
        
        for i in 1..<results.count {
            XCTAssertGreaterThanOrEqual(results[i], results[i-1], "Custom bezier curve should be monotonic")
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
}
