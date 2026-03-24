@testable import AppBundle
import Common
import XCTest

/// Diagnostic tests to understand BSP resize behavior
@MainActor
final class BSPResizeDiagnosticTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    /// Test: What happens when we resize multiple times with value 50?
    func testResizeMultipleTimes_WeightDrift() async throws {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 1.0)
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 1.0)
        
        _ = window1.focusWindow()
        
        print("\n=== Initial State ===")
        print("w1: \(window1.getWeight(.h)), w2: \(window2.getWeight(.h))")
        
        // Resize 10 times with +50, then 10 times with -50
        print("\n=== Resizing +50 ten times ===")
        for i in 1...10 {
            let cmd = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(50)))
            _ = try await cmd.run(.defaultEnv, CmdIo(stdin: .emptyStdin))
            print("After +50 #\(i): w1=\(window1.getWeight(.h)), w2=\(window2.getWeight(.h))")
        }
        
        print("\n=== Resizing -50 ten times ===")
        for i in 1...10 {
            let cmd = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .subtract(50)))
            _ = try await cmd.run(.defaultEnv, CmdIo(stdin: .emptyStdin))
            print("After -50 #\(i): w1=\(window1.getWeight(.h)), w2=\(window2.getWeight(.h))")
        }
        
        let finalW1 = window1.getWeight(.h)
        let finalW2 = window2.getWeight(.h)
        
        print("\n=== Final State ===")
        print("w1: \(finalW1), w2: \(finalW2)")
        print("Expected: w1=1.0, w2=1.0 (back to initial)")
        
        // After +50 x10 then -50 x10, should return to original
        // But due to minimum weight clamping, this won't happen
        XCTAssertNotEqual(finalW1, 1.0, "Weight drift occurs due to minimum clamping")
    }

    /// Test: The core issue - small config values on drifted weights
    func testSmallConfigValue_OnDriftedWeight() async throws {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Start with normalized weights
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 1.0)
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 1.0)
        
        _ = window1.focusWindow()
        
        print("\n=== Simulating weight drift ===")
        
        // Simulate drift: resize +50 a few times
        for _ in 1...3 {
            let cmd = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(50)))
            _ = try await cmd.run(.defaultEnv, CmdIo(stdin: .emptyStdin))
        }
        
        let driftedW1 = window1.getWeight(.h)
        let driftedW2 = window2.getWeight(.h)
        print("After drift: w1=\(driftedW1), w2=\(driftedW2)")
        
        // Now user uses config value 5 (thinking it's 5%)
        print("\n=== User tries resize -5 (thinking it's 5%) ===")
        let smallResize = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .subtract(5)))
        _ = try await smallResize.run(.defaultEnv, CmdIo(stdin: .emptyStdin))
        
        let afterSmallResize = window1.getWeight(.h)
        let changePercent = (driftedW1 - afterSmallResize) / driftedW1 * 100
        
        print("After -5: w1=\(afterSmallResize)")
        print("Actual change: \(changePercent)%")
        
        // The change should be ~5% but it's actually much less because weight is large
        // OR if weight drifted to small value, change would be huge
        print("\n=== Analysis ===")
        print("If weight=151, then -5 is only \(5.0/151.0*100)% change")
        print("If weight=5.5, then -5 is \(5.0/5.5*100)% change (90%!)")
    }

    /// Test: What the user actually wants - percentage-based resize
    func testPercentageBasedResize_WhatUserWants() async throws {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Test with different initial weights
        let testCases: [(CGFloat, CGFloat)] = [
            (1.0, 1.0),      // Normalized
            (100.0, 100.0),  // Default
            (5.5, 0.1),      // Drifted (problematic)
            (151.0, 0.1),    // Heavily drifted
        ]
        
        print("\n=== Percentage-based resize simulation ===")
        print("User wants: resize -5 means 'shrink by 5%'\n")
        
        for (w1Init, w2Init) in testCases {
            // Reset container
            for child in container.children {
                child.unbindFromParent()
            }
            
            let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: w1Init)
            let _ = TestWindow.new(id: 2, parent: container, adaptiveWeight: w2Init)
            
            _ = window1.focusWindow()
            
            let currentWeight = window1.getWeight(.h)
            
            // Current behavior: absolute
            let absoluteDiff: CGFloat = -5.0
            let absoluteNewWeight = currentWeight + absoluteDiff
            let absoluteChangePercent = abs(absoluteDiff / currentWeight * 100)
            
            // Desired behavior: percentage
            let percentageDiff = currentWeight * (-5.0 / 100.0)  // -5%
            let percentageNewWeight = currentWeight + percentageDiff
            
            print("Initial: w1=\(w1Init), w2=\(w2Init)")
            print("  Current (absolute -5): \(currentWeight) → \(max(0.1, absoluteNewWeight)) (\(String(format: "%.1f", absoluteChangePercent))% change)")
            print("  Desired (percent -5%): \(currentWeight) → \(percentageNewWeight) (5% change)")
            print("")
        }
    }

    /// Test: Proposed fix - percentage-based calculation
    func testProposedFix_PercentageBased() async throws {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Test with problematic weights
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 5.5)
        let _ = TestWindow.new(id: 2, parent: container, adaptiveWeight: 0.1)
        
        _ = window1.focusWindow()
        
        let initialWeight = window1.getWeight(.h)
        
        // Simulate percentage-based resize
        let percentValue: CGFloat = 5.0  // User wants 5%
        let percentageDiff = initialWeight * (percentValue / 100.0)
        
        print("\n=== Proposed Fix Test ===")
        print("Initial weight: \(initialWeight)")
        print("User input: -5 (meaning -5%)")
        print("Calculated diff: \(percentageDiff)")
        print("New weight would be: \(initialWeight - percentageDiff)")
        print("Change: exactly 5%")
        
        // Verify the math
        let expectedNewWeight = initialWeight * 0.95  // -5%
        let calculatedNewWeight = initialWeight - percentageDiff
        
        XCTAssertEqual(expectedNewWeight, calculatedNewWeight, accuracy: 0.001)
        XCTAssertEqual(calculatedNewWeight, 5.225, accuracy: 0.001)  // 5.5 * 0.95 = 5.225
    }
}
