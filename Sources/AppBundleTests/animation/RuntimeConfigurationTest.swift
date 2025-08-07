import XCTest
import AppKit
@testable import AppBundle

@MainActor
class RuntimeConfigurationTest: XCTestCase {
    
    func testConfigurationUpdateNotification() {
        let animationEngine = WindowAnimationEngine.shared
        
        // Set up notification observer
        var notificationReceived = false
        var receivedOldConfig: AnimationConfig?
        var receivedNewConfig: AnimationConfig?
        
        let observer = NotificationCenter.default.addObserver(
            forName: .animationConfigurationDidChange,
            object: animationEngine,
            queue: .main
        ) { notification in
            notificationReceived = true
            receivedOldConfig = notification.userInfo?["oldConfig"] as? AnimationConfig
            receivedNewConfig = notification.userInfo?["newConfig"] as? AnimationConfig
        }
        
        defer {
            NotificationCenter.default.removeObserver(observer)
            // Reset to default
            animationEngine.updateConfiguration(AnimationConfig.default)
        }
        
        // Update configuration
        var newConfig = AnimationConfig.default
        newConfig.defaultDuration = 0.5
        newConfig.easingFunction = .easeIn
        
        animationEngine.updateConfiguration(newConfig)
        
        // Verify notification was posted
        XCTAssertTrue(notificationReceived, "Configuration change notification should be posted")
        XCTAssertNotNil(receivedOldConfig, "Old configuration should be included in notification")
        XCTAssertNotNil(receivedNewConfig, "New configuration should be included in notification")
        
        if let oldConfig = receivedOldConfig, let newConfig = receivedNewConfig {
            XCTAssertEqual(oldConfig.defaultDuration, AnimationConfig.default.defaultDuration)
            XCTAssertEqual(newConfig.defaultDuration, 0.5)
            XCTAssertEqual(newConfig.easingFunction, .easeIn)
        }
    }
    
    func testConfigurationTransitionHandling() {
        let animationEngine = WindowAnimationEngine.shared
        
        // Start with animations enabled, but don't respect system preferences to avoid interference
        var config1 = AnimationConfig.default
        config1.enabled = true
        config1.maxConcurrentAnimations = 5
        config1.respectSystemPreferences = false // Disable system preference checking
        
        animationEngine.updateConfiguration(config1)
        XCTAssertTrue(animationEngine.currentConfiguration.enabled)
        XCTAssertEqual(animationEngine.currentConfiguration.maxConcurrentAnimations, 5)
        
        // Change to disabled animations
        var config2 = AnimationConfig.default
        config2.enabled = false
        config2.maxConcurrentAnimations = 10
        config2.respectSystemPreferences = false // Disable system preference checking
        
        animationEngine.updateConfiguration(config2)
        XCTAssertFalse(animationEngine.currentConfiguration.enabled)
        XCTAssertEqual(animationEngine.currentConfiguration.maxConcurrentAnimations, 10)
        
        // Reset to default
        animationEngine.updateConfiguration(AnimationConfig.default)
    }
    
    func testPerformanceSettingsUpdate() {
        let animationEngine = WindowAnimationEngine.shared
        
        // Update performance settings
        var config = AnimationConfig.default
        config.minFrameRate = 45.0
        config.maxConcurrentAnimations = 15
        config.adaptiveQuality = false
        
        animationEngine.updateConfiguration(config)
        
        let currentConfig = animationEngine.currentConfiguration
        XCTAssertEqual(currentConfig.minFrameRate, 45.0)
        XCTAssertEqual(currentConfig.maxConcurrentAnimations, 15)
        XCTAssertFalse(currentConfig.adaptiveQuality)
        
        // Reset to default
        animationEngine.updateConfiguration(AnimationConfig.default)
    }
    
    func testConfigurationValidationDuringUpdate() {
        let animationEngine = WindowAnimationEngine.shared
        
        // Try to update with invalid configuration
        var invalidConfig = AnimationConfig.default
        invalidConfig.defaultDuration = -1.0 // Invalid duration
        invalidConfig.maxConcurrentAnimations = 0 // Invalid max concurrent
        
        let originalConfig = animationEngine.currentConfiguration
        
        // This should fail validation and not update the configuration
        animationEngine.updateConfiguration(invalidConfig)
        
        // Configuration should remain unchanged
        let currentConfig = animationEngine.currentConfiguration
        XCTAssertEqual(currentConfig.defaultDuration, originalConfig.defaultDuration)
        XCTAssertEqual(currentConfig.maxConcurrentAnimations, originalConfig.maxConcurrentAnimations)
    }
    
    func testSmoothTransitionBetweenConfigurations() {
        let animationEngine = WindowAnimationEngine.shared
        
        // Start with one configuration
        var config1 = AnimationConfig.default
        config1.defaultDuration = 0.2
        config1.easingFunction = .linear
        
        animationEngine.updateConfiguration(config1)
        
        // Change to another configuration
        var config2 = AnimationConfig.default
        config2.defaultDuration = 0.8
        config2.easingFunction = .easeInOut
        
        // This should handle the transition smoothly
        XCTAssertNoThrow(animationEngine.updateConfiguration(config2))
        
        // Verify the new configuration is applied
        let currentConfig = animationEngine.currentConfiguration
        XCTAssertEqual(currentConfig.defaultDuration, 0.8)
        XCTAssertEqual(currentConfig.easingFunction, .easeInOut)
        
        // Reset to default
        animationEngine.updateConfiguration(AnimationConfig.default)
    }
    
    func testConfigurationUpdateWithActiveAnimations() async throws {
        let animationEngine = WindowAnimationEngine.shared
        
        // Enable animations
        var config = AnimationConfig.default
        config.enabled = true
        config.defaultDuration = 0.1 // Short duration for testing
        config.respectSystemPreferences = false // Disable system preference checking for tests
        
        animationEngine.updateConfiguration(config)
        
        // Create a test window and start an animation
        let workspace = Workspace.get(byName: "test")
        let testWindow = TestWindow.new(id: 1, parent: workspace.rootTilingContainer, adaptiveWeight: 1.0)
        
        // Set initial position for the test window
        testWindow.setTestRect(Rect(topLeftX: 50, topLeftY: 50, width: 150, height: 150))
        
        let targetRect = Rect(topLeftX: 100, topLeftY: 100, width: 200, height: 200)
        
        // Start animation (don't await it)
        let animationTask = Task {
            try await animationEngine.animateWindow(testWindow, to: targetRect)
        }
        
        // Wait a bit for animation to start
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Update configuration while animation is running
        var newConfig = AnimationConfig.default
        newConfig.enabled = false // This should cancel active animations
        
        animationEngine.updateConfiguration(newConfig)
        
        // Wait for animation task to complete
        try await animationTask.value
        
        // Reset to default
        animationEngine.updateConfiguration(AnimationConfig.default)
    }
    
    func testReloadConfigIntegration() {
        // Test that the reload config command properly updates animation configuration
        let animationEngine = WindowAnimationEngine.shared
        
        // Get initial configuration
        let initialConfig = animationEngine.currentConfiguration
        
        // Simulate config reload (this would normally parse from TOML)
        var newConfig = AnimationConfig.default
        newConfig.defaultDuration = 0.75
        newConfig.enabled = false
        
        // Update the global config (simulating what reloadConfig does)
        config.animation = newConfig
        
        // Update animation engine (this is what we added to reloadConfig)
        animationEngine.updateConfiguration(newConfig)
        
        // Verify the configuration was updated
        let updatedConfig = animationEngine.currentConfiguration
        XCTAssertEqual(updatedConfig.defaultDuration, 0.75)
        XCTAssertFalse(updatedConfig.enabled)
        XCTAssertNotEqual(updatedConfig.defaultDuration, initialConfig.defaultDuration)
        
        // Reset to default
        animationEngine.updateConfiguration(AnimationConfig.default)
        config.animation = AnimationConfig.default
    }
    
    func testConfigurationChangeNotificationContent() {
        let animationEngine = WindowAnimationEngine.shared
        
        var notifications: [(old: AnimationConfig, new: AnimationConfig)] = []
        
        let observer = NotificationCenter.default.addObserver(
            forName: .animationConfigurationDidChange,
            object: animationEngine,
            queue: .main
        ) { notification in
            if let oldConfig = notification.userInfo?["oldConfig"] as? AnimationConfig,
               let newConfig = notification.userInfo?["newConfig"] as? AnimationConfig {
                notifications.append((old: oldConfig, new: newConfig))
            }
        }
        
        defer {
            NotificationCenter.default.removeObserver(observer)
            // Reset to default
            animationEngine.updateConfiguration(AnimationConfig.default)
        }
        
        // Make multiple configuration changes
        var config1 = AnimationConfig.default
        config1.defaultDuration = 0.3
        animationEngine.updateConfiguration(config1)
        
        var config2 = AnimationConfig.default
        config2.defaultDuration = 0.6
        config2.easingFunction = .easeIn
        animationEngine.updateConfiguration(config2)
        
        // Verify we received notifications for both changes
        XCTAssertEqual(notifications.count, 2)
        
        // Verify first notification
        XCTAssertEqual(notifications[0].old.defaultDuration, AnimationConfig.default.defaultDuration)
        XCTAssertEqual(notifications[0].new.defaultDuration, 0.3)
        
        // Verify second notification
        XCTAssertEqual(notifications[1].old.defaultDuration, 0.3)
        XCTAssertEqual(notifications[1].new.defaultDuration, 0.6)
        XCTAssertEqual(notifications[1].new.easingFunction, .easeIn)
    }
}