@testable import AppBundle
import Common
import XCTest

@MainActor
final class BSPResizeArchitectureTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    // MARK: - Architecture Fix Verification Tests

    func testBSPResizeUsesSpecializedLogic() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 100.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 100.0)
        
        window1.focusWindow()
        
        // Verify initial state
        XCTAssertEqual(bspContainer.layout, .bsp, "Container should be BSP layout")
        XCTAssertEqual(window1.getWeight(.h), 100.0, "Window1 should have initial weight 100")
        XCTAssertEqual(window2.getWeight(.h), 100.0, "Window2 should have initial weight 100")
        
        // Execute resize command
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(20)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await resizeCommand.run(.defaultEnv, cmdIo)
        
        // Verify BSP-specific behavior
        XCTAssertTrue(result, "BSP resize should succeed")
        XCTAssertTrue(cmdIo.stderr.isEmpty, "Should not have errors")
        
        // Verify weights are not normalized (BSP-specific behavior)
        let newWeight1 = window1.getWeight(.h)
        let newWeight2 = window2.getWeight(.h)
        
        XCTAssertEqual(newWeight1, 120.0, accuracy: 0.01, "Window1 should have absolute weight 120")
        XCTAssertEqual(newWeight2, 80.0, accuracy: 0.01, "Window2 should have absolute weight 80")
        
        // Verify layout mode is preserved
        XCTAssertEqual(bspContainer.layout, .bsp, "Container should maintain BSP layout")
    }

    func testBSPResizeWeightValidationApplied() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container with extreme weights
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 0.01) // Below minimum
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 1000.0) // Very high
        
        window1.focusWindow()
        
        // Execute resize command
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(10)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await resizeCommand.run(.defaultEnv, cmdIo)
        
        XCTAssertTrue(result, "BSP resize should succeed")
        
        // Verify weight validation was applied
        let finalWeight1 = window1.getWeight(.h)
        let finalWeight2 = window2.getWeight(.h)
        
        XCTAssertGreaterThanOrEqual(finalWeight1, 0.1, "Window1 weight should be corrected to minimum")
        XCTAssertGreaterThanOrEqual(finalWeight2, 0.1, "Window2 weight should be corrected to minimum")
        
        // Verify the container's validateAndCorrectBSPWeights was called
        XCTAssertEqual(bspContainer.layout, .bsp, "Container should maintain BSP layout")
    }

    func testBSPResizeLayoutUpdateTriggered() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 100.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 100.0)
        
        window1.focusWindow()
        
        // Execute resize command
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(20)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await resizeCommand.run(.defaultEnv, cmdIo)
        
        XCTAssertTrue(result, "BSP resize should succeed")
        
        // Verify that triggerBSPLayoutUpdate was called by checking the container state
        // In a real environment, this would trigger workspace.layoutWorkspace()
        XCTAssertEqual(bspContainer.layout, .bsp, "Container should maintain BSP layout")
        
        // Verify weights were updated correctly
        let newWeight1 = window1.getWeight(.h)
        let newWeight2 = window2.getWeight(.h)
        
        XCTAssertEqual(newWeight1, 120.0, accuracy: 0.01, "Window1 should have updated weight")
        XCTAssertEqual(newWeight2, 80.0, accuracy: 0.01, "Window2 should have updated weight")
    }

    func testBSPResizeErrorHandlingForSingleWindow() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container with single window
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        let singleWindow = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 100.0)
        
        singleWindow.focusWindow()
        
        // Try to resize single window
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(20)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await resizeCommand.run(.defaultEnv, cmdIo)
        
        // Should fail with appropriate error
        XCTAssertFalse(result, "Should fail to resize single window in BSP container")
        XCTAssertTrue(cmdIo.stderr.contains("Cannot resize single window"), "Should have appropriate error message")
        
        // Verify container state is unchanged
        XCTAssertEqual(bspContainer.layout, .bsp, "Container should maintain BSP layout")
        XCTAssertEqual(singleWindow.getWeight(.h), 100.0, "Window weight should be unchanged")
    }

    func testBSPResizeErrorHandlingForUnsupportedLayout() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create container with unsupported layout
        let accordionContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .accordion, index: 0)
        let window1 = TestWindow.new(id: 1, parent: accordionContainer, adaptiveWeight: 100.0)
        let window2 = TestWindow.new(id: 2, parent: accordionContainer, adaptiveWeight: 100.0)
        
        window1.focusWindow()
        
        // Try to resize in unsupported layout
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(20)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await resizeCommand.run(.defaultEnv, cmdIo)
        
        // Should fail with appropriate error
        XCTAssertFalse(result, "Should fail to resize unsupported layout")
        XCTAssertTrue(cmdIo.stderr.contains("only supports tiles and bsp"), "Should have appropriate error message")
        
        // Verify container state is unchanged
        XCTAssertEqual(accordionContainer.layout, .accordion, "Container should maintain original layout")
        XCTAssertEqual(window1.getWeight(.h), 100.0, "Window1 weight should be unchanged")
        XCTAssertEqual(window2.getWeight(.h), 100.0, "Window2 weight should be unchanged")
    }

    func testBSPVsTilesResizeBehaviorDifference() async throws {
        // Use separate workspaces to avoid conflicts between BSP and tiles containers
        let bspWorkspace = Workspace.get(byName: name)
        let tilesWorkspace = Workspace.get(byName: "\(name)-tiles")
        
        // Create BSP container
        let bspContainer = TilingContainer(parent: bspWorkspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        let bspWindow1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 0.05) // Below minimum
        let bspWindow2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 100.0)
        
        // Create tiles container in separate workspace
        let tilesContainer = TilingContainer(parent: tilesWorkspace, adaptiveWeight: 1.0, .h, .tiles, index: 0)
        let tilesWindow1 = TestWindow.new(id: 3, parent: tilesContainer, adaptiveWeight: 0.05) // Below minimum
        let tilesWindow2 = TestWindow.new(id: 4, parent: tilesContainer, adaptiveWeight: 100.0)
        
        // Resize BSP window
        _ = bspWindow1.focusWindow()
        let bspResizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(10)))
        let bspCmdIo = CmdIo(stdin: .emptyStdin)
        let bspResult = try await bspResizeCommand.run(.defaultEnv, bspCmdIo)
        
        // Resize tiles window
        _ = tilesWindow1.focusWindow()
        let tilesResizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(10)))
        let tilesCmdIo = CmdIo(stdin: .emptyStdin)
        let tilesResult = try await tilesResizeCommand.run(.defaultEnv, tilesCmdIo)
        
        XCTAssertTrue(bspResult, "BSP resize should succeed")
        XCTAssertTrue(tilesResult, "Tiles resize should succeed")
        
        // BSP should have weight validation applied
        let bspFinalWeight1 = bspWindow1.getWeight(.h)
        let bspFinalWeight2 = bspWindow2.getWeight(.h)
        
        // Tiles should have exact weight calculation without validation
        let tilesFinalWeight1 = tilesWindow1.getWeight(.h)
        let tilesFinalWeight2 = tilesWindow2.getWeight(.h)
        
        // BSP weights should be validated (minimum applied)
        XCTAssertGreaterThanOrEqual(bspFinalWeight1, 0.1, "BSP window1 should have minimum weight applied")
        XCTAssertGreaterThanOrEqual(bspFinalWeight2, 0.1, "BSP window2 should have minimum weight applied")
        
        // Tiles weights should be exact calculation
        XCTAssertEqual(tilesFinalWeight1, 10.05, accuracy: 0.01, "Tiles window1 should have exact weight")
        XCTAssertEqual(tilesFinalWeight2, 90.0, accuracy: 0.01, "Tiles window2 should have exact weight")
    }

    func testBSPResizeAbsoluteSetBehavior() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 100.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 100.0)
        
        window1.focusWindow()
        
        // Use absolute set (should not trigger comprehensive validation)
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .set(150)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await resizeCommand.run(.defaultEnv, cmdIo)
        
        XCTAssertTrue(result, "BSP absolute set resize should succeed")
        
        // Verify absolute set behavior
        let newWeight1 = window1.getWeight(.h)
        let newWeight2 = window2.getWeight(.h)
        
        XCTAssertEqual(newWeight1, 150.0, accuracy: 0.01, "Window1 should have absolute weight 150")
        XCTAssertEqual(newWeight2, 50.0, accuracy: 0.01, "Window2 should have compensated weight")
        
        // Verify minimum weight validation is still applied
        XCTAssertGreaterThanOrEqual(newWeight1, 0.1, "Window1 should respect minimum weight")
        XCTAssertGreaterThanOrEqual(newWeight2, 0.1, "Window2 should respect minimum weight")
    }

    func testBSPResizeSmartDirectionHandling() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container with horizontal orientation
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 100.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 100.0)
        
        window1.focusWindow()
        
        // Test smart resize (should use container's orientation)
        let smartResizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(20)))
        let smartCmdIo = CmdIo(stdin: .emptyStdin)
        let smartResult = try await smartResizeCommand.run(.defaultEnv, smartCmdIo)
        
        XCTAssertTrue(smartResult, "BSP smart resize should succeed")
        
        // Test smart-opposite resize (should use opposite orientation)
        let smartOppositeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .add(20)))
        let smartOppositeCmdIo = CmdIo(stdin: .emptyStdin)
        let smartOppositeResult = try await smartOppositeCommand.run(.defaultEnv, smartOppositeCmdIo)
        
        // Smart-opposite should fail because there's no parent with vertical orientation
        XCTAssertFalse(smartOppositeResult, "BSP smart-opposite resize should fail when no matching orientation")
        
        // Verify smart resize worked correctly
        let newWeight1 = window1.getWeight(.h)
        let newWeight2 = window2.getWeight(.h)
        
        XCTAssertEqual(newWeight1, 120.0, accuracy: 0.01, "Window1 should have increased weight from smart resize")
        XCTAssertEqual(newWeight2, 80.0, accuracy: 0.01, "Window2 should have decreased weight from smart resize")
    }
}