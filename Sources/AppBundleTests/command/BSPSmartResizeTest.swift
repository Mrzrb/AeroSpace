@testable import AppBundle
import Common
import XCTest

@MainActor
final class BSPSmartResizeTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    /// Test smart resize in nested BSP containers
    func testSmartResizeInNestedContainers() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create root BSP container with horizontal orientation
        let rootContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Create left window
        let leftWindow = TestWindow.new(id: 1, parent: rootContainer, adaptiveWeight: 100.0)
        
        // Create right nested container with vertical orientation
        let rightContainer = TilingContainer(parent: rootContainer, adaptiveWeight: 100.0, .v, .bsp, index: 1)
        let topRightWindow = TestWindow.new(id: 2, parent: rightContainer, adaptiveWeight: 50.0)
        let bottomRightWindow = TestWindow.new(id: 3, parent: rightContainer, adaptiveWeight: 50.0)
        
        // Focus the top right window
        _ = topRightWindow.focusWindow()
        
        // Test smart resize - should choose the best orientation
        let smartResizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(20)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await smartResizeCommand.run(.defaultEnv, cmdIo)
        
        XCTAssertTrue(result, "Smart resize should succeed")
        XCTAssertTrue(cmdIo.stderr.isEmpty, "Should not have errors: \(cmdIo.stderr)")
        
        // Smart resize should choose the best available option
        // The algorithm may choose horizontal or vertical based on resize potential
        // Let's verify that some resize occurred and the structure is maintained
        
        // Check if horizontal resize occurred (root level)
        let leftWindowWeight = leftWindow.getWeight(.h)
        let rightContainerWeight = rightContainer.getWeight(.h)
        
        // Check if vertical resize occurred (nested level)
        let topRightWeight = topRightWindow.getWeight(.v)
        let bottomRightWeight = bottomRightWindow.getWeight(.v)
        
        // Either horizontal or vertical resize should have occurred
        let horizontalResizeOccurred = (leftWindowWeight != 100.0 || rightContainerWeight != 100.0)
        let verticalResizeOccurred = (topRightWeight != 50.0 || bottomRightWeight != 50.0)
        
        XCTAssertTrue(horizontalResizeOccurred || verticalResizeOccurred, "Some resize should have occurred")
        
        // Verify the total structure is maintained
        XCTAssertEqual(leftWindowWeight + rightContainerWeight, 200.0, accuracy: 0.01, "Horizontal weights should sum correctly")
        XCTAssertEqual(topRightWeight + bottomRightWeight, 100.0, accuracy: 0.01, "Vertical weights should sum correctly")
    }

    /// Test resize potential calculation
    func testResizePotentialCalculation() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create a scenario where one container has more resize potential
        let rootContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Left container with uneven weights (more potential for resize)
        let leftContainer = TilingContainer(parent: rootContainer, adaptiveWeight: 100.0, .v, .bsp, index: 0)
        let leftTopWindow = TestWindow.new(id: 1, parent: leftContainer, adaptiveWeight: 80.0) // Large weight
        let leftBottomWindow = TestWindow.new(id: 2, parent: leftContainer, adaptiveWeight: 20.0) // Small weight
        
        // Right container with even weights (less potential for large resize)
        let rightContainer = TilingContainer(parent: rootContainer, adaptiveWeight: 100.0, .v, .bsp, index: 1)
        let rightTopWindow = TestWindow.new(id: 3, parent: rightContainer, adaptiveWeight: 50.0)
        let rightBottomWindow = TestWindow.new(id: 4, parent: rightContainer, adaptiveWeight: 50.0)
        
        // Focus left top window and try a large resize
        _ = leftTopWindow.focusWindow()
        
        let largeResizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(50)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await largeResizeCommand.run(.defaultEnv, cmdIo)
        
        XCTAssertTrue(result, "Large resize should succeed")
        
        // The smart resize should choose the container with the best resize potential
        // This could be either the left or right container, or even the root container
        
        // Check if any resize occurred
        let leftTopWeight = leftTopWindow.getWeight(.v)
        let leftBottomWeight = leftBottomWindow.getWeight(.v)
        let rightTopWeight = rightTopWindow.getWeight(.v)
        let rightBottomWeight = rightBottomWindow.getWeight(.v)
        let leftContainerWeight = leftContainer.getWeight(.h)
        let rightContainerWeight = rightContainer.getWeight(.h)
        
        // Some resize should have occurred somewhere
        let leftVerticalResized = (leftTopWeight != 80.0 || leftBottomWeight != 20.0)
        let rightVerticalResized = (rightTopWeight != 50.0 || rightBottomWeight != 50.0)
        let horizontalResized = (leftContainerWeight != 100.0 || rightContainerWeight != 100.0)
        
        XCTAssertTrue(leftVerticalResized || rightVerticalResized || horizontalResized, "Some resize should have occurred")
        
        // Verify structural integrity
        XCTAssertEqual(leftTopWeight + leftBottomWeight, 100.0, accuracy: 0.01, "Left container weights should sum correctly")
        XCTAssertEqual(rightTopWeight + rightBottomWeight, 100.0, accuracy: 0.01, "Right container weights should sum correctly")
        XCTAssertEqual(leftContainerWeight + rightContainerWeight, 200.0, accuracy: 0.01, "Root weights should sum correctly")
    }

    /// Test that resize respects minimum weight constraints
    func testResizeWithMinimumWeightConstraints() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create container with one window having very small weight
        let container = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        let window1 = TestWindow.new(id: 1, parent: container, adaptiveWeight: 0.2) // Very small
        let window2 = TestWindow.new(id: 2, parent: container, adaptiveWeight: 100.0) // Large
        
        // Focus window2 and try to grow it significantly
        _ = window2.focusWindow()
        
        let resizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(50)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await resizeCommand.run(.defaultEnv, cmdIo)
        
        XCTAssertTrue(result, "Resize should succeed")
        
        // Window1 should not go below minimum weight
        let newWeight1 = window1.getWeight(.h)
        let newWeight2 = window2.getWeight(.h)
        
        XCTAssertGreaterThanOrEqual(newWeight1, 0.1, "Window1 should not go below minimum weight")
        XCTAssertGreaterThan(newWeight2, 100.0, "Window2 should have gained some weight")
    }

    /// Test smart opposite resize
    func testSmartOppositeResize() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create horizontal root container
        let rootContainer = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // Add nested vertical container
        let nestedContainer = TilingContainer(parent: rootContainer, adaptiveWeight: 100.0, .v, .bsp, index: 0)
        let topWindow = TestWindow.new(id: 1, parent: nestedContainer, adaptiveWeight: 50.0)
        let bottomWindow = TestWindow.new(id: 2, parent: nestedContainer, adaptiveWeight: 50.0)
        
        // Add another window to root
        let rightWindow = TestWindow.new(id: 3, parent: rootContainer, adaptiveWeight: 100.0)
        
        // Focus top window and use smart opposite resize
        _ = topWindow.focusWindow()
        
        let smartOppositeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .add(30)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await smartOppositeCommand.run(.defaultEnv, cmdIo)
        
        XCTAssertTrue(result, "Smart opposite resize should succeed")
        
        // Should resize in horizontal direction (opposite of nested container's vertical orientation)
        let newNestedWeight = nestedContainer.getWeight(.h)
        let newRightWeight = rightWindow.getWeight(.h)
        
        XCTAssertEqual(newNestedWeight, 130.0, accuracy: 0.01, "Nested container should have gained weight")
        XCTAssertEqual(newRightWeight, 70.0, accuracy: 0.01, "Right window should have lost weight")
        
        // Vertical weights within nested container should remain unchanged
        XCTAssertEqual(topWindow.getWeight(.v), 50.0, accuracy: 0.01, "Top window vertical weight unchanged")
        XCTAssertEqual(bottomWindow.getWeight(.v), 50.0, accuracy: 0.01, "Bottom window vertical weight unchanged")
    }

    /// Test resize behavior with deeply nested containers
    func testDeeplyNestedContainerResize() async throws {
        let workspace = Workspace.get(byName: name)
        
        // Create deeply nested structure
        let level1 = TilingContainer(parent: workspace, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        let level2 = TilingContainer(parent: level1, adaptiveWeight: 100.0, .v, .bsp, index: 0)
        let level3 = TilingContainer(parent: level2, adaptiveWeight: 50.0, .h, .bsp, index: 0)
        
        let deepWindow1 = TestWindow.new(id: 1, parent: level3, adaptiveWeight: 25.0)
        let deepWindow2 = TestWindow.new(id: 2, parent: level3, adaptiveWeight: 25.0)
        let _ = TestWindow.new(id: 3, parent: level2, adaptiveWeight: 50.0)
        let _ = TestWindow.new(id: 4, parent: level1, adaptiveWeight: 100.0)
        
        // Focus deep window and use smart resize
        _ = deepWindow1.focusWindow()
        
        let smartResizeCommand = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(10)))
        let cmdIo = CmdIo(stdin: .emptyStdin)
        let result = try await smartResizeCommand.run(.defaultEnv, cmdIo)
        
        XCTAssertTrue(result, "Smart resize in deep nesting should succeed")
        
        // The algorithm should choose the most appropriate level based on resize potential and depth
        // Some resize should have occurred at some level
        
        let deepWindow1Weight = deepWindow1.getWeight(.h)
        let deepWindow2Weight = deepWindow2.getWeight(.h)
        let level3Weight = level3.getWeight(.v)
        let level2Weight = level2.getWeight(.h)
        let _ = level1.getWeight(.h)
        
        // Check if resize occurred at any level
        let level3Resized = (deepWindow1Weight != 25.0 || deepWindow2Weight != 25.0)
        let level2Resized = (level3Weight != 50.0)
        let level1Resized = (level2Weight != 100.0)
        
        XCTAssertTrue(level3Resized || level2Resized || level1Resized, "Resize should have occurred at some level")
        
        // Verify structural integrity at each level
        XCTAssertEqual(deepWindow1Weight + deepWindow2Weight, 50.0, accuracy: 0.01, "Level 3 weights should sum correctly")
    }
}
