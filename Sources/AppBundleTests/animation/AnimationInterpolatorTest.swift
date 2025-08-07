import XCTest
import CoreGraphics
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
        XCTAssertEqual(AnimationInterpolator.applyEasing(0.5, easing: .linear), 0.5, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.applyEasing(0.5, easing: .easeIn), 0.25, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.applyEasing(0.5, easing: .easeOut), 0.75, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.applyEasing(0.5, easing: .easeInOut), 0.5, accuracy: 0.001)

        // Test clamping
        XCTAssertEqual(AnimationInterpolator.applyEasing(-0.5, easing: .linear), 0.0, accuracy: 0.001)
        XCTAssertEqual(AnimationInterpolator.applyEasing(1.5, easing: .linear), 1.0, accuracy: 0.001)
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
        XCTAssertEqual(easeInProgress, 0.25, accuracy: 0.001)
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
