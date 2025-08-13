@testable import AppBundle
import Common
import XCTest

@MainActor
final class ResizeCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParseCommand() {
        testParseCommandSucc("resize smart +10", ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(10)))
        testParseCommandSucc("resize smart -10", ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .subtract(10)))
        testParseCommandSucc("resize smart 10", ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .set(10)))

        testParseCommandSucc("resize smart-opposite +10", ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .add(10)))
        testParseCommandSucc("resize smart-opposite -10", ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .subtract(10)))
        testParseCommandSucc("resize smart-opposite 10", ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .set(10)))

        testParseCommandSucc("resize height 10", ResizeCmdArgs(rawArgs: [], dimension: .height, units: .set(10)))
        testParseCommandSucc("resize width 10", ResizeCmdArgs(rawArgs: [], dimension: .width, units: .set(10)))

        testParseCommandFail("resize s 10", msg: """
            ERROR: Can't parse 's'.
                   Possible values: (width|height|smart|smart-opposite)
            """)
        testParseCommandFail("resize smart foo", msg: "ERROR: <number> argument must be a number")
    }

    // MARK: - BSP Resize Tests

    func testBSPResizeHorizontalSplit() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container with horizontal orientation
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add two windows with equal weights
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 100.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 100.0)
        
        // Focus the first window
        assertEquals(window1.focusWindow(), true)
        
        // Get initial weights
        let initialWeight1 = window1.getWeight(.h)
        let initialWeight2 = window2.getWeight(.h)
        
        print("Initial weights: window1=\(initialWeight1), window2=\(initialWeight2)")
        
        // Resize first window wider by 20 units
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(20)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        assertEquals(resizeCommand.run(.defaultEnv, cmdIo), true)
        
        // Verify weights changed correctly (no normalization in BSP)
        let newWeight1 = window1.getWeight(.h)
        let newWeight2 = window2.getWeight(.h)
        
        print("New weights: window1=\(newWeight1), window2=\(newWeight2)")
        
        // Window1 should have increased weight
        XCTAssertGreaterThan(newWeight1, initialWeight1, "Window1 weight should have increased")
        // Window2 should have decreased weight (to compensate)
        XCTAssertLessThan(newWeight2, initialWeight2, "Window2 weight should have decreased")
        
        // Verify minimum weight validation (no weight should be below 0.1)
        XCTAssertGreaterThanOrEqual(newWeight1, 0.1, "Window1 weight should not be below minimum")
        XCTAssertGreaterThanOrEqual(newWeight2, 0.1, "Window2 weight should not be below minimum")
        
        // Verify the actual weight changes
        XCTAssertEqual(newWeight1, initialWeight1 + 20.0, accuracy: 0.01, "Window1 should have gained 20 units")
        XCTAssertEqual(newWeight2, initialWeight2 - 20.0, accuracy: 0.01, "Window2 should have lost 20 units")
    }

    func testBSPResizeVerticalSplit() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container with vertical orientation
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .v, .bsp, index: 0)
        
        // Add two windows with equal weights
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 1.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 1.0)
        
        // Focus the first window
        assertEquals(window1.focusWindow(), true)
        
        // Get initial weights
        let initialWeight1 = window1.getWeight(.v)
        let initialWeight2 = window2.getWeight(.v)
        
        // Resize first window taller by 30 units
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .height, units: .add(30)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        assertEquals(resizeCommand.run(.defaultEnv, cmdIo), true)
        
        // Verify weights changed correctly
        let newWeight1 = window1.getWeight(.v)
        let newWeight2 = window2.getWeight(.v)
        
        // Window1 should have increased weight
        XCTAssertGreaterThan(newWeight1, initialWeight1, "Window1 weight should have increased")
        // Window2 should have decreased weight
        XCTAssertLessThan(newWeight2, initialWeight2, "Window2 weight should have decreased")
        
        // Verify minimum weight validation
        XCTAssertGreaterThanOrEqual(newWeight1, 0.1, "Window1 weight should not be below minimum")
        XCTAssertGreaterThanOrEqual(newWeight2, 0.1, "Window2 weight should not be below minimum")
    }

    func testBSPResizeSmartDirection() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container with horizontal orientation
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add three windows
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 1.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 1.0)
        let window3 = TestWindow.new(id: 3, parent: bspContainer, adaptiveWeight: 1.0)
        
        // Focus the middle window
        assertEquals(window2.focusWindow(), true)
        
        // Get initial weights
        let initialWeight1 = window1.getWeight(.h)
        let initialWeight2 = window2.getWeight(.h)
        let initialWeight3 = window3.getWeight(.h)
        
        // Use smart resize to increase middle window
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(20)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        assertEquals(resizeCommand.run(.defaultEnv, cmdIo), true)
        
        // Verify weights changed correctly
        let newWeight1 = window1.getWeight(.h)
        let newWeight2 = window2.getWeight(.h)
        let newWeight3 = window3.getWeight(.h)
        
        // Middle window should have increased weight
        XCTAssertGreaterThan(newWeight2, initialWeight2, "Window2 weight should have increased")
        // Other windows should have decreased weight proportionally
        XCTAssertLessThan(newWeight1, initialWeight1, "Window1 weight should have decreased")
        XCTAssertLessThan(newWeight3, initialWeight3, "Window3 weight should have decreased")
        
        // All weights should be above minimum
        XCTAssertGreaterThanOrEqual(newWeight1, 0.1, "Window1 weight should not be below minimum")
        XCTAssertGreaterThanOrEqual(newWeight2, 0.1, "Window2 weight should not be below minimum")
        XCTAssertGreaterThanOrEqual(newWeight3, 0.1, "Window3 weight should not be below minimum")
    }

    func testBSPResizeWeightValidation() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add two windows with one having very small weight
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 0.05) // Below minimum
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 1.95)
        
        // Focus the first window
        assertEquals(window1.focusWindow(), true)
        
        // Try to resize (this should trigger weight validation)
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(10)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        assertEquals(resizeCommand.run(.defaultEnv, cmdIo), true)
        
        // Verify that minimum weight validation was applied
        let newWeight1 = window1.getWeight(.h)
        let newWeight2 = window2.getWeight(.h)
        
        XCTAssertGreaterThanOrEqual(newWeight1, 0.1, "Window1 weight should be at least minimum after validation")
        XCTAssertGreaterThanOrEqual(newWeight2, 0.1, "Window2 weight should be at least minimum after validation")
    }

    func testBSPResizeSetAbsoluteValue() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add two windows
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 1.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 1.0)
        
        // Focus the first window
        assertEquals(window1.focusWindow(), true)
        
        // Set absolute weight value
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .set(150)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        assertEquals(resizeCommand.run(.defaultEnv, cmdIo), true)
        
        // Verify the weight was set correctly
        let newWeight1 = window1.getWeight(.h)
        XCTAssertEqual(newWeight1, 150.0, accuracy: 0.01, "Window1 weight should be set to 150")
        
        // Verify minimum weight validation still applies
        let newWeight2 = window2.getWeight(.h)
        XCTAssertGreaterThanOrEqual(newWeight2, 0.1, "Window2 weight should not be below minimum")
    }

    func testBSPResizeSubtractValue() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .v, .bsp, index: 0)
        
        // Add two windows with reasonable initial weights
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 1.5)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 1.0)
        
        // Focus the first window
        assertEquals(window1.focusWindow(), true)
        
        // Get initial weight
        let initialWeight1 = window1.getWeight(.v)
        
        // Subtract from weight (reasonable amount)
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .height, units: .subtract(1)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        assertEquals(resizeCommand.run(.defaultEnv, cmdIo), true)
        
        // Verify the weight was reduced
        let newWeight1 = window1.getWeight(.v)
        XCTAssertLessThan(newWeight1, initialWeight1, "Window1 weight should have decreased")
        
        // Verify minimum weight validation
        XCTAssertGreaterThanOrEqual(newWeight1, 0.1, "Window1 weight should not be below minimum")
    }

    func testBSPResizePreservesLayoutMode() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add two windows
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 1.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 1.0)
        
        // Focus the first window
        assertEquals(window1.focusWindow(), true)
        
        // Verify initial layout is BSP
        XCTAssertEqual(bspContainer.layout, .bsp, "Container should start with BSP layout")
        
        // Perform resize operation
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(20)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        assertEquals(resizeCommand.run(.defaultEnv, cmdIo), true)
        
        // Verify layout mode is preserved
        XCTAssertEqual(bspContainer.layout, .bsp, "Container should maintain BSP layout after resize")
    }

    func testBSPResizeWithNestedContainers() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create root BSP container
        let rootContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Create nested BSP container
        let nestedContainer = TilingContainer(parent: rootContainer, adaptiveWeight: 1.0, .v, .bsp, index: 0)
        let window1 = TestWindow.new(id: 1, parent: nestedContainer, adaptiveWeight: 1.0)
        let window2 = TestWindow.new(id: 2, parent: nestedContainer, adaptiveWeight: 1.0)
        
        // Add another window to root container
        let window3 = TestWindow.new(id: 3, parent: rootContainer, adaptiveWeight: 1.0)
        
        // Focus window in nested container
        assertEquals(window1.focusWindow(), true)
        
        // Get initial weights
        let initialWeight1 = window1.getWeight(.v) // Vertical weight in nested container
        let initialWeight2 = window2.getWeight(.v)
        
        // Resize vertically (should affect nested container)
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .height, units: .add(30)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        assertEquals(resizeCommand.run(.defaultEnv, cmdIo), true)
        
        // Verify weights in nested container changed
        let newWeight1 = window1.getWeight(.v)
        let newWeight2 = window2.getWeight(.v)
        
        XCTAssertGreaterThan(newWeight1, initialWeight1, "Window1 weight should have increased")
        XCTAssertLessThan(newWeight2, initialWeight2, "Window2 weight should have decreased")
        
        // Verify both containers maintain BSP layout
        XCTAssertEqual(rootContainer.layout, .bsp, "Root container should maintain BSP layout")
        XCTAssertEqual(nestedContainer.layout, .bsp, "Nested container should maintain BSP layout")
    }

    func testBSPResizeTriggersLayoutUpdate() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add two windows with test rects
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 1.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 1.0)
        
        // Set initial test rects
        window1.setTestRect(Rect(topLeftX: 0, topLeftY: 0, width: 400, height: 300))
        window2.setTestRect(Rect(topLeftX: 400, topLeftY: 0, width: 400, height: 300))
        
        // Focus the first window
        assertEquals(window1.focusWindow(), true)
        
        // Perform resize operation
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(20)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        assertEquals(resizeCommand.run(.defaultEnv, cmdIo), true)
        
        // Give some time for async layout update to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify that layout update was triggered by checking if lastSetFrame was updated
        // This is a proxy for verifying that layoutWorkspace() was called
        XCTAssertNotNil(window1.lastSetFrame, "Window1 should have received layout update")
        XCTAssertNotNil(window2.lastSetFrame, "Window2 should have received layout update")
    }

    func testBSPResizeWithRealEnvironment() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add two windows
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 100.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 100.0)
        
        // Focus the first window
        assertEquals(window1.focusWindow(), true)
        
        // Create environment that simulates real usage
        let env = CmdEnv(windowId: window1.windowId, workspaceName: workspace.name, pwd: nil)
        let cmdIo = CmdIo(stdin: .emptyStdin)
        
        // Get initial weights
        let initialWeight1 = window1.getWeight(.h)
        let initialWeight2 = window2.getWeight(.h)
        
        print("Real environment test - Initial weights: window1=\(initialWeight1), window2=\(initialWeight2)")
        
        // Perform resize operation with real environment
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(20)))
        let result = resizeCommand.run(env, cmdIo)
        
        print("Resize command result: \(result)")
        print("Command output: \(cmdIo.stdout)")
        print("Command errors: \(cmdIo.stderr)")
        
        assertEquals(result, true)
        
        // Check final weights
        let finalWeight1 = window1.getWeight(.h)
        let finalWeight2 = window2.getWeight(.h)
        
        print("Final weights: window1=\(finalWeight1), window2=\(finalWeight2)")
        
        // Verify the changes
        XCTAssertEqual(finalWeight1, initialWeight1 + 20.0, accuracy: 0.01, "Window1 should have gained 20 units")
        XCTAssertEqual(finalWeight2, initialWeight2 - 20.0, accuracy: 0.01, "Window2 should have lost 20 units")
    }

    func testBSPResizeDiagnostics() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add two windows
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 100.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 100.0)
        
        // Focus the first window
        assertEquals(window1.focusWindow(), true)
        
        print("=== BSP Resize Diagnostics ===")
        print("Container layout: \(bspContainer.layout)")
        print("Container orientation: \(bspContainer.orientation)")
        print("Container children count: \(bspContainer.children.count)")
        print("Window1 parent layout: \((window1.parent as? TilingContainer)?.layout ?? .tiles)")
        print("Window1 parent orientation: \((window1.parent as? TilingContainer)?.orientation ?? .h)")
        
        // Test different resize scenarios
        let scenarios: [(String, ResizeCmdArgs.Dimension, ResizeCmdArgs.Units)] = [
            ("Width +20", .width, .add(20)),
            ("Height +20", .height, .add(20)),
            ("Smart +20", .smart, .add(20)),
            ("Smart-opposite +20", .smartOpposite, .add(20))
        ]
        
        for (name, dimension, units) in scenarios {
            print("\n--- Testing \(name) ---")
            
            let initialWeight1 = window1.getWeight(.h)
            let initialWeight2 = window2.getWeight(.h)
            let initialWeightV1 = window1.getWeight(.v)
            let initialWeightV2 = window2.getWeight(.v)
            
            let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: dimension, units: units))
            let cmdIo = CmdIo(stdin: .emptyStdin)
            let result = resizeCommand.run(.defaultEnv, cmdIo)
            
            print("Result: \(result)")
            print("Errors: \(cmdIo.stderr)")
            
            let finalWeight1 = window1.getWeight(.h)
            let finalWeight2 = window2.getWeight(.h)
            let finalWeightV1 = window1.getWeight(.v)
            let finalWeightV2 = window2.getWeight(.v)
            
            print("H weights: \(initialWeight1) -> \(finalWeight1), \(initialWeight2) -> \(finalWeight2)")
            print("V weights: \(initialWeightV1) -> \(finalWeightV1), \(initialWeightV2) -> \(finalWeightV2)")
            
            // Reset weights for next test
            window1.setWeight(.h, 100.0)
            window2.setWeight(.h, 100.0)
            window1.setWeight(.v, 100.0)
            window2.setWeight(.v, 100.0)
        }
        
        print("=== End Diagnostics ===")
    }

    func testBSPResizeVerticalContainer() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container with VERTICAL orientation
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .v, .bsp, index: 0)
        
        // Add two windows
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 100.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 100.0)
        
        // Focus the first window
        assertEquals(window1.focusWindow(), true)
        
        print("=== Vertical BSP Container Test ===")
        print("Container orientation: \(bspContainer.orientation)")
        
        // Test height resize (should work with vertical container)
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .height, units: .add(20)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        
        let initialWeight1 = window1.getWeight(.v)
        let initialWeight2 = window2.getWeight(.v)
        
        print("Initial V weights: window1=\(initialWeight1), window2=\(initialWeight2)")
        
        let result = resizeCommand.run(.defaultEnv, cmdIo)
        
        print("Height resize result: \(result)")
        print("Errors: \(cmdIo.stderr)")
        
        let finalWeight1 = window1.getWeight(.v)
        let finalWeight2 = window2.getWeight(.v)
        
        print("Final V weights: window1=\(finalWeight1), window2=\(finalWeight2)")
        
        // Should succeed with vertical container
        XCTAssertTrue(result, "Height resize should work with vertical BSP container")
        XCTAssertEqual(finalWeight1, initialWeight1 + 20.0, accuracy: 0.01, "Window1 should have gained 20 units")
        XCTAssertEqual(finalWeight2, initialWeight2 - 20.0, accuracy: 0.01, "Window2 should have lost 20 units")
    }

    func testBSPProportionalWeightCalculation() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create BSP container
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add two windows with different weights
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 150.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 50.0)
        
        print("=== BSP Proportional Weight Test ===")
        print("Initial weights: window1=\(window1.getWeight(.h)), window2=\(window2.getWeight(.h))")
        
        // Calculate expected proportions
        let totalWeight = window1.getWeight(.h) + window2.getWeight(.h)
        let window1Proportion = window1.getWeight(.h) / totalWeight
        let window2Proportion = window2.getWeight(.h) / totalWeight
        
        print("Expected proportions: window1=\(window1Proportion), window2=\(window2Proportion)")
        
        // Simulate layout calculation
        let containerWidth: CGFloat = 800
        let expectedWindow1Width = containerWidth * window1Proportion
        let expectedWindow2Width = containerWidth * window2Proportion
        
        print("Expected widths: window1=\(expectedWindow1Width), window2=\(expectedWindow2Width)")
        
        // Verify proportional calculations
        XCTAssertEqual(window1Proportion, 0.75, accuracy: 0.01, "Window1 should occupy 75% of space")
        XCTAssertEqual(window2Proportion, 0.25, accuracy: 0.01, "Window2 should occupy 25% of space")
        XCTAssertEqual(expectedWindow1Width, 600.0, accuracy: 0.01, "Window1 should be 600px wide")
        XCTAssertEqual(expectedWindow2Width, 200.0, accuracy: 0.01, "Window2 should be 200px wide")
        
        // Test weight adjustment (simulating mouse resize)
        // If user makes window1 50px wider, we need to adjust weights proportionally
        let pixelChange: CGFloat = 50.0
        let proportionalChange = pixelChange / containerWidth // 50/800 = 0.0625
        
        let newWindow1Proportion = window1Proportion + proportionalChange
        let newWindow2Proportion = window2Proportion - proportionalChange
        
        let newWindow1Weight = newWindow1Proportion * totalWeight
        let newWindow2Weight = newWindow2Proportion * totalWeight
        
        print("New proportions: window1=\(newWindow1Proportion), window2=\(newWindow2Proportion)")
        print("New weights: window1=\(newWindow1Weight), window2=\(newWindow2Weight)")
        
        // Apply the new weights
        window1.setWeight(.h, newWindow1Weight)
        window2.setWeight(.h, newWindow2Weight)
        
        // Verify the changes
        XCTAssertEqual(window1.getWeight(.h), newWindow1Weight, accuracy: 0.01, "Window1 weight should be updated")
        XCTAssertEqual(window2.getWeight(.h), newWindow2Weight, accuracy: 0.01, "Window2 weight should be updated")
        
        // Verify new proportions work correctly
        let newTotalWeight = window1.getWeight(.h) + window2.getWeight(.h)
        let finalWindow1Proportion = window1.getWeight(.h) / newTotalWeight
        let finalWindow2Proportion = window2.getWeight(.h) / newTotalWeight
        
        print("Final proportions: window1=\(finalWindow1Proportion), window2=\(finalWindow2Proportion)")
        
        XCTAssertEqual(finalWindow1Proportion, newWindow1Proportion, accuracy: 0.01, "Window1 proportion should match expected")
        XCTAssertEqual(finalWindow2Proportion, newWindow2Proportion, accuracy: 0.01, "Window2 proportion should match expected")
    }
}
