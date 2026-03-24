@testable import AppBundle
import Common
import XCTest

/// Tests for BSP resize weight behavior
/// Issue: resize with small values (e.g., 5) causes dramatic weight changes
@MainActor
final class BSPResizeWeightTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    /// Test that resize with value 50 produces reasonable weight changes
    func testBSPResizeWithValue50() async throws {
        let workspace = Workspace.get(byName: name)
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Create two windows with equal weights (100 each)
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 100.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 100.0)
        
        _ = window1.focusWindow()
        
        let initialWeight1 = window1.getWeight(.h)
        let initialWeight2 = window2.getWeight(.h)
        
        // Resize with +50 (recommended value)
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(50)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await resizeCommand.run(.defaultEnv, cmdIo)
        
        XCTAssertTrue(result, "Resize should succeed")
        
        let newWeight1 = window1.getWeight(.h)
        let newWeight2 = window2.getWeight(.h)
        
        // Calculate the change ratio
        let changeRatio = (newWeight1 - initialWeight1) / initialWeight1
        
        print("Initial: w1=\(initialWeight1), w2=\(initialWeight2)")
        print("Final: w1=\(newWeight1), w2=\(newWeight2)")
        print("Change ratio: \(changeRatio * 100)%")
        
        // With value 50 and initial weight 100, change should be ~50%
        XCTAssertEqual(newWeight1, 150.0, accuracy: 1.0, "Window1 should be 150 after +50")
        XCTAssertEqual(newWeight2, 50.0, accuracy: 1.0, "Window2 should be 50 after -50")
    }

    /// Test that resize with small value (5) on small weights causes dramatic changes
    /// This demonstrates the bug when using percentage-like values
    func testBSPResizeWithSmallValueOnSmallWeight() async throws {
        let workspace = Workspace.get(byName: name)
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Simulate the problematic scenario: weights around 5.5 (as seen in logs)
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 5.5)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 0.1)
        
        _ = window1.focusWindow()
        
        let initialWeight1 = window1.getWeight(.h)
        
        // Resize with -5 (the problematic value from config)
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .subtract(5)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await resizeCommand.run(.defaultEnv, cmdIo)
        
        XCTAssertTrue(result, "Resize should succeed")
        
        let newWeight1 = window1.getWeight(.h)
        
        print("Initial weight1: \(initialWeight1)")
        print("Final weight1: \(newWeight1)")
        print("Change: \(initialWeight1 - newWeight1)")
        
        // This demonstrates the bug: 5.5 - 5.0 = 0.5 (91% reduction!)
        // The weight drops from 5.5 to 0.5, which is a dramatic change
        let changePercent = (initialWeight1 - newWeight1) / initialWeight1 * 100
        print("Change percent: \(changePercent)%")
        
        // Document the current behavior (this is the bug)
        XCTAssertEqual(newWeight1, 0.5, accuracy: 0.1, "Weight drops dramatically from 5.5 to 0.5")
        XCTAssertGreaterThan(changePercent, 80, "Change is more than 80% - this is the bug!")
    }

    /// Test resize behavior with normalized weights (1.0 based)
    func testBSPResizeWithNormalizedWeights() async throws {
        let workspace = Workspace.get(byName: name)
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Use normalized weights (1.0 each)
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 1.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 1.0)
        
        _ = window1.focusWindow()
        
        let initialWeight1 = window1.getWeight(.h)
        
        // Resize with +50 on weight 1.0
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(50)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await resizeCommand.run(.defaultEnv, cmdIo)
        
        XCTAssertTrue(result, "Resize should succeed")
        
        let newWeight1 = window1.getWeight(.h)
        
        print("Initial weight1: \(initialWeight1)")
        print("Final weight1: \(newWeight1)")
        
        // With initial weight 1.0 and +50, new weight should be 51.0
        XCTAssertEqual(newWeight1, 51.0, accuracy: 0.1, "Weight should be 51.0 after +50")
    }

    /// Test that minimum weight (0.1) is enforced
    func testBSPResizeMinimumWeightEnforced() async throws {
        let workspace = Workspace.get(byName: name)
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 100.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 100.0)
        
        _ = window1.focusWindow()
        
        // Try to resize by a huge amount that would make window2 negative
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(200)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await resizeCommand.run(.defaultEnv, cmdIo)
        
        XCTAssertTrue(result, "Resize should succeed")
        
        let newWeight2 = window2.getWeight(.h)
        
        print("Final weight2: \(newWeight2)")
        
        // Weight should not go below minimum (0.1)
        XCTAssertGreaterThanOrEqual(newWeight2, 0.1, "Weight should not go below 0.1")
    }

    /// Test multiple consecutive resizes
    func testBSPResizeMultipleConsecutive() async throws {
        let workspace = Workspace.get(byName: name)
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 100.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 100.0)
        
        _ = window1.focusWindow()
        
        // Perform 5 consecutive resizes of +50 each
        for i in 1...5 {
            let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(50)))
            let cmdIo = CmdIo(stdin: .emptyStdin)
            let result = try await resizeCommand.run(.defaultEnv, cmdIo)
            
            XCTAssertTrue(result, "Resize \(i) should succeed")
            
            let w1 = window1.getWeight(.h)
            let w2 = window2.getWeight(.h)
            print("After resize \(i): w1=\(w1), w2=\(w2)")
        }
        
        let finalWeight1 = window1.getWeight(.h)
        let finalWeight2 = window2.getWeight(.h)
        
        // After 5 resizes of +50, window1 should have gained 250 total
        // Initial: 100, Final: 350
        XCTAssertEqual(finalWeight1, 350.0, accuracy: 5.0, "Window1 should be ~350 after 5x +50")
        
        // Window2 should have lost 250 total, but minimum is 0.1
        // Initial: 100, Expected: -150 -> clamped to 0.1
        XCTAssertGreaterThanOrEqual(finalWeight2, 0.1, "Window2 should be at minimum")
    }

    /// Test resize in vertical orientation
    func testBSPResizeVerticalOrientation() async throws {
        let workspace = Workspace.get(byName: name)
        let bspContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .v, .bsp, index: 0)
        
        let window1 = TestWindow.new(id: 1, parent: bspContainer, adaptiveWeight: 100.0)
        let window2 = TestWindow.new(id: 2, parent: bspContainer, adaptiveWeight: 100.0)
        
        _ = window1.focusWindow()
        
        // Resize height in vertical container
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .height, units: .add(50)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await resizeCommand.run(.defaultEnv, cmdIo)
        
        XCTAssertTrue(result, "Resize should succeed")
        
        let newWeight1 = window1.getWeight(.v)
        let newWeight2 = window2.getWeight(.v)
        
        print("Final: w1=\(newWeight1), w2=\(newWeight2)")
        
        XCTAssertEqual(newWeight1, 150.0, accuracy: 1.0, "Window1 should be 150 after +50")
        XCTAssertEqual(newWeight2, 50.0, accuracy: 1.0, "Window2 should be 50 after -50")
    }
}
