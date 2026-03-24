import XCTest
@testable import AppBundle
import Metal

class AnimationBatchProcessorTest: XCTestCase {

    var batchProcessor: AnimationBatchProcessor?

    override func setUp() {
        super.setUp()
        // Initialize in async context when needed
    }

    override func tearDown() {
        // Cleanup will be handled in individual tests
        super.tearDown()
    }

    @MainActor
    private func setupBatchProcessor() {
        batchProcessor = AnimationBatchProcessor()
    }

    @MainActor
    private func cleanupBatchProcessor() {
        batchProcessor?.cleanup()
        batchProcessor = nil
    }

    // MARK: - Batch Creation Tests

    @MainActor
    func testBatchedAnimationCreation() {
        setupBatchProcessor()
        let sourceRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let targetRect = Rect(topLeftX: 200, topLeftY: 200, width: 150, height: 150)

        let batchedAnimation = AnimationBatchProcessor.BatchedAnimation(
            windowId: 123,
            sourceRect: sourceRect,
            targetRect: targetRect,
            progress: 0.5,
            easing: .easeOut,
        )

        XCTAssertEqual(batchedAnimation.windowId, 123)
        XCTAssertEqual(batchedAnimation.sourceRect, sourceRect)
        XCTAssertEqual(batchedAnimation.targetRect, targetRect)
        XCTAssertEqual(batchedAnimation.progress, 0.5)
        XCTAssertEqual(batchedAnimation.easingType, .easeOut)

        cleanupBatchProcessor()
    }

    @MainActor
    func testEasingTypeConversion() {
        setupBatchProcessor()
        let sourceRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let targetRect = Rect(topLeftX: 100, topLeftY: 100, width: 100, height: 100)

        // Test basic easing conversions
        let linearAnimation = AnimationBatchProcessor.BatchedAnimation(
            windowId: 1, sourceRect: sourceRect, targetRect: targetRect, progress: 0.5, easing: .linear,
        )
        XCTAssertEqual(linearAnimation.easingType, .linear)

        let easeInAnimation = AnimationBatchProcessor.BatchedAnimation(
            windowId: 2, sourceRect: sourceRect, targetRect: targetRect, progress: 0.5, easing: .easeIn,
        )
        XCTAssertEqual(easeInAnimation.easingType, .easeIn)

        let easeOutAnimation = AnimationBatchProcessor.BatchedAnimation(
            windowId: 3, sourceRect: sourceRect, targetRect: targetRect, progress: 0.5, easing: .easeOut,
        )
        XCTAssertEqual(easeOutAnimation.easingType, .easeOut)

        let easeInOutAnimation = AnimationBatchProcessor.BatchedAnimation(
            windowId: 4, sourceRect: sourceRect, targetRect: targetRect, progress: 0.5, easing: .easeInOut,
        )
        XCTAssertEqual(easeInOutAnimation.easingType, .easeInOut)

        // Test complex easing fallback
        let customAnimation = AnimationBatchProcessor.BatchedAnimation(
            windowId: 5, sourceRect: sourceRect, targetRect: targetRect, progress: 0.5,
            easing: .custom(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1.0),
        )
        XCTAssertEqual(customAnimation.easingType, .easeOut) // Should fallback to easeOut

        let springAnimation = AnimationBatchProcessor.BatchedAnimation(
            windowId: 6, sourceRect: sourceRect, targetRect: targetRect, progress: 0.5,
            easing: .spring(damping: 0.8, velocity: 0.0),
        )
        XCTAssertEqual(springAnimation.easingType, .easeOut) // Should fallback to easeOut

        cleanupBatchProcessor()
    }

    // MARK: - CPU Processing Tests

    @MainActor
    func testCPUBatchProcessing() async {
        setupBatchProcessor()

        guard let processor = batchProcessor else {
            XCTFail("Failed to setup batch processor")
            return
        }

        let animations = createTestAnimations(count: 5)
        let results = await processor.processBatch(animations)

        XCTAssertEqual(results.count, animations.count, "Should return same number of results as input animations")

        // Verify interpolation results
        for (index, result) in results.enumerated() {
            let animation = animations[index]
            let expected = interpolateRect(
                from: animation.sourceRect,
                to: animation.targetRect,
                progress: animation.progress,
                easing: animation.easingType,
            )

            XCTAssertEqual(result.topLeftX, expected.topLeftX, accuracy: 0.01, "X position should be correctly interpolated")
            XCTAssertEqual(result.topLeftY, expected.topLeftY, accuracy: 0.01, "Y position should be correctly interpolated")
            XCTAssertEqual(result.width, expected.width, accuracy: 0.01, "Width should be correctly interpolated")
            XCTAssertEqual(result.height, expected.height, accuracy: 0.01, "Height should be correctly interpolated")
        }

        cleanupBatchProcessor()
    }

    @MainActor
    func testEmptyBatchProcessing() async {
        setupBatchProcessor()

        guard let processor = batchProcessor else {
            XCTFail("Failed to setup batch processor")
            return
        }

        let results = await processor.processBatch([])
        XCTAssertTrue(results.isEmpty, "Empty batch should return empty results")

        cleanupBatchProcessor()
    }

    @MainActor
    func testSingleAnimationBatch() async {
        setupBatchProcessor()

        guard let processor = batchProcessor else {
            XCTFail("Failed to setup batch processor")
            return
        }

        let animation = AnimationBatchProcessor.BatchedAnimation(
            windowId: 1,
            sourceRect: Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100),
            targetRect: Rect(topLeftX: 200, topLeftY: 200, width: 200, height: 200),
            progress: 0.5,
            easing: .linear,
        )

        let results = await processor.processBatch([animation])

        XCTAssertEqual(results.count, 1)
        let result = results[0]

        // At 50% progress with linear easing, should be halfway
        XCTAssertEqual(result.topLeftX, 100, accuracy: 0.01)
        XCTAssertEqual(result.topLeftY, 100, accuracy: 0.01)
        XCTAssertEqual(result.width, 150, accuracy: 0.01)
        XCTAssertEqual(result.height, 150, accuracy: 0.01)

        cleanupBatchProcessor()
    }

    // MARK: - GPU Processing Tests

    @MainActor
    func testGPUAvailabilityCheck() {
        setupBatchProcessor()
        // This test will pass or skip based on system GPU availability
        let hasGPU = MTLCreateSystemDefaultDevice() != nil

        if hasGPU {
            print("GPU available for testing")
            // GPU-specific tests can run
        } else {
            print("GPU not available, skipping GPU-specific tests")
        }

        cleanupBatchProcessor()
    }

    @MainActor
    func testGPUBatchProcessing() async {
        setupBatchProcessor()

        guard let processor = batchProcessor else {
            XCTFail("Failed to setup batch processor")
            return
        }

        // Only run if GPU is available
        guard MTLCreateSystemDefaultDevice() != nil else {
            print("Skipping GPU batch processing test - no GPU available")
            return
        }

        let animations = createTestAnimations(count: 10)
        let results = await processor.processBatch(animations)

        XCTAssertEqual(results.count, animations.count, "GPU batch should return same number of results as input animations")

        // Verify results are reasonable (GPU and CPU should produce similar results)
        for (index, result) in results.enumerated() {
            let animation = animations[index]

            // Results should be within the bounds of source and target rects
            let minX = min(animation.sourceRect.topLeftX, animation.targetRect.topLeftX)
            let maxX = max(animation.sourceRect.topLeftX, animation.targetRect.topLeftX)
            let minY = min(animation.sourceRect.topLeftY, animation.targetRect.topLeftY)
            let maxY = max(animation.sourceRect.topLeftY, animation.targetRect.topLeftY)

            XCTAssertGreaterThanOrEqual(result.topLeftX, minX, "X should be within bounds")
            XCTAssertLessThanOrEqual(result.topLeftX, maxX, "X should be within bounds")
            XCTAssertGreaterThanOrEqual(result.topLeftY, minY, "Y should be within bounds")
            XCTAssertLessThanOrEqual(result.topLeftY, maxY, "Y should be within bounds")
        }

        cleanupBatchProcessor()
    }

    // MARK: - Performance Tests

    @MainActor
    func testBatchProcessingPerformance() async {
        setupBatchProcessor()

        guard let processor = batchProcessor else {
            XCTFail("Failed to setup batch processor")
            return
        }

        let animations = createTestAnimations(count: 50)

        // Measure performance without using XCTest's measure block for async code
        let startTime = Date()
        _ = await processor.processBatch(animations)
        let processingTime = Date().timeIntervalSince(startTime)

        // Verify performance is reasonable (should complete within 1 second for 50 animations)
        XCTAssertLessThan(processingTime, 1.0, "Batch processing should complete within 1 second")

        print("Batch processing performance: \(processingTime * 1000)ms for \(animations.count) animations")

        cleanupBatchProcessor()
    }

    @MainActor
    func testCPUvsBatchPerformance() async {
        setupBatchProcessor()

        guard let processor = batchProcessor else {
            XCTFail("Failed to setup batch processor")
            return
        }

        let animations = createTestAnimations(count: 20)

        // Measure individual CPU processing
        let cpuStartTime = Date()
        var cpuResults: [Rect] = []
        for animation in animations {
            let result = interpolateRect(
                from: animation.sourceRect,
                to: animation.targetRect,
                progress: animation.progress,
                easing: animation.easingType,
            )
            cpuResults.append(result)
        }
        let cpuTime = Date().timeIntervalSince(cpuStartTime)

        // Measure batch processing
        let batchStartTime = Date()
        let batchResults = await processor.processBatch(animations)
        let batchTime = Date().timeIntervalSince(batchStartTime)

        print("CPU individual processing: \(cpuTime * 1000)ms")
        print("Batch processing: \(batchTime * 1000)ms")

        // Results should be similar
        XCTAssertEqual(cpuResults.count, batchResults.count)

        for (index, cpuResult) in cpuResults.enumerated() {
            let batchResult = batchResults[index]
            XCTAssertEqual(cpuResult.topLeftX, batchResult.topLeftX, accuracy: 0.1, "Batch and CPU results should be similar")
            XCTAssertEqual(cpuResult.topLeftY, batchResult.topLeftY, accuracy: 0.1, "Batch and CPU results should be similar")
            XCTAssertEqual(cpuResult.width, batchResult.width, accuracy: 0.1, "Batch and CPU results should be similar")
            XCTAssertEqual(cpuResult.height, batchResult.height, accuracy: 0.1, "Batch and CPU results should be similar")
        }

        cleanupBatchProcessor()
    }

    // MARK: - Performance Metrics Tests

    @MainActor
    func testPerformanceMetricsCollection() async {
        setupBatchProcessor()

        guard let processor = batchProcessor else {
            XCTFail("Failed to setup batch processor")
            return
        }

        // Process some batches to generate metrics
        let smallBatch = createTestAnimations(count: 3)
        let largeBatch = createTestAnimations(count: 15)

        _ = await processor.processBatch(smallBatch)
        _ = await processor.processBatch(largeBatch)
        _ = await processor.processBatch(smallBatch)

        let metrics = processor.getPerformanceMetrics()

        XCTAssertGreaterThan(metrics.totalBatchesProcessed, 0, "Should have processed some batches")
        XCTAssertGreaterThanOrEqual(metrics.averageBatchTime, 0, "Average batch time should be non-negative")

        print("Performance Metrics:")
        print("  - Total batches: \(metrics.totalBatchesProcessed)")
        print("  - Average batch time: \(metrics.averageBatchTime * 1000)ms")
        print("  - GPU batches: \(metrics.gpuBatchesProcessed)")
        print("  - CPU batches: \(metrics.cpuBatchesProcessed)")
        print("  - GPU speedup factor: \(metrics.gpuSpeedupFactor)x")

        cleanupBatchProcessor()
    }

    // MARK: - Error Handling Tests

    @MainActor
    func testBatchProcessorCleanup() {
        setupBatchProcessor()

        guard let processor = batchProcessor else {
            XCTFail("Failed to setup batch processor")
            return
        }

        // Cleanup should not crash
        processor.cleanup()

        // Should be able to create new processor after cleanup
        let newProcessor = AnimationBatchProcessor()
        XCTAssertNotNil(newProcessor)
        newProcessor.cleanup()

        cleanupBatchProcessor()
    }

    // MARK: - Helper Methods

    private func createTestAnimations(count: Int) -> [AnimationBatchProcessor.BatchedAnimation] {
        var animations: [AnimationBatchProcessor.BatchedAnimation] = []

        for i in 0 ..< count {
            let sourceRect = Rect(
                topLeftX: Double(i * 10),
                topLeftY: Double(i * 10),
                width: 100,
                height: 100,
            )
            let targetRect = Rect(
                topLeftX: Double(i * 10 + 200),
                topLeftY: Double(i * 10 + 200),
                width: 150,
                height: 150,
            )

            let easingTypes: [AnimationEasing] = [.linear, .easeIn, .easeOut, .easeInOut]
            let animation = AnimationBatchProcessor.BatchedAnimation(
                windowId: UInt32(i + 1),
                sourceRect: sourceRect,
                targetRect: targetRect,
                progress: Double(i) / Double(count - 1), // Progress from 0 to 1
                easing: easingTypes[i % easingTypes.count],
            )

            animations.append(animation)
        }

        return animations
    }

    private func interpolateRect(from source: Rect, to target: Rect, progress: Double, easing: AnimationBatchProcessor.EasingType) -> Rect {
        let easedProgress = applyEasing(progress, type: easing)

        return Rect(
            topLeftX: source.topLeftX + (target.topLeftX - source.topLeftX) * easedProgress,
            topLeftY: source.topLeftY + (target.topLeftY - source.topLeftY) * easedProgress,
            width: source.width + (target.width - source.width) * easedProgress,
            height: source.height + (target.height - source.height) * easedProgress,
        )
    }

    private func applyEasing(_ progress: Double, type: AnimationBatchProcessor.EasingType) -> Double {
        switch type {
            case .linear:
                return progress
            case .easeIn:
                return progress * progress
            case .easeOut:
                return 1.0 - (1.0 - progress) * (1.0 - progress)
            case .easeInOut:
                return progress < 0.5 ? 2.0 * progress * progress : 1.0 - pow(-2.0 * progress + 2.0, 2.0) / 2.0
        }
    }
}
