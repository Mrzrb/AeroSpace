import XCTest
@testable import AppBundle

class IntelligentBSPTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Set up test configuration with BSP enabled
        config.bsp.enableIntelligentRebalancing = true
        config.bsp.enableAdaptiveWeighting = true
        config.bsp.enableAutoOptimization = true
        config.bsp.splitRatio = 0.5
        config.bsp.autoSplitThreshold = 1.2
    }
    
    func testBSPTreeOptimization() {
        let workspace = Workspace.get(byName: WorkspaceName.parse("test"))
        let rootContainer = workspace.rootTilingContainer
        rootContainer.layout = .bsp
        
        // Create test windows
        let window1 = createTestWindow(id: 1)
        let window2 = createTestWindow(id: 2)
        let window3 = createTestWindow(id: 3)
        
        // Add windows to BSP container
        window1.bind(to: rootContainer, adaptiveWeight: 0.5, index: 0)
        window2.bind(to: rootContainer, adaptiveWeight: 0.3, index: 1)
        window3.bind(to: rootContainer, adaptiveWeight: 0.2, index: 2)
        
        // Test optimization
        rootContainer.handleRootContainerChange()
        
        // Verify that weights are rebalanced
        let totalWeight = rootContainer.children.map { $0.getWeight(rootContainer.orientation) }.reduce(0, +)
        XCTAssertEqual(totalWeight, 1.0, accuracy: 0.01, "Total weight should be 1.0 after optimization")
        
        // Verify that all children have reasonable weights
        for child in rootContainer.children {
            let weight = child.getWeight(rootContainer.orientation)
            XCTAssertGreaterThan(weight, 0.1, "Child weight should be at least 0.1")
            XCTAssertLessThan(weight, 0.9, "Child weight should be at most 0.9")
        }
    }
    
    func testBSPSplitDirectionSelection() {
        let workspace = Workspace.get(byName: WorkspaceName.parse("test"))
        let rootContainer = workspace.rootTilingContainer
        rootContainer.layout = .bsp
        
        // Test wide container (should prefer vertical split)
        let wideRect = Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 600)
        rootContainer.lastAppliedLayoutVirtualRect = wideRect
        
        let wideDirection = rootContainer.chooseBSPSplitDirection(width: wideRect.width, height: wideRect.height)
        XCTAssertEqual(wideDirection, .v, "Wide container should prefer vertical split")
        
        // Test tall container (should prefer horizontal split)
        let tallRect = Rect(topLeftX: 0, topLeftY: 0, width: 600, height: 1200)
        rootContainer.lastAppliedLayoutVirtualRect = tallRect
        
        let tallDirection = rootContainer.chooseBSPSplitDirection(width: tallRect.width, height: tallRect.height)
        XCTAssertEqual(tallDirection, .h, "Tall container should prefer horizontal split")
    }
    
    func testBSPWeightCalculation() {
        let workspace = Workspace.get(byName: WorkspaceName.parse("test"))
        let rootContainer = workspace.rootTilingContainer
        rootContainer.layout = .bsp
        
        // Test optimal weight calculation
        let weights = rootContainer.calculateOptimalWeights(
            windowCount: 3,
            aspectRatio: 1.5,
            orientation: .h
        )
        
        XCTAssertEqual(weights.count, 3, "Should calculate weights for all windows")
        
        let totalWeight = weights.reduce(0, +)
        XCTAssertEqual(totalWeight, 1.0, accuracy: 0.01, "Total weight should be 1.0")
        
        // First window should have slightly more weight (main window concept)
        XCTAssertGreaterThan(weights[0], weights[1], "First window should have more weight")
    }
    
    func testBSPErrorHandling() {
        let workspace = Workspace.get(byName: WorkspaceName.parse("test"))
        let rootContainer = workspace.rootTilingContainer
        rootContainer.layout = .bsp
        
        // Test handling of empty container
        XCTAssertTrue(rootContainer.validateBSPTreeStructure(), "Empty BSP container should be valid")
        
        // Test handling of single window
        let window = createTestWindow(id: 1)
        window.bind(to: rootContainer, adaptiveWeight: 1.0, index: 0)
        
        XCTAssertTrue(rootContainer.validateBSPTreeStructure(), "Single window BSP container should be valid")
        
        // Test weight rebalancing
        XCTAssertTrue(rootContainer.rebalanceBSPWeights(), "Weight rebalancing should succeed")
    }
    
    func testBSPStructureRebuild() {
        let workspace = Workspace.get(byName: WorkspaceName.parse("test"))
        let rootContainer = workspace.rootTilingContainer
        rootContainer.layout = .bsp
        
        // Create multiple windows
        let windows = (1...4).map { createTestWindow(id: UInt32($0)) }
        
        // Add windows with various weights
        for (index, window) in windows.enumerated() {
            window.bind(to: rootContainer, adaptiveWeight: CGFloat(index + 1) * 0.2, index: index)
        }
        
        // Simulate structure corruption and rebuild
        rootContainer.rebuildBSPTreeStructure()
        
        // Verify structure is valid after rebuild
        XCTAssertTrue(rootContainer.validateBSPTreeStructure(), "BSP structure should be valid after rebuild")
        
        // Verify all windows are still present
        let allWindows = rootContainer.getAllWindows()
        XCTAssertEqual(allWindows.count, 4, "All windows should be preserved after rebuild")
    }
    
    func testOptimizeBSPCommand() {
        let workspace = Workspace.get(byName: WorkspaceName.parse("test"))
        let rootContainer = workspace.rootTilingContainer
        rootContainer.layout = .bsp
        
        // Add some windows
        let window1 = createTestWindow(id: 1)
        let window2 = createTestWindow(id: 2)
        
        window1.bind(to: rootContainer, adaptiveWeight: 0.7, index: 0)
        window2.bind(to: rootContainer, adaptiveWeight: 0.3, index: 1)
        
        // Create and run optimize command
        let args = OptimizeBSPCmdArgs(rawArgs: [])
        args.workspaceName = WorkspaceName.parse("test")
        
        let command = OptimizeBSPCommand(args: args)
        let env = CmdEnv()
        let io = CmdIo()
        
        let result = command.run(env, io)
        XCTAssertTrue(result, "Optimize BSP command should succeed")
        
        // Verify optimization was applied
        let totalWeight = rootContainer.children.map { $0.getWeight(rootContainer.orientation) }.reduce(0, +)
        XCTAssertEqual(totalWeight, 1.0, accuracy: 0.01, "Weights should be normalized after optimization")
    }
    
    // Helper method to create test windows
    private func createTestWindow(id: UInt32) -> Window {
        // This would need to be implemented based on your test infrastructure
        // For now, returning a mock implementation
        fatalError("createTestWindow needs to be implemented based on your test infrastructure")
    }
}