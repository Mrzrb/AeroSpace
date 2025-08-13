@testable import AppBundle
import Common
import XCTest

@MainActor
final class BSPWeightValidationTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    // MARK: - Comprehensive Weight Validation Tests

    func testValidateBSPWeightsComprehensiveWithValidWeights() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add windows with valid weights
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 1.0)
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 1.5)
        let window3 = TestWindow.new(id: 3, parent: container, adaptiveWeight: 0.8)
        
        let result = container.validateBSPWeightsComprehensive(orientation: .h)
        
        XCTAssertFalse(result.correctionsMade, "No corrections should be needed for valid weights")
        XCTAssertTrue(result.issues.isEmpty, "No issues should be found for valid weights")
        XCTAssertEqual(result.summary, "No weight corrections needed", "Summary should indicate no corrections")
    }

    func testValidateBSPWeightsComprehensiveWithSmallWeights() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add windows with weights below minimum
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 0.05) // Too small
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 0.02) // Too small
        let window3 = TestWindow.new(id: 3, parent: container, adaptiveWeight: 1.0)   // Valid
        
        let result = container.validateBSPWeightsComprehensive(orientation: .h)
        
        XCTAssertTrue(result.correctionsMade, "Corrections should be made for small weights")
        XCTAssertEqual(result.issues.count, 2, "Should find 2 small weight issues")
        
        // Verify corrections were applied
        XCTAssertGreaterThanOrEqual(window1.getWeight(.h), 0.1, "Window1 weight should be corrected to minimum")
        XCTAssertGreaterThanOrEqual(window2.getWeight(.h), 0.1, "Window2 weight should be corrected to minimum")
        XCTAssertEqual(window3.getWeight(.h), 1.0, accuracy: 0.01, "Window3 weight should remain unchanged")
        
        // Check issue types
        let smallWeightIssues = result.issues.compactMap { issue in
            if case .weightTooSmall = issue { return issue } else { return nil }
        }
        XCTAssertEqual(smallWeightIssues.count, 2, "Should have 2 small weight issues")
    }

    func testValidateBSPWeightsComprehensiveWithLargeWeights() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add windows with excessive weights (but total weight not too high to avoid normalization)
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 2.0) // Too large for individual limit
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 1.0)   // Valid
        
        let maxAllowed = 0.9 * CGFloat(2) // 90% of total space for 2 children
        
        let result = container.validateBSPWeightsComprehensive(orientation: .h)
        
        XCTAssertTrue(result.correctionsMade, "Corrections should be made for large weights")
        
        // Verify correction was applied
        XCTAssertLessThanOrEqual(window1.getWeight(.h), maxAllowed, "Window1 weight should be capped at maximum")
        
        // Check for large weight issue
        let largeWeightIssues = result.issues.compactMap { issue in
            if case .weightTooLarge = issue { return issue } else { return nil }
        }
        XCTAssertGreaterThan(largeWeightIssues.count, 0, "Should have at least one large weight issue")
    }

    func testValidateBSPWeightsComprehensiveWithZeroTotalWeight() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add windows with zero weights
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 0.0)
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 0.0)
        
        let result = container.validateBSPWeightsComprehensive(orientation: .h)
        
        XCTAssertTrue(result.correctionsMade, "Corrections should be made for zero total weight")
        
        // Verify equal distribution was applied
        let expectedWeight = 1.0 // Target: 1.0 per child
        XCTAssertEqual(window1.getWeight(.h), expectedWeight, accuracy: 0.01, "Window1 should get equal weight")
        XCTAssertEqual(window2.getWeight(.h), expectedWeight, accuracy: 0.01, "Window2 should get equal weight")
        
        // Check for total weight issue
        let totalWeightIssues = result.issues.compactMap { issue in
            if case .totalWeightInvalid = issue { return issue } else { return nil }
        }
        XCTAssertEqual(totalWeightIssues.count, 1, "Should have one total weight invalid issue")
    }

    func testValidateBSPWeightsComprehensiveWithExcessiveTotalWeight() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add windows with excessive total weight
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 15.0)
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 15.0)
        
        let initialTotal = window1.getWeight(.h) + window2.getWeight(.h)
        XCTAssertGreaterThan(initialTotal, CGFloat(2) * 2.0, "Initial total should be excessive")
        
        let result = container.validateBSPWeightsComprehensive(orientation: .h)
        
        XCTAssertTrue(result.correctionsMade, "Corrections should be made for excessive total weight")
        
        // Verify normalization was applied
        let finalTotal = window1.getWeight(.h) + window2.getWeight(.h)
        let expectedTotal = CGFloat(2) // Target: 1.0 per child
        XCTAssertEqual(finalTotal, expectedTotal, accuracy: 0.01, "Total weight should be normalized")
        
        // Check for excessive total weight issue
        let excessiveWeightIssues = result.issues.compactMap { issue in
            if case .totalWeightExcessive = issue { return issue } else { return nil }
        }
        XCTAssertEqual(excessiveWeightIssues.count, 1, "Should have one excessive total weight issue")
    }

    func testValidateBSPWeightsComprehensiveSkipsNonBSPContainers() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .tiles, index: 0) // Not BSP
        
        // Add window with invalid weight
        let window = TestWindow.new(id: 1, parent: container, adaptiveWeight: 0.05)
        let originalWeight = window.getWeight(.h)
        
        let result = container.validateBSPWeightsComprehensive(orientation: .h)
        
        XCTAssertFalse(result.correctionsMade, "No corrections should be made for non-BSP containers")
        XCTAssertTrue(result.issues.isEmpty, "No issues should be found for non-BSP containers")
        XCTAssertEqual(window.getWeight(.h), originalWeight, accuracy: 0.001, "Weight should remain unchanged")
    }

    // MARK: - Intelligent Weight Distribution Tests

    func testApplyIntelligentBSPWeightsBasicDistribution() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add three windows
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 1.0)
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 1.0)
        let window3 = TestWindow.new(id: 3, parent: container, adaptiveWeight: 1.0)
        
        container.applyIntelligentBSPWeights(orientation: .h)
        
        // Verify weights were applied
        let totalWeight = container.children.sumOfDouble { $0.getWeight(.h) }
        let expectedTotal = CGFloat(3) // Target: 1.0 per child on average
        XCTAssertEqual(totalWeight, expectedTotal, accuracy: 0.1, "Total weight should be reasonable")
        
        // First window should get slightly more weight (main window concept)
        XCTAssertGreaterThan(window1.getWeight(.h), window2.getWeight(.h), "First window should get more weight")
        XCTAssertGreaterThan(window1.getWeight(.h), window3.getWeight(.h), "First window should get more weight")
    }

    func testApplyIntelligentBSPWeightsWithAspectRatio() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add three windows
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 1.0)
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 1.0)
        let window3 = TestWindow.new(id: 3, parent: container, adaptiveWeight: 1.0)
        
        // Apply intelligent weights with wide aspect ratio
        let wideRect = Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 600) // 3.2:1 aspect ratio
        container.applyIntelligentBSPWeights(orientation: .h, containerRect: wideRect)
        
        // For wide containers with horizontal split, center window should get more weight
        XCTAssertGreaterThan(window2.getWeight(.h), window1.getWeight(.h), "Center window should get more weight in wide container")
        XCTAssertGreaterThan(window2.getWeight(.h), window3.getWeight(.h), "Center window should get more weight in wide container")
    }

    func testApplyIntelligentBSPWeightsSkipsNonBSPContainers() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .tiles, index: 0) // Not BSP
        
        // Add windows
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 1.0)
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 2.0)
        
        let originalWeight1 = window1.getWeight(.h)
        let originalWeight2 = window2.getWeight(.h)
        
        container.applyIntelligentBSPWeights(orientation: .h)
        
        // Weights should remain unchanged for non-BSP containers
        XCTAssertEqual(window1.getWeight(.h), originalWeight1, accuracy: 0.001, "Weight should remain unchanged")
        XCTAssertEqual(window2.getWeight(.h), originalWeight2, accuracy: 0.001, "Weight should remain unchanged")
    }

    // MARK: - Weight Summary Tests

    func testGetBSPWeightSummaryForValidWeights() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add windows with known weights
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 1.0)
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 1.5)
        let window3 = TestWindow.new(id: 3, parent: container, adaptiveWeight: 0.8)
        
        let summary = container.getBSPWeightSummary(orientation: .h)
        
        XCTAssertTrue(summary.isValid, "Summary should indicate valid weights")
        XCTAssertEqual(summary.totalWeight, 3.3, accuracy: 0.01, "Total weight should be sum of individual weights")
        XCTAssertEqual(summary.averageWeight, 1.1, accuracy: 0.01, "Average weight should be total/count")
        XCTAssertEqual(summary.minWeight, 0.8, accuracy: 0.01, "Min weight should be smallest weight")
        XCTAssertEqual(summary.maxWeight, 1.5, accuracy: 0.01, "Max weight should be largest weight")
        XCTAssertEqual(summary.childWeights.count, 3, "Should have weights for all children")
        
        // Verify description contains expected information
        XCTAssertTrue(summary.description.contains("Valid: true"), "Description should indicate validity")
        XCTAssertTrue(summary.description.contains("Total: 3.30"), "Description should show total weight")
    }

    func testGetBSPWeightSummaryForInvalidWeights() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add windows with invalid weights
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 0.05) // Too small
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 10.0) // Excessive total
        
        let summary = container.getBSPWeightSummary(orientation: .h)
        
        XCTAssertFalse(summary.isValid, "Summary should indicate invalid weights")
        XCTAssertEqual(summary.totalWeight, 10.05, accuracy: 0.01, "Total weight should be sum of individual weights")
        XCTAssertEqual(summary.minWeight, 0.05, accuracy: 0.01, "Min weight should be smallest weight")
        XCTAssertEqual(summary.maxWeight, 10.0, accuracy: 0.01, "Max weight should be largest weight")
        
        // Verify description indicates invalidity
        XCTAssertTrue(summary.description.contains("Valid: false"), "Description should indicate invalidity")
    }

    func testGetBSPWeightSummaryForNonBSPContainer() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .tiles, index: 0) // Not BSP
        
        // Add windows
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 1.0)
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 2.0)
        
        let summary = container.getBSPWeightSummary(orientation: .h)
        
        XCTAssertFalse(summary.isValid, "Summary should indicate invalid for non-BSP containers")
        XCTAssertEqual(summary.totalWeight, 0, "Total weight should be 0 for non-BSP containers")
        XCTAssertEqual(summary.averageWeight, 0, "Average weight should be 0 for non-BSP containers")
        XCTAssertTrue(summary.childWeights.isEmpty, "Child weights should be empty for non-BSP containers")
    }

    // MARK: - Integration Tests

    func testWeightValidationIntegrationWithResizeCommand() async throws {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add windows with one having invalid weight
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 0.05) // Below minimum
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 1.0)
        
        // Focus first window
        assertEquals(window1.focusWindow(), true)
        
        // Perform resize operation (this should trigger weight validation)
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(10)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        assertEquals(resizeCommand.run(.defaultEnv, cmdIo), true)
        
        // Verify weight validation was applied
        XCTAssertGreaterThanOrEqual(window1.getWeight(.h), 0.1, "Weight should be corrected to minimum")
        XCTAssertGreaterThanOrEqual(window2.getWeight(.h), 0.1, "Weight should be at least minimum")
        
        // Verify comprehensive validation would show no issues now
        let result = container.validateBSPWeightsComprehensive(orientation: .h)
        XCTAssertFalse(result.correctionsMade, "No further corrections should be needed after resize")
    }

    func testWeightValidationWithMultipleOrientations() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add windows with invalid weights in the container's orientation
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 1.0)
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 1.0)
        
        // Set invalid weight for the container's orientation (horizontal)
        window1.setWeight(.h, 0.05) // Horizontal too small - this should be corrected
        window2.setWeight(.h, 1.0)  // Horizontal valid
        
        // Attempt to set weights for non-matching orientation (vertical)
        // These operations should be no-ops due to orientation mismatch
        window1.setWeight(.v, 0.03) // This should be ignored (no-op)
        window2.setWeight(.v, 1.0)  // This should be ignored (no-op)
        
        // Validate horizontal orientation (container's orientation)
        let hResult = container.validateBSPWeightsComprehensive(orientation: .h)
        XCTAssertTrue(hResult.correctionsMade, "Horizontal corrections should be made")
        XCTAssertGreaterThanOrEqual(window1.getWeight(.h), 0.1, "Horizontal weight should be corrected")
        
        // Validate vertical orientation (non-matching orientation)
        // Since the container is horizontal, vertical weights should return default values (1.0)
        // and no corrections should be needed
        let vResult = container.validateBSPWeightsComprehensive(orientation: .v)
        XCTAssertFalse(vResult.correctionsMade, "No vertical corrections should be made for horizontal container")
        
        // Verify that vertical weights return default values
        XCTAssertEqual(window1.getWeight(.v), 1.0, "Vertical weight should return default value for horizontal container")
        XCTAssertEqual(window2.getWeight(.v), 1.0, "Vertical weight should return default value for horizontal container")
        
        // Verify both orientations are valid
        let hSummary = container.getBSPWeightSummary(orientation: .h)
        let vSummary = container.getBSPWeightSummary(orientation: .v)
        XCTAssertTrue(hSummary.isValid, "Horizontal weights should be valid after correction")
        XCTAssertTrue(vSummary.isValid, "Vertical weights should be valid (default values)")
    }

    func testWeightValidationPreservesProportions() {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add windows with valid proportions but excessive total
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 6.0) // 2:1 ratio
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 3.0)
        
        let initialRatio = window1.getWeight(.h) / window2.getWeight(.h)
        
        let result = container.validateBSPWeightsComprehensive(orientation: .h)
        XCTAssertTrue(result.correctionsMade, "Corrections should be made for excessive total")
        
        let finalRatio = window1.getWeight(.h) / window2.getWeight(.h)
        XCTAssertEqual(finalRatio, initialRatio, accuracy: 0.01, "Proportions should be preserved")
        
        // Verify total weight is now reasonable
        let summary = container.getBSPWeightSummary(orientation: .h)
        XCTAssertTrue(summary.isValid, "Weights should be valid after correction")
        XCTAssertLessThanOrEqual(summary.totalWeight, CGFloat(container.children.count) * 2.0, "Total weight should be reasonable")
    }
}