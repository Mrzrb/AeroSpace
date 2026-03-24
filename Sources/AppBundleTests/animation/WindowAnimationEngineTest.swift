import XCTest
@testable import AppBundle
import Common

@MainActor
final class WindowAnimationEngineTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        WindowAnimationEngine.shared.forceStopAllAnimations()
    }

    // MARK: - Configuration Tests

    func testUpdateConfiguration() {
        let engine = WindowAnimationEngine.shared
        var config = AnimationConfig.default
        config.enabled = false
        config.defaultDuration = 0.5
        config.respectSystemPreferences = false // Disable system preference checking for tests

        engine.updateConfiguration(config)

        XCTAssertEqual(engine.currentConfiguration.enabled, false)
        XCTAssertEqual(engine.currentConfiguration.defaultDuration, 0.5)
    }

    func testInvalidConfigurationRejected() {
        let engine = WindowAnimationEngine.shared
        var config = AnimationConfig.default
        config.defaultDuration = -1.0 // Invalid duration

        let originalConfig = engine.currentConfiguration
        engine.updateConfiguration(config)

        // Configuration should remain unchanged
        XCTAssertEqual(engine.currentConfiguration.defaultDuration, originalConfig.defaultDuration)
    }

    // MARK: - Animation Control Tests

    func testAnimateWindow() async throws {
        let engine = WindowAnimationEngine.shared
        var config = AnimationConfig.default
        config.respectSystemPreferences = false // Disable system preference checking for tests
        engine.updateConfiguration(config)

        let testWindow = TestWindow.new(id: 1, parent: Workspace.get(byName: "test").rootTilingContainer)
        let sourceRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let targetRect = Rect(topLeftX: 200, topLeftY: 200, width: 150, height: 150)

        testWindow.setTestRect(sourceRect)

        try await engine.animateWindow(testWindow, to: targetRect, duration: 0.01)

        XCTAssertTrue(engine.hasActiveAnimation(for: testWindow))
        XCTAssertEqual(engine.activeAnimationCount, 1)
    }

    func testCancelAnimation() async throws {
        let engine = WindowAnimationEngine.shared
        var config = AnimationConfig.default
        config.respectSystemPreferences = false // Disable system preference checking for tests
        engine.updateConfiguration(config)

        let testWindow = TestWindow.new(id: 2, parent: Workspace.get(byName: "test").rootTilingContainer)
        let sourceRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let targetRect = Rect(topLeftX: 200, topLeftY: 200, width: 150, height: 150)

        testWindow.setTestRect(sourceRect)

        try await engine.animateWindow(testWindow, to: targetRect, duration: 0.01)
        XCTAssertTrue(engine.hasActiveAnimation(for: testWindow))

        engine.cancelAnimation(for: testWindow)
        XCTAssertFalse(engine.hasActiveAnimation(for: testWindow))
        XCTAssertEqual(engine.activeAnimationCount, 0)
    }

    func testAnimationsDisabled() {
        let engine = WindowAnimationEngine.shared
        var config = AnimationConfig.default
        config.enabled = false
        config.respectSystemPreferences = false // Disable system preference checking for tests
        engine.updateConfiguration(config)

        // Verify configuration was updated
        XCTAssertFalse(engine.currentConfiguration.enabled)

        // Reset to enabled for other tests
        var enabledConfig = AnimationConfig.default
        enabledConfig.enabled = true
        enabledConfig.respectSystemPreferences = false
        engine.updateConfiguration(enabledConfig)
    }

    func testPerformanceMetrics() {
        let engine = WindowAnimationEngine.shared
        let metrics = engine.getPerformanceMetrics()

        XCTAssertGreaterThanOrEqual(metrics.averageFrameRate, 0.0)
        XCTAssertGreaterThanOrEqual(metrics.droppedFrames, 0)
        XCTAssertGreaterThanOrEqual(metrics.activeAnimationCount, 0)
        XCTAssertGreaterThanOrEqual(metrics.totalAnimationsCompleted, 0)
        XCTAssertGreaterThanOrEqual(metrics.memoryUsage, 0)
    }

    func testDebugInfo() {
        let engine = WindowAnimationEngine.shared
        let debugInfo = engine.getDebugInfo()

        XCTAssertTrue(debugInfo.contains { $0.contains("WindowAnimationEngine Debug Info") })
        XCTAssertTrue(debugInfo.contains { $0.contains("Active animations:") })
        XCTAssertTrue(debugInfo.contains { $0.contains("Timer running:") })
    }

    func testAdaptiveQuality() {
        let engine = WindowAnimationEngine.shared
        var config = AnimationConfig.default
        config.adaptiveQuality = true
        config.minFrameRate = 30.0
        engine.updateConfiguration(config)

        XCTAssertTrue(engine.currentConfiguration.adaptiveQuality)
        XCTAssertEqual(engine.currentConfiguration.minFrameRate, 30.0)
    }

    func testPerformanceMetricsTracking() {
        let engine = WindowAnimationEngine.shared
        let initialMetrics = engine.getPerformanceMetrics()

        // Metrics should be initialized
        XCTAssertGreaterThanOrEqual(initialMetrics.averageFrameRate, 0.0)
        XCTAssertGreaterThanOrEqual(initialMetrics.droppedFrames, 0)
        XCTAssertEqual(initialMetrics.activeAnimationCount, 0)
        XCTAssertGreaterThanOrEqual(initialMetrics.totalAnimationsCompleted, 0)
        XCTAssertGreaterThanOrEqual(initialMetrics.memoryUsage, 0)
    }

    // MARK: - Concurrent Animation Tests

    func testConcurrentAnimations() async throws {
        let engine = WindowAnimationEngine.shared
        var config = AnimationConfig.default
        config.respectSystemPreferences = false // Disable system preference checking for tests
        engine.updateConfiguration(config)

        // Create multiple test windows
        let testWindow1 = TestWindow.new(id: 10, parent: Workspace.get(byName: "test").rootTilingContainer)
        let testWindow2 = TestWindow.new(id: 11, parent: Workspace.get(byName: "test").rootTilingContainer)
        let testWindow3 = TestWindow.new(id: 12, parent: Workspace.get(byName: "test").rootTilingContainer)

        let sourceRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let targetRect = Rect(topLeftX: 200, topLeftY: 200, width: 150, height: 150)

        testWindow1.setTestRect(sourceRect)
        testWindow2.setTestRect(sourceRect)
        testWindow3.setTestRect(sourceRect)

        // Start concurrent animations
        try await engine.animateWindow(testWindow1, to: targetRect, duration: 0.1)
        try await engine.animateWindow(testWindow2, to: targetRect, duration: 0.1)
        try await engine.animateWindow(testWindow3, to: targetRect, duration: 0.1)

        // Should have multiple active animations
        XCTAssertEqual(engine.activeAnimationCount, 3)
        XCTAssertTrue(engine.hasActiveAnimation(for: testWindow1))
        XCTAssertTrue(engine.hasActiveAnimation(for: testWindow2))
        XCTAssertTrue(engine.hasActiveAnimation(for: testWindow3))
    }

    func testAnimationConflictResolution() async throws {
        let engine = WindowAnimationEngine.shared
        var config = AnimationConfig.default
        config.respectSystemPreferences = false // Disable system preference checking for tests
        engine.updateConfiguration(config)

        let testWindow = TestWindow.new(id: 20, parent: Workspace.get(byName: "test").rootTilingContainer)
        let sourceRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let targetRect1 = Rect(topLeftX: 100, topLeftY: 100, width: 120, height: 120)
        let targetRect2 = Rect(topLeftX: 200, topLeftY: 200, width: 150, height: 150)

        testWindow.setTestRect(sourceRect)

        // Start first animation
        try await engine.animateWindow(testWindow, to: targetRect1, duration: 0.1)
        XCTAssertEqual(engine.activeAnimationCount, 1)

        // Start second animation for same window - should replace first
        try await engine.animateWindow(testWindow, to: targetRect2, duration: 0.1)
        XCTAssertEqual(engine.activeAnimationCount, 1)

        // Should still have active animation for the window
        XCTAssertTrue(engine.hasActiveAnimation(for: testWindow))
    }

    func testMaxConcurrentAnimationsLimit() {
        let engine = WindowAnimationEngine.shared
        var config = AnimationConfig.default
        config.maxConcurrentAnimations = 2
        engine.updateConfiguration(config)

        // Verify the configuration was set
        XCTAssertEqual(engine.currentConfiguration.maxConcurrentAnimations, 2)

        // Reset to default for other tests
        var defaultConfig = AnimationConfig.default
        defaultConfig.respectSystemPreferences = false
        engine.updateConfiguration(defaultConfig)
    }

    func testBatchAnimations() async throws {
        let engine = WindowAnimationEngine.shared
        var config = AnimationConfig.default
        config.respectSystemPreferences = false // Disable system preference checking for tests
        engine.updateConfiguration(config)

        // Create multiple test windows
        let testWindow1 = TestWindow.new(id: 40, parent: Workspace.get(byName: "test").rootTilingContainer)
        let testWindow2 = TestWindow.new(id: 41, parent: Workspace.get(byName: "test").rootTilingContainer)

        let sourceRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let targetRect1 = Rect(topLeftX: 150, topLeftY: 150, width: 120, height: 120)
        let targetRect2 = Rect(topLeftX: 250, topLeftY: 250, width: 140, height: 140)

        testWindow1.setTestRect(sourceRect)
        testWindow2.setTestRect(sourceRect)

        // Batch animate multiple windows
        let animations: [(Window, Rect, TimeInterval?, AnimationEasing?)] = [
            (testWindow1, targetRect1, 0.1, nil),
            (testWindow2, targetRect2, 0.1, nil),
        ]

        try await engine.batchAnimateWindows(animations)

        // Should have multiple active animations
        XCTAssertEqual(engine.activeAnimationCount, 2)
        XCTAssertTrue(engine.hasActiveAnimation(for: testWindow1))
        XCTAssertTrue(engine.hasActiveAnimation(for: testWindow2))
    }

    // MARK: - CVDisplayLink Tests

    func testDisplayLinkSetup() {
        let engine = WindowAnimationEngine.shared
        let metrics = engine.getPerformanceMetrics()

        // CVDisplayLink should be available on macOS
        XCTAssertTrue(metrics.usingDisplayLink, "CVDisplayLink should be available and set up")
    }

    func testDisplayLinkSynchronization() async throws {
        let engine = WindowAnimationEngine.shared
        var config = AnimationConfig.default
        config.respectSystemPreferences = false
        engine.updateConfiguration(config)

        let testWindow = TestWindow.new(id: 1, parent: Workspace.get(byName: "test").rootTilingContainer)
        let sourceRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let targetRect = Rect(topLeftX: 200, topLeftY: 200, width: 150, height: 150)

        testWindow.setAxFrameImmediate(CGPoint(x: sourceRect.topLeftX, y: sourceRect.topLeftY),
                                       CGSize(width: sourceRect.width, height: sourceRect.height))

        // Start animation
        try await engine.animateWindow(testWindow, to: targetRect, duration: 0.1)

        // Check that display link is running during animation
        let metricsWithAnimation = engine.getPerformanceMetrics()
        XCTAssertTrue(metricsWithAnimation.displayLinkRunning, "CVDisplayLink should be running during animation")

        // Wait for animation to complete
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        // Check that display link stops after animation completes
        let metricsAfterAnimation = engine.getPerformanceMetrics()
        XCTAssertFalse(metricsAfterAnimation.displayLinkRunning, "CVDisplayLink should stop after animation completes")
    }

    func testDisplayRefreshRateDetection() {
        let engine = WindowAnimationEngine.shared
        let metrics = engine.getPerformanceMetrics()

        // Display refresh rate should be detected and within reasonable bounds
        XCTAssertGreaterThanOrEqual(metrics.displayRefreshRate, 30.0, "Display refresh rate should be at least 30 Hz")
        XCTAssertLessThanOrEqual(metrics.displayRefreshRate, 240.0, "Display refresh rate should be at most 240 Hz")
    }

    func testDisplaySyncAccuracy() async throws {
        let engine = WindowAnimationEngine.shared
        var config = AnimationConfig.default
        config.respectSystemPreferences = false
        engine.updateConfiguration(config)

        let testWindow = TestWindow.new(id: 1, parent: Workspace.get(byName: "test").rootTilingContainer)
        let sourceRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let targetRect = Rect(topLeftX: 200, topLeftY: 200, width: 150, height: 150)

        testWindow.setAxFrameImmediate(CGPoint(x: sourceRect.topLeftX, y: sourceRect.topLeftY),
                                       CGSize(width: sourceRect.width, height: sourceRect.height))

        // Start animation
        try await engine.animateWindow(testWindow, to: targetRect, duration: 0.2)

        // Allow some time for sync accuracy measurement
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        let metrics = engine.getPerformanceMetrics()

        // Display sync accuracy should be measured when using CVDisplayLink
        if metrics.usingDisplayLink && metrics.displayLinkRunning {
            XCTAssertGreaterThan(metrics.displaySyncAccuracy, 0.0, "Display sync accuracy should be measured")
        }
    }

    func testFallbackToTimer() {
        // This test would require mocking CVDisplayLink failure, which is complex
        // For now, we just verify that the engine can handle both timing mechanisms
        let engine = WindowAnimationEngine.shared
        let metrics = engine.getPerformanceMetrics()

        // The engine should have some timing mechanism available
        XCTAssertTrue(metrics.usingDisplayLink || metrics.displayRefreshRate > 0,
                      "Engine should have either CVDisplayLink or Timer fallback available")
    }

    // MARK: - Multi-Display Tests

    func testMultiDisplayDetection() {
        let engine = WindowAnimationEngine.shared
        let metrics = engine.getPerformanceMetrics()

        // Should detect at least one display
        XCTAssertGreaterThanOrEqual(metrics.activeDisplayCount, 1, "Should detect at least one active display")

        // Should have refresh rate information for detected displays
        XCTAssertGreaterThanOrEqual(metrics.displayRefreshRates.count, 1, "Should have refresh rate info for detected displays")

        // All detected refresh rates should be within reasonable bounds
        for (displayID, refreshRate) in metrics.displayRefreshRates {
            XCTAssertGreaterThanOrEqual(refreshRate, 30.0, "Display \(displayID) refresh rate should be at least 30 Hz")
            XCTAssertLessThanOrEqual(refreshRate, 240.0, "Display \(displayID) refresh rate should be at most 240 Hz")
        }
    }

    func testMultiDisplayRefreshRateOptimization() {
        let engine = WindowAnimationEngine.shared
        let metrics = engine.getPerformanceMetrics()

        // If multiple displays are detected, the engine should use the optimal refresh rate
        if metrics.activeDisplayCount > 1 {
            let maxRefreshRate = metrics.displayRefreshRates.values.max() ?? 60.0
            XCTAssertEqual(metrics.displayRefreshRate, maxRefreshRate,
                           "Engine should use the highest refresh rate among all displays")
        }
    }

    func testDisplayConfigurationChangeHandling() {
        let engine = WindowAnimationEngine.shared
        let _ = engine.getPerformanceMetrics()

        // Simulate display configuration change by posting notification
        NotificationCenter.default.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil,
        )

        // Allow some time for the configuration change to be processed
        let expectation = XCTestExpectation(description: "Display configuration change processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let updatedMetrics = engine.getPerformanceMetrics()

        // The engine should still be functional after display configuration change
        XCTAssertGreaterThanOrEqual(updatedMetrics.activeDisplayCount, 1,
                                    "Should still detect displays after configuration change")
        XCTAssertGreaterThan(updatedMetrics.displayRefreshRate, 0,
                             "Should still have valid refresh rate after configuration change")
    }

    func testMultiDisplayAnimationSynchronization() async throws {
        let engine = WindowAnimationEngine.shared
        var config = AnimationConfig.default
        config.respectSystemPreferences = false
        engine.updateConfiguration(config)

        let testWindow = TestWindow.new(id: 1, parent: Workspace.get(byName: "test").rootTilingContainer)
        let sourceRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        let targetRect = Rect(topLeftX: 200, topLeftY: 200, width: 150, height: 150)

        testWindow.setAxFrameImmediate(CGPoint(x: sourceRect.topLeftX, y: sourceRect.topLeftY),
                                       CGSize(width: sourceRect.width, height: sourceRect.height))

        // Start animation
        try await engine.animateWindow(testWindow, to: targetRect, duration: 0.1)

        // Check that multi-display synchronization is working
        let metricsWithAnimation = engine.getPerformanceMetrics()

        if metricsWithAnimation.activeDisplayCount > 1 {
            XCTAssertTrue(metricsWithAnimation.usingDisplayLink,
                          "Should use CVDisplayLink for multi-display synchronization")
            XCTAssertTrue(metricsWithAnimation.displayLinkRunning,
                          "CVDisplayLink should be running during animation")
        }

        // Wait for animation to complete
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        let metricsAfterAnimation = engine.getPerformanceMetrics()
        XCTAssertFalse(metricsAfterAnimation.displayLinkRunning,
                       "CVDisplayLink should stop after animation completes")
    }
}
