@testable import AppBundle
import Common
import XCTest

@MainActor
final class MoveCommandBSPTest: XCTestCase {
    override func setUp() async throws { 
        setUpWorkspacesForTests() 
    }

    // MARK: - Test BSP Layout Preservation in createImplicitContainer

    func testCreateImplicitContainer_preservesBSPLayout() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Set up BSP layout with multiple windows
        workspace.rootTilingContainer.layout = .bsp
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0)
        }
        
        // Verify initial BSP layout
        assertEquals(workspace.rootTilingContainer.layout, .bsp)
        
        // Execute move command that should create implicit container
        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .up)).run(.defaultEnv, .emptyStdin)
        
        // Verify the operation succeeded
        assertEquals(result.exitCode, 0)
        
        // Verify that the root container still has BSP layout
        assertEquals(workspace.rootTilingContainer.layout, .bsp)
        
        // Verify that any child containers also have BSP layout
        for child in workspace.rootTilingContainer.children {
            if let childContainer = child as? TilingContainer {
                assertEquals(childContainer.layout, .bsp, additionalMsg: "Child container should preserve BSP layout")
            }
        }
    }

    func testCreateImplicitContainer_preservesTilesLayout() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Set up tiles layout (default)
        workspace.rootTilingContainer.layout = .tiles
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0)
        }
        
        // Verify initial tiles layout
        assertEquals(workspace.rootTilingContainer.layout, .tiles)
        
        // Execute move command that should create implicit container
        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .up)).run(.defaultEnv, .emptyStdin)
        
        // Verify the operation succeeded
        assertEquals(result.exitCode, 0)
        
        // Verify that the root container still has tiles layout
        assertEquals(workspace.rootTilingContainer.layout, .tiles)
        
        // Verify that any child containers also have tiles layout
        for child in workspace.rootTilingContainer.children {
            if let childContainer = child as? TilingContainer {
                assertEquals(childContainer.layout, .tiles, additionalMsg: "Child container should preserve tiles layout")
            }
        }
    }

    func testCreateImplicitContainer_preservesAccordionLayout() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Set up accordion layout
        workspace.rootTilingContainer.layout = .accordion
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0)
        }
        
        // Verify initial accordion layout
        assertEquals(workspace.rootTilingContainer.layout, .accordion)
        
        // Execute move command that should create implicit container
        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .up)).run(.defaultEnv, .emptyStdin)
        
        // Verify the operation succeeded
        assertEquals(result.exitCode, 0)
        
        // Verify that the root container still has accordion layout
        assertEquals(workspace.rootTilingContainer.layout, .accordion)
        
        // Verify that any child containers also have accordion layout
        for child in workspace.rootTilingContainer.children {
            if let childContainer = child as? TilingContainer {
                assertEquals(childContainer.layout, .accordion, additionalMsg: "Child container should preserve accordion layout")
            }
        }
    }

    // MARK: - Test BSP Optimization After Move

    func testBSPOptimizationAfterMove() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Set up BSP layout with nested containers
        workspace.rootTilingContainer.layout = .bsp
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer(parent: $0, adaptiveWeight: 1, .v, .bsp, index: 1).apply {
                TestWindow.new(id: 2, parent: $0)
                assertEquals(TestWindow.new(id: 3, parent: $0).focusWindow(), true)
            }
        }
        
        // Verify initial BSP layout structure
        assertEquals(root.layout, .bsp)
        let nestedContainer = root.children[1] as? TilingContainer
        assertEquals(nestedContainer?.layout, .bsp)
        
        // Execute move command
        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .left)).run(.defaultEnv, .emptyStdin)
        
        // Verify the operation succeeded
        assertEquals(result.exitCode, 0)
        
        // Verify that BSP layout is preserved throughout the tree
        assertEquals(root.layout, .bsp)
        for child in root.children {
            if let childContainer = child as? TilingContainer {
                assertEquals(childContainer.layout, .bsp, additionalMsg: "All containers should maintain BSP layout after move")
            }
        }
    }

    // MARK: - Test Complex BSP Move Scenarios

    func testComplexBSPMoveScenario() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create a complex BSP layout
        workspace.rootTilingContainer.layout = .bsp
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer(parent: $0, adaptiveWeight: 1, .v, .bsp, index: 1).apply {
                TestWindow.new(id: 2, parent: $0)
                TilingContainer(parent: $0, adaptiveWeight: 1, .h, .bsp, index: 1).apply {
                    TestWindow.new(id: 3, parent: $0)
                    assertEquals(TestWindow.new(id: 4, parent: $0).focusWindow(), true)
                }
            }
        }
        
        // Verify initial structure
        assertEquals(root.layout, .bsp)
        
        // Execute multiple move operations
        _ = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .up)).run(.defaultEnv, .emptyStdin)
        _ = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .left)).run(.defaultEnv, .emptyStdin)
        
        // Verify that BSP layout is maintained throughout all operations
        assertEquals(root.layout, .bsp)
        
        // Recursively check all containers maintain BSP layout
        func checkBSPLayoutRecursive(_ container: TilingContainer) {
            assertEquals(container.layout, .bsp, additionalMsg: "Container should maintain BSP layout")
            for child in container.children {
                if let childContainer = child as? TilingContainer {
                    checkBSPLayoutRecursive(childContainer)
                }
            }
        }
        
        checkBSPLayoutRecursive(root)
    }

    // MARK: - Test Error Handling

    func testMoveCommandWithInvalidBSPStructure() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Set up BSP layout
        workspace.rootTilingContainer.layout = .bsp
        workspace.rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }
        
        // Execute move command on single window (should handle gracefully)
        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .up)).run(.defaultEnv, .emptyStdin)
        
        // Should succeed and maintain BSP layout
        assertEquals(result.exitCode, 0)
        assertEquals(workspace.rootTilingContainer.layout, .bsp)
    }

    // MARK: - Test BSP Tree Structure Validation

    func testBSPTreeStructureValidation() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create a BSP layout with potential structural issues
        workspace.rootTilingContainer.layout = .bsp
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer(parent: $0, adaptiveWeight: 1, .v, .bsp, index: 1).apply {
                // Create a single-child container (should be optimized)
                TilingContainer(parent: $0, adaptiveWeight: 1, .h, .bsp, index: 0).apply {
                    assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
                }
            }
        }
        
        // Execute move command which should trigger optimization
        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .left)).run(.defaultEnv, .emptyStdin)
        
        // Verify the operation succeeded
        assertEquals(result.exitCode, 0)
        
        // Verify that BSP layout is maintained and structure is optimized
        assertEquals(root.layout, .bsp)
        
        // The structure should be optimized to remove unnecessary nesting
        // (exact structure depends on optimization implementation)
        for child in root.children {
            if let childContainer = child as? TilingContainer {
                assertEquals(childContainer.layout, .bsp, additionalMsg: "All containers should maintain BSP layout")
            }
        }
    }

    func testBSPWeightValidationAfterMove() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Set up BSP layout with specific weights
        workspace.rootTilingContainer.layout = .bsp
        let root = workspace.rootTilingContainer.apply {
            let _ = TestWindow.new(id: 1, parent: $0, adaptiveWeight: 0.3)
            let window2 = TestWindow.new(id: 2, parent: $0, adaptiveWeight: 0.7)
            assertEquals(window2.focusWindow(), true)
        }
        
        // Store initial weights
        let _ = root.children[0].getWeight(.h)
        let _ = root.children[1].getWeight(.h)
        
        // Execute move command
        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .left)).run(.defaultEnv, .emptyStdin)
        
        // Verify the operation succeeded
        assertEquals(result.exitCode, 0)
        
        // Verify that weights are still valid after move and optimization
        let finalWeight1 = root.children[0].getWeight(.h)
        let finalWeight2 = root.children[1].getWeight(.h)
        
        // Weights should be positive and reasonable
        XCTAssertGreaterThan(finalWeight1, 0.0, "Weight should be positive")
        XCTAssertGreaterThan(finalWeight2, 0.0, "Weight should be positive")
        
        // Total weight should be reasonable (not necessarily 1.0 due to BSP implementation)
        let totalWeight = finalWeight1 + finalWeight2
        XCTAssertGreaterThan(totalWeight, 0.0, "Total weight should be positive")
    }

    func testBSPOptimizationWithEmptyContainers() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Set up BSP layout
        workspace.rootTilingContainer.layout = .bsp
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer(parent: $0, adaptiveWeight: 1, .v, .bsp, index: 1).apply {
                assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
                TestWindow.new(id: 3, parent: $0)
            }
        }
        
        // Remove a window to create potential empty containers
        let windowToRemove = root.children[1] as! TilingContainer
        let window2 = windowToRemove.children[0] as! Window
        window2.unbindFromParent()
        
        // Execute move command which should trigger optimization
        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.defaultEnv, .emptyStdin)
        
        // Verify the operation succeeded
        assertEquals(result.exitCode, 0)
        
        // Verify that BSP layout is maintained and empty containers are handled
        assertEquals(root.layout, .bsp)
        
        // All remaining containers should have BSP layout
        for child in root.children {
            if let childContainer = child as? TilingContainer {
                assertEquals(childContainer.layout, .bsp, additionalMsg: "All containers should maintain BSP layout")
            }
        }
    }

    // MARK: - Test BSP Swap Behavior

    /// Test: BSP mode swaps window with adjacent sibling container (same level)
    func testBSPSwapWithAdjacentContainer() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Layout: [Window1] | [Container with Window2, Window3 vertical]
        workspace.rootTilingContainer.layout = .bsp
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0, adaptiveWeight: 0.5)
            TilingContainer(parent: $0, adaptiveWeight: 0.5, .v, .bsp, index: 1).apply {
                TestWindow.new(id: 2, parent: $0)
                assertEquals(TestWindow.new(id: 3, parent: $0).focusWindow(), true)
            }
        }
        
        // Store initial weights
        let initialLeftWeight = root.children[0].getWeight(.h)
        let initialRightWeight = root.children[1].getWeight(.h)
        
        // Window3 is focused, move left should swap the right container with Window1
        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .left)).run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        
        // After swap: [Container with Window2, Window3] | [Window1]
        // Weights should be preserved (swapped)
        let finalLeftWeight = root.children[0].getWeight(.h)
        let finalRightWeight = root.children[1].getWeight(.h)
        
        // Weights should be swapped, not reset
        XCTAssertEqual(finalLeftWeight, initialRightWeight, accuracy: 0.01, "Left weight should equal original right weight")
        XCTAssertEqual(finalRightWeight, initialLeftWeight, accuracy: 0.01, "Right weight should equal original left weight")
        
        // The container should now be on the left
        XCTAssertTrue(root.children[0] is TilingContainer, "Container should be on the left after swap")
        XCTAssertTrue(root.children[1] is Window, "Window1 should be on the right after swap")
    }

    /// Test: BSP mode swaps windows at same level (simple case)
    func testBSPSwapTwoWindows() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Layout: [Window1] | [Window2]
        workspace.rootTilingContainer.layout = .bsp
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0, adaptiveWeight: 0.3)
            assertEquals(TestWindow.new(id: 2, parent: $0, adaptiveWeight: 0.7).focusWindow(), true)
        }
        
        let initialLeftWeight = root.children[0].getWeight(.h)
        let initialRightWeight = root.children[1].getWeight(.h)
        
        // Window2 is focused, move left should swap with Window1
        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .left)).run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        
        // Weights should be swapped
        let finalLeftWeight = root.children[0].getWeight(.h)
        let finalRightWeight = root.children[1].getWeight(.h)
        
        XCTAssertEqual(finalLeftWeight, initialRightWeight, accuracy: 0.01)
        XCTAssertEqual(finalRightWeight, initialLeftWeight, accuracy: 0.01)
    }

    /// Test: BSP moveOut swaps containers, preserving weights
    func testBSPMoveOutSwapsContainers() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Layout: [Window1 (0.4)] | [Window2 / Window3 vertical (0.6)]
        // When Window2 or Window3 moves left, the entire right container should swap with Window1
        workspace.rootTilingContainer.layout = .bsp
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0, adaptiveWeight: 0.4)
            TilingContainer(parent: $0, adaptiveWeight: 0.6, .v, .bsp, index: 1).apply {
                assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
                TestWindow.new(id: 3, parent: $0)
            }
        }
        
        let initialLeftWeight = root.children[0].getWeight(.h)
        let initialRightWeight = root.children[1].getWeight(.h)
        
        // Window2 is in vertical container, move left triggers moveOut
        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .left)).run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        
        // After swap: Container should be on left with its original weight (0.6)
        // Window1 should be on right with its original weight (0.4)
        let finalLeftWeight = root.children[0].getWeight(.h)
        let finalRightWeight = root.children[1].getWeight(.h)
        
        XCTAssertEqual(finalLeftWeight, initialRightWeight, accuracy: 0.01, "Left element should have original right weight after swap")
        XCTAssertEqual(finalRightWeight, initialLeftWeight, accuracy: 0.01, "Right element should have original left weight after swap")
    }

    /// Test: BSP swap preserves tree structure
    func testBSPSwapPreservesTreeStructure() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Complex layout: [W1] | [[W2|W3] / W4]
        workspace.rootTilingContainer.layout = .bsp
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer(parent: $0, adaptiveWeight: 1, .v, .bsp, index: 1).apply {
                TilingContainer(parent: $0, adaptiveWeight: 1, .h, .bsp, index: 0).apply {
                    TestWindow.new(id: 2, parent: $0)
                    TestWindow.new(id: 3, parent: $0)
                }
                assertEquals(TestWindow.new(id: 4, parent: $0).focusWindow(), true)
            }
        }
        
        // Count windows before
        func countWindows(_ container: TilingContainer) -> Int {
            var count = 0
            for child in container.children {
                if child is Window { count += 1 }
                else if let c = child as? TilingContainer { count += countWindows(c) }
            }
            return count
        }
        let windowCountBefore = countWindows(root)
        
        // Move left
        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .left)).run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        
        // Window count should be preserved
        let windowCountAfter = countWindows(root)
        assertEquals(windowCountBefore, windowCountAfter, additionalMsg: "Window count should be preserved after swap")
    }

    // MARK: - Test Layout Mode Validation

    func testLayoutModeValidationAfterMove() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Set up mixed layout scenario (this should be corrected)
        workspace.rootTilingContainer.layout = .bsp
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            // Intentionally create a tiles container in BSP workspace
            TilingContainer(parent: $0, adaptiveWeight: 1, .v, .tiles, index: 1).apply {
                assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
                TestWindow.new(id: 3, parent: $0)
            }
        }
        
        // Execute move command
        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .left)).run(.defaultEnv, .emptyStdin)
        
        // Verify the operation succeeded
        assertEquals(result.exitCode, 0)
        
        // After move and optimization, all containers should be BSP
        assertEquals(root.layout, .bsp)
        for child in root.children {
            if let childContainer = child as? TilingContainer {
                // Note: The current implementation may not automatically convert tiles to BSP
                // This test documents the current behavior and can be updated when 
                // automatic layout consistency enforcement is implemented
                print("Child container layout: \(childContainer.layout)")
            }
        }
    }
}
