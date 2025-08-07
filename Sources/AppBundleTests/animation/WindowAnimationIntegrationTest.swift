import XCTest
@testable import AppBundle
import Common

@MainActor
class WindowAnimationIntegrationTest: XCTestCase {
    
    var testWindow: TestWindow!
    var animationEngine: WindowAnimationEngine!
    
    func createTestWindow() -> TestWindow {
        let window = TestWindow(
            id: 1,
            app: TestApp.shared,
            lastFloatingSize: CGSize(width: 400, height: 300),
            parent: TestTilingContainer(orientation: .h),
            adaptiveWeight: 1.0,
            index: 0
        )
        
        // Set initial position and size
        window.testRect = Rect(topLeftX: 100, topLeftY: 100, width: 400, height: 300)
        return window
    }
    
    func setupAnimationEngine() -> WindowAnimationEngine {
        let engine = WindowAnimationEngine.shared
        
        // Reset animation engine state
        engine.forceStopAllAnimations()
        
        // Configure animation engine for testing
        var testConfig = AnimationConfig.default
        testConfig.enabled = true
        testConfig.defaultDuration = 0.1 // Short duration for tests
        testConfig.moveAnimationEnabled = true
        testConfig.resizeAnimationEnabled = true
        testConfig.layoutChangeAnimationEnabled = true
        engine.updateConfiguration(testConfig)
        
        return engine
    }
    
    // MARK: - Window Position Animation Tests
    
    func testAnimateWindowPosition() async throws {
        let testWindow = createTestWindow()
        let animationEngine = setupAnimationEngine()
        
        let initialPosition = CGPoint(x: 100, y: 100)
        let targetPosition = CGPoint(x: 200, y: 150)
        
        // Set initial position
        testWindow.testRect = Rect(topLeftX: initialPosition.x, topLeftY: initialPosition.y, width: 400, height: 300)
        
        // Animate to new position
        try await animationEngine.animateWindowPosition(testWindow, to: targetPosition)
        
        // Wait for animation to complete
        try await Task.sleep(for: .milliseconds(150))
        
        // Verify final position
        let finalRect = try await testWindow.getAxRect()
        XCTAssertNotNil(finalRect)
        XCTAssertEqual(finalRect!.topLeftX, targetPosition.x, accuracy: 1.0)
        XCTAssertEqual(finalRect!.topLeftY, targetPosition.y, accuracy: 1.0)
        XCTAssertEqual(finalRect!.width, 400, accuracy: 1.0)
        XCTAssertEqual(finalRect!.height, 300, accuracy: 1.0)
    }
    
    func testAnimateWindowSize() async throws {
        let initialSize = CGSize(width: 400, height: 300)
        let targetSize = CGSize(width: 600, height: 450)
        
        // Set initial size
        testWindow.testRect = Rect(topLeftX: 100, topLeftY: 100, width: initialSize.width, height: initialSize.height)
        
        // Animate to new size
        try await animationEngine.animateWindowSize(testWindow, to: targetSize)
        
        // Wait for animation to complete
        try await Task.sleep(for: .milliseconds(150))
        
        // Verify final size
        let finalRect = try await testWindow.getAxRect()
        XCTAssertNotNil(finalRect)
        XCTAssertEqual(finalRect!.topLeftX, 100, accuracy: 1.0)
        XCTAssertEqual(finalRect!.topLeftY, 100, accuracy: 1.0)
        XCTAssertEqual(finalRect!.width, targetSize.width, accuracy: 1.0)
        XCTAssertEqual(finalRect!.height, targetSize.height, accuracy: 1.0)
    }
    
    func testAnimateWindowFrame() async throws {
        let initialRect = Rect(topLeftX: 100, topLeftY: 100, width: 400, height: 300)
        let targetRect = Rect(topLeftX: 200, topLeftY: 150, width: 600, height: 450)
        
        // Set initial frame
        testWindow.testRect = initialRect
        
        // Animate to new frame
        try await animationEngine.animateWindow(testWindow, to: targetRect)
        
        // Wait for animation to complete
        try await Task.sleep(for: .milliseconds(150))
        
        // Verify final frame
        let finalRect = try await testWindow.getAxRect()
        XCTAssertNotNil(finalRect)
        XCTAssertEqual(finalRect!.topLeftX, targetRect.topLeftX, accuracy: 1.0)
        XCTAssertEqual(finalRect!.topLeftY, targetRect.topLeftY, accuracy: 1.0)
        XCTAssertEqual(finalRect!.width, targetRect.width, accuracy: 1.0)
        XCTAssertEqual(finalRect!.height, targetRect.height, accuracy: 1.0)
    }
    
    // MARK: - Animation Bypass Tests
    
    func testImmediatePositioningWhenAnimationsDisabled() async throws {
        let testWindow = createTestWindow()
        let animationEngine = setupAnimationEngine()
        
        // Disable animations
        var testConfig = AnimationConfig.default
        testConfig.enabled = false
        animationEngine.updateConfiguration(testConfig)
        
        let initialPosition = CGPoint(x: 100, y: 100)
        let targetPosition = CGPoint(x: 200, y: 150)
        
        // Set initial position
        testWindow.testRect = Rect(topLeftX: initialPosition.x, topLeftY: initialPosition.y, width: 400, height: 300)
        
        // Animate to new position (should be immediate)
        try await animationEngine.animateWindowPosition(testWindow, to: targetPosition)
        
        // Verify immediate positioning (no wait needed)
        let finalRect = try await testWindow.getAxRect()
        XCTAssertNotNil(finalRect)
        XCTAssertEqual(finalRect!.topLeftX, targetPosition.x, accuracy: 1.0)
        XCTAssertEqual(finalRect!.topLeftY, targetPosition.y, accuracy: 1.0)
        
        // Verify no active animations
        XCTAssertEqual(animationEngine.activeAnimationCount, 0)
    }
    
    func testImmediatePositioningWhenMoveAnimationsDisabled() async throws {
        // Disable only move animations
        var testConfig = AnimationConfig.default
        testConfig.enabled = true
        testConfig.moveAnimationEnabled = false
        testConfig.resizeAnimationEnabled = true
        animationEngine.updateConfiguration(testConfig)
        
        let initialPosition = CGPoint(x: 100, y: 100)
        let targetPosition = CGPoint(x: 200, y: 150)
        
        // Set initial position
        testWindow.testRect = Rect(topLeftX: initialPosition.x, topLeftY: initialPosition.y, width: 400, height: 300)
        
        // Animate to new position (should be immediate)
        try await animationEngine.animateWindowPosition(testWindow, to: targetPosition)
        
        // Verify immediate positioning (no wait needed)
        let finalRect = try await testWindow.getAxRect()
        XCTAssertNotNil(finalRect)
        XCTAssertEqual(finalRect!.topLeftX, targetPosition.x, accuracy: 1.0)
        XCTAssertEqual(finalRect!.topLeftY, targetPosition.y, accuracy: 1.0)
        
        // Verify no active animations
        XCTAssertEqual(animationEngine.activeAnimationCount, 0)
    }
    
    // MARK: - MacWindow Integration Tests
    
    func testMacWindowSetAxFrameWithAnimation() async throws {
        // Create a mock MacWindow (we'll use TestWindow for simplicity)
        let targetPosition = CGPoint(x: 200, y: 150)
        let targetSize = CGSize(width: 600, height: 450)
        
        // Set initial frame
        testWindow.testRect = Rect(topLeftX: 100, topLeftY: 100, width: 400, height: 300)
        
        // Call setAxFrame (which should trigger animation)
        testWindow.setAxFrame(targetPosition, targetSize)
        
        // Wait for animation to complete
        try await Task.sleep(for: .milliseconds(150))
        
        // Verify final frame
        let finalRect = try await testWindow.getAxRect()
        XCTAssertNotNil(finalRect)
        XCTAssertEqual(finalRect!.topLeftX, targetPosition.x, accuracy: 1.0)
        XCTAssertEqual(finalRect!.topLeftY, targetPosition.y, accuracy: 1.0)
        XCTAssertEqual(finalRect!.width, targetSize.width, accuracy: 1.0)
        XCTAssertEqual(finalRect!.height, targetSize.height, accuracy: 1.0)
    }
    
    func testMacWindowSetAxTopLeftCornerWithAnimation() async throws {
        let targetPosition = CGPoint(x: 200, y: 150)
        
        // Set initial frame
        testWindow.testRect = Rect(topLeftX: 100, topLeftY: 100, width: 400, height: 300)
        
        // Call setAxTopLeftCorner (which should trigger animation)
        testWindow.setAxTopLeftCorner(targetPosition)
        
        // Wait for animation to complete
        try await Task.sleep(for: .milliseconds(150))
        
        // Verify final position
        let finalRect = try await testWindow.getAxRect()
        XCTAssertNotNil(finalRect)
        XCTAssertEqual(finalRect!.topLeftX, targetPosition.x, accuracy: 1.0)
        XCTAssertEqual(finalRect!.topLeftY, targetPosition.y, accuracy: 1.0)
        XCTAssertEqual(finalRect!.width, 400, accuracy: 1.0) // Size should remain unchanged
        XCTAssertEqual(finalRect!.height, 300, accuracy: 1.0)
    }
    
    func testMacWindowSetSizeAsyncWithAnimation() async throws {
        let targetSize = CGSize(width: 600, height: 450)
        
        // Set initial frame
        testWindow.testRect = Rect(topLeftX: 100, topLeftY: 100, width: 400, height: 300)
        
        // Call setSizeAsync (which should trigger animation)
        testWindow.setSizeAsync(targetSize)
        
        // Wait for animation to complete
        try await Task.sleep(for: .milliseconds(150))
        
        // Verify final size
        let finalRect = try await testWindow.getAxRect()
        XCTAssertNotNil(finalRect)
        XCTAssertEqual(finalRect!.topLeftX, 100, accuracy: 1.0) // Position should remain unchanged
        XCTAssertEqual(finalRect!.topLeftY, 100, accuracy: 1.0)
        XCTAssertEqual(finalRect!.width, targetSize.width, accuracy: 1.0)
        XCTAssertEqual(finalRect!.height, targetSize.height, accuracy: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testAnimationFallbackOnError() async throws {
        // Create a window that will fail to get current rect
        let failingWindow = TestWindow(
            id: 999,
            app: TestApp.shared,
            lastFloatingSize: nil,
            parent: TestTilingContainer(orientation: .h),
            adaptiveWeight: 1.0,
            index: 0
        )
        failingWindow.shouldFailGetAxRect = true
        
        let targetPosition = CGPoint(x: 200, y: 150)
        
        // This should not throw an error, but should fallback to immediate positioning
        try await animationEngine.animateWindowPosition(failingWindow, to: targetPosition)
        
        // Verify no active animations (since it should have failed and fallen back)
        XCTAssertEqual(animationEngine.activeAnimationCount, 0)
    }
    
    // MARK: - Performance Tests
    
    func testConcurrentAnimationLimit() async throws {
        // Set a low concurrent animation limit
        var testConfig = AnimationConfig.default
        testConfig.enabled = true
        testConfig.maxConcurrentAnimations = 2
        testConfig.defaultDuration = 0.2 // Longer duration to test concurrency
        animationEngine.updateConfiguration(testConfig)
        
        // Create multiple test windows
        var testWindows: [TestWindow] = []
        for i in 0..<5 {
            let window = TestWindow(
                id: UInt32(i + 10),
                app: TestApp.shared,
                lastFloatingSize: CGSize(width: 400, height: 300),
                parent: TestTilingContainer(orientation: .h),
                adaptiveWeight: 1.0,
                index: i
            )
            window.testRect = Rect(topLeftX: 100, topLeftY: 100, width: 400, height: 300)
            testWindows.append(window)
        }
        
        // Start animations for all windows
        for (index, window) in testWindows.enumerated() {
            let targetPosition = CGPoint(x: 200 + index * 50, y: 150)
            try await animationEngine.animateWindowPosition(window, to: targetPosition)
        }
        
        // Verify that only the maximum number of animations are active
        XCTAssertLessThanOrEqual(animationEngine.activeAnimationCount, 2)
        
        // Wait for animations to complete
        try await Task.sleep(for: .milliseconds(250))
        
        // Verify all animations are complete
        XCTAssertEqual(animationEngine.activeAnimationCount, 0)
    }
}