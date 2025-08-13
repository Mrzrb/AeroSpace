@testable import AppBundle
import Common
import XCTest

@MainActor
final class TilingContainerLayoutUpdateTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    // MARK: - Layout Update Trigger Tests

    func testTriggerLayoutUpdateCallsWorkspaceLayout() async throws {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add a test window to make the workspace non-empty
        let window = TestWindow.new(id: 1, parent: container, adaptiveWeight: 1.0)
        
        // Set initial test rect
        window.setTestRect(Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600))
        
        // Clear any previous layout calls
        window.lastSetFrame = nil
        
        // Trigger layout update
        container.triggerLayoutUpdate()
        
        // Give time for async operation to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify that layout was applied (window should have received setAxFrame call)
        XCTAssertNotNil(window.lastSetFrame, "Window should have received layout update")
    }

    func testTriggerLayoutUpdateWithCompletion() async throws {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add a test window
        let window = TestWindow.new(id: 1, parent: container, adaptiveWeight: 1.0)
        window.setTestRect(Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600))
        
        var completionCalled = false
        
        // Trigger layout update with completion
        container.triggerLayoutUpdate {
            completionCalled = true
        }
        
        // Give time for async operation to complete
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Verify completion was called
        XCTAssertTrue(completionCalled, "Completion callback should have been called")
        XCTAssertNotNil(window.lastSetFrame, "Window should have received layout update")
    }

    func testTriggerLayoutUpdateHandlesErrors() async throws {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        var completionCalled = false
        
        // This should complete successfully and call the completion callback
        container.triggerLayoutUpdate {
            completionCalled = true
        }
        
        // Give time for async operation to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Completion should be called
        XCTAssertTrue(completionCalled, "Completion callback should be called")
    }

    // MARK: - BSP Weight Validation Tests

    func testValidateBSPWeightsMinimumConstraint() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add windows with some having weights below minimum
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 0.05) // Below minimum
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 0.02) // Below minimum
        let window3 = TestWindow.new(id: 3, parent: container, adaptiveWeight: 1.0)   // Above minimum
        
        // Validate weights
        container.validateBSPWeights(orientation: .h)
        
        // Check that minimum weights were applied
        XCTAssertGreaterThanOrEqual(window1.getWeight(.h), 0.1, "Window1 weight should be at least minimum")
        XCTAssertGreaterThanOrEqual(window2.getWeight(.h), 0.1, "Window2 weight should be at least minimum")
        XCTAssertGreaterThanOrEqual(window3.getWeight(.h), 0.1, "Window3 weight should be at least minimum")
    }

    func testValidateBSPWeightsSkipsNonBSPContainers() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .tiles, index: 0) // Not BSP
        
        // Add window with weight below minimum
        let window = TestWindow.new(id: 1, parent: container, adaptiveWeight: 0.05)
        let originalWeight = window.getWeight(.h)
        
        // Validate weights (should do nothing for non-BSP containers)
        container.validateBSPWeights(orientation: .h)
        
        // Weight should remain unchanged
        XCTAssertEqual(window.getWeight(.h), originalWeight, accuracy: 0.001, "Weight should not change for non-BSP containers")
    }

    func testValidateAndCorrectBSPWeightsReturnsCorrectStatus() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Test case 1: Weights already valid
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 1.0)
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 1.0)
        
        let correctionsMade1 = container.validateAndCorrectBSPWeights(orientation: .h)
        XCTAssertFalse(correctionsMade1, "Should return false when no corrections needed")
        
        // Test case 2: Weights need correction
        window1.setWeight(.h, 0.05) // Below minimum
        let correctionsMade2 = container.validateAndCorrectBSPWeights(orientation: .h)
        XCTAssertTrue(correctionsMade2, "Should return true when corrections were made")
        
        // Verify correction was applied
        XCTAssertGreaterThanOrEqual(window1.getWeight(.h), 0.1, "Weight should be corrected to minimum")
    }

    func testValidateAndCorrectBSPWeightsMaximumConstraint() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add windows with one having excessive weight
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 5.0) // Excessive
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 1.0)
        
        let correctionsMade = container.validateAndCorrectBSPWeights(orientation: .h)
        XCTAssertTrue(correctionsMade, "Should return true when corrections were made")
        
        // Verify maximum constraint was applied (90% of total space for 2 children = 1.8)
        let maxAllowed = 0.9 * CGFloat(container.children.count)
        XCTAssertLessThanOrEqual(window1.getWeight(.h), maxAllowed, "Weight should not exceed maximum")
    }

    func testValidateAndCorrectBSPWeightsNormalizesTotalWeight() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add windows with total weight that's too high
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 10.0)
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 10.0)
        let window3 = TestWindow.new(id: 3, parent: container, adaptiveWeight: 10.0)
        
        let initialTotalWeight = container.children.sumOfDouble { $0.getWeight(.h) }
        XCTAssertGreaterThan(initialTotalWeight, CGFloat(container.children.count) * 2.0, "Initial total weight should be excessive")
        
        let correctionsMade = container.validateAndCorrectBSPWeights(orientation: .h)
        XCTAssertTrue(correctionsMade, "Should return true when normalization was applied")
        
        let finalTotalWeight = container.children.sumOfDouble { $0.getWeight(.h) }
        let expectedTotalWeight = CGFloat(container.children.count) // Target: 1.0 per child
        XCTAssertEqual(finalTotalWeight, expectedTotalWeight, accuracy: 0.01, "Total weight should be normalized")
    }

    func testValidateAndCorrectBSPWeightsHandlesZeroWeights() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add windows with zero weights
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 0.0)
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 0.0)
        
        let correctionsMade = container.validateAndCorrectBSPWeights(orientation: .h)
        XCTAssertTrue(correctionsMade, "Should return true when zero weights were corrected")
        
        // Verify weights were corrected to minimum weight (0.1)
        XCTAssertEqual(window1.getWeight(.h), 0.1, accuracy: 0.01, "Window1 should get minimum weight")
        XCTAssertEqual(window2.getWeight(.h), 0.1, accuracy: 0.01, "Window2 should get minimum weight")
    }

    func testValidateAndCorrectBSPWeightsPreservesProportions() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add windows with proportions within BSP limits
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 1.5) // 1.5:1 ratio
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 1.0)
        
        let initialRatio = window1.getWeight(.h) / window2.getWeight(.h)
        
        let correctionsMade = container.validateAndCorrectBSPWeights(orientation: .h)
        
        let finalRatio = window1.getWeight(.h) / window2.getWeight(.h)
        XCTAssertEqual(finalRatio, initialRatio, accuracy: 0.1, "Proportions should be approximately preserved when within BSP limits")
    }

    // MARK: - Integration Tests

    func testLayoutUpdateAndWeightValidationIntegration() async throws {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add windows with invalid weights
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 0.05) // Below minimum
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 1.0)
        
        // Set test rects
        window1.setTestRect(Rect(topLeftX: 0, topLeftY: 0, width: 400, height: 300))
        window2.setTestRect(Rect(topLeftX: 400, topLeftY: 0, width: 400, height: 300))
        
        // Clear layout history
        window1.lastSetFrame = nil
        window2.lastSetFrame = nil
        
        // Validate weights and trigger layout update
        container.validateBSPWeights(orientation: .h)
        container.triggerLayoutUpdate()
        
        // Give time for async operation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify weight was corrected
        XCTAssertGreaterThanOrEqual(window1.getWeight(.h), 0.1, "Weight should be corrected")
        
        // Verify layout update was triggered
        XCTAssertNotNil(window1.lastSetFrame, "Window1 should have received layout update")
        XCTAssertNotNil(window2.lastSetFrame, "Window2 should have received layout update")
    }

    func testLayoutUpdateWithMultipleOrientations() async throws {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add windows
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 1.0)
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 1.0)
        
        // Set test rects
        window1.setTestRect(Rect(topLeftX: 0, topLeftY: 0, width: 400, height: 300))
        window2.setTestRect(Rect(topLeftX: 400, topLeftY: 0, width: 400, height: 300))
        
        // Test horizontal orientation validation
        window1.setWeight(.h, 0.05) // Below minimum
        container.validateBSPWeights(orientation: .h)
        XCTAssertGreaterThanOrEqual(window1.getWeight(.h), 0.1, "Horizontal weight should be corrected")
        
        // Test vertical orientation validation
        window1.setWeight(.v, 0.03) // Below minimum
        container.validateBSPWeights(orientation: .v)
        XCTAssertGreaterThanOrEqual(window1.getWeight(.v), 0.1, "Vertical weight should be corrected")
        
        // Trigger layout update
        container.triggerLayoutUpdate()
        
        // Give time for async operation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify layout update was applied
        XCTAssertNotNil(window1.lastSetFrame, "Layout update should have been applied")
    }
}