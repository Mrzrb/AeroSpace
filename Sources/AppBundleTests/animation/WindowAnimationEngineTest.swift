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
        engine.updateConfiguration(AnimationConfig.default)
        
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
        engine.updateConfiguration(AnimationConfig.default)
        
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
        engine.updateConfiguration(config)
        
        // Verify configuration was updated
        XCTAssertFalse(engine.currentConfiguration.enabled)
        
        // Reset to enabled for other tests
        var enabledConfig = AnimationConfig.default
        enabledConfig.enabled = true
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
        engine.updateConfiguration(AnimationConfig.default)
        
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
        engine.updateConfiguration(AnimationConfig.default)
        
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
        engine.updateConfiguration(defaultConfig)
    }
    
    func testBatchAnimations() async throws {
        let engine = WindowAnimationEngine.shared
        engine.updateConfiguration(AnimationConfig.default)
        
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
            (testWindow2, targetRect2, 0.1, nil)
        ]
        
        try await engine.batchAnimateWindows(animations)
        
        // Should have multiple active animations
        XCTAssertEqual(engine.activeAnimationCount, 2)
        XCTAssertTrue(engine.hasActiveAnimation(for: testWindow1))
        XCTAssertTrue(engine.hasActiveAnimation(for: testWindow2))
    }
}