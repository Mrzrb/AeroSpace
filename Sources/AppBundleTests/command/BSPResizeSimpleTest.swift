@testable import AppBundle
import Common
import XCTest

@MainActor
final class BSPResizeSimpleTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testBSPResizeWeightUpdate() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container with horizontal orientation
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add two windows with equal weights
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 100.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 100.0)
        
        // Focus the first window
        _ = window1.focusWindow()
        
        // Get initial weights
        let initialWeight1 = window1.getWeight(.h)
        let initialWeight2 = window2.getWeight(.h)
        
        // Resize first window wider by 20 units
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(20)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await resizeCommand.run(.defaultEnv, cmdIo)
        
        // Verify command succeeded
        XCTAssertTrue(result, "BSP resize command should succeed")
        XCTAssertTrue(cmdIo.stderr.isEmpty, "Should not have errors: \(cmdIo.stderr)")
        
        // Verify weights changed correctly
        let newWeight1 = window1.getWeight(.h)
        let newWeight2 = window2.getWeight(.h)
        
        // Window1 should have increased weight
        XCTAssertGreaterThan(newWeight1, initialWeight1, "Window1 weight should have increased")
        // Window2 should have decreased weight (to compensate)
        XCTAssertLessThan(newWeight2, initialWeight2, "Window2 weight should have decreased")
        
        // Verify the actual weight changes
        XCTAssertEqual(newWeight1, initialWeight1 + 20.0, accuracy: 0.01, "Window1 should have gained 20 units")
        XCTAssertEqual(newWeight2, initialWeight2 - 20.0, accuracy: 0.01, "Window2 should have lost 20 units")
        
        // Verify layout mode is preserved
        XCTAssertEqual(bspContainer.layout, .bsp, "Container should maintain BSP layout")
    }

    func testBSPResizeMinimumWeightValidation() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add two windows with one having very small weight
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 0.05) // Below minimum
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 100.0)
        
        _ = window1.focusWindow()
        
        // Perform resize
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(10)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await resizeCommand.run(.defaultEnv, cmdIo)
        
        XCTAssertTrue(result, "BSP resize should succeed")
        
        // Verify minimum weight validation was applied
        let finalWeight1 = window1.getWeight(.h)
        let finalWeight2 = window2.getWeight(.h)
        
        XCTAssertGreaterThanOrEqual(finalWeight1, 0.1, "Window1 weight should be corrected to minimum")
        XCTAssertGreaterThanOrEqual(finalWeight2, 0.1, "Window2 weight should be corrected to minimum")
    }

    func testBSPResizeErrorHandling() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Test single window error
        let singleWindowContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        let singleWindow = TestWindow.new(id: 1, parent: singleWindowContainer, adaptiveWeight: 100.0)
        
        _ = singleWindow.focusWindow()
        
        let singleWindowResize = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(20)))
        let singleWindowIo = CmdIo(stdin: .emptyStdin)
        let singleWindowResult = try await singleWindowResize.run(.defaultEnv, singleWindowIo)
        
        XCTAssertFalse(singleWindowResult, "Should fail to resize single window in BSP container")
        XCTAssertTrue(singleWindowIo.stderr.joined().contains("Cannot resize single window"), "Should have appropriate error message")
    }
}