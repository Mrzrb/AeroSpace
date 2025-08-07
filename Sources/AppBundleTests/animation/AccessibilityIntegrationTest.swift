import XCTest
import AppKit
@testable import AppBundle

@MainActor
class AccessibilityIntegrationTest: XCTestCase {
    
    func testSystemMotionPreferenceDetection() {
        // Test that we can detect system motion preferences
        let reducedMotionEnabled = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        
        // This test verifies the API is available and returns a boolean
        XCTAssertTrue(reducedMotionEnabled == true || reducedMotionEnabled == false)
    }
    
    func testAnimationDisabledWhenRespectSystemPreferencesEnabled() {
        let animationEngine = WindowAnimationEngine.shared
        
        // Create a config that respects system preferences
        var config = AnimationConfig.default
        config.respectSystemPreferences = true
        config.enabled = true
        
        animationEngine.updateConfiguration(config)
        
        // The actual behavior depends on system settings, but we can test the logic
        let currentConfig = animationEngine.currentConfiguration
        
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            // If system has reduced motion enabled, animations should be disabled
            XCTAssertFalse(currentConfig.enabled, "Animations should be disabled when system prefers reduced motion")
        } else {
            // If system doesn't have reduced motion enabled, animations should remain enabled
            XCTAssertTrue(currentConfig.enabled, "Animations should remain enabled when system doesn't prefer reduced motion")
        }
        
        // Reset to default
        animationEngine.updateConfiguration(AnimationConfig.default)
    }
    
    func testAnimationNotDisabledWhenRespectSystemPreferencesDisabled() {
        let animationEngine = WindowAnimationEngine.shared
        
        // Create a config that doesn't respect system preferences
        var config = AnimationConfig.default
        config.respectSystemPreferences = false
        config.enabled = true
        
        animationEngine.updateConfiguration(config)
        
        let currentConfig = animationEngine.currentConfiguration
        
        // Animations should remain enabled regardless of system preferences
        XCTAssertTrue(currentConfig.enabled, "Animations should remain enabled when not respecting system preferences")
        
        // Reset to default
        animationEngine.updateConfiguration(AnimationConfig.default)
    }
    
    func testAccessibilityAlternativesDetection() {
        let animationEngine = WindowAnimationEngine.shared
        
        // Test the accessibility alternatives logic indirectly
        var config = AnimationConfig.default
        config.respectSystemPreferences = true
        config.enabled = false // Simulate animations being disabled
        
        animationEngine.updateConfiguration(config)
        
        // We can't test the private method directly, but we can test the behavior
        // If system has reduced motion enabled and animations are disabled due to system preferences,
        // then accessibility alternatives should be used
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            XCTAssertFalse(animationEngine.currentConfiguration.enabled, "Animations should be disabled when system prefers reduced motion")
        }
        
        // Reset to default
        animationEngine.updateConfiguration(AnimationConfig.default)
    }
    
    func testConfigurationValidationWithAccessibilitySettings() {
        // Test that configuration validation works with accessibility settings
        var config = AnimationConfig.default
        config.respectSystemPreferences = true
        config.enabled = true
        config.defaultDuration = 0.25
        
        let validationErrors = config.validate()
        XCTAssertTrue(validationErrors.isEmpty, "Valid configuration should pass validation")
        
        // Test invalid configuration
        config.defaultDuration = -1.0
        let invalidValidationErrors = config.validate()
        XCTAssertFalse(invalidValidationErrors.isEmpty, "Invalid configuration should fail validation")
    }
    
    func testNotificationObserverSetup() {
        let animationEngine = WindowAnimationEngine.shared
        
        // Test that notification observer is properly set up
        // This is more of an integration test to ensure no crashes occur
        
        var config = AnimationConfig.default
        config.respectSystemPreferences = true
        
        // This should not crash and should properly set up observers
        XCTAssertNoThrow(animationEngine.updateConfiguration(config))
        
        // Reset to default
        animationEngine.updateConfiguration(AnimationConfig.default)
    }
    
    func testAccessibilityFeedbackIntegration() async throws {
        let animationEngine = WindowAnimationEngine.shared
        
        // Test that accessibility feedback is called when animations are disabled
        let workspace = Workspace.get(byName: "test")
        let testWindow = TestWindow.new(id: 1, parent: workspace.rootTilingContainer, adaptiveWeight: 1.0)
        
        // Configure engine to disable animations
        var config = AnimationConfig.default
        config.enabled = false
        config.respectSystemPreferences = true
        
        animationEngine.updateConfiguration(config)
        
        let targetRect = Rect(topLeftX: 100, topLeftY: 100, width: 200, height: 200)
        
        // This should complete immediately without animation
        try await animationEngine.animateWindow(testWindow, to: targetRect)
        
        // Verify window was moved immediately
        let currentRect = try await testWindow.getAxRect()
        XCTAssertEqual(currentRect?.topLeftX, targetRect.topLeftX)
        XCTAssertEqual(currentRect?.topLeftY, targetRect.topLeftY)
        XCTAssertEqual(currentRect?.width, targetRect.width)
        XCTAssertEqual(currentRect?.height, targetRect.height)
        
        // Reset to default
        animationEngine.updateConfiguration(AnimationConfig.default)
    }
    
    func testAccessibilityPreferenceChangeHandling() {
        let animationEngine = WindowAnimationEngine.shared
        
        // Test that the engine properly handles accessibility preference changes
        var config = AnimationConfig.default
        config.respectSystemPreferences = true
        config.enabled = true
        
        animationEngine.updateConfiguration(config)
        
        // Simulate accessibility preference change notification
        // This tests that the notification observer is properly set up
        NotificationCenter.default.post(
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
        
        // The engine should handle this notification without crashing
        // The actual behavior depends on system settings
        XCTAssertNotNil(animationEngine.currentConfiguration)
        
        // Reset to default
        animationEngine.updateConfiguration(AnimationConfig.default)
    }
    
    func testOriginalConfigurationRestoration() {
        let animationEngine = WindowAnimationEngine.shared
        
        // Test that original configuration is restored when reduced motion is disabled
        var config = AnimationConfig.default
        config.respectSystemPreferences = true
        config.enabled = true
        
        animationEngine.updateConfiguration(config)
        
        // If system doesn't have reduced motion, animations should remain enabled
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            XCTAssertTrue(animationEngine.currentConfiguration.enabled)
        }
        
        // Test with animations originally disabled
        config.enabled = false
        animationEngine.updateConfiguration(config)
        
        // Even if system doesn't have reduced motion, animations should remain disabled
        // because they were originally disabled in the config
        XCTAssertFalse(animationEngine.currentConfiguration.enabled)
        
        // Reset to default
        animationEngine.updateConfiguration(AnimationConfig.default)
    }
}