@testable import AppBundle
import Common
import XCTest

/// Tests for percentage-based BSP resize (after fix)
@MainActor
final class BSPResizePercentageTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    /// Test: resize +5 should always mean +5% regardless of current weight
    func testResizePlus5_AlwaysMeans5Percent() async throws {
        let testCases: [CGFloat] = [1.0, 5.5, 100.0, 151.0, 500.0]
        
        for initialWeight in testCases {
            let workspace = Workspace.get(byName: "\(name)_\(initialWeight)")
            let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
            
            let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: initialWeight)
            let _ = TestWindow.new(id: 2, parent: container, adaptiveWeight: initialWeight)
            
            _ = window1.focusWindow()
            
            let beforeWeight = window1.getWeight(.h)
            
            let cmd = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(5)))
            _ = try await cmd.run(.defaultEnv, CmdIo(stdin: .emptyStdin))
            
            let afterWeight = window1.getWeight(.h)
            let actualChangePercent = (afterWeight - beforeWeight) / beforeWeight * 100
            
            print("Initial=\(initialWeight): \(beforeWeight) → \(afterWeight) (\(actualChangePercent)%)")
            
            // Should be exactly 5% increase
            XCTAssertEqual(actualChangePercent, 5.0, accuracy: 0.1, 
                "resize +5 should mean +5% for weight \(initialWeight)")
        }
    }

    /// Test: resize -5 should always mean -5% regardless of current weight
    func testResizeMinus5_AlwaysMeans5Percent() async throws {
        let testCases: [CGFloat] = [1.0, 5.5, 100.0, 151.0, 500.0]
        
        for initialWeight in testCases {
            let workspace = Workspace.get(byName: "\(name)_\(initialWeight)")
            let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
            
            let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: initialWeight)
            let _ = TestWindow.new(id: 2, parent: container, adaptiveWeight: initialWeight)
            
            _ = window1.focusWindow()
            
            let beforeWeight = window1.getWeight(.h)
            
            let cmd = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .subtract(5)))
            _ = try await cmd.run(.defaultEnv, CmdIo(stdin: .emptyStdin))
            
            let afterWeight = window1.getWeight(.h)
            let actualChangePercent = (beforeWeight - afterWeight) / beforeWeight * 100
            
            print("Initial=\(initialWeight): \(beforeWeight) → \(afterWeight) (-\(actualChangePercent)%)")
            
            // Should be exactly 5% decrease
            XCTAssertEqual(actualChangePercent, 5.0, accuracy: 0.1,
                "resize -5 should mean -5% for weight \(initialWeight)")
        }
    }

    /// Test: The problematic case from user's config is now fixed
    func testUserConfig_ResizeMinus5_OnSmallWeight() async throws {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Simulate the problematic scenario: weight 5.5
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 5.5)
        let _ = TestWindow.new(id: 2, parent: container, adaptiveWeight: 0.1)
        
        _ = window1.focusWindow()
        
        let beforeWeight = window1.getWeight(.h)
        
        // User's config: resize -5
        let cmd = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .subtract(5)))
        _ = try await cmd.run(.defaultEnv, CmdIo(stdin: .emptyStdin))
        
        let afterWeight = window1.getWeight(.h)
        let changePercent = (beforeWeight - afterWeight) / beforeWeight * 100
        
        print("Before: \(beforeWeight), After: \(afterWeight), Change: \(changePercent)%")
        
        // Before fix: 5.5 → 0.5 (90.9% change) - BAD
        // After fix: 5.5 → 5.225 (5% change) - GOOD
        XCTAssertEqual(afterWeight, 5.225, accuracy: 0.01, "Weight should be 5.5 * 0.95 = 5.225")
        XCTAssertEqual(changePercent, 5.0, accuracy: 0.1, "Change should be exactly 5%")
    }

    /// Test: Multiple resizes should be reversible
    func testResizeReversibility() async throws {
        let workspace = Workspace.get(byName: name)
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 100.0)
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 100.0)
        
        _ = window1.focusWindow()
        
        let initialW1 = window1.getWeight(.h)
        let initialW2 = window2.getWeight(.h)
        
        // Resize +10% five times
        for _ in 1...5 {
            let cmd = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(10)))
            _ = try await cmd.run(.defaultEnv, CmdIo(stdin: .emptyStdin))
        }
        
        let afterIncrease = window1.getWeight(.h)
        print("After 5x +10%: w1=\(afterIncrease)")
        
        // Resize -10% five times (approximately reverse)
        for _ in 1...5 {
            let cmd = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .subtract(10)))
            _ = try await cmd.run(.defaultEnv, CmdIo(stdin: .emptyStdin))
        }
        
        let finalW1 = window1.getWeight(.h)
        print("After 5x -10%: w1=\(finalW1)")
        print("Initial was: \(initialW1)")
        
        // Note: Due to percentage math, +10% then -10% doesn't return to exact original
        // 100 * 1.1 = 110, 110 * 0.9 = 99 (not 100)
        // But it should be close and predictable
        XCTAssertEqual(finalW1, initialW1, accuracy: 10.0, "Should be close to initial after reverse operations")
    }
}
