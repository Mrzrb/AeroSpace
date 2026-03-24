import XCTest
@testable import AppBundle

@MainActor
class WindowAnimationContextTest: XCTestCase {

    // MARK: - Test Properties

    let testWindowId: UInt32 = 123
    let sourceRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
    let targetRect = Rect(topLeftX: 50, topLeftY: 25, width: 200, height: 150)
    let testDuration: TimeInterval = 1.0

    // MARK: - Initialization Tests

    func testInitialization() {
        let startTime = Date()
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
            easingFunction: .linear,
            startTime: startTime,
        )

        XCTAssertEqual(context.windowId, testWindowId)
        XCTAssertEqual(context.animationType, .move)
        XCTAssertEqual(context.sourceRect, sourceRect)
        XCTAssertEqual(context.targetRect, targetRect)
        XCTAssertEqual(context.duration, testDuration)
        XCTAssertEqual(context.easingFunction, .linear)
        XCTAssertEqual(context.startTime, startTime)
        XCTAssertFalse(context.isComplete)
        XCTAssertFalse(context.isCancelled)
        XCTAssertTrue(context.isActive)
    }

    func testDefaultValues() {
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .resize,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )

        XCTAssertEqual(context.easingFunction, .easeOut)
        XCTAssertTrue(context.isActive)
    }

    // MARK: - Progress Calculation Tests

    func testCurrentProgressAtStart() {
        let startTime = Date()
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
            startTime: startTime,
        )

        XCTAssertEqual(context.currentProgress, 0.0, accuracy: 0.01)
    }

    func testCurrentProgressMidway() {
        let startTime = Date().addingTimeInterval(-0.5) // Started 0.5 seconds ago
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
            startTime: startTime,
        )

        XCTAssertEqual(context.currentProgress, 0.5, accuracy: 0.1)
    }

    func testCurrentProgressComplete() {
        let startTime = Date().addingTimeInterval(-1.5) // Started 1.5 seconds ago
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
            startTime: startTime,
        )

        XCTAssertEqual(context.currentProgress, 1.0, accuracy: 0.01)
        XCTAssertTrue(context.isComplete)
    }

    // MARK: - Animation State Tests

    func testAnimationStates() {
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )

        // Initially active
        XCTAssertTrue(context.isActive)
        XCTAssertFalse(context.isComplete)
        XCTAssertFalse(context.isCancelled)

        // After completion
        context.complete()
        XCTAssertFalse(context.isActive)
        XCTAssertTrue(context.isComplete)
        XCTAssertFalse(context.isCancelled)
    }

    func testAnimationCancellation() {
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )

        context.cancel()

        XCTAssertFalse(context.isActive)
        XCTAssertFalse(context.isComplete)
        XCTAssertTrue(context.isCancelled)
    }

    // MARK: - Update Method Tests

    func testUpdateReturnsCurrentRect() {
        let startTime = Date().addingTimeInterval(-0.5) // Midway through animation
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
            easingFunction: .linear,
            startTime: startTime,
        )

        let result = context.update()
        XCTAssertNotNil(result)

        // Should be halfway between source and target
        let expectedRect = Rect(topLeftX: 25, topLeftY: 12.5, width: 150, height: 125)
        XCTAssertEqual(result!.topLeftX, expectedRect.topLeftX, accuracy: 1.0)
        XCTAssertEqual(result!.topLeftY, expectedRect.topLeftY, accuracy: 1.0)
        XCTAssertEqual(result!.width, expectedRect.width, accuracy: 1.0)
        XCTAssertEqual(result!.height, expectedRect.height, accuracy: 1.0)
    }

    func testUpdateReturnsNilWhenComplete() {
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )

        context.complete()
        let result = context.update()
        XCTAssertNil(result)
    }

    func testUpdateReturnsNilWhenCancelled() {
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )

        context.cancel()
        let result = context.update()
        XCTAssertNil(result)
    }

    func testUpdateCompletesWhenProgressReachesOne() {
        let startTime = Date().addingTimeInterval(-1.5) // Past completion time
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
            startTime: startTime,
        )

        let result = context.update()
        XCTAssertEqual(result, targetRect)
        XCTAssertTrue(context.isComplete)
    }

    // MARK: - Current Rect Tests

    func testGetCurrentRectAtStart() {
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
            easingFunction: .linear,
        )

        let currentRect = context.getCurrentRect()
        XCTAssertEqual(currentRect.topLeftX, sourceRect.topLeftX, accuracy: 1.0)
        XCTAssertEqual(currentRect.topLeftY, sourceRect.topLeftY, accuracy: 1.0)
        XCTAssertEqual(currentRect.width, sourceRect.width, accuracy: 1.0)
        XCTAssertEqual(currentRect.height, sourceRect.height, accuracy: 1.0)
    }

    func testGetCurrentRectWhenComplete() {
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )

        context.complete()
        let currentRect = context.getCurrentRect()
        XCTAssertEqual(currentRect, targetRect)
    }

    func testGetCurrentRectWhenCancelled() {
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )

        context.cancel()
        let currentRect = context.getCurrentRect()
        XCTAssertEqual(currentRect, sourceRect)
    }

    // MARK: - Position and Size Tests

    func testGetCurrentPosition() {
        let startTime = Date().addingTimeInterval(-0.5) // Midway
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
            easingFunction: .linear,
            startTime: startTime,
        )

        let position = context.getCurrentPosition()
        XCTAssertEqual(position.x, 25, accuracy: 1.0) // Halfway between 0 and 50
        XCTAssertEqual(position.y, 12.5, accuracy: 1.0) // Halfway between 0 and 25
    }

    func testGetCurrentSize() {
        let startTime = Date().addingTimeInterval(-0.5) // Midway
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .resize,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
            easingFunction: .linear,
            startTime: startTime,
        )

        let size = context.getCurrentSize()
        XCTAssertEqual(size.width, 150, accuracy: 1.0) // Halfway between 100 and 200
        XCTAssertEqual(size.height, 125, accuracy: 1.0) // Halfway between 100 and 150
    }

    // MARK: - Utility Method Tests

    func testRemainingDuration() {
        let startTime = Date().addingTimeInterval(-0.3) // 0.3 seconds elapsed
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
            startTime: startTime,
        )

        XCTAssertEqual(context.remainingDuration, 0.7, accuracy: 0.1)
    }

    func testRemainingDurationWhenComplete() {
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )

        context.complete()
        XCTAssertEqual(context.remainingDuration, 0.0)
    }

    func testElapsedTime() {
        let startTime = Date().addingTimeInterval(-0.4) // 0.4 seconds ago
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
            startTime: startTime,
        )

        XCTAssertEqual(context.elapsedTime, 0.4, accuracy: 0.1)
    }

    // MARK: - Conflict Detection Tests

    func testConflictsWithSameWindow() {
        let context1 = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )

        let context2 = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .resize,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )

        XCTAssertTrue(context1.conflictsWith(context2))
        XCTAssertTrue(context2.conflictsWith(context1))
    }

    func testNoConflictWithDifferentWindow() {
        let context1 = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )

        let context2 = WindowAnimationContext(
            windowId: 456,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )

        XCTAssertFalse(context1.conflictsWith(context2))
        XCTAssertFalse(context2.conflictsWith(context1))
    }

    func testNoConflictWhenInactive() {
        let context1 = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )

        let context2 = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .resize,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )

        context2.complete()

        XCTAssertFalse(context1.conflictsWith(context2))
        XCTAssertFalse(context2.conflictsWith(context1))
    }

    // MARK: - Animation Type Tests

    func testAnimationTypes() {
        let moveContext = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )
        XCTAssertEqual(moveContext.animationType, .move)

        let resizeContext = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .resize,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )
        XCTAssertEqual(resizeContext.animationType, .resize)

        let moveAndResizeContext = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .moveAndResize,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )
        XCTAssertEqual(moveAndResizeContext.animationType, .moveAndResize)
    }

    // MARK: - Debug Description Tests

    func testDebugDescription() {
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )

        let description = context.debugDescription
        XCTAssertTrue(description.contains("WindowAnimationContext"))
        XCTAssertTrue(description.contains("windowId: \(testWindowId)"))
        XCTAssertTrue(description.contains("type: move"))
        XCTAssertTrue(description.contains("status: active"))
    }

    func testDebugDescriptionWhenComplete() {
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .resize,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )

        context.complete()
        let description = context.debugDescription
        XCTAssertTrue(description.contains("status: complete"))
    }

    func testDebugDescriptionWhenCancelled() {
        let context = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .layoutTransition,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
        )

        context.cancel()
        let description = context.debugDescription
        XCTAssertTrue(description.contains("status: cancelled"))
    }

    // MARK: - Easing Function Tests

    func testEasingFunctionApplication() {
        let startTime = Date().addingTimeInterval(-0.5) // Midway
        let easeInContext = WindowAnimationContext(
            windowId: testWindowId,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
            easingFunction: .easeIn,
            startTime: startTime,
        )

        let linearContext = WindowAnimationContext(
            windowId: testWindowId + 1,
            animationType: .move,
            sourceRect: sourceRect,
            targetRect: targetRect,
            duration: testDuration,
            easingFunction: .linear,
            startTime: startTime,
        )

        let easeInRect = easeInContext.getCurrentRect()
        let linearRect = linearContext.getCurrentRect()

        // Ease-in should be slower at the beginning, so position should be less than linear
        XCTAssertLessThan(easeInRect.topLeftX, linearRect.topLeftX)
    }
}
