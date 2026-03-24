@testable import AppBundle
import Common
import XCTest

@MainActor
final class BSPResizeFinalTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    /// Test that verifies the complete BSP resize fix
    func testBSPResizeCompleteFix() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container with horizontal orientation
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add three windows to test complex scenarios
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 100.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 100.0)
        let window3 = TestWindow.new(id: 3, parent: bspContainer, adaptiveWeight: 100.0)
        
        // Focus the middle window
        _ = window2.focusWindow()
        
        // Get initial weights
        let initialWeight1 = window1.getWeight(.h)
        let initialWeight2 = window2.getWeight(.h)
        let initialWeight3 = window3.getWeight(.h)
        
        print("Initial weights: w1=\(initialWeight1), w2=\(initialWeight2), w3=\(initialWeight3)")
        
        // Resize middle window wider by 30 units
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(30)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await resizeCommand.run(.defaultEnv, cmdIo)
        
        // Verify command succeeded
        XCTAssertTrue(result, "BSP resize command should succeed")
        XCTAssertTrue(cmdIo.stderr.isEmpty, "Should not have errors: \(cmdIo.stderr)")
        
        // Verify weights changed correctly
        let newWeight1 = window1.getWeight(.h)
        let newWeight2 = window2.getWeight(.h)
        let newWeight3 = window3.getWeight(.h)
        
        print("Final weights: w1=\(newWeight1), w2=\(newWeight2), w3=\(newWeight3)")
        
        // Window2 should have increased weight
        XCTAssertGreaterThan(newWeight2, initialWeight2, "Window2 weight should have increased")
        
        // Other windows should have decreased weight proportionally
        XCTAssertLessThan(newWeight1, initialWeight1, "Window1 weight should have decreased")
        XCTAssertLessThan(newWeight3, initialWeight3, "Window3 weight should have decreased")
        
        // Verify the actual weight changes (30 units distributed among 2 other windows = 15 each)
        XCTAssertEqual(newWeight2, initialWeight2 + 30.0, accuracy: 0.01, "Window2 should have gained 30 units")
        XCTAssertEqual(newWeight1, initialWeight1 - 15.0, accuracy: 0.01, "Window1 should have lost 15 units")
        XCTAssertEqual(newWeight3, initialWeight3 - 15.0, accuracy: 0.01, "Window3 should have lost 15 units")
        
        // Verify layout mode is preserved
        XCTAssertEqual(bspContainer.layout, .bsp, "Container should maintain BSP layout")
        
        // Verify all weights are above minimum
        XCTAssertGreaterThanOrEqual(newWeight1, 0.1, "Window1 weight should be above minimum")
        XCTAssertGreaterThanOrEqual(newWeight2, 0.1, "Window2 weight should be above minimum")
        XCTAssertGreaterThanOrEqual(newWeight3, 0.1, "Window3 weight should be above minimum")
    }

    /// Test that BSP resize works with different dimensions
    func testBSPResizeDifferentDimensions() async throws {
        // Use separate workspaces to avoid conflicts between different BSP containers
        let hWorkspace = Workspace.get(byName: name)
        let vWorkspace = Workspace.get(byName: "\(name)-vertical")
        
        // Test horizontal resize
        let hContainer = TilingContainer(parent: hWorkspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        let hWindow1 = TestWindow.new(id: 1, parent: hContainer, adaptiveWeight: 100.0)
        let hWindow2 = TestWindow.new(id: 2, parent: hContainer, adaptiveWeight: 100.0)
        
        _ = hWindow1.focusWindow()
        
        let hResizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(20)))
        let hCmdIo = CmdIo(stdin: .emptyStdin)
        let hResult = try await hResizeCommand.run(.defaultEnv, hCmdIo)
        
        XCTAssertTrue(hResult, "Horizontal BSP resize should succeed")
        // With new BSP logic: window1 gains 20, window2 loses 20
        XCTAssertEqual(hWindow1.getWeight(.h), 120.0, accuracy: 0.01, "Window1 should gain 20 units")
        XCTAssertEqual(hWindow2.getWeight(.h), 80.0, accuracy: 0.01, "Window2 should lose 20 units")
        
        // Test vertical resize in separate workspace
        let vContainer = TilingContainer(parent: vWorkspace, adaptiveWeight: 1.0, .v, .bsp, index: 0)
        let vWindow1 = TestWindow.new(id: 3, parent: vContainer, adaptiveWeight: 100.0)
        let vWindow2 = TestWindow.new(id: 4, parent: vContainer, adaptiveWeight: 100.0)
        
        _ = vWindow1.focusWindow()
        
        let vResizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .height, units: .add(25)))
        let vCmdIo = CmdIo(stdin: .emptyStdin)
        let vResult = try await vResizeCommand.run(.defaultEnv, vCmdIo)
        
        XCTAssertTrue(vResult, "Vertical BSP resize should succeed")
        // With new BSP logic: vWindow1 gains 25, vWindow2 loses 25
        XCTAssertEqual(vWindow1.getWeight(.v), 125.0, accuracy: 0.01, "VWindow1 should gain 25 units")
        XCTAssertEqual(vWindow2.getWeight(.v), 75.0, accuracy: 0.01, "VWindow2 should lose 25 units")
    }

    /// Test that smart resize works in BSP mode
    func testBSPSmartResize() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container with horizontal orientation
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 100.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 100.0)
        
        _ = window1.focusWindow()
        
        // Smart resize should use the container's orientation (horizontal)
        let smartResizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(15)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await smartResizeCommand.run(.defaultEnv, cmdIo)
        
        XCTAssertTrue(result, "Smart BSP resize should succeed")
        XCTAssertEqual(window1.getWeight(.h), 115.0, accuracy: 0.01, "Smart resize should work with container orientation")
        XCTAssertEqual(window2.getWeight(.h), 85.0, accuracy: 0.01, "Other window should be adjusted")
    }

    /// Test that BSP resize handles edge cases correctly
    func testBSPResizeEdgeCases() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Test with very small weights
        let smallWeightContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        let smallWindow1 = TestWindow.new(id: 1, parent: smallWeightContainer, adaptiveWeight: 0.01)
        let smallWindow2 = TestWindow.new(id: 2, parent: smallWeightContainer, adaptiveWeight: 0.02)
        
        _ = smallWindow1.focusWindow()
        
        let smallResizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(1)))
        let smallCmdIo = CmdIo(stdin: .emptyStdin)
        let smallResult = try await smallResizeCommand.run(.defaultEnv, smallCmdIo)
        
        XCTAssertTrue(smallResult, "BSP resize with small weights should succeed")
        
        // Verify minimum weight validation was applied
        let finalSmallWeight1 = smallWindow1.getWeight(.h)
        let finalSmallWeight2 = smallWindow2.getWeight(.h)
        
        XCTAssertGreaterThanOrEqual(finalSmallWeight1, 0.1, "Small weight should be corrected to minimum")
        XCTAssertGreaterThanOrEqual(finalSmallWeight2, 0.1, "Small weight should be corrected to minimum")
    }
}